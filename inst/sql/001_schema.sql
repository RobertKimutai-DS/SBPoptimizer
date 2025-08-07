-- Business Permit Management System Database Schema
-- 001_schema.sql

CREATE TABLE IF NOT EXISTS users (
  user_id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  phone TEXT UNIQUE,
  password_hash TEXT NOT NULL,
  role TEXT CHECK (role IN ('admin', 'officer', 'inspector', 'finance')) NOT NULL,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS businesses (
  business_id SERIAL PRIMARY KEY,
  owner_id INTEGER REFERENCES users(user_id),
  kra_pin TEXT NOT NULL,
  name TEXT NOT NULL,
  category TEXT NOT NULL,
  size TEXT CHECK (size IN ('Small', 'Medium', 'Large')) NOT NULL,
  location TEXT NOT NULL,
  latitude DOUBLE PRECISION CHECK (latitude BETWEEN -90 AND 90),
  longitude DOUBLE PRECISION CHECK (longitude BETWEEN -180 AND 180),
  ward TEXT NOT NULL,
  status TEXT DEFAULT 'active',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS permits (
  permit_id SERIAL PRIMARY KEY,
  business_id INTEGER REFERENCES businesses(business_id),
  permit_year INTEGER NOT NULL,
  fee_amount NUMERIC NOT NULL,
  status TEXT CHECK (status IN ('issued', 'expired', 'cancelled')) NOT NULL,
  pdf_url TEXT,
  qr_code_data TEXT,
  issue_date DATE,
  expiry_date DATE,
  penalty_amount NUMERIC DEFAULT 0
);

CREATE TABLE IF NOT EXISTS payments (
  payment_id SERIAL PRIMARY KEY,
  permit_id INTEGER REFERENCES permits(permit_id),
  amount NUMERIC NOT NULL,
  payment_method TEXT CHECK (payment_method IN ('mpesa', 'cash', 'bank')) NOT NULL,
  mpesa_code TEXT UNIQUE,
  receipt_url TEXT,
  status TEXT CHECK (status IN ('pending', 'success', 'failed')) NOT NULL,
  paid_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS compliance_scores (
  score_id SERIAL PRIMARY KEY,
  business_id INTEGER REFERENCES businesses(business_id),
  score NUMERIC CHECK (score BETWEEN 0 AND 1) NOT NULL,
  model_version TEXT NOT NULL,
  features_json JSONB,
  cluster_label TEXT,
  scored_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS inspections (
  inspection_id SERIAL PRIMARY KEY,
  business_id INTEGER REFERENCES businesses(business_id),
  inspector_id INTEGER REFERENCES users(user_id),
  notes TEXT,
  status TEXT CHECK (status IN ('visited', 'not_found', 'noncompliant')),
  photo_url TEXT,
  latitude DOUBLE PRECISION CHECK (latitude BETWEEN -90 AND 90),
  longitude DOUBLE PRECISION CHECK (longitude BETWEEN -180 AND 180),
  inspected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS audit_logs (
  log_id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(user_id),
  action TEXT NOT NULL,
  target_table TEXT NOT NULL,
  target_id INTEGER,
  timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  metadata JSONB
);

CREATE TABLE IF NOT EXISTS chatbot_interactions (
  chat_id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(user_id),
  question TEXT NOT NULL,
  response TEXT NOT NULL,
  language TEXT DEFAULT 'en',
  rag_context_used TEXT,
  responded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS reports (
  report_id SERIAL PRIMARY KEY,
  type TEXT CHECK (type IN ('daily', 'weekly', 'monthly')) NOT NULL,
  report_url TEXT NOT NULL,
  generated_by INTEGER REFERENCES users(user_id),
  parameters JSONB,
  generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS api_keys (
  key_id SERIAL PRIMARY KEY,
  label TEXT NOT NULL,
  api_key_hash TEXT UNIQUE NOT NULL,
  access_scope TEXT CHECK (access_scope IN ('read', 'write', 'admin')) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  expires_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS notifications_log (
  notification_id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(user_id),
  channel TEXT CHECK (channel IN ('sms', 'email')) NOT NULL,
  message TEXT NOT NULL,
  status TEXT CHECK (status IN ('sent', 'failed')) NOT NULL,
  sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS tickets (
  ticket_id SERIAL PRIMARY KEY,
  business_id INTEGER REFERENCES businesses(business_id),
  created_by INTEGER REFERENCES users(user_id),
  assigned_to INTEGER REFERENCES users(user_id),
  status TEXT CHECK (status IN ('open', 'resolved', 'escalated')) NOT NULL,
  category TEXT NOT NULL,
  notes TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS report_schedule (
  schedule_id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(user_id),
  frequency TEXT CHECK (frequency IN ('daily','weekly','monthly')) NOT NULL,
  report_type TEXT NOT NULL,
  parameters JSONB,
  next_run TIMESTAMP
);

-- Helpful indexes
CREATE INDEX IF NOT EXISTS idx_businesses_owner_id      ON businesses(owner_id);
CREATE INDEX IF NOT EXISTS idx_permits_business_id      ON permits(business_id);
CREATE INDEX IF NOT EXISTS idx_payments_permit_id       ON payments(permit_id);
CREATE INDEX IF NOT EXISTS idx_scores_business_id       ON compliance_scores(business_id);
CREATE INDEX IF NOT EXISTS idx_insp_business_id         ON inspections(business_id);
CREATE INDEX IF NOT EXISTS idx_insp_inspector_id        ON inspections(inspector_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id       ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_chat_user_id             ON chatbot_interactions(user_id);
CREATE INDEX IF NOT EXISTS idx_reports_generated_by     ON reports(generated_by);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id    ON notifications_log(user_id);
CREATE INDEX IF NOT EXISTS idx_tickets_business_id      ON tickets(business_id);
CREATE INDEX IF NOT EXISTS idx_tickets_created_by       ON tickets(created_by);
CREATE INDEX IF NOT EXISTS idx_tickets_assigned_to      ON tickets(assigned_to);
