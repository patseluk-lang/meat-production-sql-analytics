-- Q4. Sales seasonality and trend.
--
-- 4a. Monthly revenue with a 3-month moving average (to smooth noise) and
--     year-over-year growth (LAG 12 months). Shows the underlying trend and
--     whether each month beats the same month last year.
-- 4b. Seasonal index per calendar month: average revenue of that month vs the
--     overall monthly average (100 = typical month). Quantifies the December
--     peak and January trough for production planning.

-- 4a. Trend + moving average + YoY
WITH monthly AS (
    SELECT date_trunc('month', date_key)::date AS month,
           SUM(revenue) AS revenue,
           SUM(qty_kg)  AS qty_kg
    FROM fact_sales
    GROUP BY 1
)
SELECT month,
       ROUND(revenue)                                        AS revenue,
       ROUND(AVG(revenue) OVER (ORDER BY month
             ROWS BETWEEN 2 PRECEDING AND CURRENT ROW))      AS mov_avg_3m,
       ROUND(qty_kg)                                         AS qty_kg,
       ROUND(100 * (revenue - LAG(revenue, 12) OVER (ORDER BY month))
                 / NULLIF(LAG(revenue, 12) OVER (ORDER BY month), 0), 1) AS yoy_pct
FROM monthly
ORDER BY month;

-- 4b. Seasonal index by calendar month
WITH monthly AS (
    SELECT date_trunc('month', date_key) AS m, SUM(revenue) AS revenue
    FROM fact_sales
    GROUP BY 1
)
SELECT EXTRACT(MONTH FROM m)::int              AS month_no,
       to_char(m, 'FMMonth')                   AS month_name,
       ROUND(AVG(revenue))                     AS avg_revenue,
       ROUND(100 * AVG(revenue)
                 / (SELECT AVG(revenue) FROM monthly), 0) AS seasonal_index
FROM monthly
GROUP BY 1, 2
ORDER BY month_no;
