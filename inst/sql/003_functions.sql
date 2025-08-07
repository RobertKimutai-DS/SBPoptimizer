-- Database functions and views for Business Permit Management System
-- 003_functions.sql

-- Function to calculate permit fee based on business size and category
CREATE OR REPLACE FUNCTION calculate_permit_fee(business_size TEXT, business_category TEXT)
RETURNS NUMERIC AS $$
BEGIN
  CASE business_size
    WHEN 'Small' THEN
      CASE business_category
        WHEN 'Retail' THEN RETURN 5000;
        WHEN 'Services' THEN RETURN 7500;
        ELSE RETURN 10000;
      END CASE;
    WHEN 'Medium' THEN
      CASE business_category
        WHEN 'Retail' THEN RETURN 15000;
        WHEN 'Services' THEN RETURN 20000;
        ELSE RETURN 25000;
      END CASE;
    WHEN 'Large' THEN
      CASE business_category
        WHEN 'Manufacturing' THEN RETURN 100000;
        ELSE RETURN 50000;
      END CASE;
    ELSE
      RETURN 5000; -- Default minimum fee
  END CASE;
END;
$$ LANGUAGE plpgsql;

-- Function to check if permit is expired
CREATE OR REPLACE FUNCTION is_permit_expired(permit_id INTEGER)
RETURNS BOOLEAN AS $$
DECLARE
  expiry_date DATE;
BEGIN
  SELECT p.expiry_date INTO expiry_date
  FROM permits p
  WHERE p.permit_id = $1;

  IF expiry_date IS NULL THEN
    RETURN TRUE;
  END IF;

  RETURN expiry_date < CURRENT_DATE;
END;
$$ LANGUAGE plpgsql;

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
  END as permit_status_desc,
  cs.score as compliance_score,
  cs.cluster_label
FROM businesses b
LEFT JOIN permits p ON b.business_id = p.business_id AND p.permit_year = EXTRACT(YEAR FROM CURRENT_DATE)
LEFT JOIN compliance_scores cs ON b.business_id = cs.business_id
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
  p.fee_amount,
  (p.fee_amount - COALESCE(SUM(CASE WHEN pay.status = 'success' THEN pay.amount ELSE 0 END), 0)) as outstanding_amount
FROM payments pay
JOIN permits p ON pay.permit_id = p.permit_id
JOIN businesses b ON p.business_id = b.business_id
GROUP BY pay.payment_id, b.business_id, b.name, p.permit_year, pay.amount, pay.payment_method, pay.status, pay.paid_at, p.fee_amount;

-- Function to audit table changes
CREATE OR REPLACE FUNCTION audit_trigger()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    INSERT INTO audit_logs (user_id, action, target_table, target_id, metadata)
    VALUES (
      COALESCE(CURRENT_SETTING('app.current_user_id', true)::INTEGER, 0),
      'DELETE',
      TG_TABLE_NAME,
      OLD.business_id,
      row_to_json(OLD)
    );
    RETURN OLD;
  ELSIF TG_OP = 'UPDATE' THEN
    INSERT INTO audit_logs (user_id, action, target_table, target_id, metadata)
    VALUES (
      COALESCE(CURRENT_SETTING('app.current_user_id', true)::INTEGER, 0),
      'UPDATE',
      TG_TABLE_NAME,
      NEW.business_id,
      json_build_object('old', row_to_json(OLD), 'new', row_to_json(NEW))
    );
    RETURN NEW;
  ELSIF TG_OP = 'INSERT' THEN
    INSERT INTO audit_logs (user_id, action, target_table, target_id, metadata)
    VALUES (
      COALESCE(CURRENT_SETTING('app.current_user_id', true)::INTEGER, 0),
      'INSERT',
      TG_TABLE_NAME,
      NEW.business_id,
      row_to_json(NEW)
    );
    RETURN NEW;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create audit triggers for key tables
DROP TRIGGER IF EXISTS audit_businesses ON businesses;
CREATE TRIGGER audit_businesses
  AFTER INSERT OR UPDATE OR DELETE ON businesses
  FOR EACH ROW EXECUTE FUNCTION audit_trigger();

DROP TRIGGER IF EXISTS audit_permits ON permits;
CREATE TRIGGER audit_permits
  AFTER INSERT OR UPDATE OR DELETE ON permits
  FOR EACH ROW EXECUTE FUNCTION audit_trigger();

DROP TRIGGER IF EXISTS audit_payments ON payments;
CREATE TRIGGER audit_payments
  AFTER INSERT OR UPDATE OR DELETE ON payments
  FOR EACH ROW EXECUTE FUNCTION audit_trigger();
