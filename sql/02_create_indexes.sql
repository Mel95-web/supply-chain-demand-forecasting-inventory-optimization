CREATE INDEX IF NOT EXISTS idx_fact_sales_date
    ON warehouse.fact_sales (date_key);

CREATE INDEX IF NOT EXISTS idx_fact_sales_store
    ON warehouse.fact_sales (store_key);

ANALYZE warehouse.fact_sales;
