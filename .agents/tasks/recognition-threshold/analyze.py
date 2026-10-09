#!/usr/bin/env python3
"""Throwaway analysis for the recognition accept-threshold + margin gate.

Reference vectors in reference_embeddings.json are L2-normalized, so cosine
similarity == dot product. We treat each reference vector as a query and compute:

  INTRA  : for each ref vector, its MAX cosine to the OTHER refs of the SAME
           landmark (leave-one-out). Proxy for "real photo of X vs X refs".
  INTER  : for each ref vector, its MAX cosine to the BEST OTHER landmark's refs.
           Proxy for "photo matched against the WRONG landmark".
  MARGIN : (best landmark score) - (second-best landmark score) for each ref
           vector, where per-landmark score = max cosine over that landmark's
           refs (the exact aggregation LandmarkMatcher.match uses).

NOTE: reference-vs-reference scores are an OPTIMISTIC proxy. Real held-out
on-device photos were observed in the 0.36-0.68 raw-cosine band, far below the
~0.9+ typical of reference-to-reference. The chosen numbers are weighed against
both distributions. This script lives outside lib/ and is not shipped.
"""
import json
import math
import statistics
from collections import defaultdict

PATH = "assets/landmarks/reference_embeddings.json"


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def pct(sorted_vals, p):
    if not sorted_vals:
        return float("nan")
    k = (len(sorted_vals) - 1) * (p / 100.0)
    lo = math.floor(k)
    hi = math.ceil(k)
    if lo == hi:
        return sorted_vals[int(k)]
    return sorted_vals[lo] * (hi - k) + sorted_vals[hi] * (k - lo)


def describe(name, vals):
    s = sorted(vals)
    print(f"\n== {name} (n={len(s)}) ==")
    print(f"  min    {min(s):.4f}")
    print(f"  p05    {pct(s,5):.4f}")
    print(f"  p10    {pct(s,10):.4f}")
    print(f"  p25    {pct(s,25):.4f}")
    print(f"  median {statistics.median(s):.4f}")
    print(f"  mean   {statistics.mean(s):.4f}")
    print(f"  p75    {pct(s,75):.4f}")
    print(f"  p90    {pct(s,90):.4f}")
    print(f"  p95    {pct(s,95):.4f}")
    print(f"  max    {max(s):.4f}")
    return s


def main():
    data = json.load(open(PATH))
    dim = data["dimension"]
    refs = data["references"]
    print(f"dimension={dim}  model_id={data['model_id']}  n_refs={len(refs)}")

    by_lm = defaultdict(list)
    for r in refs:
        by_lm[r["landmark_id"]].append(r["vector"])
    print(f"landmarks={len(by_lm)}")

    single_ref = [lm for lm, v in by_lm.items() if len(v) < 2]
    if single_ref:
        print(f"landmarks with <2 refs (skipped in INTRA): {single_ref}")
    else:
        print("every landmark has >=2 refs (INTRA defined for all)")

    intra, inter, margin = [], [], []

    for lm, vecs in by_lm.items():
        for i, q in enumerate(vecs):
            # INTRA: leave-one-out max over same landmark's OTHER refs.
            same_others = [dot(q, v) for j, v in enumerate(vecs) if j != i]
            if same_others:
                intra.append(max(same_others))

            # per-landmark score = max cosine over that landmark's refs,
            # but for the query's OWN landmark use leave-one-out so the self
            # (==1.0) doesn't dominate; for other landmarks use plain max.
            lm_scores = {}
            for other_lm, other_vecs in by_lm.items():
                if other_lm == lm:
                    if same_others:
                        lm_scores[other_lm] = max(same_others)
                else:
                    lm_scores[other_lm] = max(dot(q, v) for v in other_vecs)

            # INTER: best score among the WRONG landmarks.
            wrong = [s for olm, s in lm_scores.items() if olm != lm]
            if wrong:
                inter.append(max(wrong))

            # MARGIN: top1 - top2 across the per-landmark scores.
            ordered = sorted(lm_scores.values(), reverse=True)
            if len(ordered) >= 2:
                margin.append(ordered[0] - ordered[1])

    describe("INTRA (same-landmark best, leave-one-out)", intra)
    describe("INTER (best WRONG-landmark)", inter)
    describe("MARGIN (top1 - top2)", margin)

    # How much intra would be retained / inter rejected at candidate thresholds.
    print("\n== threshold trade-off (fraction kept) ==")
    for t in (0.30, 0.35, 0.40, 0.45, 0.50, 0.55, 0.60):
        intra_keep = sum(1 for x in intra if x >= t) / len(intra)
        inter_keep = sum(1 for x in inter if x >= t) / len(inter)
        print(
            f"  t={t:.2f}  intra_kept={intra_keep:6.1%}  "
            f"inter_kept(wrong accepted)={inter_keep:6.1%}"
        )

    print("\n== margin trade-off (fraction of refs whose top1-top2 >= m) ==")
    for m in (0.02, 0.03, 0.05, 0.07, 0.10, 0.15):
        keep = sum(1 for x in margin if x >= m) / len(margin)
        print(f"  m={m:.2f}  refs_with_clear_winner={keep:6.1%}")


if __name__ == "__main__":
    main()
