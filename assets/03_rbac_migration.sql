-- =============================================================================
-- MAKARYA HYBRID ERP — Role-Based Access Control (RBAC)
-- File: 03_rbac_migration.sql
-- Jalankan di Supabase SQL Editor
-- =============================================================================

-- =============================================================================
-- STEP 1: Update staff table — tambah kolom yang dibutuhkan
-- =============================================================================

ALTER TABLE staff
  ADD COLUMN IF NOT EXISTS last_login           TIMESTAMPTZ DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS failed_pin_attempts  SMALLINT    DEFAULT 0,
  ADD COLUMN IF NOT EXISTS locked_until         TIMESTAMPTZ DEFAULT NULL;

-- =============================================================================
-- STEP 2: Set PIN untuk staff (di-hash pakai pgcrypto bcrypt)
-- PIN default: Manager=1234, Kasir=2222, Barista=3333
-- WAJIB ganti di production!
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

UPDATE staff SET pin_hash = crypt('1234', gen_salt('bf')) WHERE employee_id = 'EMP-001';
UPDATE staff SET pin_hash = crypt('2222', gen_salt('bf')) WHERE employee_id = 'EMP-002';
UPDATE staff SET pin_hash = crypt('3333', gen_salt('bf')) WHERE employee_id = 'EMP-003';
UPDATE staff SET pin_hash = crypt('2222', gen_salt('bf')) WHERE employee_id = 'EMP-004';
UPDATE staff SET pin_hash = crypt('3333', gen_salt('bf')) WHERE employee_id = 'EMP-005';
UPDATE staff SET pin_hash = crypt('4444', gen_salt('bf')) WHERE employee_id = 'EMP-006';
UPDATE staff SET pin_hash = crypt('5555', gen_salt('bf')) WHERE employee_id = 'EMP-007';

-- =============================================================================
-- STEP 3: Fungsi verify_staff_pin — dipanggil dari Flutter via .rpc()
-- =============================================================================

CREATE OR REPLACE FUNCTION verify_staff_pin(
  p_employee_id TEXT,
  p_pin         TEXT
)
RETURNS TABLE (
  success      BOOLEAN,
  staff_id     INT,
  full_name    TEXT,
  role         TEXT,
  shift        TEXT,
  employee_id  TEXT,
  message      TEXT
)
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_staff  staff%ROWTYPE;
  v_now    TIMESTAMPTZ := NOW();
BEGIN
  SELECT * INTO v_staff FROM staff
  WHERE staff.employee_id = p_employee_id AND is_active = TRUE;

  IF NOT FOUND THEN
    RETURN QUERY SELECT FALSE,NULL::INT,NULL::TEXT,NULL::TEXT,NULL::TEXT,NULL::TEXT,'ID karyawan tidak ditemukan';
    RETURN;
  END IF;

  IF v_staff.locked_until IS NOT NULL AND v_staff.locked_until > v_now THEN
    RETURN QUERY SELECT FALSE,NULL::INT,NULL::TEXT,NULL::TEXT,NULL::TEXT,NULL::TEXT,
      'Akun terkunci sampai ' || TO_CHAR(v_staff.locked_until AT TIME ZONE 'Asia/Jakarta','HH24:MI');
    RETURN;
  END IF;

  IF v_staff.pin_hash IS NULL OR NOT (v_staff.pin_hash = crypt(p_pin, v_staff.pin_hash)) THEN
    UPDATE staff SET
      failed_pin_attempts = failed_pin_attempts + 1,
      locked_until = CASE WHEN failed_pin_attempts + 1 >= 5
                     THEN NOW() + INTERVAL '15 minutes' ELSE NULL END
    WHERE staff.employee_id = p_employee_id;

    RETURN QUERY SELECT FALSE,NULL::INT,NULL::TEXT,NULL::TEXT,NULL::TEXT,NULL::TEXT,
      'PIN salah. Sisa percobaan: ' || GREATEST(0, 4 - v_staff.failed_pin_attempts)::TEXT;
    RETURN;
  END IF;

  UPDATE staff SET failed_pin_attempts=0, locked_until=NULL, last_login=v_now
  WHERE staff.employee_id = p_employee_id;

  RETURN QUERY SELECT TRUE, v_staff.id, v_staff.full_name,
    v_staff.role::TEXT, v_staff.shift::TEXT, v_staff.employee_id::TEXT, 'Login berhasil'::TEXT;
END; $$;

-- =============================================================================
-- STEP 4: Helper set/get app context (role + staff_id per session)
-- =============================================================================

CREATE OR REPLACE FUNCTION set_current_role(p_role TEXT, p_staff_id INT)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  PERFORM set_config('app.current_role',     p_role,           FALSE);
  PERFORM set_config('app.current_staff_id', p_staff_id::TEXT, FALSE);
END; $$;

CREATE OR REPLACE FUNCTION current_app_role()
RETURNS TEXT LANGUAGE sql STABLE AS
$$ SELECT current_setting('app.current_role', TRUE) $$;

CREATE OR REPLACE FUNCTION current_app_staff_id()
RETURNS INT LANGUAGE sql STABLE AS
$$ SELECT current_setting('app.current_staff_id', TRUE)::INT $$;

-- =============================================================================
-- STEP 5: Hapus policy lama yang terlalu permisif, enable RLS semua tabel
-- =============================================================================

DROP POLICY IF EXISTS "Allow all" ON transactions;
DROP POLICY IF EXISTS "Allow all" ON transaction_details;
DROP POLICY IF EXISTS "Allow all" ON items;
DROP POLICY IF EXISTS "Allow all" ON expenses;

ALTER TABLE staff            ENABLE ROW LEVEL SECURITY;
ALTER TABLE wastage_logs     ENABLE ROW LEVEL SECURITY;
ALTER TABLE bundle_analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers        ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- STEP 6: RLS Policies per tabel per role
-- =============================================================================

-- TRANSACTIONS
CREATE POLICY "trx_manager"          ON transactions FOR ALL    USING (current_app_role()='MANAGER');
CREATE POLICY "trx_read_all"         ON transactions FOR SELECT USING (current_app_role() IN ('CASHIER','BARISTA','STOCK_KEEPER','RESEARCHER'));
CREATE POLICY "trx_cashier_insert"   ON transactions FOR INSERT WITH CHECK (current_app_role()='CASHIER');
CREATE POLICY "trx_cashier_update"   ON transactions FOR UPDATE
  USING (current_app_role()='CASHIER' AND status='PENDING' AND staff_id=current_app_staff_id());

-- TRANSACTION DETAILS
CREATE POLICY "td_manager"           ON transaction_details FOR ALL    USING (current_app_role()='MANAGER');
CREATE POLICY "td_read_all"          ON transaction_details FOR SELECT USING (current_app_role() IN ('CASHIER','BARISTA','STOCK_KEEPER','RESEARCHER'));
CREATE POLICY "td_cashier_insert"    ON transaction_details FOR INSERT WITH CHECK (current_app_role()='CASHIER');

-- ITEMS
CREATE POLICY "items_manager_stock"  ON items FOR ALL    USING (current_app_role() IN ('MANAGER','STOCK_KEEPER'));
CREATE POLICY "items_read"           ON items FOR SELECT USING (current_app_role() IN ('CASHIER','BARISTA','RESEARCHER') AND is_active=TRUE);

-- EXPENSES
CREATE POLICY "exp_manager"          ON expenses FOR ALL    USING (current_app_role()='MANAGER');
CREATE POLICY "exp_cashier_insert"   ON expenses FOR INSERT WITH CHECK (current_app_role()='CASHIER');
CREATE POLICY "exp_researcher_read"  ON expenses FOR SELECT USING (current_app_role()='RESEARCHER');

-- STAFF (lihat diri sendiri; manager lihat semua)
CREATE POLICY "staff_manager"        ON staff FOR ALL    USING (current_app_role()='MANAGER');
CREATE POLICY "staff_self"           ON staff FOR SELECT USING (id=current_app_staff_id());

-- WASTAGE LOGS
CREATE POLICY "wl_manager"           ON wastage_logs FOR ALL    USING (current_app_role()='MANAGER');
CREATE POLICY "wl_barista_insert"    ON wastage_logs FOR INSERT WITH CHECK (current_app_role()='BARISTA');
CREATE POLICY "wl_read"              ON wastage_logs FOR SELECT USING (current_app_role() IN ('BARISTA','STOCK_KEEPER','RESEARCHER'));

-- CUSTOMERS
CREATE POLICY "cust_manager"         ON customers FOR ALL    USING (current_app_role()='MANAGER');
CREATE POLICY "cust_cashier_read"    ON customers FOR SELECT USING (current_app_role()='CASHIER');
CREATE POLICY "cust_cashier_insert"  ON customers FOR INSERT WITH CHECK (current_app_role()='CASHIER');

-- BUNDLE ANALYTICS
CREATE POLICY "ba_manager"           ON bundle_analytics FOR ALL    USING (current_app_role()='MANAGER');
CREATE POLICY "ba_read"              ON bundle_analytics FOR SELECT USING (current_app_role() IN ('CASHIER','RESEARCHER'));
CREATE POLICY "ba_cashier_insert"    ON bundle_analytics FOR INSERT WITH CHECK (current_app_role()='CASHIER');

-- =============================================================================
-- STEP 7: View antrian barista (pesanan cafe/food hari ini)
-- =============================================================================

CREATE OR REPLACE VIEW vw_barista_queue AS
SELECT
  t.id,
  t.trx_code,
  t.trx_at,
  t.status,
  t.notes,
  EXTRACT(MINUTE FROM (NOW() - t.trx_at))::INT AS minutes_waiting,
  json_agg(
    json_build_object(
      'item',     i.name_short,
      'qty',      td.qty,
      'notes',    td.special_notes,
      'category', td.category_code,
      'prep_sec', i.prep_time_sec
    ) ORDER BY td.id
  ) AS order_items
FROM transactions t
JOIN transaction_details td ON td.transaction_id = t.id
JOIN items i                ON td.item_id = i.id
WHERE t.status IN ('PENDING','COMPLETED')
  AND DATE(t.trx_at AT TIME ZONE 'Asia/Jakarta') = CURRENT_DATE
  AND td.category_code IN ('COFFEE','FOOD')
GROUP BY t.id, t.trx_code, t.trx_at, t.status, t.notes
ORDER BY t.trx_at;

-- =============================================================================
-- STEP 8: Fungsi ganti PIN sendiri
-- =============================================================================

CREATE OR REPLACE FUNCTION change_staff_pin(p_staff_id INT, p_old_pin TEXT, p_new_pin TEXT)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_hash TEXT;
BEGIN
  SELECT pin_hash INTO v_hash FROM staff WHERE id = p_staff_id;
  IF v_hash IS NULL OR NOT (v_hash = crypt(p_old_pin, v_hash)) THEN
    RETURN json_build_object('success',FALSE,'message','PIN lama tidak benar');
  END IF;
  IF LENGTH(p_new_pin) < 4 THEN
    RETURN json_build_object('success',FALSE,'message','PIN minimal 4 digit');
  END IF;
  UPDATE staff SET pin_hash = crypt(p_new_pin, gen_salt('bf')) WHERE id = p_staff_id;
  RETURN json_build_object('success',TRUE,'message','PIN berhasil diubah');
END; $$;

-- =============================================================================
-- STEP 9: Audit log
-- =============================================================================

CREATE TABLE IF NOT EXISTS audit_logs (
  id          BIGSERIAL    PRIMARY KEY,
  staff_id    INT          REFERENCES staff(id),
  action      VARCHAR(50)  NOT NULL,
  table_name  VARCHAR(50)  DEFAULT NULL,
  record_id   BIGINT       DEFAULT NULL,
  old_value   JSONB        DEFAULT NULL,
  new_value   JSONB        DEFAULT NULL,
  logged_at   TIMESTAMPTZ  DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_staff  ON audit_logs(staff_id, logged_at);
CREATE INDEX IF NOT EXISTS idx_audit_action ON audit_logs(action,   logged_at);

CREATE OR REPLACE FUNCTION log_audit(
  p_staff_id INT, p_action TEXT,
  p_table TEXT=NULL, p_record_id BIGINT=NULL,
  p_old JSONB=NULL,  p_new JSONB=NULL
) RETURNS VOID LANGUAGE sql SECURITY DEFINER AS $$
  INSERT INTO audit_logs(staff_id,action,table_name,record_id,old_value,new_value)
  VALUES(p_staff_id,p_action,p_table,p_record_id,p_old,p_new);
$$;

-- =============================================================================
-- RINGKASAN AKSES PER ROLE
-- Manager      : Full semua tabel + audit + void + delete
-- Cashier      : Baca semua trx, insert trx/expense, update PENDING milik sendiri
-- Barista      : Read items aktif, insert wastage, lihat vw_barista_queue
-- Stock_Keeper : Full items, baca wastage
-- Researcher   : Read-only trx/expense/analytics, no write
-- =============================================================================
