-- ============================================================================
-- Q1. ABC/XYZ analysis of the product range.
--
-- ABC: which SKUs generate the revenue? Class A = top SKUs making up to 80% of
--      revenue, B = next up to 95%, C = the long tail.
-- XYZ: how predictable is each SKU's demand? Coefficient of variation of
--      monthly kg — X = stable (<0.25), Y = moderate (0.25–0.50), Z = erratic.
--
-- The ABC/XYZ matrix tells you where to guarantee availability (AX) and where
-- to cut safety stock or delist (CZ). Technique: window running totals.
-- ============================================================================
WITH product_rev AS (
    SELECT product_key, SUM(revenue) AS revenue
    FROM fact_sales
    GROUP BY product_key
),
abc AS (
    SELECT product_key,
           revenue,
           SUM(revenue) OVER (ORDER BY revenue DESC)
               / SUM(revenue) OVER ()             AS cum_share,
           RANK() OVER (ORDER BY revenue DESC)    AS revenue_rank
    FROM product_rev
),
monthly AS (
    SELECT product_key,
           date_trunc('month', date_key) AS m,
           SUM(qty_kg)                    AS qty
    FROM fact_sales
    GROUP BY 1, 2
),
xyz AS (
    SELECT product_key,
           stddev_pop(qty) / NULLIF(avg(qty), 0) AS cv
    FROM monthly
    GROUP BY product_key
)
SELECT dp.sku,
       dp.name,
       dp.category,
       ROUND(a.revenue)                        AS revenue,
       ROUND(100 * a.cum_share, 1)             AS cum_share_pct,
       CASE WHEN a.cum_share <= 0.80 THEN 'A'
            WHEN a.cum_share <= 0.95 THEN 'B'
            ELSE 'C' END                        AS abc_class,
       ROUND(x.cv, 2)                          AS demand_cv,
       CASE WHEN x.cv < 0.25 THEN 'X'
            WHEN x.cv < 0.50 THEN 'Y'
            ELSE 'Z' END                        AS xyz_class
FROM abc a
JOIN dim_product dp ON dp.product_key = a.product_key
JOIN xyz x          ON x.product_key = a.product_key
ORDER BY a.revenue DESC;
