# Data-driven accept decision: absolute threshold + top-1/top-2 margin gate

The change tightens `LandmarkMatcher`'s accept decision from a single absolute-cosine gate into two gates: an absolute minimum cosine (`defaultScoreThreshold`, lowered 0.55 → 0.40) and a new top-1-minus-top-2 margin (`defaultMinTopMargin = 0.05`). The intent is that weak or ambiguous photos read as "Not recognized" instead of being surfaced as a confident #1. The design rests on a measured reference-embedding study (`analysis.md`, reproduced from `analyze.py`) which shows the absolute threshold alone cannot separate correct from wrong-landmark matches, so the margin gate is made the primary ambiguity filter and the absolute gate is pulled down to a noise floor that preserves the observed on-device real-photo band (raw cosine 0.36–0.68). The new parameter is threaded through the private constructor and all three factories mirroring `scoreThreshold`, and the test file gains five focused cases while fixing one fixture that the new margin gate would otherwise reject.

Watch for: (1) the task spec's margin gate carried an "and the top is not strongly above threshold" escape clause that the implementation deliberately omits — this is a justified deviation, not a bug (confirmed). (2) The absolute threshold now accepts 98% of *wrong*-landmark reference pairs; the margin gate alone carries the discrimination load (confirmed, and this is openly stated in the analysis).

**Verdict**: APPROVED

## High-level view

The honesty bar is met. Every percentile, trade-off fraction, and the 0.40/0.05 choice in `analysis.md` reproduces exactly from the shipped reference asset (512-dim, 51 refs, 15 landmarks, ≥3 refs each) when `analyze.py` is re-run. The analysis explicitly refuses to claim a clean separation the data does not support — it states plainly that INTRA (correct) and INTER (wrong) cosine distributions overlap so heavily that no absolute cutoff separates them, and that reference-to-reference scores are an optimistic proxy weighed against the observed 0.36–0.68 on-device band. The score stays documented as a ranking signal, never a probability or percentage.

The correctness contract holds. Cosine remains a plain dot product with no re-normalization, max-per-landmark aggregation and descending sort are unchanged, the ≤3-distinct-id cap is preserved, and the `FormatException` validation on dimension and non-finite values is untouched. The margin gate fires after the absolute threshold and sort: with ≥2 survivors and `top1 - top2 < minTopMargin` it returns an empty `MatchResult`. `LandmarkCandidate` and `MatchResult` public shapes are unchanged.

The one divergence from the task's written criterion is the missing "top is not strongly above threshold" escape on the margin gate. The implementation rejects purely on `count >= 2 && margin < minTopMargin`. This is the correct call for this dataset: the data shows wrong-landmark matches routinely land at high absolute cosine (INTER median 0.66), so an absolute-score escape hatch would re-admit exactly the confusing cases the task set out to suppress. The deviation makes the gate stricter and more honest, consistent with `analysis.md`.

Threading is exact. `minTopMargin` is a named parameter defaulting to `defaultMinTopMargin` on `fromDecodedJson`, `fromJsonString`, and `load`, and a positional field on the private constructor in the same slot style as `scoreThreshold`.

Scope is clean. Only `landmark_matcher.dart` and `landmark_matcher_test.dart` changed under the approved set, plus notes under `.agents/tasks/recognition-threshold`. The map files are byte-identical to HEAD. The prior crash-fix uncommitted changes (`README.md`, `android/app/build.gradle.kts`, `MainActivity.kt`) exist in the working tree but were last modified ~04:43–04:50 versus this task's ~06:03 edits, and their diffs contain no threshold/margin/recognition logic — they are untouched prior work.

<details>
<summary>Issues (2)</summary>

1. **Margin gate omits the "strongly above threshold" escape** — the task description's margin condition included "and the top is not strongly above threshold"; the implementation rejects unconditionally on `count>=2 && margin<minTopMargin`. Non-blocking: justified by the measured INTER distribution and consistent with analysis.md; worth a one-line acknowledgement that the spec parenthetical was intentionally dropped.
2. **Absolute gate accepts ~98% of wrong-landmark pairs at 0.40** — the absolute threshold does almost no discrimination; all ambiguity rejection rests on the 0.05 margin gate. Non-blocking and openly documented, but means the gate's effectiveness is entirely sensitive to the margin value; flagged so future tuning targets the margin, not the threshold.

</details>

<details>
<summary>Details</summary>

### Honesty: numbers trace to measured data, reproduced from source

The core honesty claim — that 0.40 and 0.05 are measured, not guessed — holds under re-execution. Running `analyze.py` against `assets/landmarks/reference_embeddings.json` reproduces every figure in the distribution table (INTRA median 0.7729, INTER median 0.6645, MARGIN median 0.1022) and both trade-off tables (e.g. threshold 0.40 keeps 98.0% INTRA / 98.0% INTER; margin 0.05 keeps 68.6% of refs) bit-for-bit. The asset metadata the analysis cites is accurate: dimension 512, 51 references, 15 landmarks, minimum 3 refs per landmark so leave-one-out INTRA is defined everywhere.

The analysis does the hard, honest thing. Rather than fabricate a clean threshold that separates correct from wrong, it states the opposite outright: "There is no single cosine cutoff that cleanly rejects wrong-landmark matches without also rejecting genuine ones for this model + reference set." It explains *why* the old 0.55 single gate confused users (wrong photos routinely land in 0.60–0.74, above 0.55, so they showed as confident #1) and uses that to motivate shifting the discrimination load onto the margin. The reconciliation the review was asked to check is present and correct: 0.40 is chosen specifically because the observed on-device real-photo band is 0.36–0.68, so a higher absolute gate near the INTER median would reject genuine matches. The threshold is set just above the ~0.36–0.39 noise floor to preserve that band.

The doc comments on both constants carry the "ranking signal, NOT a calibrated probability — never present as a percentage" framing, and the `match` docstring and inline comments repeat it. This satisfies AGENTS.md §8's "no pretending similarity is calibrated probability."

### The margin gate and the dropped "strongly above threshold" escape

```
candidates.sort(desc by score)
if candidates.length >= 2:
    margin = candidates[0].score - candidates[1].score
    if margin < minTopMargin:
        return MatchResult([])     # Not recognized
kept = candidates[:maxCandidates]
return MatchResult(kept)
```

The task's criterion #2 phrased the reject condition as "`(top1 - top2) < minTopMargin` **and the top is not strongly above threshold**." The shipped code has no "strongly above threshold" term — it rejects on count and margin alone. This is the one place implementation and task text diverge, and it resolves in the implementation's favor. An absolute-score escape hatch would say "if top1 is high enough, accept even a near-tie." But `analysis.md` measures that wrong-landmark matches cluster at high absolute cosine (INTER p90 = 0.74), so "top1 is high" does not imply "top1 is correct." Adding the escape would re-admit precisely the high-cosine near-ties the task exists to suppress. Dropping it makes the gate strictly stricter and matches the analysis's stated design that the margin — not the absolute score — is the discriminator. Worth one line in the notes acknowledging the spec parenthetical was intentionally not implemented, but not a blocking defect.

### Preserved invariants

Verified against the diff that the task's required invariants did not regress: the dot-product loop is unchanged (no re-normalization), per-landmark max aggregation and descending sort are intact, the `maxCandidates` cap still yields at most 3 distinct ids (one entry per landmark in `_refsByLandmark`), both `FormatException` paths are byte-identical, and `LandmarkCandidate`/`MatchResult` are not touched so their public shapes and `isRecognized`/`top` accessors are unchanged.

### Threading of minTopMargin

`minTopMargin` is added as a positional field on the private constructor in the same slot pattern as `scoreThreshold`, and as a named parameter `minTopMargin = defaultMinTopMargin` on all three factories. `fromJsonString` forwards it into `fromDecodedJson`; `load` forwards it into `fromJsonString`. This mirrors `scoreThreshold` exactly, satisfying criterion #3.

### Test coverage

Five new cases cover the behavior the task asked for: a within-margin near-tie (two refs at ~0.707 to a diagonal query) → Not recognized; a clear dominant winner (margin 0.4 ≫ 0.05) → recognized; below-absolute-threshold with no tie → Not recognized; a single candidate above threshold → accepted (margin gate not applicable); and a defaults assertion pinning `defaultScoreThreshold == 0.40` and `defaultMinTopMargin == 0.05`. The "caps the result at 3" fixture was rewritten rather than gutted — the old near-identical scores ([0.9999, 0.0141] etc.) would now trip the margin gate, so it was changed to give `alpha` cosine 1.0 with the runner-ups spread to 0.707/0.6/0.55, which both clears the margin and still exercises the 3-distinct-id cap. The existing below-threshold and validation tests remain.

Not tested: the near-tie fixture uses `margin=0.0000` (an exact tie), so the strict-inequality boundary at exactly `margin == minTopMargin` (which should be *accepted*, since the gate rejects only when `margin < minTopMargin`) is not directly asserted. Low risk given the clear-winner case sits far on the accept side, but a boundary case at `margin == 0.05` would nail the `<` vs `<=` contract.

### Verification evidence

`verification.md` records `flutter pub get` (clean), `flutter analyze` (No issues found), and `flutter test` (60 passed, including the matcher file's 14), with the ambiguity-gate debug line quoted. Per the review instruction I did not re-run the suites; the evidence is specific and internally consistent (test names in the verification match the test file), so no articulable doubt remains that would justify a spot-check of the suites. The one spot-check I did perform — re-running the read-only `analyze.py` to confirm the data behind the chosen numbers — reproduced the analysis exactly. The verification also correctly scopes out device/APK and 8 GB memory proof as a separate obligation (AGENTS.md §9), which is accurate for a pure recognition-logic change.

### Scope

`git diff --stat lib/features/map/` is empty — the map files are unchanged, satisfying the hard constraint. The only approved-set files changed are `landmark_matcher.dart` and `landmark_matcher_test.dart`; no new packages, no new files under `lib/`. The crash-fix files (`README.md`, `android/app/build.gradle.kts`, `MainActivity.kt`) are present in the working tree as uncommitted changes but belong to the prior OpenCLIP-crash task: their mtimes (~04:43–04:50) predate this task's edits (~06:03), and grepping their diffs for threshold/margin/recognition logic returns only pre-existing product copy in README, no accept-decision changes. They were not touched by this task.

</details>

<details>
<summary>File map</summary>

- `lib/features/recognition/landmark_matcher.dart` — `defaultScoreThreshold` 0.55→0.40; new `defaultMinTopMargin = 0.05` + field; threaded through private ctor and 3 factories; margin gate added to `match()` after sort; debug logging extended.
- `test/landmark_matcher_test.dart` — rewrote the 3-cap fixture to clear the new margin gate; added 5 cases (near-tie reject, clear winner accept, below-threshold reject, single-candidate accept, defaults pin).
- `.agents/tasks/recognition-threshold/analysis.md`, `analyze.py`, `verification.md` — data study, reproducible analysis script, and command log (notes only, outside `lib/`).

Full diff: `git diff lib/features/recognition/landmark_matcher.dart test/landmark_matcher_test.dart`.

</details>
