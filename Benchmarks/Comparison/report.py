#!/usr/bin/env python3
"""Turns the text output of `swift package benchmark --time-units nanoseconds` into Markdown tables, one per workload.

    python3 report.py raw.txt > report.md

A workload is a benchmark name without its last path component; the last component is the variant. Each table lists the
variants fastest first, with the median, tail, allocation count, and the speed relative to AemiJSON's reference variant
(`json.AemiJSON.codable` when the workload has one, otherwise the first AemiJSON variant). Above 1.0 is faster.
"""
import re
import sys
from collections import OrderedDict

ROW = re.compile(r"^│\s*(?P<metric>[^│]+?)\s*│(?P<cells>.*)│\s*$")


def parse(path):
    results = OrderedDict()
    name = None
    for line in open(path, encoding="utf-8"):
        line = line.rstrip("\n")
        if re.match(r"^[a-z0-9]+(/[A-Za-z0-9_.]+)+$", line):
            name = line
            results[name] = {}
            continue
        m = ROW.match(line)
        if m and name:
            cells = [c.strip() for c in m.group("cells").split("│")]
            if not cells or not re.match(r"^-?\d", cells[0]):
                continue
            metric = m.group("metric")
            key = ("wall" if "wall clock" in metric else "cpu" if "total CPU" in metric
                   else "malloc" if "Malloc (total)" in metric else "tput" if "Throughput" in metric else None)
            if key:
                # A count is printed scaled and rounded to three digits: "(K)" means thousands, "(M)" millions.
                unit = re.search(r"\((K|M|G)\)", metric)
                scale = {"K": 1e3, "M": 1e6, "G": 1e9}.get(unit.group(1), 1.0) if unit else 1.0
                results[name][key] = [float(c) * scale for c in cells[:7]] + [int(cells[7])]
                results[name][key + "_scaled"] = scale > 1
    return results


def fmt_ns(ns):
    if ns >= 1e9:
        return f"{ns / 1e9:.2f} s"
    if ns >= 1e6:
        return f"{ns / 1e6:.2f} ms"
    if ns >= 1e3:
        return f"{ns / 1e3:.1f} µs"
    return f"{ns:.0f} ns"


def main():
    results = parse(sys.argv[1])
    workloads = OrderedDict()
    for name, metrics in results.items():
        if "wall" not in metrics:
            continue
        workload, _, variant = name.rpartition("/")
        workloads.setdefault(workload, OrderedDict())[variant] = metrics
    for workload, variants in workloads.items():
        ref = variants.get("json.AemiJSON.codable") or next(
            (m for v, m in variants.items() if v.startswith("json.AemiJSON")), None)
        print(f"#### `{workload}`\n")
        print("| variant | p50 | p90 | p99 | allocations | samples | vs AemiJSON |")
        print("|---|---:|---:|---:|---:|---:|---:|")
        for variant, m in sorted(variants.items(), key=lambda kv: kv[1]["wall"][2]):
            w = m["wall"]
            mallocs = "-"
            if "malloc" in m:
                mallocs = ("~" if m["malloc_scaled"] else "") + f"{int(m['malloc'][2]):,}"
            speed = f"{ref['wall'][2] / w[2]:.2f}×" if ref else "-"
            print(f"| {variant} | {fmt_ns(w[2])} | {fmt_ns(w[4])} | {fmt_ns(w[5])} | {mallocs} | {w[7]} | {speed} |")
        print()


main()
