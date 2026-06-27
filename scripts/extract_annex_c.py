#!/usr/bin/env python3

import json
import re
from pathlib import Path

INPUT = Path("tmp/FWC2026_regulations_EN.txt");
OUTPUT = Path("data/third_place_annex_c.json");

SLOT_LABELS = [
    "3CEFHI",
    "3EFGIJ",
    "3BEFGJ",
    "3ABCDF",
    "3AEHIJ",
    "3CDFGH",
    "3DEIJL",
    "3EHIJK",
];

OPTION_RE = re.compile(r"^\s*(\d{1,3})\b")
TEAM_RE = re.compile(r"3[A-L]")

def combination_from_values(values):
    groups = sorted(value[1] for value in values)
    return "".join(groups)


def main():
    text = INPUT.read_text(encoding="utf-8", errors="replace")
    rows = []

    for line in text.splitlines():
        option_match = OPTION_RE.match(line)
        if not option_match:
            continue

        option = int(option_match.group(1))

        if option < 1 or option > 495:
            continue

        values = TEAM_RE.findall(line)

        if len(values) < 8:
            continue

        values = values[:8]

        slots = {
            slot_label: value[1]
            for slot_label, value in zip(SLOT_LABELS, values)
        }

        rows.append({
            "option": option,
            "combination": combination_from_values(values),
            "slots": slots,
        })

    rows.sort(key=lambda row: row["option"])

    if len(rows) != 495:
        found_options = sorted(row["option"] for row in rows)
        expected_options = list(range(1, 496))
        missing = sorted(set(expected_options) - set(found_options))

        raise SystemExit(
            f"Expected 495 Annexe C rows, got {len(rows)}. "
            f"Missing options: {missing}"
        )

    options = [row["option"] for row in rows]
    expected_options = list(range(1, 496))
    if options != expected_options:
        missing = sorted(set(expected_options) - set(options))
        duplicated = sorted(option for option in set(options) if options.count(option) > 1)
        raise SystemExit(f"Invalid options. Missing={missing}, duplicated={duplicated}")

    combinations = [row["combination"] for row in rows]
    if len(set(combinations)) != 495:
        duplicated = sorted(
            combination
            for combination in set(combinations)
            if combinations.count(combination) > 1
        )
        raise SystemExit(f"Duplicate combinations: {duplicated}")

    current = next((row for row in rows if row["combination"] == "ABDEFGIL"), None)
    if current is None:
        raise SystemExit("Missing current combination ABDEFGIL")

    print("ABDEFGIL option:", current["option"])
    print("ABDEFGIL 3ABCDF:", current["slots"]["3ABCDF"])
    print("ABDEFGIL 3CDFGH:", current["slots"]["3CDFGH"])

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(
        json.dumps(rows, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )

    print(f"Wrote {OUTPUT}")


if __name__ == "__main__":
    main()
