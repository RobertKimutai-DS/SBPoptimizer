-- Simple SQL functions and views for Business Permit Management System
-- 003_functions_simple.sql

-- Create views for common queries (no complex functions for now)

-- View for business permit summary
CREATE OR REPLACE VIEW v_business_permit_summary AS
SELECT
  b.business_id,
  b.name as business_name,
  b.kra_pin,
  b.category,
  b.size,
  b.location,
  b.ward,
  b.status as business_status,
  p.permit_id,
  p.permit_year,
  p.status as permit_status,
  p.fee_amount,
  p.issue_date,
  p.expiry_date,
  CASE
    WHEN p.expiry_date < CURRENT_DATE THEN 'Expired'
    WHEN p.expiry_date < CURRENT_DATE + INTERVAL '30 days' THEN 'Expiring Soon'
    ELSE 'Valid'
  END as permit_status_desc
FROM businesses b
LEFT JOIN permits p ON b.business_id = p.business_id
  AND p.permit_year = EXTRACT(YEAR FROM CURRENT_DATE)
WHERE b.status = 'active';

-- View for inspection summary
CREATE OR REPLACE VIEW v_inspection_summary AS
SELECT
  i.inspection_id,
  b.business_id,
  b.name as business_name,
  u.name as inspector_name,
  i.status as inspection_status,
  i.notes,
  i.inspected_at,
  EXTRACT(DAYS FROM (CURRENT_TIMESTAMP - i.inspected_at)) as days_since_inspection
FROM inspections i
JOIN businesses b ON i.business_id = b.business_id
JOIN users u ON i.inspector_id = u.user_id
ORDER BY i.inspected_at DESC;

-- View for payment summary
CREATE OR REPLACE VIEW v_payment_summary AS
SELECT
  pay.payment_id,
  b.business_id,
  b.name as business_name,
  p.permit_year,
  pay.amount,
  pay.payment_method,
  pay.status as payment_status,
  pay.paid_at,
  p.fee_amount
FROM payments pay
JOIN permits p ON pay.permit_id = p.permit_id
JOIN businesses b ON p.business_id = b.business_id;
