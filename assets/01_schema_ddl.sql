-- =============================================================================
-- MAKARYA HYBRID ERP — SUPABASE SCHEMA (PostgreSQL)
-- Converted from MySQL DDL
-- =============================================================================

-- 1. CATEGORIES
CREATE TABLE IF NOT EXISTS categories (
    id              SMALLSERIAL         PRIMARY KEY,
    code            VARCHAR(20)         NOT NULL UNIQUE,
    label           VARCHAR(60)         NOT NULL,
    icon_codepoint  VARCHAR(10)         DEFAULT NULL,
    color_hex       CHAR(7)             DEFAULT '#A9A9A9',
    sort_order      SMALLINT            DEFAULT 0,
    is_active       BOOLEAN             DEFAULT TRUE,
    created_at      TIMESTAMPTZ         DEFAULT NOW()
);

-- 2. SUPPLIERS
CREATE TABLE IF NOT EXISTS suppliers (
    id              SERIAL              PRIMARY KEY,
    code            VARCHAR(20)         NOT NULL UNIQUE,
    name            VARCHAR(120)        NOT NULL,
    contact_person  VARCHAR(80)         DEFAULT NULL,
    phone           VARCHAR(25)         DEFAULT NULL,
    email           VARCHAR(120)        DEFAULT NULL,
    address         TEXT                DEFAULT NULL,
    payment_terms   SMALLINT            DEFAULT 30,
    is_active       BOOLEAN             DEFAULT TRUE,
    created_at      TIMESTAMPTZ         DEFAULT NOW(),
    updated_at      TIMESTAMPTZ         DEFAULT NOW()
);

-- 3. TAX PROFILES
CREATE TABLE IF NOT EXISTS tax_profiles (
    id              SMALLSERIAL         PRIMARY KEY,
    name            VARCHAR(60)         NOT NULL,
    ppn_rate        DECIMAL(5,4)        NOT NULL DEFAULT 0.1100,
    service_rate    DECIMAL(5,4)        NOT NULL DEFAULT 0.0000,
    pb1_rate        DECIMAL(5,4)        NOT NULL DEFAULT 0.0000,
    is_default      BOOLEAN             DEFAULT FALSE,
    created_at      TIMESTAMPTZ         DEFAULT NOW()
);

-- 4. STAFF
CREATE TABLE IF NOT EXISTS staff (
    id              SERIAL              PRIMARY KEY,
    employee_id     VARCHAR(20)         NOT NULL UNIQUE,
    full_name       VARCHAR(100)        NOT NULL,
    role            VARCHAR(20)         NOT NULL DEFAULT 'CASHIER' CHECK (role IN ('MANAGER','CASHIER','BARISTA','STOCK_KEEPER','RESEARCHER')),
    shift           VARCHAR(20)         DEFAULT 'FULL' CHECK (shift IN ('MORNING','AFTERNOON','EVENING','FULL')),
    pin_hash        VARCHAR(255)        DEFAULT NULL,
    is_active       BOOLEAN             DEFAULT TRUE,
    hired_at        DATE                DEFAULT NULL,
    created_at      TIMESTAMPTZ         DEFAULT NOW()
);

-- 5. EXPENSE CATEGORIES
CREATE TABLE IF NOT EXISTS expense_categories (
    id              SMALLSERIAL         PRIMARY KEY,
    code            VARCHAR(30)         NOT NULL UNIQUE,
    label           VARCHAR(80)         NOT NULL,
    affects_profit  BOOLEAN             DEFAULT TRUE
);

-- 6. CUSTOMERS
CREATE TABLE IF NOT EXISTS customers (
    id              SERIAL              PRIMARY KEY,
    code            VARCHAR(30)         DEFAULT NULL UNIQUE,
    name            VARCHAR(120)        DEFAULT 'Guest',
    phone           VARCHAR(25)         DEFAULT NULL,
    email           VARCHAR(120)        DEFAULT NULL,
    birth_date      DATE                DEFAULT NULL,
    loyalty_points  INT                 DEFAULT 0,
    total_spend     DECIMAL(14,2)       DEFAULT 0.00,
    visit_count     INT                 DEFAULT 0,
    is_member       BOOLEAN             DEFAULT FALSE,
    created_at      TIMESTAMPTZ         DEFAULT NOW(),
    updated_at      TIMESTAMPTZ         DEFAULT NOW()
);

-- 7. ITEMS
CREATE TABLE IF NOT EXISTS items (
    id                  SERIAL          PRIMARY KEY,
    sku                 VARCHAR(40)     NOT NULL UNIQUE,
    qr_payload          VARCHAR(500)    DEFAULT NULL,
    category_id         SMALLINT        NOT NULL REFERENCES categories(id),
    supplier_id         INT             DEFAULT NULL REFERENCES suppliers(id),
    tax_profile_id      SMALLINT        DEFAULT 1 REFERENCES tax_profiles(id),
    name                VARCHAR(200)    NOT NULL,
    name_short          VARCHAR(80)     DEFAULT NULL,
    description         TEXT            DEFAULT NULL,
    image_path          VARCHAR(300)    DEFAULT NULL,
    -- Book fields
    isbn                VARCHAR(20)     DEFAULT NULL,
    author              VARCHAR(200)    DEFAULT NULL,
    publisher           VARCHAR(120)    DEFAULT NULL,
    published_year      SMALLINT        DEFAULT NULL,
    edition             VARCHAR(40)     DEFAULT NULL,
    pages               SMALLINT        DEFAULT NULL,
    genre               VARCHAR(80)     DEFAULT NULL,
    -- Cafe fields
    volume_ml           SMALLINT        DEFAULT NULL,
    temperature_option  VARCHAR(20)     DEFAULT NULL,
    caffeine_mg         SMALLINT        DEFAULT NULL,
    prep_time_sec       SMALLINT        DEFAULT NULL,
    -- Financial
    cost_price          DECIMAL(12,2)   NOT NULL DEFAULT 0.00,
    selling_price       DECIMAL(12,2)   NOT NULL DEFAULT 0.00,
    -- Inventory
    stock               INT             NOT NULL DEFAULT 0,
    min_stock_alert     INT             NOT NULL DEFAULT 5,
    max_stock           INT             DEFAULT NULL,
    unit                VARCHAR(20)     DEFAULT 'pcs',
    turnover_rate       DECIMAL(8,4)    DEFAULT 0.0000,
    shelf_life_days     SMALLINT        DEFAULT NULL,
    last_restocked      TIMESTAMPTZ     DEFAULT NULL,
    last_sold           TIMESTAMPTZ     DEFAULT NULL,
    is_bundle_eligible  BOOLEAN         DEFAULT TRUE,
    is_active           BOOLEAN         DEFAULT TRUE,
    created_at          TIMESTAMPTZ     DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     DEFAULT NOW()
);

-- 8. TRANSACTIONS
CREATE TABLE IF NOT EXISTS transactions (
    id              BIGSERIAL           PRIMARY KEY,
    trx_code        VARCHAR(30)         NOT NULL UNIQUE,
    customer_id     INT                 DEFAULT NULL REFERENCES customers(id),
    staff_id        INT                 NOT NULL REFERENCES staff(id),
    tax_profile_id  SMALLINT            NOT NULL DEFAULT 1 REFERENCES tax_profiles(id),
    trx_at          TIMESTAMPTZ         NOT NULL DEFAULT NOW(),
    subtotal        DECIMAL(14,2)       NOT NULL DEFAULT 0.00,
    discount_amount DECIMAL(14,2)       NOT NULL DEFAULT 0.00,
    discount_pct    DECIMAL(5,4)        NOT NULL DEFAULT 0.0000,
    ppn_amount      DECIMAL(14,2)       NOT NULL DEFAULT 0.00,
    service_charge  DECIMAL(14,2)       NOT NULL DEFAULT 0.00,
    pb1_amount      DECIMAL(14,2)       NOT NULL DEFAULT 0.00,
    grand_total     DECIMAL(14,2)       NOT NULL DEFAULT 0.00,
    total_cogs      DECIMAL(14,2)       NOT NULL DEFAULT 0.00,
    payment_method  VARCHAR(10)         NOT NULL DEFAULT 'CASH' CHECK (payment_method IN ('CASH','QRIS','DEBIT','CREDIT','VOUCHER','SPLIT')),
    payment_ref     VARCHAR(100)        DEFAULT NULL,
    cash_tendered   DECIMAL(14,2)       DEFAULT NULL,
    change_given    DECIMAL(14,2)       DEFAULT NULL,
    has_book        BOOLEAN             DEFAULT FALSE,
    has_cafe        BOOLEAN             DEFAULT FALSE,
    status          VARCHAR(10)         NOT NULL DEFAULT 'COMPLETED' CHECK (status IN ('PENDING','COMPLETED','VOIDED','REFUNDED')),
    void_reason     VARCHAR(200)        DEFAULT NULL,
    notes           TEXT                DEFAULT NULL,
    created_at      TIMESTAMPTZ         DEFAULT NOW()
);

-- Computed columns as views (PostgreSQL doesn't support stored generated cols like MySQL for these)
CREATE OR REPLACE VIEW transactions_computed AS
SELECT *,
    (has_book AND has_cafe)                     AS is_bundle,
    DATE(trx_at AT TIME ZONE 'Asia/Jakarta')    AS trx_date,
    EXTRACT(HOUR FROM trx_at AT TIME ZONE 'Asia/Jakarta')::SMALLINT AS trx_hour
FROM transactions;

-- 9. TRANSACTION DETAILS
CREATE TABLE IF NOT EXISTS transaction_details (
    id              BIGSERIAL           PRIMARY KEY,
    transaction_id  BIGINT              NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
    item_id         INT                 NOT NULL REFERENCES items(id),
    category_code   VARCHAR(20)         NOT NULL,
    qty             DECIMAL(10,3)       NOT NULL DEFAULT 1.000,
    unit_sell_price DECIMAL(12,2)       NOT NULL,
    cost_at_time    DECIMAL(12,2)       NOT NULL,
    unit_discount   DECIMAL(12,2)       NOT NULL DEFAULT 0.00,
    modifier_cost   DECIMAL(10,2)       DEFAULT 0.00,
    modifiers_json  JSONB               DEFAULT NULL,
    special_notes   VARCHAR(200)        DEFAULT NULL,
    created_at      TIMESTAMPTZ         DEFAULT NOW()
);

-- Computed columns for transaction_details
CREATE OR REPLACE VIEW transaction_details_computed AS
SELECT *,
    qty * (unit_sell_price - unit_discount + modifier_cost)             AS line_subtotal,
    qty * cost_at_time                                                  AS line_cogs,
    qty * (unit_sell_price - unit_discount + modifier_cost - cost_at_time) AS line_gross_pft,
    CASE WHEN (unit_sell_price - unit_discount) > 0
        THEN (unit_sell_price - unit_discount - cost_at_time) / (unit_sell_price - unit_discount)
        ELSE 0 END                                                      AS line_margin_pct
FROM transaction_details;

-- 10. EXPENSES
CREATE TABLE IF NOT EXISTS expenses (
    id              SERIAL              PRIMARY KEY,
    expense_cat_id  SMALLINT            NOT NULL REFERENCES expense_categories(id),
    staff_id        INT                 NOT NULL REFERENCES staff(id),
    reference_no    VARCHAR(60)         DEFAULT NULL,
    description     VARCHAR(300)        NOT NULL,
    amount          DECIMAL(14,2)       NOT NULL,
    expense_date    DATE                NOT NULL,
    expense_at      TIMESTAMPTZ         DEFAULT NOW(),
    is_recurring    BOOLEAN             DEFAULT FALSE,
    notes           TEXT                DEFAULT NULL
);

-- 11. WASTAGE LOGS
CREATE TABLE IF NOT EXISTS wastage_logs (
    id              BIGSERIAL           PRIMARY KEY,
    item_id         INT                 NOT NULL REFERENCES items(id),
    staff_id        INT                 NOT NULL REFERENCES staff(id),
    qty_wasted      DECIMAL(10,3)       NOT NULL,
    cost_at_time    DECIMAL(12,2)       NOT NULL,
    gross_waste_cost DECIMAL(14,2)      GENERATED ALWAYS AS (qty_wasted * cost_at_time) STORED,
    insurance_claim DECIMAL(12,2)       DEFAULT 0.00,
    net_waste_cost  DECIMAL(14,2)       GENERATED ALWAYS AS (qty_wasted * cost_at_time - insurance_claim) STORED,
    waste_type      VARCHAR(20)         NOT NULL CHECK (waste_type IN ('SPILLED','EXPIRED','DAMAGED','OVER_PREPARED','QUALITY_REJECT','THEFT','OTHER')),
    waste_date      DATE                NOT NULL DEFAULT CURRENT_DATE,
    notes           VARCHAR(300)        DEFAULT NULL,
    created_at      TIMESTAMPTZ         DEFAULT NOW()
);

-- 12. BUNDLE RULES
CREATE TABLE IF NOT EXISTS bundle_rules (
    id              SERIAL              PRIMARY KEY,
    name            VARCHAR(100)        NOT NULL,
    discount_type   VARCHAR(10)         DEFAULT 'PERCENT' CHECK (discount_type IN ('FIXED','PERCENT')),
    discount_value  DECIMAL(10,2)       NOT NULL DEFAULT 0.00,
    requires_cat_a  VARCHAR(20)         NOT NULL,
    requires_cat_b  VARCHAR(20)         NOT NULL,
    min_qty_a       SMALLINT            DEFAULT 1,
    min_qty_b       SMALLINT            DEFAULT 1,
    valid_from      DATE                DEFAULT NULL,
    valid_until     DATE                DEFAULT NULL,
    is_active       BOOLEAN             DEFAULT TRUE
);

-- 13. BUNDLE ANALYTICS
CREATE TABLE IF NOT EXISTS bundle_analytics (
    id              BIGSERIAL           PRIMARY KEY,
    transaction_id  BIGINT              NOT NULL UNIQUE REFERENCES transactions(id),
    book_item_id    INT                 DEFAULT NULL REFERENCES items(id),
    cafe_item_id    INT                 DEFAULT NULL REFERENCES items(id),
    bundle_rule_id  INT                 DEFAULT NULL REFERENCES bundle_rules(id),
    book_revenue    DECIMAL(12,2)       DEFAULT 0.00,
    cafe_revenue    DECIMAL(12,2)       DEFAULT 0.00,
    discount_given  DECIMAL(12,2)       DEFAULT 0.00,
    recorded_at     TIMESTAMPTZ         DEFAULT NOW()
);

-- =============================================================================
-- VIEWS FOR DASHBOARD
-- =============================================================================

-- Sales Mix (today)
CREATE OR REPLACE VIEW vw_sales_mix AS
SELECT
    td.category_code,
    c.label             AS category_label,
    c.color_hex,
    COUNT(DISTINCT t.id) AS transaction_count,
    SUM(td.qty)         AS units_sold,
    SUM(td.qty * (td.unit_sell_price - td.unit_discount)) AS revenue,
    SUM(td.qty * td.cost_at_time)   AS cogs,
    SUM(td.qty * (td.unit_sell_price - td.unit_discount - td.cost_at_time)) AS gross_profit
FROM transaction_details td
JOIN transactions t   ON td.transaction_id = t.id
JOIN categories c     ON c.code = td.category_code
WHERE t.status = 'COMPLETED'
  AND DATE(t.trx_at AT TIME ZONE 'Asia/Jakarta') = CURRENT_DATE
GROUP BY td.category_code, c.label, c.color_hex;

-- Peak Hours (last 30 days)
CREATE OR REPLACE VIEW vw_peak_hours AS
SELECT
    EXTRACT(HOUR FROM t.trx_at AT TIME ZONE 'Asia/Jakarta')::INT AS hour_of_day,
    LPAD(EXTRACT(HOUR FROM t.trx_at AT TIME ZONE 'Asia/Jakarta')::TEXT, 2, '0') || ':00' AS hour_label,
    COUNT(DISTINCT t.id)    AS transaction_count,
    SUM(t.grand_total)      AS revenue,
    AVG(t.grand_total)      AS avg_transaction_value,
    SUM(CASE WHEN t.has_book AND t.has_cafe THEN 1 ELSE 0 END) AS bundle_count
FROM transactions t
WHERE t.status = 'COMPLETED'
  AND t.trx_at >= NOW() - INTERVAL '30 days'
GROUP BY hour_of_day, hour_label
ORDER BY hour_of_day;

-- Inventory Aging
CREATE OR REPLACE VIEW vw_inventory_aging AS
SELECT
    i.id,
    i.sku,
    i.name,
    c.code              AS category_code,
    i.stock,
    i.min_stock_alert,
    i.cost_price,
    i.selling_price,
    i.last_sold,
    i.last_restocked,
    i.shelf_life_days,
    i.turnover_rate,
    EXTRACT(DAY FROM NOW() - i.last_sold)::INT AS days_since_last_sale,
    CASE
        WHEN i.stock = 0 THEN 'OUT_OF_STOCK'
        WHEN c.code = 'BOOK' AND EXTRACT(DAY FROM NOW() - i.last_sold) > 30 THEN 'SLOW_MOVER'
        WHEN c.code IN ('COFFEE','FOOD') AND i.shelf_life_days IS NOT NULL
             AND EXTRACT(DAY FROM NOW() - i.last_restocked) >= i.shelf_life_days THEN 'EXPIRED_RISK'
        WHEN i.stock <= i.min_stock_alert THEN 'LOW_STOCK'
        ELSE 'HEALTHY'
    END AS stock_health
FROM items i
JOIN categories c ON i.category_id = c.id
WHERE i.is_active = TRUE
ORDER BY days_since_last_sale DESC NULLS LAST;

-- Daily PnL
CREATE OR REPLACE VIEW vw_daily_pnl AS
SELECT
    DATE(t.trx_at AT TIME ZONE 'Asia/Jakarta')  AS report_date,
    COUNT(DISTINCT t.id)                         AS total_transactions,
    COUNT(DISTINCT CASE WHEN t.has_book AND t.has_cafe THEN t.id END) AS bundle_transactions,
    SUM(t.grand_total)                           AS net_revenue,
    SUM(t.total_cogs)                            AS total_cogs,
    SUM(t.grand_total) - SUM(t.total_cogs)       AS gross_profit
FROM transactions t
WHERE t.status = 'COMPLETED'
GROUP BY report_date
ORDER BY report_date DESC;

-- =============================================================================
-- INDEXES
-- =============================================================================
CREATE INDEX IF NOT EXISTS idx_trx_at_status     ON transactions(trx_at, status);
CREATE INDEX IF NOT EXISTS idx_td_category       ON transaction_details(category_code, transaction_id);
CREATE INDEX IF NOT EXISTS idx_items_active      ON items(is_active, category_id, last_sold);
CREATE INDEX IF NOT EXISTS idx_wl_date           ON wastage_logs(waste_date, item_id);
CREATE INDEX IF NOT EXISTS idx_exp_date          ON expenses(expense_date, expense_cat_id);

-- Enable Row Level Security (Supabase best practice)
ALTER TABLE transactions        ENABLE ROW LEVEL SECURITY;
ALTER TABLE transaction_details ENABLE ROW LEVEL SECURITY;
ALTER TABLE items               ENABLE ROW LEVEL SECURITY;
ALTER TABLE expenses            ENABLE ROW LEVEL SECURITY;

-- Allow all access for anon key (adjust in production!)
CREATE POLICY "Allow all" ON transactions        FOR ALL USING (true);
CREATE POLICY "Allow all" ON transaction_details FOR ALL USING (true);
CREATE POLICY "Allow all" ON items               FOR ALL USING (true);
CREATE POLICY "Allow all" ON expenses            FOR ALL USING (true);