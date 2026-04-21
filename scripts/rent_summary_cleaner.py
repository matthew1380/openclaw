#!/usr/bin/env python3
"""
Rent Summary Cleaner for Rental OS — Shaxi pilot version.

Reads a raw rent summary CSV matching the real pilot structure, preserves
original wording, normalizes numeric and confidence fields, and routes
ambiguous rows to a review queue.

Expected input columns (case-insensitive header matching):
  property_code_hint, rent_collector, property_group, tenant_name,
  paying_unit_text, monthly_rent_due, received_ytd,
  expected_rent_ytd_simple, ytd_gap_simple, overdue_confidence, remarks

Rules:
- Preserves every raw field for audit in source_text_raw.
- NEVER guesses unit_code or contract_code from the rent summary.
- Normalizes overdue_confidence to high / medium / low / unknown.
  Any value that does not map cleanly is treated as unmapped → review queue.
- Routes rows to review queue instead of auto-correcting ambiguous data.
- Does not modify raw source files.
"""

import argparse
import csv
import re
import sys
from pathlib import Path


# Normalized output columns
CLEANED_COLUMNS = [
    "property_code_hint",
    "rent_collector",
    "property_group",
    "tenant_name_raw",
    "paying_unit_text_raw",
    "monthly_rent_due_raw",
    "received_ytd_raw",
    "expected_rent_ytd_simple_raw",
    "ytd_gap_simple_raw",
    "overdue_confidence_raw",
    "remarks_raw",
    "source_text_raw",
    "cleaned_monthly_rent_due",
    "cleaned_received_ytd",
    "cleaned_expected_rent_ytd_simple",
    "cleaned_ytd_gap_simple",
    "normalized_overdue_confidence",
    "row_index",
    "notes",
]

REVIEW_QUEUE_COLUMNS = [
    "row_index",
    "property_code_hint",
    "tenant_name_raw",
    "source_text_raw",
    "review_reason",
    "suggested_action",
]


def normalize_confidence(value: str) -> tuple[str | None, bool]:
    """
    Normalize overdue_confidence to high / medium / low / unknown.
    Returns (normalized_value, is_recognized).
    Unrecognized values return (original_stripped, False) and should go to review.
    """
    if value is None:
        return "unknown", True
    s = value.strip().lower()
    if not s:
        return "unknown", True

    high_vals = {"confirmed", "high", "高", "yes", "sure", "definite", "确定", "确认"}
    medium_vals = {"estimated", "medium", "中", "partial", "likely", "probably", "估计", "可能"}
    low_vals = {"low", "低", "weak", "doubtful", "unlikely", "maybe", "弱", "不确定"}
    unknown_vals = {"unknown", "未知", "none", "no", "na", "n/a", "nil", "null", "无"}

    if s in high_vals:
        return "high", True
    if s in medium_vals:
        return "medium", True
    if s in low_vals:
        return "low", True
    if s in unknown_vals:
        return "unknown", True

    return s, False


def parse_numeric(value: str) -> tuple[float | None, str]:
    """Extract float from messy numeric string. Returns (number, leftover)."""
    if value is None:
        return None, ""
    cleaned = re.sub(r"[,%\s¥￥]", "", value.strip())
    # Handle negative signs and decimals
    cleaned = re.sub(r"^-", "-", cleaned)
    try:
        num = float(cleaned)
        return num, ""
    except ValueError:
        return None, value.strip()


def get_col(row: dict, *candidates: str) -> str:
    """Fetch first matching key from row (case-insensitive)."""
    row_lower = {k.lower().strip(): v for k, v in row.items()}
    for c in candidates:
        if c.lower() in row_lower:
            return row_lower[c.lower()]
    return ""


def clean_row(row: dict, row_index: int) -> tuple[dict | None, dict | None]:
    """
    Clean a single raw row.
    Returns (cleaned_record, review_item). Only one is non-None.
    """
    # Extract fields with flexible column name matching
    property_code_hint = get_col(row, "property_code_hint", "property", "物业", "property_code").strip()
    rent_collector = get_col(row, "rent_collector", "collector", "收款人", "收租人").strip()
    property_group = get_col(row, "property_group", "group", "组别", "物业组").strip()
    tenant_name = get_col(row, "tenant_name", "tenant", "租户", "承租方", "客户").strip()
    paying_unit_text = get_col(row, "paying_unit_text", "paying_unit", "缴费单元", "单元", "位置").strip()
    monthly_rent_due = get_col(row, "monthly_rent_due", "monthly_rent", "rent_due", "月租", "应收月租")
    received_ytd = get_col(row, "received_ytd", "received", "ytd_received", "已收", "实收")
    expected_rent_ytd_simple = get_col(row, "expected_rent_ytd_simple", "expected_ytd", "expected_rent", "应计租金", "应收ytd")
    ytd_gap_simple = get_col(row, "ytd_gap_simple", "gap", "ytd_gap", "差额", "欠额")
    overdue_confidence_raw = get_col(row, "overdue_confidence", "confidence", "确认度", "可信度")
    remarks = get_col(row, "remarks", "remark", "备注", "说明")

    # Build audit text
    source_text_raw = " | ".join(
        f"{k}={v}" for k, v in row.items() if v and str(v).strip()
    )

    # Normalize confidence
    normalized_confidence, confidence_recognized = normalize_confidence(overdue_confidence_raw)

    # Parse numerics
    cleaned_rent, rent_leftover = parse_numeric(monthly_rent_due)
    cleaned_received, received_leftover = parse_numeric(received_ytd)
    cleaned_expected, expected_leftover = parse_numeric(expected_rent_ytd_simple)
    cleaned_gap, gap_leftover = parse_numeric(ytd_gap_simple)

    review_reasons = []
    suggestions = []

    if not property_code_hint:
        review_reasons.append("missing_property_code_hint")
        suggestions.append("ask staff to identify property")

    if not tenant_name:
        review_reasons.append("missing_tenant_name")
        suggestions.append("check raw source for tenant name")

    if not confidence_recognized:
        review_reasons.append(f"unmapped_overdue_confidence: {overdue_confidence_raw}")
        suggestions.append("map confidence to high/medium/low/unknown or confirm with staff")

    if cleaned_rent is None and rent_leftover:
        review_reasons.append("unparseable_monthly_rent_due")
        suggestions.append(f"manual review: {rent_leftover}")

    if cleaned_received is None and received_leftover:
        review_reasons.append("unparseable_received_ytd")
        suggestions.append(f"manual review: {received_leftover}")

    if cleaned_expected is None and expected_leftover:
        review_reasons.append("unparseable_expected_rent_ytd")
        suggestions.append(f"manual review: {expected_leftover}")

    if cleaned_gap is None and gap_leftover:
        review_reasons.append("unparseable_ytd_gap")
        suggestions.append(f"manual review: {gap_leftover}")

    # Cross-check: if all three numeric values exist, verify gap ≈ expected - received
    if cleaned_expected is not None and cleaned_received is not None and cleaned_gap is not None:
        computed_gap = round(cleaned_expected - cleaned_received, 2)
        if abs(computed_gap - cleaned_gap) > 0.01:
            review_reasons.append("ytd_gap_mismatch")
            suggestions.append(
                f"expected({cleaned_expected}) - received({cleaned_received}) = {computed_gap}, "
                f"but gap given as {cleaned_gap}"
            )

    if review_reasons:
        review_item = {
            "row_index": row_index,
            "property_code_hint": property_code_hint,
            "tenant_name_raw": tenant_name,
            "source_text_raw": source_text_raw[:800],
            "review_reason": "; ".join(review_reasons),
            "suggested_action": "; ".join(suggestions),
        }
        return None, review_item

    cleaned = {
        "property_code_hint": property_code_hint,
        "rent_collector": rent_collector,
        "property_group": property_group,
        "tenant_name_raw": tenant_name,
        "paying_unit_text_raw": paying_unit_text,
        "monthly_rent_due_raw": monthly_rent_due,
        "received_ytd_raw": received_ytd,
        "expected_rent_ytd_simple_raw": expected_rent_ytd_simple,
        "ytd_gap_simple_raw": ytd_gap_simple,
        "overdue_confidence_raw": overdue_confidence_raw,
        "remarks_raw": remarks,
        "source_text_raw": source_text_raw[:1200],
        "cleaned_monthly_rent_due": cleaned_rent,
        "cleaned_received_ytd": cleaned_received,
        "cleaned_expected_rent_ytd_simple": cleaned_expected,
        "cleaned_ytd_gap_simple": cleaned_gap,
        "normalized_overdue_confidence": normalized_confidence,
        "row_index": row_index,
        "notes": "cleaned_by_rent_summary_cleaner",
    }
    return cleaned, None


def main():
    parser = argparse.ArgumentParser(
        description="Clean a raw rent summary CSV for Rental OS staging."
    )
    parser.add_argument("input_csv", type=Path, help="Path to raw rent summary CSV.")
    parser.add_argument(
        "--output-cleaned", type=Path, default=Path("rent_summary_cleaned.csv")
    )
    parser.add_argument(
        "--output-review", type=Path, default=Path("rent_summary_review_queue.csv")
    )
    args = parser.parse_args()

    if not args.input_csv.exists():
        print(f"ERROR: Input file not found: {args.input_csv}", file=sys.stderr)
        sys.exit(1)

    cleaned_rows = []
    review_rows = []

    with args.input_csv.open("r", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        for idx, row in enumerate(reader, start=2):
            cleaned, review = clean_row(row, idx)
            if cleaned:
                cleaned_rows.append(cleaned)
            if review:
                review_rows.append(review)

    with args.output_cleaned.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=CLEANED_COLUMNS)
        writer.writeheader()
        writer.writerows(cleaned_rows)

    with args.output_review.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=REVIEW_QUEUE_COLUMNS)
        writer.writeheader()
        writer.writerows(review_rows)

    print(f"Cleaned records: {len(cleaned_rows)}")
    print(f"Review queue:    {len(review_rows)}")
    print(f"Output files:")
    print(f"  {args.output_cleaned}")
    print(f"  {args.output_review}")


if __name__ == "__main__":
    main()
