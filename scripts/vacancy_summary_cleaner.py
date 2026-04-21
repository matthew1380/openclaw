#!/usr/bin/env python3
"""
Vacancy Summary Cleaner for Rental OS.

Reads rentable_areas, lease_package_components, contracts (and optionally units)
to produce a vacancy/occupancy report following the Shaxi hierarchy.

Expected input CSV schemas:

  rentable_areas.csv
    id, area_code, area_name, property_code, building_code, parcel_code,
    area_type, floor_label, card_or_room_label, area_sqm, current_status

  lease_package_components.csv
    package_unit_id, rentable_area_id, component_role, component_ratio,
    is_estimated, notes

  contracts.csv
    contract_code, unit_id, unit_code, tenant_id, tenant_name,
    contract_status, start_date, end_date, contract_role, monthly_rent

  units.csv  (ONLY required if contracts.csv lacks a unit_code column)
    id, unit_code

Contract roles understood:
  direct_lease, master_lease, sublease

Occupancy rules:
- 1 active link -> occupied
- Multiple links, same contract_code -> occupied
- 1 master_lease + N subleases -> occupied ONLY when:
  - the master lease component_role is "primary"
  - all sublease component_roles are "component" or "corrected_component"
  -> Otherwise marked unclear.
- Multiple master_leases -> unclear
- Multiple direct_leases -> unclear
- direct_lease mixed with any other role -> unclear
- sublease without master_lease -> unclear

Rules:
- site -> parcel -> building -> rentable area -> lease package -> contract
- Never guess occupancy status for ambiguous areas.
- Route unclear areas to a review queue instead of auto-resolving.
- Do not modify raw source files.
"""

import argparse
import csv
import sys
from pathlib import Path
from datetime import date


VACANCY_REPORT_COLUMNS = [
    "property_code",
    "parcel_code",
    "building_code",
    "area_code",
    "area_name",
    "area_type",
    "floor_label",
    "card_or_room_label",
    "area_sqm",
    "status",
    "active_contract_code",
    "active_tenant_name",
    "lease_package_unit_code",
    "contract_role",
    "notes",
]

UNCLEAR_QUEUE_COLUMNS = [
    "area_code",
    "area_name",
    "building_code",
    "property_code",
    "unclear_reason",
    "suggested_action",
    "linked_contracts",
    "linked_contract_roles",
]


def parse_iso_date(s: str) -> date | None:
    if not s or not s.strip():
        return None
    try:
        return date.fromisoformat(s.strip())
    except ValueError:
        return None


def is_contract_active(contract: dict, as_of: date | None = None) -> bool:
    """Determine if a contract is active as of a given date (defaults to today)."""
    if as_of is None:
        as_of = date.today()

    status = contract.get("contract_status", "").strip().lower()
    if status in ("terminated", "expired", "ended", "cancelled", "canceled"):
        return False

    start = parse_iso_date(contract.get("start_date", ""))
    end = parse_iso_date(contract.get("end_date", ""))

    if start and end:
        return start <= as_of <= end
    if start and not end:
        return as_of >= start
    if end and not start:
        return as_of <= end

    return status in ("active", "current", "生效", "执行中", "")


def load_csv(path: Path) -> tuple[list[dict], list[str]]:
    if not path.exists():
        print(f"ERROR: File not found: {path}", file=sys.stderr)
        sys.exit(1)
    with path.open("r", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        headers = reader.fieldnames or []
        return list(reader), headers


def build_contract_lookup(contracts: list[dict]) -> dict[str, dict]:
    return {
        c.get("contract_code", "").strip(): c
        for c in contracts
        if c.get("contract_code", "").strip()
    }


def build_area_component_map(components: list[dict]) -> dict[str, list[dict]]:
    """Map rentable_area_id -> list of components."""
    mapping: dict[str, list[dict]] = {}
    for comp in components:
        area_id = comp.get("rentable_area_id", "").strip()
        if area_id:
            mapping.setdefault(area_id, []).append(comp)
    return mapping


def build_unit_contract_map(contracts: list[dict]) -> dict[str, list[dict]]:
    """Map unit_id -> list of contracts."""
    mapping: dict[str, list[dict]] = {}
    for c in contracts:
        unit_id = c.get("unit_id", "").strip()
        if unit_id:
            mapping.setdefault(unit_id, []).append(c)
    return mapping


def build_unit_code_map(units: list[dict]) -> dict[str, str]:
    """Map unit_id -> unit_code."""
    return {
        u.get("id", "").strip(): u.get("unit_code", "").strip()
        for u in units
        if u.get("id", "").strip()
    }


def determine_area_status(
    area: dict,
    area_components: list[dict],
    contract_lookup: dict[str, dict],
    unit_contract_map: dict[str, list[dict]],
    unit_code_map: dict[str, str],
    as_of: date | None = None,
) -> tuple[str, list[dict], str]:
    """
    Returns (status, active_links, note).
    status is one of: occupied, vacant, unclear
    """
    if not area_components:
        return "vacant", [], "no lease package links"

    active_links = []
    inactive_reasons = []

    for comp in area_components:
        package_unit_id = comp.get("package_unit_id", "").strip()
        unit_contracts = unit_contract_map.get(package_unit_id, [])
        for uc in unit_contracts:
            contract_code = uc.get("contract_code", "").strip()
            if is_contract_active(uc, as_of):
                # Enrich link with component_role from lease_package_components
                active_links.append({
                    "contract_code": contract_code,
                    "contract": uc,
                    "component": comp,
                    "package_unit_id": package_unit_id,
                    "contract_role": uc.get("contract_role", "").strip().lower(),
                    "component_role": comp.get("component_role", "").strip().lower(),
                    "unit_code": uc.get("unit_code", "").strip()
                        or unit_code_map.get(package_unit_id, ""),
                })
            else:
                inactive_reasons.append(f"{contract_code}:inactive")

    if not active_links:
        if inactive_reasons:
            return "vacant", [], "linked contracts inactive: " + "; ".join(inactive_reasons)
        return "vacant", [], "no active contract links"

    # Single active link -> occupied
    if len(active_links) == 1:
        return "occupied", active_links, "single active contract"

    # Multiple links, all same contract_code -> occupied
    contract_codes = {link["contract_code"] for link in active_links}
    if len(contract_codes) == 1:
        return "occupied", active_links, "multiple components under same active contract"

    # Multiple different contracts -> analyze roles
    roles = [link["contract_role"] for link in active_links]
    master_count = sum(1 for r in roles if r == "master_lease")
    sub_count = sum(1 for r in roles if r == "sublease")
    direct_count = sum(1 for r in roles if r == "direct_lease")

    # Master + sublease: only occupied if structurally expected
    if master_count == 1 and sub_count >= 1 and direct_count == 0:
        master_link = next(l for l in active_links if l["contract_role"] == "master_lease")
        sub_links = [l for l in active_links if l["contract_role"] == "sublease"]

        master_component_role = master_link.get("component_role", "")
        sub_component_roles = [l.get("component_role", "") for l in sub_links]

        if (master_component_role == "primary" and
                all(r in ("component", "corrected_component") for r in sub_component_roles)):
            return (
                "occupied",
                active_links,
                "master/sublease structurally expected on same footprint",
            )
        return (
            "unclear",
            active_links,
            "master+sublease present but component roles do not confirm expected structure",
        )

    if master_count > 1:
        return "unclear", active_links, "multiple master leases on same area"
    if direct_count > 1:
        return "unclear", active_links, "multiple direct leases on same area"
    if direct_count == 1 and len(set(roles)) > 1:
        return "unclear", active_links, "direct lease mixed with other roles"
    if sub_count >= 1 and master_count == 0:
        return "unclear", active_links, "sublease without master lease"

    return "unclear", active_links, "multiple active contracts with unexpected roles"


def main():
    parser = argparse.ArgumentParser(
        description="Build a vacancy report from Rental OS area and contract data."
    )
    parser.add_argument(
        "--rentable-areas", type=Path, required=True, help="CSV of rentable_areas."
    )
    parser.add_argument(
        "--components", type=Path, required=True, help="CSV of lease_package_components."
    )
    parser.add_argument(
        "--contracts", type=Path, required=True, help="CSV of contracts."
    )
    parser.add_argument(
        "--units", type=Path, default=None,
        help="CSV of units (required ONLY if contracts.csv lacks a unit_code column)."
    )
    parser.add_argument(
        "--as-of", type=str, default=None,
        help="Evaluate status as of YYYY-MM-DD (default: today)."
    )
    parser.add_argument(
        "--output-report", type=Path, default=Path("vacancy_report.csv")
    )
    parser.add_argument(
        "--output-review", type=Path, default=Path("vacancy_unclear_queue.csv")
    )
    args = parser.parse_args()

    as_of = parse_iso_date(args.as_of) if args.as_of else date.today()

    areas, _ = load_csv(args.rentable_areas)
    components, _ = load_csv(args.components)
    contracts, contract_headers = load_csv(args.contracts)

    # Determine if we need units.csv
    has_unit_code_in_contracts = "unit_code" in [h.strip() for h in contract_headers]
    unit_code_map: dict[str, str] = {}

    if not has_unit_code_in_contracts:
        if args.units is None:
            print(
                "ERROR: contracts.csv does not contain a 'unit_code' column. "
                "Please provide --units CSV with id and unit_code columns.",
                file=sys.stderr,
            )
            sys.exit(1)
        units, _ = load_csv(args.units)
        unit_code_map = build_unit_code_map(units)
    else:
        if args.units is not None:
            print(
                "NOTE: contracts.csv already contains unit_code. --units will be ignored.",
                file=sys.stderr,
            )

    contract_lookup = build_contract_lookup(contracts)
    area_component_map = build_area_component_map(components)
    unit_contract_map = build_unit_contract_map(contracts)

    report_rows = []
    unclear_rows = []

    for area in areas:
        area_id = area.get("id", "").strip()
        area_code = area.get("area_code", "").strip()
        area_name = area.get("area_name", "").strip()
        building_code = area.get("building_code", "").strip() or area.get("building_id", "").strip()
        property_code = area.get("property_code", "").strip() or area.get("property_id", "").strip()
        parcel_code = area.get("parcel_code", "").strip() or area.get("land_parcel_id", "").strip()

        area_components = area_component_map.get(area_id, [])
        status, active_links, note = determine_area_status(
            area, area_components, contract_lookup, unit_contract_map, unit_code_map, as_of
        )

        active_contract_code = ""
        active_tenant_name = ""
        lease_package_unit_code = ""
        contract_role = ""

        if active_links:
            first = active_links[0]
            active_contract_code = first["contract_code"]
            contract = first["contract"]
            active_tenant_name = contract.get("tenant_name", "").strip()
            lease_package_unit_code = first.get("unit_code", "")
            contract_role = first["contract_role"]

        if status == "unclear":
            linked_contracts = "; ".join(sorted({link["contract_code"] for link in active_links}))
            linked_roles = "; ".join(sorted({link["contract_role"] for link in active_links}))
            unclear_rows.append({
                "area_code": area_code,
                "area_name": area_name,
                "building_code": building_code,
                "property_code": property_code,
                "unclear_reason": note,
                "suggested_action": "manual_review_confirm_contract_hierarchy",
                "linked_contracts": linked_contracts,
                "linked_contract_roles": linked_roles,
            })

        report_rows.append({
            "property_code": property_code,
            "parcel_code": parcel_code,
            "building_code": building_code,
            "area_code": area_code,
            "area_name": area_name,
            "area_type": area.get("area_type", "").strip(),
            "floor_label": area.get("floor_label", "").strip(),
            "card_or_room_label": area.get("card_or_room_label", "").strip(),
            "area_sqm": area.get("area_sqm", "").strip(),
            "status": status,
            "active_contract_code": active_contract_code,
            "active_tenant_name": active_tenant_name,
            "lease_package_unit_code": lease_package_unit_code,
            "contract_role": contract_role,
            "notes": note,
        })

    with args.output_report.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=VACANCY_REPORT_COLUMNS)
        writer.writeheader()
        writer.writerows(report_rows)

    with args.output_review.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=UNCLEAR_QUEUE_COLUMNS)
        writer.writeheader()
        writer.writerows(unclear_rows)

    counts = {"occupied": 0, "vacant": 0, "unclear": 0}
    for r in report_rows:
        counts[r["status"]] += 1

    print(f"Vacancy report written: {args.output_report}")
    print(f"Unclear queue written:  {args.output_review}")
    print(f"Summary as of {as_of}:")
    print(f"  Occupied: {counts['occupied']}")
    print(f"  Vacant:   {counts['vacant']}")
    print(f"  Unclear:  {counts['unclear']}")


if __name__ == "__main__":
    main()
