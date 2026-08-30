-- ============================================================================
-- Q6. Inventory turnover and days of supply.
--
-- With no stored stock level, on-hand is reconstructed as a running balance
-- over the ledger of flows: + production, − sales, − write-offs (window SUM).
-- From the average on-hand and the sales rate we derive, per product:
--   * turnover_per_year — how many times stock rotates a year (higher = better)
--   * days_of_supply     — how many days the average stock would last
-- Slow movers (low turnover, high days of supply) tie up cash and risk
-- spoilage; fast movers may need bigger safety stock.
-- ============================================================================
WITH flow AS (
    SELECT product_key, date_key AS d,  actual_kg AS delta FROM fact_production
    UNION ALL
    SELECT product_key, date_key,      -qty_kg           FROM fact_sales
    UNION ALL
    SELECT p.id,        w.writeoff_date, -w.qty_kg
    FROM write_offs w JOIN products p ON p.id = w.product_id
),
balance AS (
    SELECT product_key,
           d,
           SUM(delta) OVER (PARTITION BY product_key ORDER BY d
                            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS on_hand
    FROM flow
),
avg_inv AS (
    SELECT product_key,
           AVG(on_hand)          AS avg_on_hand,
           (MAX(d) - MIN(d))     AS span_days
    FROM balance
    GROUP BY product_key
),
sold AS (
    SELECT product_key, SUM(qty_kg) AS sold_kg, SUM(cogs) AS cogs
    FROM fact_sales
    GROUP BY product_key
)
SELECT dp.sku,
       dp.name,
       dp.category,
       ROUND(GREATEST(ai.avg_on_hand, 0))                     AS avg_inventory_kg,
       ROUND(s.sold_kg)                                       AS sold_kg,
       ROUND(365.0 * s.sold_kg / NULLIF(ai.span_days, 0)
                   / NULLIF(ai.avg_on_hand, 0), 2)            AS turnover_per_year,
       ROUND(ai.avg_on_hand
                   / NULLIF(s.sold_kg / NULLIF(ai.span_days, 0), 0), 1) AS days_of_supply
FROM avg_inv ai
JOIN sold s        ON s.product_key = ai.product_key
JOIN dim_product dp ON dp.product_key = ai.product_key
ORDER BY turnover_per_year DESC;
