-- ============================================================
-- sql/02_promote_shaxi_v1.sql
-- Shaxi staging -> operational truth PROMOTION
-- Batch: shaxi_promotion_v1
--
-- Purpose: Promote the 11 staged Shaxi areas into rentable_areas
--          using confirmed final schema with UUID FKs.
--
-- Rules:
--   1. Idempotent insert (skips rows already present by
--      property_id + building_id + area_name).
--   2. Generates unique area_code per row.
--   3. Maps unit_type_raw to English area_type.
--   4. Does NOT promote the 9 pending candidate rows.
--   5. Does NOT create lease_package_components.
--   6. Keeps unmatched contract-area rows in
--      promotion_contract_area_candidates only.
-- ============================================================


-- ============================================================
-- STEP 1: Preview rows to be inserted
-- Expected: 9 new rows (2 already exist in rentable_areas).
-- ============================================================

SELECT
  p.id AS property_id,
  b.id AS building_id,
  'RA-' || s.building_code || '-' ||
    CASE
      WHEN REPLACE(s.prepared_area_name, s.building_name_current, '') = ''
      THEN s.prepared_area_name
      ELSE REPLACE(s.prepared_area_name, s.building_name_current, '')
    END AS area_code,
  s.prepared_area_name AS area_name,
  CASE s.unit_type_raw
    WHEN '厂房' THEN 'factory'
    WHEN '宿舍' THEN 'dormitory'
    ELSE s.unit_type_raw
  END AS area_type,
  s.avg_area_sqm_raw AS area_sqm,
  s.normalized_scope_text AS leaseable_scope,
  s.parcel_name AS section_group_name,
  s.source_companies AS source_text_raw,
  lp.certificate_no_raw,
  COALESCE(s.remarks_raw, '') || ' | batch: shaxi_promotion_v1' AS notes
FROM public.stg_shaxi_areas_prepared s
JOIN public.properties p ON p.property_code = s.property_code
JOIN public.building_registry b ON b.building_code = s.building_code
LEFT JOIN public.land_parcels lp ON lp.parcel_code = s.parcel_code
LEFT JOIN public.rentable_areas existing
  ON existing.property_id = p.id
  AND existing.building_id = b.id
  AND existing.area_name = s.prepared_area_name
WHERE existing.id IS NULL
ORDER BY s.building_code, s.prepared_area_name;


-- ============================================================
-- STEP 2: Idempotent insert into rentable_areas
-- ============================================================

INSERT INTO public.rentable_areas (
  property_id,
  building_id,
  area_code,
  area_name,
  area_type,
  area_sqm,
  leaseable_scope,
  section_group_name,
  source_text_raw,
  certificate_no_raw,
  notes,
  created_at
)
SELECT
  p.id,
  b.id,
  'RA-' || s.building_code || '-' ||
    CASE
      WHEN REPLACE(s.prepared_area_name, s.building_name_current, '') = ''
      THEN s.prepared_area_name
      ELSE REPLACE(s.prepared_area_name, s.building_name_current, '')
    END,
  s.prepared_area_name,
  CASE s.unit_type_raw
    WHEN '厂房' THEN 'factory'
    WHEN '宿舍' THEN 'dormitory'
    ELSE s.unit_type_raw
  END,
  s.avg_area_sqm_raw,
  s.normalized_scope_text,
  s.parcel_name,
  s.source_companies,
  lp.certificate_no_raw,
  COALESCE(s.remarks_raw, '') || ' | batch: shaxi_promotion_v1',
  NOW()
FROM public.stg_shaxi_areas_prepared s
JOIN public.properties p ON p.property_code = s.property_code
JOIN public.building_registry b ON b.building_code = s.building_code
LEFT JOIN public.land_parcels lp ON lp.parcel_code = s.parcel_code
LEFT JOIN public.rentable_areas existing
  ON existing.property_id = p.id
  AND existing.building_id = b.id
  AND existing.area_name = s.prepared_area_name
WHERE existing.id IS NULL;


-- ============================================================
-- STEP 3: Post-insert verification
-- ============================================================

-- 3.1 Total staged areas now represented in rentable_areas
-- Expected: 11
SELECT
  'POST_INSERT: staged areas in rentable_areas' AS check_name,
  COUNT(*) AS matched_count
FROM public.stg_shaxi_areas_prepared s
JOIN public.properties p ON p.property_code = s.property_code
JOIN public.building_registry b ON b.building_code = s.building_code
JOIN public.rentable_areas ra
  ON ra.property_id = p.id
  AND ra.building_id = b.id
  AND ra.area_name = s.prepared_area_name;


-- 3.2 Newly inserted rows for this batch
-- Expected: 9
SELECT
  'POST_INSERT: newly created rows for batch' AS check_name,
  COUNT(*) AS new_row_count
FROM public.rentable_areas
WHERE notes LIKE '%batch: shaxi_promotion_v1%';


-- 3.3 No duplicate area_names per building for SX-39
-- Expected: 0
SELECT
  'POST_INSERT: duplicate area_name per building' AS check_name,
  COUNT(*) AS duplicate_count
FROM (
  SELECT ra.property_id, ra.building_id, ra.area_name
  FROM public.rentable_areas ra
  JOIN public.properties p ON p.id = ra.property_id
  WHERE p.property_code = 'SX-39'
  GROUP BY ra.property_id, ra.building_id, ra.area_name
  HAVING COUNT(*) > 1
) dups;
