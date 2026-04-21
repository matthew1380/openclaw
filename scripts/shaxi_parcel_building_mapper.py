#!/usr/bin/env python3
"""
Shaxi Parcel/Building Mapper for Rental OS.

Maps raw Chinese location strings to normalized parcel/building/area codes
following the official Shaxi truth.

Hierarchy:
    site -> parcel -> building -> rentable area

Shaxi truth:
    一区 = SX39-Q1 (certificate 0233015, 港园村, building 1)
    二区 = SX39-Q2 (certificate 0230865, 下泽村, buildings A/B/C)
    三区 = SX39-Q3 (certificate 0231461, 下泽村, buildings A/B/C)
    四区 = SX39-Q4 (certificate 0230864, 下泽村, buildings A/B/C)

Important: A/B/C is only unique inside a parcel.
`三区A栋` and `四区A栋` are different buildings.

Rules:
- Never guess ambiguous locations.
- Route unmatched or low-confidence strings to a review queue.
- Preserve the original raw string for audit.
- Broad/vague remainders (e.g. `主租区域`, `整栋`, `首层及2至4楼` without card specificity)
  are treated as low-confidence review items.
- Do not modify raw source files.
"""

import argparse
import csv
import re
import sys
from pathlib import Path


# Official Shaxi parcel/building truth
PARCEL_TRUTH = {
    "一区": {"parcel_code": "SX39-Q1", "certificate": "0233015", "village": "港园村", "buildings": ["1"]},
    "二区": {"parcel_code": "SX39-Q2", "certificate": "0230865", "village": "下泽村", "buildings": ["A", "B", "C"]},
    "三区": {"parcel_code": "SX39-Q3", "certificate": "0231461", "village": "下泽村", "buildings": ["A", "B", "C"]},
    "四区": {"parcel_code": "SX39-Q4", "certificate": "0230864", "village": "下泽村", "buildings": ["A", "B", "C"]},
}

PARCEL_CODE_TO_NAME = {v["parcel_code"]: k for k, v in PARCEL_TRUTH.items()}

OUTPUT_COLUMNS = [
    "raw_location",
    "property_code",
    "parcel_code",
    "parcel_name",
    "building_code",
    "building_name",
    "area_name",
    "floor_label",
    "card_or_room_label",
    "confidence",
    "mapping_rule",
    "notes",
]

REVIEW_COLUMNS = [
    "raw_location",
    "review_reason",
    "suggested_action",
    "matched_partial",
]


def classify_remainder(remainder: str) -> tuple[str, str]:
    """
    Classify the remainder portion of a location string.
    Returns (confidence, note).
    """
    if not remainder:
        return "medium", "parcel_building_only_no_remainder"

    r = remainder.strip()

    # Specific card/room patterns indicate high confidence
    has_specific_card = bool(re.search(r"\d+卡|\d+房", r))
    if has_specific_card:
        return "high", "specific_card_or_room_found"

    # Broad/vague patterns indicate low confidence
    broad_patterns = [
        r"主租区域",
        r"整栋",
        r"全部",
        r"全体",
        r"整租",
        r"主租",
        r"首层及\d+至\d+[层楼]",
        r"\d+至\d+[层楼]",
        r"及\d+至\d+[层楼]",
    ]
    for pattern in broad_patterns:
        if re.search(pattern, r):
            return "low", f"broad_vague_remainder: matched_pattern={pattern}"

    # Floor-only patterns (no card) indicate medium confidence
    has_floor = bool(re.search(r"首层|\d+[层楼]", r))
    if has_floor:
        return "medium", "floor_label_without_specific_card"

    # Anything else is medium confidence (we have a building but unclear area detail)
    return "medium", "building_matched_unclear_area_detail"


def try_match_location(raw: str) -> tuple[dict | None, str, str]:
    """
    Try to parse a raw location string.
    Returns (mapped_record, confidence, rule_name) or (None, "", "") if unmapped.
    """
    if not raw or not raw.strip():
        return None, "", ""

    s = raw.strip()

    # Pattern: parcel + building + remainder, e.g. 三区A栋首层2卡
    m = re.search(r"(一区|二区|三区|四区)([1ABC])栋?(.+)?", s)
    if m:
        parcel_name = m.group(1)
        building_label = m.group(2)
        remainder = m.group(3) or ""

        parcel_info = PARCEL_TRUTH.get(parcel_name)
        if not parcel_info:
            return None, "", ""

        if building_label not in parcel_info["buildings"]:
            # Invalid building for parcel
            return None, "", ""

        parcel_code = parcel_info["parcel_code"]
        building_code = f"{parcel_code}-{building_label}"
        building_name = f"{parcel_name}{building_label}栋"

        # Extract floor and card labels from remainder
        floor_label = ""
        card_label = ""

        floor_match = re.search(r"(首层|\d+层|\d+楼|首层及[\d至\-]+层|首层及[\d至\-]+楼)", remainder)
        if floor_match:
            floor_label = floor_match.group(1)

        card_match = re.search(r"(\d+卡|\d+房)", remainder)
        if card_match:
            card_label = card_match.group(1)

        area_name = f"{building_name}{remainder}".strip()

        confidence, note = classify_remainder(remainder)

        record = {
            "raw_location": raw,
            "property_code": "SX-39",
            "parcel_code": parcel_code,
            "parcel_name": parcel_name,
            "building_code": building_code,
            "building_name": building_name,
            "area_name": area_name,
            "floor_label": floor_label,
            "card_or_room_label": card_label,
            "confidence": confidence,
            "mapping_rule": "parcel_building_remainder",
            "notes": f"certificate={parcel_info['certificate']}, village={parcel_info['village']}; {note}",
        }
        return record, confidence, record["mapping_rule"]

    # Pattern: parcel name alone, e.g. "二区"
    m2 = re.search(r"^(一区|二区|三区|四区)$", s)
    if m2:
        parcel_name = m2.group(1)
        parcel_info = PARCEL_TRUTH.get(parcel_name)
        if parcel_info:
            record = {
                "raw_location": raw,
                "property_code": "SX-39",
                "parcel_code": parcel_info["parcel_code"],
                "parcel_name": parcel_name,
                "building_code": "",
                "building_name": "",
                "area_name": parcel_name,
                "floor_label": "",
                "card_or_room_label": "",
                "confidence": "low",
                "mapping_rule": "parcel_only",
                "notes": "parcel-level only; building/area undetermined",
            }
            return record, "low", "parcel_only"

    # Pattern: SX39-QX style codes directly
    m3 = re.search(r"(SX39-Q[1-4])[-]?([1ABC])?", s.upper())
    if m3:
        parcel_code = m3.group(1)
        building_label = m3.group(2) or ""
        parcel_name = PARCEL_CODE_TO_NAME.get(parcel_code)
        if parcel_name:
            parcel_info = PARCEL_TRUTH[parcel_name]
            if building_label and building_label in parcel_info["buildings"]:
                building_code = f"{parcel_code}-{building_label}"
                building_name = f"{parcel_name}{building_label}栋"
            else:
                building_code = ""
                building_name = ""
            record = {
                "raw_location": raw,
                "property_code": "SX-39",
                "parcel_code": parcel_code,
                "parcel_name": parcel_name,
                "building_code": building_code,
                "building_name": building_name,
                "area_name": s,
                "floor_label": "",
                "card_or_room_label": "",
                "confidence": "medium" if building_code else "low",
                "mapping_rule": "code_pattern",
                "notes": "",
            }
            return record, record["confidence"], "code_pattern"

    return None, "", ""


def process_row(raw_location: str, row_index: int) -> tuple[dict | None, dict | None]:
    record, confidence, rule = try_match_location(raw_location)
    if record is None:
        review = {
            "raw_location": raw_location,
            "review_reason": "no_matching_pattern",
            "suggested_action": "manual_review_add_custom_rule",
            "matched_partial": "",
        }
        return None, review

    if confidence == "low":
        review = {
            "raw_location": raw_location,
            "review_reason": f"low_confidence_match: {rule}",
            "suggested_action": "confirm_area_split_or_add_precision",
            "matched_partial": record.get("building_code", ""),
        }
        return record, review

    return record, None


def main():
    parser = argparse.ArgumentParser(
        description="Map raw Shaxi location strings to parcel/building/area codes."
    )
    parser.add_argument("input_csv", type=Path, help="CSV containing raw location strings.")
    parser.add_argument(
        "--location-column", type=str, default="location",
        help="Column name with raw location text."
    )
    parser.add_argument(
        "--output-mapped", type=Path, default=Path("shaxi_mapped_locations.csv")
    )
    parser.add_argument(
        "--output-review", type=Path, default=Path("shaxi_mapping_review_queue.csv")
    )
    args = parser.parse_args()

    if not args.input_csv.exists():
        print(f"ERROR: Input file not found: {args.input_csv}", file=sys.stderr)
        sys.exit(1)

    mapped_rows = []
    review_rows = []

    with args.input_csv.open("r", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        for idx, row in enumerate(reader, start=2):
            raw = row.get(args.location_column, "").strip()
            if not raw:
                continue
            mapped, review = process_row(raw, idx)
            if mapped:
                mapped_rows.append(mapped)
            if review:
                review_rows.append(review)

    with args.output_mapped.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=OUTPUT_COLUMNS)
        writer.writeheader()
        writer.writerows(mapped_rows)

    with args.output_review.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=REVIEW_COLUMNS)
        writer.writeheader()
        writer.writerows(review_rows)

    print(f"Mapped locations: {len(mapped_rows)}")
    print(f"Review queue:     {len(review_rows)}")
    print(f"Output files:")
    print(f"  {args.output_mapped}")
    print(f"  {args.output_review}")


if __name__ == "__main__":
    main()
