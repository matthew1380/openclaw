# DATABASE_SCHEMA.md
- status
- assigned_to
- cost
- notes
- created_at
- updated_at

---

## 10. tasks
Version-1 extension table after the core layer works.

### Suggested fields
- id
- related_type
- related_id
- task_title
- task_description
- due_date
- priority
- status
- assigned_to
- notes
- created_at
- updated_at

---

## 11. approvals
Version-1 extension table after the core layer works.

### Suggested fields
- id
- related_type
- related_id
- approval_type
- requested_by
- approved_by
- approval_status
- approval_date
- notes
- created_at
- updated_at

---

## Core calculated outputs needed for MVP
- active lease per unit
- overdue amount
- overdue days
- vacancy status
- days to lease expiry

## Important schema rules
1. Avoid fragile manual links where logic can determine current state
2. Do not allow AI-generated draft records to become final without review
3. Keep core tables stable before expanding features
4. Every field added should solve a real operating need
