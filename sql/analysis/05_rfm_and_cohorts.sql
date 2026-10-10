-- Q5. B2B client value: RFM segmentation + cohort retention.
--
-- 5a. RFM — score every client 1..5 on Recency, Frequency and Monetary
--     (NTILE quintiles), then map to actionable segments. Shows where the
--     revenue concentrates and who is slipping away.
-- 5b. Cohort retention — group clients by the month of their first order and
--     track how many order again N months later. A recursive CTE generates the
--     0..12 month offsets so months with zero activity still appear.

-- 5a. RFM segmentation
WITH base AS (
    SELECT o.client_id,
           MAX(o.order_date)                       AS last_order,
           COUNT(DISTINCT o.id)                    AS frequency,
           SUM(oi.qty_kg * oi.unit_price)          AS monetary
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.id
    GROUP BY o.client_id
),
scored AS (
    SELECT b.*,
           (SELECT MAX(order_date) FROM orders) - last_order AS recency_days,
           NTILE(5) OVER (ORDER BY (SELECT MAX(order_date) FROM orders) - last_order DESC) AS r,
           NTILE(5) OVER (ORDER BY frequency)                                              AS f,
           NTILE(5) OVER (ORDER BY monetary)                                               AS m
    FROM base b
),
classified AS (
    SELECT s.*,
           CASE
               WHEN r >= 4 AND f >= 4            THEN 'Чемпіони'
               WHEN r >= 4 AND f >= 2            THEN 'Лояльні'
               WHEN r >= 3 AND f <= 2            THEN 'Нові/перспективні'
               WHEN r = 2  AND f >= 3            THEN 'Під загрозою'
               WHEN r <= 2 AND f >= 4            THEN 'Не можна втратити'
               ELSE 'Сплячі'
           END AS segment
    FROM scored s
)
SELECT segment,
       COUNT(*)                          AS clients,
       ROUND(SUM(monetary))              AS revenue,
       ROUND(100 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 1) AS revenue_share_pct,
       ROUND(AVG(recency_days))          AS avg_recency_days,
       ROUND(AVG(frequency), 1)          AS avg_frequency
FROM classified
GROUP BY segment
ORDER BY revenue DESC;

-- 5b. Cohort retention (recursive month offsets 0..12)
WITH RECURSIVE period(n) AS (
    SELECT 0
    UNION ALL
    SELECT n + 1 FROM period WHERE n < 12
),
first_order AS (
    SELECT client_id, date_trunc('month', MIN(order_date))::date AS cohort
    FROM orders
    GROUP BY client_id
),
cohort_size AS (
    SELECT cohort, COUNT(*) AS n_clients FROM first_order GROUP BY cohort
),
activity AS (
    SELECT DISTINCT client_id, date_trunc('month', order_date)::date AS am
    FROM orders
),
retained AS (
    SELECT f.cohort,
           p.n AS month_no,
           COUNT(DISTINCT a.client_id) AS n_active
    FROM first_order f
    CROSS JOIN period p
    LEFT JOIN activity a
           ON a.client_id = f.client_id
          AND a.am = (f.cohort + (p.n || ' month')::interval)::date
    GROUP BY f.cohort, p.n
)
SELECT r.cohort,
       cs.n_clients,
       r.month_no,
       r.n_active,
       ROUND(100.0 * r.n_active / NULLIF(cs.n_clients, 0), 1) AS retention_pct
FROM retained r
JOIN cohort_size cs ON cs.cohort = r.cohort
WHERE r.month_no IN (0, 1, 3, 6, 12)
ORDER BY r.cohort, r.month_no
LIMIT 60;
