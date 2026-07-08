#!/usr/bin/env python3
"""
merge_sr_niter_batches.py

Combine the "fast" (20 easy problems) and "hard" (ss_5genes4, threeGenes1)
batch results from sweep_sr_niter.sh into one 22-problem csv/json per
niterations_derivative value, matching the original single-batch schema.

Usage:
    python3 benchmark/merge_sr_niter_batches.py \
        --fast-csv sr_niter/sr_niter_..._niter150_fast_results_<ts>.csv \
        --hard-csv sr_niter/sr_niter_..._niter150_hard_results_<ts>.csv \
        --out sr_niter_merged/sr_niter_..._niter150_merged.csv
"""

import argparse
import csv
import json
import os


def read_csv_rows(path):
    with open(path, newline="") as f:
        reader = csv.DictReader(f)
        return list(reader.fieldnames), list(reader)


def merge_csv(fast_csv, hard_csv, out_csv):
    fieldnames, fast_rows = read_csv_rows(fast_csv)
    _, hard_rows = read_csv_rows(hard_csv)

    combined = fast_rows + hard_rows
    combined.sort(key=lambda r: r["problem"])

    os.makedirs(os.path.dirname(out_csv) or ".", exist_ok=True)
    with open(out_csv, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(combined)

    print(f"[merge] {len(combined)} problems written to {out_csv}")
    return combined


def merge_json(fast_json, hard_json, out_json):
    with open(fast_json) as f:
        fast_data = json.load(f)
    with open(hard_json) as f:
        hard_data = json.load(f)

    # Results are expected under a "results" list; merge and keep the rest
    # of the fast run's metadata as the base.
    merged = dict(fast_data)
    fast_results = fast_data.get("results", [])
    hard_results = hard_data.get("results", [])
    merged["results"] = fast_results + hard_results

    os.makedirs(os.path.dirname(out_json) or ".", exist_ok=True)
    with open(out_json, "w") as f:
        json.dump(merged, f, indent=4)

    print(f"[merge] {len(merged['results'])} problems written to {out_json}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fast-csv", required=True)
    parser.add_argument("--hard-csv", required=True)
    parser.add_argument("--out", required=True, help="output csv path")
    parser.add_argument("--fast-json", help="optional: also merge matching json files")
    parser.add_argument("--hard-json")
    parser.add_argument("--out-json")
    args = parser.parse_args()

    merge_csv(args.fast_csv, args.hard_csv, args.out)

    if args.fast_json and args.hard_json:
        out_json = args.out_json or os.path.splitext(args.out)[0] + ".json"
        merge_json(args.fast_json, args.hard_json, out_json)


if __name__ == "__main__":
    main()
