import argparse
import csv
from collections import defaultdict
from pathlib import Path


def to_float(value: str) -> float:
    try:
        return float((value or "").strip())
    except ValueError:
        return 0.0


def group_year_file(input_csv: Path, output_csv: Path) -> int:
    grouped = defaultdict(lambda: {"total_insured_capital": 0.0, "policy_count": 0})

    with input_csv.open("r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            commune = (row.get("COMMUNE_NAME") or "").strip()
            if not commune:
                continue

            grouped[commune]["total_insured_capital"] += to_float(row.get("INSURED_CAPITAL", ""))
            grouped[commune]["policy_count"] += 1

    with output_csv.open("w", encoding="utf-8", newline="") as f:
        fieldnames = ["COMMUNE_NAME", "TOTAL_INSURED_CAPITAL", "POLICY_COUNT"]
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()

        for commune in sorted(grouped):
            writer.writerow(
                {
                    "COMMUNE_NAME": commune,
                    "TOTAL_INSURED_CAPITAL": f"{grouped[commune]['total_insured_capital']:.2f}",
                    "POLICY_COUNT": grouped[commune]["policy_count"],
                }
            )

    return len(grouped)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Group insured capital by commune for yearly cleaned CSV files with zones."
    )
    parser.add_argument("--years", nargs="+", default=["2023", "2024", "2025"])
    parser.add_argument("--input-prefix", default="cleaned_")
    parser.add_argument("--input-suffix", default="_with_zones.csv")
    parser.add_argument("--output-suffix", default="_capital_by_commune.csv")
    args = parser.parse_args()

    for year in args.years:
        input_csv = Path(f"{args.input_prefix}{year}{args.input_suffix}")
        output_csv = Path(f"cleaned_{year}{args.output_suffix}")

        if not input_csv.exists():
            print(f"Skipped {year}: missing file {input_csv}")
            continue

        total_communes = group_year_file(input_csv, output_csv)
        print(f"Wrote {output_csv} ({total_communes} communes)")


if __name__ == "__main__":
    main()
