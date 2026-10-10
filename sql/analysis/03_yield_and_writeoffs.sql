-- Q3. Production yield (actual vs planned) and write-off (spoilage) rate.
--
-- Two management questions in one place:
--   * Are batches hitting planned output? (yield = actual / planned)
--   * How much finished product is written off, relative to what was made?
-- Short-shelf-life lines (pate, grill) should show the highest write-off rate.

-- 3a. Worst product-months by write-off rate (where to act first).
WITH prod AS (
    SELECT product_key,
           date_trunc('month', date_key) AS m,
           SUM(planned_kg) AS planned,
           SUM(actual_kg)  AS actual
    FROM fact_production
    GROUP BY 1, 2
),
wo AS (
    SELECT p.id AS product_key,
           date_trunc('month', w.writeoff_date) AS m,
           SUM(w.qty_kg) AS writeoff
    FROM write_offs w
    JOIN products p ON p.id = w.product_id
    GROUP BY 1, 2
)
SELECT dp.sku,
       dp.name,
       prod.m::date                                   AS month,
       ROUND(prod.planned)                            AS planned_kg,
       ROUND(prod.actual)                             AS actual_kg,
       ROUND(100 * prod.actual / NULLIF(prod.planned, 0), 1) AS yield_pct,
       ROUND(COALESCE(wo.writeoff, 0))                AS writeoff_kg,
       ROUND(100 * COALESCE(wo.writeoff, 0)
                 / NULLIF(prod.actual, 0), 1)         AS writeoff_pct
FROM prod
JOIN dim_product dp ON dp.product_key = prod.product_key
LEFT JOIN wo ON wo.product_key = prod.product_key AND wo.m = prod.m
ORDER BY writeoff_pct DESC NULLS LAST, month
LIMIT 20;

-- 3b. Category summary: average yield and overall write-off rate.
WITH prod AS (
    SELECT product_key, SUM(planned_kg) planned, SUM(actual_kg) actual
    FROM fact_production GROUP BY product_key
),
wo AS (
    SELECT product_id AS product_key, SUM(qty_kg) writeoff
    FROM write_offs GROUP BY product_id
)
SELECT dp.category,
       ROUND(100 * SUM(prod.actual) / NULLIF(SUM(prod.planned), 0), 1) AS avg_yield_pct,
       ROUND(SUM(COALESCE(wo.writeoff, 0)))                            AS writeoff_kg,
       ROUND(100 * SUM(COALESCE(wo.writeoff, 0))
                 / NULLIF(SUM(prod.actual), 0), 2)                     AS writeoff_pct
FROM prod
JOIN dim_product dp ON dp.product_key = prod.product_key
LEFT JOIN wo ON wo.product_key = prod.product_key
GROUP BY dp.category
ORDER BY writeoff_pct DESC;
