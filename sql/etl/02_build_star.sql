-- Build the star schema from the OLTP tables. Pure SQL: dimensions first,
-- then facts referencing them, then a materialized view for reporting.
TRUNCATE fact_sales, fact_production,
    dim_date, dim_product, dim_client, dim_channel RESTART IDENTITY CASCADE;

-- dim_date: a contiguous calendar covering all events
INSERT INTO dim_date (date_key, year, quarter, month, month_name, day, dow,
                      iso_week, is_weekend)
SELECT d::date,
       EXTRACT(YEAR   FROM d)::int,
       EXTRACT(QUARTER FROM d)::int,
       EXTRACT(MONTH  FROM d)::int,
       to_char(d, 'FMTMMonth'),
       EXTRACT(DAY    FROM d)::int,
       EXTRACT(DOW    FROM d)::int,
       EXTRACT(WEEK   FROM d)::int,
       EXTRACT(DOW    FROM d)::int IN (0, 6)
FROM generate_series(
        LEAST((SELECT MIN(order_date) FROM orders),
              (SELECT MIN(batch_date) FROM production_batches)),
        GREATEST((SELECT MAX(order_date) FROM orders),
                 (SELECT MAX(batch_date) FROM production_batches)),
        interval '1 day') AS g(d);

-- dim_channel
INSERT INTO dim_channel (channel)
SELECT DISTINCT channel FROM clients ORDER BY channel;

-- dim_product: unit_cost derived from the bill of materials
INSERT INTO dim_product (product_key, sku, name, category, shelf_life_days, unit_cost)
SELECT p.id, p.sku, p.name, p.category, p.shelf_life_days,
       COALESCE(SUM(b.qty_per_kg * i.cost_per_unit), 0)
FROM products p
LEFT JOIN bom b        ON b.product_id = p.id
LEFT JOIN ingredients i ON i.id = b.ingredient_id
GROUP BY p.id, p.sku, p.name, p.category, p.shelf_life_days;

-- dim_client
INSERT INTO dim_client (client_key, name, channel, region, since)
SELECT id, name, channel, region, since FROM clients;

-- fact_sales: one row per order line
INSERT INTO fact_sales (sale_id, date_key, product_key, client_key, channel_key,
                        qty_kg, unit_price, revenue, unit_cost, cogs, gross_margin)
SELECT oi.id,
       o.order_date,
       oi.product_id,
       o.client_id,
       ch.channel_key,
       oi.qty_kg,
       oi.unit_price,
       ROUND(oi.qty_kg * oi.unit_price, 2)                       AS revenue,
       dp.unit_cost,
       ROUND(oi.qty_kg * dp.unit_cost, 2)                        AS cogs,
       ROUND(oi.qty_kg * oi.unit_price - oi.qty_kg * dp.unit_cost, 2) AS gross_margin
FROM order_items oi
JOIN orders      o  ON o.id = oi.order_id
JOIN dim_client  dc ON dc.client_key = o.client_id
JOIN dim_channel ch ON ch.channel = dc.channel
JOIN dim_product dp ON dp.product_key = oi.product_id;

-- fact_production: one row per batch
INSERT INTO fact_production (prod_key, date_key, product_key, planned_kg,
                             actual_kg, yield_pct)
SELECT pb.id, pb.batch_date, pb.product_id, pb.planned_kg, pb.actual_kg,
       ROUND(pb.actual_kg / NULLIF(pb.planned_kg, 0), 4)
FROM production_batches pb;

-- reporting materialized view: monthly sales by product & channel
DROP MATERIALIZED VIEW IF EXISTS mv_monthly_sales;
CREATE MATERIALIZED VIEW mv_monthly_sales AS
SELECT date_trunc('month', fs.date_key)::date AS month,
       fs.product_key,
       fs.channel_key,
       SUM(fs.qty_kg)       AS qty_kg,
       SUM(fs.revenue)      AS revenue,
       SUM(fs.cogs)         AS cogs,
       SUM(fs.gross_margin) AS gross_margin
FROM fact_sales fs
GROUP BY 1, 2, 3
WITH DATA;

CREATE UNIQUE INDEX uq_mv_monthly_sales
    ON mv_monthly_sales (month, product_key, channel_key);
