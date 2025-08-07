-- Seed data for Business Permit Management System
-- 002_seed_data.sql

-- Insert default admin user (password: admin123 - change in production!)
INSERT INTO users (name, email, phone, password_hash, role)
VALUES
  ('System Administrator', 'admin@permits.gov.ke', '+254700000000',
   '$2a$10$xvPS8oYr5Z1z5qHXQlY.qOQHDOT7w8eZ5KCKBqfA9pzOo5FqPdBxK', 'admin'),
  ('John Doe', 'john.officer@permits.gov.ke', '+254700000001',
   '$2a$10$xvPS8oYr5Z1z5qHXQlY.qOQHDOT7w8eZ5KCKBqfA9pzOo5FqPdBxK', 'officer'),
  ('Jane Smith', 'jane.inspector@permits.gov.ke', '+254700000002',
   '$2a$10$xvPS8oYr5Z1z5qHXQlY.qOQHDOT7w8eZ5KCKBqfA9pzOo5FqPdBxK', 'inspector')
ON CONFLICT (email) DO NOTHING;

-- Insert sample businesses
INSERT INTO businesses (owner_id, kra_pin, name, category, size, location, latitude, longitude, ward)
VALUES
  (2, 'A001234567B', 'Mama Mboga Groceries', 'Retail', 'Small', 'Nairobi CBD', -1.2921, 36.8219, 'Central Ward'),
  (2, 'A001234568C', 'Tech Solutions Ltd', 'Services', 'Medium', 'Westlands', -1.2630, 36.8063, 'Westlands Ward'),
  (2, 'A001234569D', 'Manufacturing Co', 'Manufacturing', 'Large', 'Industrial Area', -1.3197, 36.8510, 'Industrial Ward')
ON CONFLICT DO NOTHING;

-- Insert sample permits
INSERT INTO permits (business_id, permit_year, fee_amount, status, issue_date, expiry_date)
SELECT
  b.business_id,
  2024,
  CASE
    WHEN b.size = 'Small' THEN 5000
    WHEN b.size = 'Medium' THEN 15000
    ELSE 50000
  END,
  'issued',
  '2024-01-15'::DATE,
  '2024-12-31'::DATE
FROM businesses b
WHERE NOT EXISTS (
  SELECT 1 FROM permits p WHERE p.business_id = b.business_id AND p.permit_year = 2024
);

-- Insert sample compliance scores
INSERT INTO compliance_scores (business_id, score, model_version, features_json, cluster_label)
SELECT
  b.business_id,
  0.75 + (RANDOM() * 0.25), -- Random score between 0.75 and 1.0
  'v1.0',
  '{"location_score": 0.8, "payment_history": 0.9, "inspection_score": 0.7}'::jsonb,
  'medium_risk'
FROM businesses b
WHERE NOT EXISTS (
  SELECT 1 FROM compliance_scores cs WHERE cs.business_id = b.business_id
);

-- Insert API key for testing
INSERT INTO api_keys (label, api_key_hash, access_scope)
VALUES
  ('Development Key', '$2a$10$abcdefghijklmnopqrstuvwxyz123456789', 'admin'),
  ('Read Only Key', '$2a$10$zyxwvutsrqponmlkjihgfedcba987654321', 'read')
ON CONFLICT (api_key_hash) DO NOTHING;
