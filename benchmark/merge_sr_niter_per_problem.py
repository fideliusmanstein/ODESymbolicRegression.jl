#!/usr/bin/env python3
"""
merge_sr_niter_per_problem.py

Combine the per-problem result files produced by
sweep_sr_niter_per_problem.sh (one csv/json/txt triple per problem) into a
single combined csv/json for a given niterations_derivative value.

Usage:
    python3 benchmark/merge_sr_niter_per_problem.py \
        --niter 450 \
        --results-dir sr_niter_per_problem \
        --out sr_niter_merged/sr_niter_niter450_merged.csv
"""

import argparse
import csv
import glob
import json
import os


def find_csvs(results_dir, niter):
    pattern = os.path.join(results_dir, f"*_niter{niter}_*_results_*.csv")
    return sorted(glob.glob(pattern))


def find_jsons(results_dir, niter):
    pattern = os.path.join(results_dir, f"*_niter{niter}_*_results_*.json")
    return sorted(glob.glob(pattern))


def merge_csv(csv_paths, out_csv, expected_problems=None):
    fieldnames = None
    rows = []
    seen_problems = set()

    for path in csv_paths:
        with open(path, newline="") as f:
            reader = csv.DictReader(f)
            if fieldnames is None:
                fieldnames = reader.fieldnames
            for row in reader:
                rows.append(row)
                seen_problems.add(row["problem"])

    if fieldnames is None:
        raise SystemExit("No csv files found -- nothing to merge.")

    rows.sort(key=lambda r: r["problem"])

    os.makedirs(os.path.dirname(out_csv) or ".", exist_ok=True)
    with open(out_csv, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    print(f"[merge] {len(rows)} problems written to {out_csv}")

    if expected_problems is not None:
        missing = set(expected_problems) - seen_problems
        extra = seen_problems - set(expected_problems)
        if missing:
            print(f"[merge] WARNING: missing problems (not yet finished?): {sorted(missing)}")
        if extra:
            print(f"[merge] WARNING: unexpected extra problems: {sorted(extra)}")

    return rows


def merge_json(json_paths, out_json):
    merged = None
    all_results = []

    for path in json_paths:
        with open(path) as f:
            data = json.load(f)
        if merged is None:
            merged = dict(data)
        all_results.extend(data.get("results", []))

    if merged is None:
        raise SystemExit("No json files found -- nothing to merge.")

    merged["results"] = all_results

    os.makedirs(os.path.dirname(out_json) or ".", exist_ok=True)
    with open(out_json, "w") as f:
        json.dump(merged, f, indent=4)

    print(f"[merge] {len(all_results)} problems written to {out_json}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--niter", required=True, type=int)
    parser.add_argument("--results-dir", required=True)
    parser.add_argument("--out", required=True, help="output csv path")
    parser.add_argument("--out-json", help="output json path (default: same basename as --out, .json)")
    parser.add_argument(
        "--expect",
        help="comma-separated list of problem names expected to be present (warns if any are missing)",
    )
    args = parser.parse_args()

    expected = args.expect.split(",") if args.expect else None

    csv_paths = find_csvs(args.results_dir, args.niter)
    merge_csv(csv_paths, args.out, expected_problems=expected)

    json_paths = find_jsons(args.results_dir, args.niter)
    if json_paths:
        out_json = args.out_json or os.path.splitext(args.out)[0] + ".json"
        merge_json(json_paths, out_json)


if __name__ == "__main__":
    main()
