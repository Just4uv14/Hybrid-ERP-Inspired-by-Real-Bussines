-- =============================================================================
-- MAKARYA HYBRID ERP — MOCK DATA (PostgreSQL / Supabase)
-- =============================================================================

-- CATEGORIES
INSERT INTO categories (code, label, icon_codepoint, color_hex, sort_order) VALUES
('COFFEE',      'Kopi & Minuman',   'e5d2', '#8B5E3C', 1),
('FOOD',        'Makanan',          'e56c', '#C4956A', 2),
('BOOK',        'Buku',             'e865', '#A9A9A9', 3),
('MERCHANDISE', 'Merchandise',      'e8f8', '#5C6BC0', 4)
ON CONFLICT (code) DO NOTHING;

-- TAX PROFILES
INSERT INTO tax_profiles (name, ppn_rate, service_rate, pb1_rate, is_default) VALUES
('Standar PPN 11%',     0.1100, 0.0000, 0.0000, TRUE),
('Restoran (PB1+SC)',   0.0000, 0.0500, 0.1000, FALSE),
('Bebas Pajak',         0.0000, 0.0000, 0.0000, FALSE),
('Full Tax (PPN+SC)',   0.1100, 0.0500, 0.0000, FALSE)
ON CONFLICT DO NOTHING;

-- EXPENSE CATEGORIES
INSERT INTO expense_categories (code, label, affects_profit) VALUES
('SALARIES',    'Gaji Karyawan',        TRUE),
('UTILITIES',   'Listrik & Air',        TRUE),
('RENT',        'Sewa Tempat',          TRUE),
('MARKETING',   'Marketing & Promo',    TRUE),
('MAINTENANCE', 'Pemeliharaan',         TRUE),
('SUPPLIES',    'Perlengkapan Kantor',  TRUE),
('CAPEX',       'Investasi Aset',       FALSE),
('INSURANCE',   'Asuransi',             TRUE)
ON CONFLICT (code) DO NOTHING;

-- SUPPLIERS
INSERT INTO suppliers (code, name, contact_person, phone, email, payment_terms) VALUES
('SUP-KOPI-01', 'Sumber Kopi Nusantara',        'Budi Santoso',  '021-5551001', 'budi@skn.co.id',    30),
('SUP-KOPI-02', 'Flores Coffee Roasters',        'Maria Flores',  '021-5551002', 'maria@florescr.com',14),
('SUP-BUKU-01', 'Gramedia Pustaka Utama',        'Dewi Rahayu',   '021-5553001', 'dewi@gramedia.com', 60),
('SUP-BUKU-02', 'Mizan Publishing',              'Ahmad Fauzi',   '021-5553002', 'ahmad@mizan.com',   45),
('SUP-BUKU-03', 'Penerbit Kepustakaan Populer',  'Siti Aminah',   '021-5553003', 'siti@kpg.co.id',    45)
ON CONFLICT (code) DO NOTHING;

-- STAFF
INSERT INTO staff (employee_id, full_name, role, shift, hired_at) VALUES
('EMP-001', 'Arif Wibowo',    'MANAGER',      'FULL',      '2022-01-15'),
('EMP-002', 'Sari Permata',   'CASHIER',      'MORNING',   '2023-03-01'),
('EMP-003', 'Rizky Pratama',  'BARISTA',      'MORNING',   '2023-05-10'),
('EMP-004', 'Nadia Putri',    'CASHIER',      'AFTERNOON', '2023-07-20'),
('EMP-005', 'Fahmi Hakim',    'BARISTA',      'AFTERNOON', '2024-01-08'),
('EMP-006', 'Laila Fitriani', 'STOCK_KEEPER', 'MORNING',   '2023-09-15'),
('EMP-007', 'Dr. Bina Widya', 'RESEARCHER',   'FULL',      '2024-06-01')
ON CONFLICT (employee_id) DO NOTHING;

-- CUSTOMERS
INSERT INTO customers (code, name, phone, email, birth_date, loyalty_points, total_spend, visit_count, is_member) VALUES
('MBR-001', 'Andi Kurniawan',  '081234567890', 'andi@email.com',  '1990-05-15', 1250, 1875000, 42, TRUE),
('MBR-002', 'Dinda Maharani',  '081234567891', 'dinda@email.com', '1995-08-22',  890, 1335000, 28, TRUE),
('MBR-003', 'Hendra Gunawan',  '081234567892', NULL,              '1988-11-03',  520,  780000, 18, TRUE),
('MBR-004', 'Yunita Sari',     '081234567893', 'yunita@email.com','1992-02-14',  230,  345000,  9, TRUE),
('GUEST',   'Tamu / Walk-in',  NULL,           NULL,              NULL,            0,       0,  0, FALSE)
ON CONFLICT (code) DO NOTHING;

-- ITEMS — COFFEE
INSERT INTO items (sku, category_id, supplier_id, tax_profile_id, name, name_short, volume_ml, temperature_option, caffeine_mg, prep_time_sec, cost_price, selling_price, stock, min_stock_alert, unit, shelf_life_days, last_restocked, last_sold, is_bundle_eligible)
SELECT 'C-MKSIG-001', c.id, s.id, 4, 'Makarya Signature Espresso', 'Sig. Espresso', 60, 'HOT,ICED', 120, 180, 9500.00, 32000.00, 150, 20, 'cup', 14, NOW() - INTERVAL '3 days', NOW() - INTERVAL '1 hour', TRUE
FROM categories c, suppliers s WHERE c.code='COFFEE' AND s.code='SUP-KOPI-01'
ON CONFLICT (sku) DO NOTHING;

INSERT INTO items (sku, category_id, supplier_id, tax_profile_id, name, name_short, volume_ml, temperature_option, caffeine_mg, prep_time_sec, cost_price, selling_price, stock, min_stock_alert, unit, shelf_life_days, last_restocked, last_sold, is_bundle_eligible)
SELECT 'C-BSOAT-002', c.id, s.id, 4, 'Brown Sugar Oat Latte', 'BS Oat Latte', 350, 'HOT,ICED', 95, 240, 15500.00, 45000.00, 80, 15, 'cup', 14, NOW() - INTERVAL '5 days', NOW() - INTERVAL '30 minutes', TRUE
FROM categories c, suppliers s WHERE c.code='COFFEE' AND s.code='SUP-KOPI-02'
ON CONFLICT (sku) DO NOTHING;

INSERT INTO items (sku, category_id, supplier_id, tax_profile_id, name, name_short, volume_ml, temperature_option, caffeine_mg, prep_time_sec, cost_price, selling_price, stock, min_stock_alert, unit, shelf_life_days, last_restocked, last_sold, is_bundle_eligible)
SELECT 'C-V60GA-003', c.id, s.id, 4, 'V60 Pour Over — Aceh Gayo', 'V60 Gayo', 220, 'HOT', 140, 420, 12000.00, 38000.00, 60, 10, 'cup', 14, NOW() - INTERVAL '7 days', NOW() - INTERVAL '2 hours', TRUE
FROM categories c, suppliers s WHERE c.code='COFFEE' AND s.code='SUP-KOPI-01'
ON CONFLICT (sku) DO NOTHING;

INSERT INTO items (sku, category_id, supplier_id, tax_profile_id, name, name_short, volume_ml, temperature_option, caffeine_mg, prep_time_sec, cost_price, selling_price, stock, min_stock_alert, unit, shelf_life_days, last_restocked, last_sold, is_bundle_eligible)
SELECT 'C-MATPR-004', c.id, s.id, 4, 'Matcha Latte Premium', 'Matcha Premium', 350, 'HOT,ICED', 45, 200, 14500.00, 42000.00, 70, 15, 'cup', 10, NOW() - INTERVAL '4 days', NOW() - INTERVAL '45 minutes', TRUE
FROM categories c, suppliers s WHERE c.code='COFFEE' AND s.code='SUP-KOPI-02'
ON CONFLICT (sku) DO NOTHING;

INSERT INTO items (sku, category_id, supplier_id, tax_profile_id, name, name_short, volume_ml, temperature_option, caffeine_mg, prep_time_sec, cost_price, selling_price, stock, min_stock_alert, unit, shelf_life_days, last_restocked, last_sold, is_bundle_eligible)
SELECT 'C-TUBJA-005', c.id, s.id, 4, 'Kopi Tubruk Jawa Klasik', 'Tubruk Jawa', 200, 'HOT', 180, 120, 6500.00, 22000.00, 120, 25, 'cup', 21, NOW() - INTERVAL '2 days', NOW() - INTERVAL '3 hours', TRUE
FROM categories c, suppliers s WHERE c.code='COFFEE' AND s.code='SUP-KOPI-01'
ON CONFLICT (sku) DO NOTHING;

-- ITEMS — BOOKS
INSERT INTO items (sku, category_id, supplier_id, tax_profile_id, name, name_short, isbn, author, publisher, cost_price, selling_price, stock, min_stock_alert, unit, last_restocked, last_sold, is_bundle_eligible)
SELECT 'B-FILTE-001', c.id, s.id, 1, 'Filosofi Teras', 'Filosofi Teras', '9786024247515', 'Henry Manampiring', 'Kompas', 59000.00, 98000.00, 45, 8, 'pcs', NOW() - INTERVAL '10 days', NOW() - INTERVAL '2 hours', TRUE
FROM categories c, suppliers s WHERE c.code='BOOK' AND s.code='SUP-BUKU-01'
ON CONFLICT (sku) DO NOTHING;

INSERT INTO items (sku, category_id, supplier_id, tax_profile_id, name, name_short, isbn, author, publisher, cost_price, selling_price, stock, min_stock_alert, unit, last_restocked, last_sold, is_bundle_eligible)
SELECT 'B-BUTRE-002', c.id, s.id, 1, 'Bumi (Tere Liye)', 'Bumi', '9786020323040', 'Tere Liye', 'Gramedia', 52000.00, 89000.00, 38, 10, 'pcs', NOW() - INTERVAL '15 days', NOW() - INTERVAL '4 hours', TRUE
FROM categories c, suppliers s WHERE c.code='BOOK' AND s.code='SUP-BUKU-01'
ON CONFLICT (sku) DO NOTHING;

INSERT INTO items (sku, category_id, supplier_id, tax_profile_id, name, name_short, isbn, author, publisher, cost_price, selling_price, stock, min_stock_alert, unit, last_restocked, last_sold, is_bundle_eligible)
SELECT 'B-SAPIE-003', c.id, s.id, 1, 'Sapiens (ID)', 'Sapiens', '9786020990750', 'Yuval Noah Harari', 'KPG', 88000.00, 145000.00, 22, 5, 'pcs', NOW() - INTERVAL '20 days', NOW() - INTERVAL '6 hours', TRUE
FROM categories c, suppliers s WHERE c.code='BOOK' AND s.code='SUP-BUKU-03'
ON CONFLICT (sku) DO NOTHING;

INSERT INTO items (sku, category_id, supplier_id, tax_profile_id, name, name_short, isbn, author, publisher, cost_price, selling_price, stock, min_stock_alert, unit, last_restocked, last_sold, is_bundle_eligible)
SELECT 'B-ATHAT-004', c.id, s.id, 1, 'Atomic Habits (ID)', 'Atomic Habits', '9786230011047', 'James Clear', 'Gramedia', 70000.00, 115000.00, 55, 10, 'pcs', NOW() - INTERVAL '8 days', NOW() - INTERVAL '1 hour', TRUE
FROM categories c, suppliers s WHERE c.code='BOOK' AND s.code='SUP-BUKU-01'
ON CONFLICT (sku) DO NOTHING;

INSERT INTO items (sku, category_id, supplier_id, tax_profile_id, name, name_short, isbn, author, publisher, cost_price, selling_price, stock, min_stock_alert, unit, last_restocked, last_sold, is_bundle_eligible)
SELECT 'B-PULTR-005', c.id, s.id, 1, 'Pulang (Tere Liye)', 'Pulang', '9786020324920', 'Tere Liye', 'Republika', 48000.00, 79000.00, 18, 5, 'pcs', NOW() - INTERVAL '45 days', NOW() - INTERVAL '35 days', TRUE
FROM categories c, suppliers s WHERE c.code='BOOK' AND s.code='SUP-BUKU-01'
ON CONFLICT (sku) DO NOTHING;

-- BUNDLE RULES
INSERT INTO bundle_rules (name, discount_type, discount_value, requires_cat_a, requires_cat_b, min_qty_a, min_qty_b, is_active)
VALUES ('Book + Coffee 10%', 'PERCENT', 10.00, 'BOOK', 'COFFEE', 1, 1, TRUE)
ON CONFLICT DO NOTHING;

-- TRANSACTIONS (today's data)
DO $$
DECLARE
  v_staff2  INT; v_staff4  INT;
  v_cust1   INT; v_cust2   INT; v_cust3   INT; v_cust4   INT;
  v_item1   INT; v_item2   INT; v_item3   INT; v_item4   INT; v_item5   INT;
  v_item7   INT; v_item8   INT; v_item9   INT; v_item10  INT;
  v_rule1   INT;
  v_trx1 BIGINT; v_trx2 BIGINT; v_trx3 BIGINT; v_trx4 BIGINT;
  v_trx5 BIGINT; v_trx6 BIGINT; v_trx7 BIGINT; v_trx8 BIGINT;
  v_trx9 BIGINT; v_trx10 BIGINT;
BEGIN
  SELECT id INTO v_staff2  FROM staff WHERE employee_id='EMP-002';
  SELECT id INTO v_staff4  FROM staff WHERE employee_id='EMP-004';
  SELECT id INTO v_cust1   FROM customers WHERE code='MBR-001';
  SELECT id INTO v_cust2   FROM customers WHERE code='MBR-002';
  SELECT id INTO v_cust3   FROM customers WHERE code='MBR-003';
  SELECT id INTO v_cust4   FROM customers WHERE code='MBR-004';
  SELECT id INTO v_item1   FROM items WHERE sku='C-MKSIG-001';
  SELECT id INTO v_item2   FROM items WHERE sku='C-BSOAT-002';
  SELECT id INTO v_item3   FROM items WHERE sku='C-V60GA-003';
  SELECT id INTO v_item4   FROM items WHERE sku='C-MATPR-004';
  SELECT id INTO v_item5   FROM items WHERE sku='C-TUBJA-005';
  SELECT id INTO v_item7   FROM items WHERE sku='B-FILTE-001';
  SELECT id INTO v_item8   FROM items WHERE sku='B-BUTRE-002';
  SELECT id INTO v_item9   FROM items WHERE sku='B-SAPIE-003';
  SELECT id INTO v_item10  FROM items WHERE sku='B-ATHAT-004';
  SELECT id INTO v_rule1   FROM bundle_rules WHERE name='Book + Coffee 10%';

  -- TRX 1
  INSERT INTO transactions (trx_code, customer_id, staff_id, tax_profile_id, trx_at, subtotal, ppn_amount, service_charge, grand_total, total_cogs, payment_method, has_book, has_cafe, status)
  VALUES ('TRX-TODAY-0001', v_cust1, v_staff2, 4, NOW()-INTERVAL '7 hours 30 minutes', 54000, 5940, 2700, 100920, 9500, 'CASH', FALSE, TRUE, 'COMPLETED')
  RETURNING id INTO v_trx1;
  INSERT INTO transaction_details (transaction_id, item_id, category_code, qty, unit_sell_price, cost_at_time) VALUES (v_trx1, v_item1, 'COFFEE', 1, 32000, 9500);

  -- TRX 2 (bundle)
  INSERT INTO transactions (trx_code, customer_id, staff_id, tax_profile_id, trx_at, subtotal, discount_amount, discount_pct, ppn_amount, grand_total, total_cogs, payment_method, cash_tendered, change_given, has_book, has_cafe, status)
  VALUES ('TRX-TODAY-0002', v_cust1, v_staff2, 1, NOW()-INTERVAL '6 hours', 213000, 21300, 0.10, 21252, 212952, 127500, 'CASH', 220000, 7048, TRUE, TRUE, 'COMPLETED')
  RETURNING id INTO v_trx2;
  INSERT INTO transaction_details (transaction_id, item_id, category_code, qty, unit_sell_price, cost_at_time, unit_discount) VALUES
  (v_trx2, v_item7,  'BOOK',   1, 98000,  59000, 9800),
  (v_trx2, v_item8,  'BOOK',   1, 115000, 70000, 11500),
  (v_trx2, v_item2,  'COFFEE', 1, 45000,  15500, 4500);
  INSERT INTO bundle_analytics (transaction_id, book_item_id, cafe_item_id, bundle_rule_id, book_revenue, cafe_revenue, discount_given) VALUES (v_trx2, v_item7, v_item2, v_rule1, 202200, 40500, 25800);

  -- TRX 3
  INSERT INTO transactions (trx_code, customer_id, staff_id, tax_profile_id, trx_at, subtotal, ppn_amount, grand_total, total_cogs, payment_method, has_book, has_cafe, status)
  VALUES ('TRX-TODAY-0003', v_cust2, v_staff2, 1, NOW()-INTERVAL '5 hours', 145000, 15950, 160950, 88000, 'DEBIT', TRUE, FALSE, 'COMPLETED')
  RETURNING id INTO v_trx3;
  INSERT INTO transaction_details (transaction_id, item_id, category_code, qty, unit_sell_price, cost_at_time) VALUES (v_trx3, v_item9, 'BOOK', 1, 145000, 88000);

  -- TRX 4
  INSERT INTO transactions (trx_code, customer_id, staff_id, tax_profile_id, trx_at, subtotal, ppn_amount, service_charge, grand_total, total_cogs, payment_method, payment_ref, has_book, has_cafe, status)
  VALUES ('TRX-TODAY-0004', NULL, v_staff4, 4, NOW()-INTERVAL '4 hours', 129000, 14190, 6450, 149640, 39500, 'QRIS', 'QRIS-TRX-004', FALSE, TRUE, 'COMPLETED')
  RETURNING id INTO v_trx4;
  INSERT INTO transaction_details (transaction_id, item_id, category_code, qty, unit_sell_price, cost_at_time) VALUES
  (v_trx4, v_item3, 'COFFEE', 2, 38000, 12000),
  (v_trx4, v_item4, 'COFFEE', 1, 42000, 14500);

  -- TRX 5 (bundle)
  INSERT INTO transactions (trx_code, customer_id, staff_id, tax_profile_id, trx_at, subtotal, discount_amount, discount_pct, ppn_amount, grand_total, total_cogs, payment_method, cash_tendered, change_given, has_book, has_cafe, status)
  VALUES ('TRX-TODAY-0005', v_cust3, v_staff4, 1, NOW()-INTERVAL '3 hours', 153000, 15300, 0.10, 15147, 152847, 82000, 'CASH', 160000, 7153, TRUE, TRUE, 'COMPLETED')
  RETURNING id INTO v_trx5;
  INSERT INTO transaction_details (transaction_id, item_id, category_code, qty, unit_sell_price, cost_at_time, unit_discount) VALUES
  (v_trx5, v_item8, 'BOOK',   1, 115000, 70000, 11500),
  (v_trx5, v_item3, 'COFFEE', 1, 38000,  12000, 3800);
  INSERT INTO bundle_analytics (transaction_id, book_item_id, cafe_item_id, bundle_rule_id, book_revenue, cafe_revenue, discount_given) VALUES (v_trx5, v_item8, v_item3, v_rule1, 103500, 34200, 15300);

  -- TRX 6
  INSERT INTO transactions (trx_code, customer_id, staff_id, tax_profile_id, trx_at, subtotal, ppn_amount, service_charge, grand_total, total_cogs, payment_method, has_book, has_cafe, status)
  VALUES ('TRX-TODAY-0006', v_cust4, v_staff4, 4, NOW()-INTERVAL '2 hours', 84000, 9240, 4200, 97440, 29000, 'CREDIT', FALSE, TRUE, 'COMPLETED')
  RETURNING id INTO v_trx6;
  INSERT INTO transaction_details (transaction_id, item_id, category_code, qty, unit_sell_price, cost_at_time) VALUES (v_trx6, v_item4, 'COFFEE', 2, 42000, 14500);

  -- TRX 7
  INSERT INTO transactions (trx_code, customer_id, staff_id, tax_profile_id, trx_at, subtotal, ppn_amount, grand_total, total_cogs, payment_method, has_book, has_cafe, status)
  VALUES ('TRX-TODAY-0007', v_cust2, v_staff4, 1, NOW()-INTERVAL '90 minutes', 145000, 15950, 160950, 88000, 'QRIS', TRUE, FALSE, 'COMPLETED')
  RETURNING id INTO v_trx7;
  INSERT INTO transaction_details (transaction_id, item_id, category_code, qty, unit_sell_price, cost_at_time) VALUES (v_trx7, v_item9, 'BOOK', 1, 145000, 88000);

  -- TRX 8 (bundle)
  INSERT INTO transactions (trx_code, customer_id, staff_id, tax_profile_id, trx_at, subtotal, discount_amount, discount_pct, ppn_amount, grand_total, total_cogs, payment_method, cash_tendered, change_given, has_book, has_cafe, status)
  VALUES ('TRX-TODAY-0008', v_cust1, v_staff4, 1, NOW()-INTERVAL '60 minutes', 184000, 18400, 0.10, 18216, 183816, 97500, 'CASH', 200000, 16184, TRUE, TRUE, 'COMPLETED')
  RETURNING id INTO v_trx8;
  INSERT INTO transaction_details (transaction_id, item_id, category_code, qty, unit_sell_price, cost_at_time, unit_discount) VALUES
  (v_trx8, v_item7, 'BOOK',   1, 98000, 59000, 9800),
  (v_trx8, v_item1, 'COFFEE', 2, 32000,  9500, 3200),
  (v_trx8, v_item5, 'COFFEE', 1, 22000,  6500, 2200);
  INSERT INTO bundle_analytics (transaction_id, book_item_id, cafe_item_id, bundle_rule_id, book_revenue, cafe_revenue, discount_given) VALUES (v_trx8, v_item7, v_item1, v_rule1, 88200, 77400, 18400);

  -- TRX 9
  INSERT INTO transactions (trx_code, customer_id, staff_id, tax_profile_id, trx_at, subtotal, ppn_amount, service_charge, grand_total, total_cogs, payment_method, payment_ref, has_book, has_cafe, status)
  VALUES ('TRX-TODAY-0009', NULL, v_staff4, 4, NOW()-INTERVAL '30 minutes', 22000, 2420, 1100, 25520, 6500, 'QRIS', 'QRIS-TRX-009', FALSE, TRUE, 'COMPLETED')
  RETURNING id INTO v_trx9;
  INSERT INTO transaction_details (transaction_id, item_id, category_code, qty, unit_sell_price, cost_at_time) VALUES (v_trx9, v_item5, 'COFFEE', 1, 22000, 6500);

  -- TRX 10 (bundle)
  INSERT INTO transactions (trx_code, customer_id, staff_id, tax_profile_id, trx_at, subtotal, discount_amount, discount_pct, ppn_amount, grand_total, total_cogs, payment_method, payment_ref, has_book, has_cafe, status)
  VALUES ('TRX-TODAY-0010', v_cust3, v_staff4, 1, NOW()-INTERVAL '10 minutes', 204000, 20400, 0.10, 20196, 203796, 134500, 'QRIS', 'QRIS-TRX-010', TRUE, TRUE, 'COMPLETED')
  RETURNING id INTO v_trx10;
  INSERT INTO transaction_details (transaction_id, item_id, category_code, qty, unit_sell_price, cost_at_time, unit_discount) VALUES
  (v_trx10, v_item10, 'BOOK',   1, 115000, 70000, 11500),
  (v_trx10, v_item9,  'BOOK',   1,  89000, 52000,  8900),
  (v_trx10, v_item2,  'COFFEE', 1,  45000, 15500,  4500);
  INSERT INTO bundle_analytics (transaction_id, book_item_id, cafe_item_id, bundle_rule_id, book_revenue, cafe_revenue, discount_given) VALUES (v_trx10, v_item10, v_item2, v_rule1, 183600, 40500, 20400);

  -- EXPENSES
  INSERT INTO expenses (expense_cat_id, staff_id, description, amount, expense_date) VALUES
  ((SELECT id FROM expense_categories WHERE code='SALARIES'),    v_staff2, 'Gaji karyawan minggu ini',    28500000, CURRENT_DATE - 6),
  ((SELECT id FROM expense_categories WHERE code='UTILITIES'),   v_staff2, 'Listrik & Air',                3200000, CURRENT_DATE - 5),
  ((SELECT id FROM expense_categories WHERE code='RENT'),        v_staff2, 'Sewa tempat bulan ini',       15000000, CURRENT_DATE - 5),
  ((SELECT id FROM expense_categories WHERE code='MARKETING'),   v_staff2, 'Promo media sosial',            500000, CURRENT_DATE - 2),
  ((SELECT id FROM expense_categories WHERE code='MAINTENANCE'),  v_staff2, 'Service mesin kopi',           750000, CURRENT_DATE - 1),
  ((SELECT id FROM expense_categories WHERE code='SUPPLIES'),    v_staff2, 'Perlengkapan kantor',           280000, CURRENT_DATE);

  -- WASTAGE LOGS
  INSERT INTO wastage_logs (item_id, staff_id, qty_wasted, cost_at_time, insurance_claim, waste_type, waste_date) VALUES
  (v_item1, v_staff4, 2.0, 9500,  0, 'SPILLED',        CURRENT_DATE),
  (v_item2, v_staff4, 1.0, 15500, 0, 'QUALITY_REJECT', CURRENT_DATE),
  (v_item4, v_staff4, 0.5, 14500, 0, 'OVER_PREPARED',  CURRENT_DATE),
  (v_item5, v_staff4, 3.0, 6500,  0, 'EXPIRED',        CURRENT_DATE),
  (v_item7, v_staff4, 1.0, 59000, 0, 'DAMAGED',        CURRENT_DATE);

END $$;