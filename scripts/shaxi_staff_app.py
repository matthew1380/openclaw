#!/usr/bin/env python3
"""
shaxi_staff_app.py

Streamlit staff operating interface for Shaxi Rental OS.

Usage:
  .venv\\Scripts\\python.exe -m streamlit run scripts/shaxi_staff_app.py

Requirements:
  - streamlit (installed in project .venv)
  - psql CLI available on PATH
  - .env file with SUPABASE_DB_URL in project root

Safety rules:
  - Payments can only be recorded against issued bills.
  - Draft bills (e.g. 杨华禾) are blocked.
  - Held cases (川田, 朱河芳) are not in the eligible list.
  - Allocation amount cannot exceed the bill's outstanding amount.
  - No contract/area/rent editing is exposed.
"""

import csv
import os
import subprocess
import sys
from datetime import datetime

import streamlit as st

# Ensure we can find .env regardless of working directory
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def get_db_url():
    env_path = os.path.join(PROJECT_ROOT, '.env')
    with open(env_path, 'r', encoding='utf-8') as f:
        for line in f:
            if line.startswith('SUPABASE_DB_URL='):
                return line.split('=', 1)[1].strip().strip('"').strip("'")
    raise RuntimeError('SUPABASE_DB_URL not found in .env')


DB_URL = get_db_url()


def psql_csv(query):
    """Run a psql query and return list of dicts (CSV header -> values)."""
    result = subprocess.run(
        ['psql', DB_URL, '-c', query, '--csv'],
        capture_output=True,
        text=True,
        encoding='utf-8',
        errors='replace'
    )
    if result.returncode != 0:
        raise RuntimeError(f'psql error: {result.stderr}')
    reader = csv.DictReader(result.stdout.strip().splitlines())
    return list(reader)


def psql_exec(sql):
    """Execute a psql command that does not return rows."""
    result = subprocess.run(
        ['psql', DB_URL, '-c', sql],
        capture_output=True,
        text=True,
        encoding='utf-8',
        errors='replace'
    )
    if result.returncode != 0:
        raise RuntimeError(f'psql error: {result.stderr}')
    return result.stdout


def psql_returning_id(sql):
    """Execute INSERT ... RETURNING id and return the new UUID."""
    result = subprocess.run(
        ['psql', DB_URL, '-c', sql, '--csv'],
        capture_output=True,
        text=True,
        encoding='utf-8',
        errors='replace'
    )
    if result.returncode != 0:
        raise RuntimeError(f'psql error: {result.stderr}')
    lines = result.stdout.strip().splitlines()
    if len(lines) < 2:
        raise RuntimeError('No rows returned from RETURNING query')
    reader = csv.DictReader(lines)
    rows = list(reader)
    if not rows:
        raise RuntimeError('No ID returned from INSERT')
    return rows[0]['id']


# ============================================================
# Page config
# ============================================================
st.set_page_config(
    page_title='Shaxi Staff Operating Interface',
    page_icon='🏢',
    layout='wide'
)

# ============================================================
# Helper: decision status color badge
# ============================================================
def decision_status_color(status):
    return {
        'pending_decision': '🔵',
        'needs_adjustment': '🟡',
        'approved_to_bill': '🟢',
        'approved_to_issue': '🟢',
        'keep_on_hold': '🔴',
        'mark_vacant': '⚫',
        'renewed_contract_needed': '🟠',
        'resolved': '✅',
    }.get(status, '⚪')

# ============================================================
# Load data
# ============================================================
try:
    outstanding = psql_csv('SELECT * FROM public.vw_shaxi_outstanding_bills_v2_3 ORDER BY amount_due DESC')
    queue = psql_csv('SELECT * FROM public.vw_shaxi_payment_recording_queue_v2_3 ORDER BY amount_due DESC')
    holds = psql_csv('SELECT * FROM public.vw_shaxi_billing_hold_review_v2_0 ORDER BY candidate_status, tenant_name')
    mapping_exc = psql_csv('SELECT COUNT(*) AS cnt FROM public.vw_shaxi_mapping_exceptions')
    billing_exc = psql_csv('SELECT COUNT(*) AS cnt FROM public.vw_shaxi_billing_exceptions')
    payment_exc = psql_csv('SELECT COUNT(*) AS cnt FROM public.vw_shaxi_payment_allocation_exceptions_v2_3')
    summary = psql_csv('SELECT * FROM public.vw_shaxi_bill_approval_summary_v2_1')[0]
    draft_queue = psql_csv('SELECT * FROM public.vw_shaxi_bill_review_queue_v2_0 ORDER BY amount_due DESC')
    exception_queue = psql_csv('SELECT * FROM public.vw_shaxi_business_exception_queue_v2_5 ORDER BY decision_status, tenant_name')
    exception_summary = psql_csv('SELECT * FROM public.vw_shaxi_business_exception_summary_v2_5')[0]
except Exception as e:
    st.error(f'Database connection error: {e}')
    st.stop()

# ============================================================
# Compute dashboard numbers
# ============================================================
issued_count = int(summary.get('issued_count', 0))
pending_count = int(summary.get('pending_count', 0))
approved_count = int(summary.get('approved_count', 0))
hold_count = len(holds)
mapping_cnt = int(mapping_exc[0].get('cnt', 0))
billing_cnt = int(billing_exc[0].get('cnt', 0))
payment_cnt = int(payment_exc[0].get('cnt', 0))

total_issued = sum(float(r.get('amount_due', 0) or 0) for r in outstanding)
total_outstanding = sum(float(r.get('outstanding_amount', 0) or 0) for r in outstanding)

# ============================================================
# Header
# ============================================================
st.title('🏢 Shaxi Staff Operating Interface')
st.caption(f'May 2026 | Last refreshed: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}')

# ============================================================
# Dashboard Cards
# ============================================================
exception_pending = int(exception_summary.get('pending_decision_count', 0))
exception_total = int(exception_summary.get('total_exception_count', 0))

row1, row2, row3, row4, row5, row6, row7, row8 = st.columns(8)
row1.metric('Issued Bills', issued_count)
row2.metric('Total Issued', f'¥{total_issued:,.0f}')
row3.metric('Outstanding', f'¥{total_outstanding:,.0f}')
row4.metric('Payment-Eligible', len(queue))
row5.metric('Draft/Pending', pending_count)
row6.metric('Holds', hold_count)
row7.metric('Exceptions', billing_cnt + mapping_cnt + payment_cnt)
row8.metric('Biz Exceptions', f'{exception_pending}/{exception_total}')

# ============================================================
# Tabs
# ============================================================
tab1, tab2, tab3, tab4, tab5 = st.tabs([
    '📋 Outstanding Bills',
    '💳 Payment Recording',
    '⏸️ Holds',
    '🔍 Exceptions',
    '⚠️ Business Exceptions'
])

# ============================================================
# Tab 1: Outstanding Bills
# ============================================================
with tab1:
    st.subheader('Outstanding Bills (Issued)')
    if outstanding:
        st.dataframe(
            outstanding,
            width='stretch',
            column_order=[
                'tenant_name', 'area_name', 'amount_due',
                'allocated_paid_amount', 'outstanding_amount',
                'due_date', 'days_overdue', 'payment_status'
            ]
        )
    else:
        st.info('No outstanding bills.')

    st.subheader('Payment Recording Queue')
    if queue:
        st.dataframe(
            queue,
            width='stretch',
            column_order=[
                'tenant_name', 'area_name', 'amount_due',
                'outstanding_amount', 'due_date', 'days_overdue', 'payment_status'
            ]
        )
    else:
        st.info('No bills eligible for payment recording.')

# ============================================================
# Tab 2: Payment Recording
# ============================================================
with tab2:
    st.subheader('Record a Payment')
    st.markdown('---')

    if not queue:
        st.info('No bills are currently eligible for payment recording.')
    else:
        # Build dropdown options from queue
        bill_options = {
            f"{r['tenant_name']} — {r['area_name']} — Outstanding: ¥{float(r['outstanding_amount'] or 0):,.2f}": r
            for r in queue
        }

        with st.form('payment_form', clear_on_submit=True):
            selected_label = st.selectbox(
                'Select Bill to Pay',
                options=list(bill_options.keys()),
                index=0
            )
            selected_bill = bill_options[selected_label]

            col1, col2 = st.columns(2)
            with col1:
                payment_date = st.date_input('Payment Date', value=datetime.now().date())
                amount_received = st.number_input('Amount Received (¥)', min_value=0.01, step=100.0, format='%.2f')
                allocated_amount = st.number_input(
                    'Allocate to This Bill (¥)',
                    min_value=0.01,
                    max_value=float(selected_bill['outstanding_amount'] or 0),
                    step=100.0,
                    format='%.2f',
                    value=min(float(selected_bill['outstanding_amount'] or 0), amount_received if amount_received > 0 else float(selected_bill['outstanding_amount'] or 0))
                )
            with col2:
                payment_method = st.selectbox(
                    'Payment Method',
                    ['cash', 'bank_transfer', 'personal_wechat', 'personal_alipay',
                     'company_wechat', 'company_alipay', 'pos', 'check']
                )
                bank_account = st.text_input('Bank Account (hint only)', max_chars=100)
                reference_no = st.text_input('Reference No', max_chars=100)
                payer_name = st.text_input('Payer Name', value=selected_bill['tenant_name'], max_chars=100)

            notes = st.text_area('Notes', max_chars=500)

            # Safety warnings
            st.markdown('---')
            if allocated_amount > float(selected_bill['outstanding_amount'] or 0):
                st.error('❌ Allocation cannot exceed the outstanding amount.')
                submit_disabled = True
            elif allocated_amount > amount_received:
                st.error('❌ Allocation cannot exceed the amount received.')
                submit_disabled = True
            else:
                submit_disabled = False

            submitted = st.form_submit_button('💾 Record Payment', disabled=submit_disabled)

            if submitted:
                bill_id = selected_bill['bill_id']
                tenant_id = selected_bill['lease_contract_id']  # Actually need tenant_id, not contract_id
                # Wait, the outstanding view doesn't expose tenant_id directly. I need to get it.
                # Let me query rent_bills for the tenant_id.
                try:
                    tenant_lookup = psql_csv(f"SELECT tenant_id FROM public.rent_bills WHERE id = '{bill_id}'")
                    tenant_id = tenant_lookup[0]['tenant_id'] if tenant_lookup else 'NULL'
                except Exception:
                    tenant_id = 'NULL'

                # Escape single quotes in text fields
                def esc(val):
                    return str(val).replace("'", "''") if val else ''

                # Insert payment
                payment_sql = f"""
INSERT INTO public.payments (
  tenant_id, payment_date, amount_received, payment_method,
  bank_account, reference_no, payer_name, source_type, notes, created_at, updated_at
)
VALUES (
  {'NULL' if tenant_id == 'NULL' else f"'{tenant_id}'"},
  '{payment_date}',
  {amount_received},
  '{payment_method}',
  {'NULL' if not bank_account else f"'{esc(bank_account)}'"},
  {'NULL' if not reference_no else f"'{esc(reference_no)}'"},
  {'NULL' if not payer_name else f"'{esc(payer_name)}'"},
  'staff_entry',
  {'NULL' if not notes else f"'{esc(notes)}'"},
  NOW(),
  NOW()
)
RETURNING id;
"""
                try:
                    payment_id = psql_returning_id(payment_sql)

                    # Insert allocation
                    alloc_sql = f"""
INSERT INTO public.payment_allocations (
  payment_id, bill_id, allocated_amount, created_at
)
VALUES (
  '{payment_id}',
  '{bill_id}',
  {allocated_amount},
  NOW()
);
"""
                    psql_exec(alloc_sql)

                    st.success(
                        f'✅ Payment recorded. Payment ID: `{payment_id}`\n'
                        f'Allocated ¥{allocated_amount:,.2f} to bill `{bill_id}`.'
                    )
                    st.balloons()
                except Exception as e:
                    st.error(f'❌ Failed to record payment: {e}')

# ============================================================
# Tab 3: Holds
# ============================================================
with tab3:
    st.subheader('Billing Holds')
    if holds:
        st.dataframe(holds, use_container_width=True)
    else:
        st.info('No holds.')

    st.subheader('Draft Bills Awaiting Review')
    if draft_queue:
        st.dataframe(
            draft_queue,
            width='stretch',
            column_order=[
                'tenant_name', 'area_name', 'amount_due',
                'due_date', 'review_recommendation', 'bill_status'
            ]
        )
    else:
        st.info('No draft bills awaiting review.')

# ============================================================
# Tab 4: Exceptions
# ============================================================
with tab4:
    st.subheader('Exception Summary')
    c1, c2, c3 = st.columns(3)
    c1.metric('Mapping Exceptions', mapping_cnt)
    c2.metric('Billing Exceptions', billing_cnt)
    c3.metric('Payment Allocation Exceptions', payment_cnt)

    if mapping_cnt == 0 and billing_cnt == 0 and payment_cnt == 0:
        st.success('✅ All exception checks pass. No issues detected.')
    else:
        st.warning('⚠️ Exceptions detected. Review the details below.')

    if mapping_cnt > 0:
        st.subheader('Mapping Exceptions')
        st.dataframe(psql_csv('SELECT * FROM public.vw_shaxi_mapping_exceptions'), use_container_width=True)

    if billing_cnt > 0:
        st.subheader('Billing Exceptions')
        st.dataframe(psql_csv('SELECT * FROM public.vw_shaxi_billing_exceptions'), use_container_width=True)

    if payment_cnt > 0:
        st.subheader('Payment Allocation Exceptions')
        st.dataframe(psql_csv('SELECT * FROM public.vw_shaxi_payment_allocation_exceptions_v2_3'), use_container_width=True)


# ============================================================
# Tab 5: Business Exceptions
# ============================================================
with tab5:
    st.subheader('Business Exception Resolution Workflow')

    # Summary cards
    ec1, ec2, ec3, ec4 = st.columns(4)
    ec1.metric('Pending Decision', exception_summary.get('pending_decision_count', 0))
    ec2.metric('Needs Adjustment', exception_summary.get('needs_adjustment_count', 0))
    ec3.metric('Resolved', exception_summary.get('resolved_count', 0))
    ec4.metric('Total', exception_summary.get('total_exception_count', 0))

    st.markdown('---')

    if exception_queue:
        # Decorate decision_status with emoji
        for row in exception_queue:
            status = row.get('decision_status', '')
            row['status_badge'] = f"{decision_status_color(status)} {status}"

        st.dataframe(
            exception_queue,
            use_container_width=True,
            column_order=[
                'status_badge', 'tenant_name', 'area_name', 'exception_type',
                'current_status', 'recommended_action', 'contract_end_date',
                'related_bill_amount', 'created_at'
            ]
        )

        st.markdown('---')
        st.subheader('Exception Details')
        for row in exception_queue:
            with st.expander(f"{decision_status_color(row.get('decision_status'))} {row.get('tenant_name')} — {row.get('area_name')}"):
                st.write(f"**Exception Type:** {row.get('exception_type')}")
                st.write(f"**Current Status:** {row.get('current_status')}")
                st.write(f"**Decision Status:** {row.get('decision_status')}")
                st.write(f"**Contract Code:** {row.get('related_contract_code', 'N/A')}")
                st.write(f"**Contract End Date:** {row.get('contract_end_date', 'N/A')}")
                st.write(f"**Related Bill Amount:** ¥{row.get('related_bill_amount', 'N/A')}")
                st.write(f"**Recommended Action:** {row.get('recommended_action')}")
                if row.get('decision_note'):
                    st.write(f"**Decision Note:** {row.get('decision_note')}")
                else:
                    st.info('No decision recorded yet.')
    else:
        st.success('✅ All business exceptions are resolved.')

# ============================================================
# Footer
# ============================================================
st.markdown('---')
st.caption('Shaxi Rental OS v2.5 | Internal staff interface | Read-only for views, controlled write for payments only')
