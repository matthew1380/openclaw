import "server-only";
import { query } from "@/lib/db";

export const SHAXI_PROPERTY_CODE = "SX-39";
export const CURRENT_BILLING_MONTH = "2026-05-01";

export type DashboardCounts = {
  issued_count: number;
  issued_total: string;
  draft_count: number;
  draft_total: string;
  outstanding: string;
  exception_pending: number;
  exception_held: number;
  exception_total: number;
  holds_count: number;
};

export async function getDashboardCounts(): Promise<DashboardCounts> {
  const rows = await query<DashboardCounts>(
    `
    WITH bills AS (
      SELECT bill_status, amount_due
      FROM rent_bills
      WHERE billing_month = $1 AND bill_type = 'rent'
    ),
    paid AS (
      SELECT COALESCE(SUM(pa.allocated_amount), 0) AS paid_total
      FROM payment_allocations pa
      JOIN rent_bills rb ON rb.id = pa.bill_id
      WHERE rb.billing_month = $1 AND rb.bill_type = 'rent'
    ),
    excs AS (
      SELECT decision_status FROM shaxi_business_exception_reviews
    )
    SELECT
      COUNT(*) FILTER (WHERE b.bill_status = 'issued')::int AS issued_count,
      COALESCE(SUM(b.amount_due) FILTER (WHERE b.bill_status = 'issued'), 0)::text AS issued_total,
      COUNT(*) FILTER (WHERE b.bill_status = 'draft')::int AS draft_count,
      COALESCE(SUM(b.amount_due) FILTER (WHERE b.bill_status = 'draft'), 0)::text AS draft_total,
      (COALESCE(SUM(b.amount_due) FILTER (WHERE b.bill_status = 'issued'), 0) - (SELECT paid_total FROM paid))::text AS outstanding,
      (SELECT COUNT(*) FROM excs WHERE decision_status = 'pending_decision')::int AS exception_pending,
      (SELECT COUNT(*) FROM excs WHERE decision_status = 'keep_on_hold')::int AS exception_held,
      (SELECT COUNT(*) FROM excs)::int AS exception_total,
      (SELECT COUNT(*) FROM excs WHERE decision_status IN ('pending_decision','keep_on_hold'))::int AS holds_count
    FROM bills b
    `,
    [CURRENT_BILLING_MONTH],
  );
  return rows[0];
}

export type IssuedBill = {
  bill_id: string;
  tenant_name: string;
  area_code: string | null;
  area_name: string | null;
  amount_due: string;
  bill_status: string;
  reviewed_by: string | null;
  contract_code: string | null;
};

export async function getIssuedBills(): Promise<IssuedBill[]> {
  return query<IssuedBill>(
    `
    SELECT
      rb.id::text AS bill_id,
      COALESCE(co.name, '') AS tenant_name,
      ra.area_code,
      ra.area_name,
      rb.amount_due::text AS amount_due,
      rb.bill_status,
      bar.reviewed_by,
      c.contract_code
    FROM rent_bills rb
    LEFT JOIN lease_package_components lpc ON lpc.id = rb.lease_package_component_id
    LEFT JOIN rentable_areas ra ON ra.id = lpc.rentable_area_id
    LEFT JOIN contracts c ON c.id = rb.lease_contract_id
    LEFT JOIN contacts co ON co.id = COALESCE(rb.tenant_id, c.tenant_id)
    LEFT JOIN bill_approval_reviews bar ON bar.bill_id = rb.id
    WHERE rb.billing_month = $1
      AND rb.bill_type = 'rent'
      AND rb.bill_status = 'issued'
    ORDER BY rb.amount_due DESC NULLS LAST
    `,
    [CURRENT_BILLING_MONTH],
  );
}

export type ExceptionRow = {
  id: string;
  exception_type: string;
  tenant_name: string;
  area_code: string | null;
  decision_status: string;
  decision_by: string | null;
  decision_note_snippet: string | null;
};

export async function getExceptions(): Promise<ExceptionRow[]> {
  return query<ExceptionRow>(
    `
    SELECT
      id::text,
      exception_type,
      tenant_name,
      area_code,
      decision_status,
      decision_by,
      LEFT(COALESCE(decision_note, ''), 80) AS decision_note_snippet
    FROM shaxi_business_exception_reviews
    ORDER BY
      CASE decision_status
        WHEN 'pending_decision' THEN 0
        WHEN 'keep_on_hold' THEN 1
        ELSE 2
      END,
      created_at
    `,
  );
}
