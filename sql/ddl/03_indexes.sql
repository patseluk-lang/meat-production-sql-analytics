-- Indexes for the analytical workload. Created after the bulk load so the
-- COPY stays fast. See reports/explain/ for EXPLAIN ANALYZE before/after.

-- Fact tables: the columns joined to dimensions and filtered by date.
CREATE INDEX IF NOT EXISTS ix_fact_sales_date     ON fact_sales (date_key);
CREATE INDEX IF NOT EXISTS ix_fact_sales_product  ON fact_sales (product_key);
CREATE INDEX IF NOT EXISTS ix_fact_sales_client   ON fact_sales (client_key);
CREATE INDEX IF NOT EXISTS ix_fact_sales_channel  ON fact_sales (channel_key);

CREATE INDEX IF NOT EXISTS ix_fact_prod_date      ON fact_production (date_key);
CREATE INDEX IF NOT EXISTS ix_fact_prod_product   ON fact_production (product_key);

-- OLTP indexes used by the ETL joins and any operational queries.
CREATE INDEX IF NOT EXISTS ix_order_items_order   ON order_items (order_id);
CREATE INDEX IF NOT EXISTS ix_order_items_product ON order_items (product_id);
CREATE INDEX IF NOT EXISTS ix_orders_date         ON orders (order_date);
CREATE INDEX IF NOT EXISTS ix_prices_product      ON prices (product_id);
CREATE INDEX IF NOT EXISTS ix_writeoffs_product   ON write_offs (product_id);
CREATE INDEX IF NOT EXISTS ix_batches_product     ON production_batches (product_id);

ANALYZE;
