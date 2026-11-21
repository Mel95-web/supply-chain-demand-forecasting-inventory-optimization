-- Erstellung des Data-Warehouse-Schemas

CREATE SCHEMA IF NOT EXISTS warehouse;

-- Überprüfung des erstellten Datenbankschemas

SELECT
    schema_name,
    schema_owner
FROM information_schema.schemata
WHERE schema_name = 'warehouse';



-- Erstellung der Produktdimension

CREATE TABLE IF NOT EXISTS warehouse.dim_product (

    product_key INTEGER PRIMARY KEY,

    item_id VARCHAR(30) NOT NULL UNIQUE,

    dept_id VARCHAR(20) NOT NULL,

    cat_id VARCHAR(20) NOT NULL

);

-- Erstellung der Filialdimension

CREATE TABLE IF NOT EXISTS warehouse.dim_store (

    store_key INTEGER PRIMARY KEY,

    store_id VARCHAR(10) NOT NULL UNIQUE,

    state_id VARCHAR(2) NOT NULL

);


-- Erstellung der Kalenderdimension

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

-- Überprüfung der erstellten Dimensionstabellen

SELECT
    table_name,
    COUNT(*) AS anzahl_spalten
FROM information_schema.columns
WHERE table_schema = 'warehouse'
GROUP BY table_name
ORDER BY table_name;


-- Erstellung der zentralen Faktentabelle

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


-- Überprüfung aller Tabellen des Star Schemas

SELECT
    table_name,
    COUNT(*) AS anzahl_spalten
FROM information_schema.columns
WHERE table_schema = 'warehouse'
GROUP BY table_name
ORDER BY table_name;

-- Überprüfung der importierten Produktdimension

SELECT *
FROM warehouse.dim_product
ORDER BY product_key
LIMIT 10;

-- Ermittlung der Anzahl importierter Produkte

SELECT COUNT(*) AS anzahl_produkte
FROM warehouse.dim_product;

-- Überprüfung aller importierten Dimensionstabellen

SELECT
    'dim_product' AS tabelle,
    COUNT(*) AS anzahl_beobachtungen
FROM warehouse.dim_product

UNION ALL

SELECT
    'dim_store',
    COUNT(*)
FROM warehouse.dim_store

UNION ALL

SELECT
    'dim_date',
    COUNT(*)
FROM warehouse.dim_date;


-- Validierung der importierten Faktentabelle

SELECT
    COUNT(*) AS anzahl_beobachtungen,
    SUM(sales) AS gesamtabsatz,
    ROUND(SUM(revenue), 2) AS gesamtumsatz_usd,
    COUNT(*) FILTER (
        WHERE sell_price IS NULL
    ) AS fehlende_verkaufspreise,
    COUNT(*) FILTER (
        WHERE sales > 0 AND sell_price IS NULL
    ) AS fehlende_preise_bei_absatz
FROM warehouse.fact_sales;


-- Index für zeitbezogene Analysen

CREATE INDEX IF NOT EXISTS idx_fact_sales_date
ON warehouse.fact_sales (date_key);

-- Index für Analysen auf Filialebene

CREATE INDEX IF NOT EXISTS idx_fact_sales_store
ON warehouse.fact_sales (store_key);

-- Aktualisierung der Datenbankstatistiken

ANALYZE warehouse.fact_sales;



-- Überprüfung der vorhandenen Indizes

SELECT
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'warehouse'
  AND tablename = 'fact_sales'
ORDER BY indexname;


-- Überprüfung der referenziellen Integrität

SELECT
    COUNT(*) AS anzahl_beobachtungen,

    COUNT(*) FILTER (
        WHERE p.product_key IS NULL
    ) AS fehlende_produktreferenzen,

    COUNT(*) FILTER (
        WHERE s.store_key IS NULL
    ) AS fehlende_filialreferenzen,

    COUNT(*) FILTER (
        WHERE d.date_key IS NULL
    ) AS fehlende_datumsreferenzen

FROM warehouse.fact_sales AS f

LEFT JOIN warehouse.dim_product AS p
    ON f.product_key = p.product_key

LEFT JOIN warehouse.dim_store AS s
    ON f.store_key = s.store_key

LEFT JOIN warehouse.dim_date AS d
    ON f.date_key = d.date_key;


-- Monatliche Absatz- und Umsatzentwicklung

SELECT
    DATE_TRUNC('month', d.date)::date AS monat,
    SUM(f.sales) AS gesamtabsatz,
    ROUND(SUM(f.revenue), 2) AS gesamtumsatz_usd

FROM warehouse.fact_sales AS f

INNER JOIN warehouse.dim_date AS d
    ON f.date_key = d.date_key

GROUP BY
    DATE_TRUNC('month', d.date)

ORDER BY
    monat;


-- Absatz- und Umsatzanalyse nach Produktkategorien

SELECT
    p.cat_id AS kategorie,
    SUM(f.sales) AS gesamtabsatz,
    ROUND(SUM(f.revenue), 2) AS gesamtumsatz_usd,
    COUNT(DISTINCT p.product_key) AS anzahl_produkte

FROM warehouse.fact_sales AS f

INNER JOIN warehouse.dim_product AS p
    ON f.product_key = p.product_key

GROUP BY p.cat_id

ORDER BY gesamtumsatz_usd DESC;


-- Absatz- und Umsatzanalyse nach Filialen

SELECT
    s.store_id AS filiale,
    s.state_id AS bundesstaat,
    SUM(f.sales) AS gesamtabsatz,
    ROUND(SUM(f.revenue), 2) AS gesamtumsatz_usd

FROM warehouse.fact_sales AS f

INNER JOIN warehouse.dim_store AS s
    ON f.store_key = s.store_key

GROUP BY
    s.store_id,
    s.state_id

ORDER BY
    gesamtumsatz_usd DESC;


-- Absatz- und Umsatzanalyse nach Bundesstaat

SELECT
    s.state_id AS bundesstaat,
    COUNT(DISTINCT s.store_key) AS anzahl_filialen,
    SUM(f.sales) AS gesamtabsatz,
    ROUND(SUM(f.revenue), 2) AS gesamtumsatz_usd

FROM warehouse.fact_sales AS f

INNER JOIN warehouse.dim_store AS s
    ON f.store_key = s.store_key

GROUP BY s.state_id

ORDER BY gesamtumsatz_usd DESC;


-- Verteilung von Beobachtungen mit und ohne Absatz

SELECT
    COUNT(*) AS anzahl_beobachtungen,

    COUNT(*) FILTER (
        WHERE sales = 0
    ) AS beobachtungen_ohne_absatz,

    COUNT(*) FILTER (
        WHERE sales > 0
    ) AS beobachtungen_mit_absatz,

    ROUND(
        100.0 * COUNT(*) FILTER (WHERE sales = 0)
        / NULLIF(COUNT(*), 0),
        2
    ) AS nullabsatz_anteil_prozent

FROM warehouse.fact_sales;