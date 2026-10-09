# Recognition accept-threshold + margin analysis

**Serves:** PRD **P0-04** ("Handle uncertainty — Unknown/ambiguous input can yield
*Not recognized*; no invented GPS or fake confidence percentage") and supports
P0-03 (max 3 distinct POIs).

**Source data:** `assets/landmarks/reference_embeddings.json`
(dimension 512, model_id `openclip-vit-b32-laion2b-s34b-b79k-int8-dynamic`,
51 reference vectors across 15 landmarks, every landmark has ≥2 references so
leave-one-out INTRA is defined for all).

**Method:** vectors are L2-normalized so cosine == dot product. Each reference
vector was treated as a query. See `analyze.py` (throwaway, outside `lib/`).

- **INTRA** — for each ref, MAX cosine to the OTHER refs of the SAME landmark
  (leave-one-out). Proxy for "a real photo of X scored against X's references".
- **INTER** — for each ref, the best WRONG-landmark score (max over each other
  landmark's refs). Proxy for "a photo matched against the wrong landmark".
- **MARGIN** — per-ref `top1 - top2`, where each landmark's score is the max
  cosine over its refs (exactly `LandmarkMatcher.match`'s aggregation; the
  query's own landmark uses its leave-one-out score so the self-dot of 1.0 does
  not dominate).

## Measured distributions (n=51)

| stat   | INTRA (correct) | INTER (wrong) | MARGIN (top1−top2) |
|--------|-----------------|---------------|--------------------|
| min    | 0.3559          | 0.3859        | 0.0024             |
| p05    | 0.4561          | 0.5396        | 0.0050             |
| p10    | 0.5362          | 0.5838        | 0.0099             |
| p25    | 0.6896          | 0.6275        | 0.0438             |
| median | 0.7729          | 0.6645        | 0.1022             |
| mean   | 0.7443          | 0.6638        | 0.1053             |
| p75    | 0.8558          | 0.7185        | 0.1651             |
| p90    | 0.9053          | 0.7392        | 0.1998             |
| p95    | 0.9201          | 0.7594        | 0.2158             |
| max    | 0.9292          | 0.7970        | 0.2961             |

### Absolute-threshold trade-off (fraction kept)

| threshold | INTRA kept (correct) | INTER kept (wrong accepted) |
|-----------|----------------------|-----------------------------|
| 0.30 | 100.0% | 100.0% |
| 0.35 | 100.0% | 100.0% |
| 0.40 |  98.0% |  98.0% |
| 0.45 |  96.1% |  98.0% |
| 0.50 |  90.2% |  96.1% |
| 0.55 |  84.3% |  92.2% |
| 0.60 |  78.4% |  84.3% |

### Margin trade-off (fraction of refs whose top1−top2 ≥ m)

| margin | refs with a clear winner |
|--------|--------------------------|
| 0.02 | 86.3% |
| 0.03 | 84.3% |
| 0.05 | 68.6% |
| 0.07 | 58.8% |
| 0.10 | 51.0% |
| 0.15 | 31.4% |

## Honest finding: the absolute threshold alone CANNOT separate correct from wrong

The INTRA and INTER distributions overlap massively. The INTER (wrong-landmark)
median is **0.66** and p90 is **0.74**, while the INTRA (correct) p25 is **0.69**
and median **0.77**. At every absolute threshold the fraction of *wrong* matches
accepted is roughly equal to (and sometimes exceeds) the fraction of *correct*
matches kept. There is no single cosine cutoff that cleanly rejects wrong-landmark
matches without also rejecting genuine ones for this model + reference set. This is
stated plainly rather than fabricating a clean separation.

The reason the current single-gate 0.55 confuses users is now clear from the data:
a wrong photo routinely lands in the 0.60–0.74 band, i.e. **above** 0.55, so it is
shown as a confident #1. The absolute threshold is the wrong tool for ambiguity.

**The margin is the real discriminator.** When a photo genuinely depicts one
landmark, that landmark's score should clearly beat the runner-up; when a photo is
generic/ambiguous it sits near-equally close to several landmarks (small margin).
The margin distribution has real spread (median 0.10, p25 0.044), so a margin gate
rejects the near-tie cases that the absolute gate cannot.

## Chosen values and justification

- **`defaultScoreThreshold = 0.40`** (was 0.55)
- **`defaultMinTopMargin = 0.05`** (new)

The real on-device held-out photos were observed at raw cosine **0.36–0.68**, far
below the ~0.9+ typical of reference-to-reference. Setting the absolute threshold
near the INTER median (~0.66) or higher would reject essentially the entire real
held-out band — defeating recognition. So the absolute gate is set to **0.40**:
above the INTER/INTRA floor (both bottom out ~0.36–0.39, i.e. this still rejects
genuine noise and the lowest fraction of near-random matches) and comfortably below
the real-photo band so a genuine dominant match in 0.40–0.68 is still accepted. The
absolute gate is deliberately NOT the primary ambiguity filter — the data shows it
cannot be.

The **margin gate of 0.05** is the stricter-than-today safeguard the user asked for:
when the top-two landmark scores are within 0.05 of each other, the photo is near-
equally close to two landmarks and is rejected as *Not recognized* rather than shown
as a confident #1. From the margin trade-off table, m=0.05 treats the bottom ~31% of
cases (margin < 0.05) as ambiguous while keeping the ~69% with a clear winner. This
is strictly stricter than the old single 0.55 gate for exactly the confusing
near-tie cases, yet it still accepts a genuine dominant match sitting in the
real-photo band. It stays a ranking/accept-reject decision — never presented as a
calibrated probability.

These numbers are derived from the measured reference distribution above weighed
against the observed on-device 0.36–0.68 real-photo band, not guessed.

## Lone-candidate gate (2026-10-10) — aggressive rejection update

**Problem the data confirmed is still open:** the two-gate rule above only runs
the margin gate when **≥2** candidates clear the 0.40 floor. A photo that weakly
matches **exactly one** landmark above 0.40 has no runner-up to trip the margin,
so it leaked through as a lone confident #1. An observed synthetic image hit
**0.4951** on exactly one landmark and passed. The user asked for a more
aggressive rule so non-reference photos reliably read as *Not recognized*.

**New constant chosen — `defaultStrongMatchThreshold = 0.55`.** It applies ONLY
to the sole-above-floor case (where the margin gate cannot apply): a lone
candidate is accepted only if its score ≥ 0.55, otherwise *Not recognized*.
Percentile justification (all from the n=51 table above):

- Must reject the observed lone false hit 0.4951 → value **> 0.4951**. ✓ (0.55)
- A genuine dominant real-photo match can land mid-band in the observed
  **0.36–0.68** raw-cosine band, so the gate must stay **≤ ~0.60** to keep a
  legitimate ~0.55–0.68 lone match. ✓ (0.55 ≤ 0.60)
- Cross-check vs INTRA (correct): INTRA p10 = **0.5362**, p25 = **0.6896**,
  median = **0.7729**. 0.55 sits just above INTRA p10, and INTRA-kept@0.55 =
  **84.3%** from the trade-off table, so it keeps the bulk of correct
  reference-grade matches while rejecting the 0.40–0.55 lone-noise band.

**Margin widened — `defaultMinTopMargin` 0.05 → 0.07** for the ≥2-candidate case.
From the margin trade-off table, m=0.07 keeps **58.8%** of refs with a clear
winner (vs 68.6% at 0.05). The genuine median margin is **0.10**, which still
clears 0.07, so widening rejects a further ~10% of near-tie ambiguous pairs
(the exact confusing cases) at a modest cost to genuine multi-candidate winners.
`defaultScoreThreshold` stays **0.40** (the noise floor; raising it would reject
the real-photo 0.36–0.68 band).

**Honesty:** INTRA (correct) and INTER (wrong) still overlap heavily — INTER
median 0.6645, p90 0.7392 vs INTRA p25 0.6896 — so NO threshold cleanly
separates correct from wrong for this model + reference set. These values are
the most defensible aggressive *ranking* accept/reject decision, never a
calibrated probability or confidence percentage. The strong-match gate closes
the specific lone-candidate hole; the margin gate remains the primary filter for
the multi-candidate case. No clean separation is claimed.
