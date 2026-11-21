CREATE SCHEMA IF NOT EXISTS warehouse;

CREATE TABLE IF NOT EXISTS warehouse.dim_product (
    product_key INTEGER PRIMARY KEY,
    item_id VARCHAR(30) NOT NULL UNIQUE,
    dept_id VARCHAR(20) NOT NULL,
    cat_id VARCHAR(20) NOT NULL
);

CREATE TABLE IF NOT EXISTS warehouse.dim_store (
    store_key INTEGER PRIMARY KEY,
    store_id VARCHAR(10) NOT NULL UNIQUE,
    state_id VARCHAR(2) NOT NULL
);

CREATE TABLE IF NOT EXISTS warehouse.dim_date (
    date_key INTEGER PRIMARY KEY,
    date DATE NOT NULL UNIQUE,
    wm_yr_wk INTEGER NOT NULL,
    weekday VARCHAR(15) NOT NULL,
    wday SMALLINT NOT NULL,
    month SMALLINT NOT NULL,
    year SMALLINT NOT NULL,
    d VARCHAR(10) NOT NULL UNIQUE,
    event_name_1 VARCHAR(50) NOT NULL,
    event_type_1 VARCHAR(30) NOT NULL,
    event_name_2 VARCHAR(50) NOT NULL,
    event_type_2 VARCHAR(30) NOT NULL,
    snap_ca SMALLINT NOT NULL,
    snap_tx SMALLINT NOT NULL,
    snap_wi SMALLINT NOT NULL,
    quarter SMALLINT NOT NULL,
    day_of_month SMALLINT NOT NULL,
    week_of_year SMALLINT NOT NULL,
    is_weekend SMALLINT NOT NULL,
    is_month_start SMALLINT NOT NULL,
    is_month_end SMALLINT NOT NULL,
    event_count SMALLINT NOT NULL,
    is_event SMALLINT NOT NULL,
    -- Validierung der Kalenderattribute
    CHECK (wday BETWEEN 1 AND 7),
    CHECK (month BETWEEN 1 AND 12),
    CHECK (quarter BETWEEN 1 AND 4),
    CHECK (day_of_month BETWEEN 1 AND 31),
    CHECK (week_of_year BETWEEN 1 AND 53),
    CHECK (snap_ca IN (0, 1)),
    CHECK (snap_tx IN (0, 1)),
    CHECK (snap_wi IN (0, 1)),
    CHECK (is_weekend IN (0, 1)),
    CHECK (is_month_start IN (0, 1)),
    CHECK (is_month_end IN (0, 1)),
    CHECK (event_count BETWEEN 0 AND 2),
    CHECK (is_event IN (0, 1))
);

CREATE TABLE IF NOT EXISTS warehouse.fact_sales (
    product_key INTEGER NOT NULL,
    store_key INTEGER NOT NULL,
    date_key INTEGER NOT NULL,
    sales INTEGER NOT NULL,
    sell_price NUMERIC(10,2),
    revenue NUMERIC(14,2) NOT NULL,
    price_available SMALLINT NOT NULL,
    has_sales SMALLINT NOT NULL,
    -- Zusammengesetzter Primärschlüssel
    CONSTRAINT pk_fact_sales
        PRIMARY KEY (product_key, store_key, date_key),
    -- Fremdschlüssel
    CONSTRAINT fk_fact_product
        FOREIGN KEY (product_key)
        REFERENCES warehouse.dim_product(product_key),
    CONSTRAINT fk_fact_store
        FOREIGN KEY (store_key)
        REFERENCES warehouse.dim_store(store_key),
    CONSTRAINT fk_fact_date
        FOREIGN KEY (date_key)
        REFERENCES warehouse.dim_date(date_key),
    -- Fachliche Datenqualitätsregeln
    CHECK (sales >= 0),
    CHECK (sell_price > 0),
    CHECK (revenue >= 0),
    CHECK (price_available IN (0, 1)),
    CHECK (has_sales IN (0, 1))
);
