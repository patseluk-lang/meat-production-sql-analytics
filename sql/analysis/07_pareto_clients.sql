-- Q7. Pareto (80/20) analysis of clients.
--
-- Rank clients by revenue and accumulate their share. Answers: what fraction of
-- clients generates 80% of revenue? Concentration risk and where key-account
-- attention should go. Technique: window running total + share of grand total.
WITH client_rev AS (
    SELECT client_key, SUM(revenue) AS revenue
    FROM fact_sales
    GROUP BY client_key
),
ranked AS (
    SELECT cr.client_key,
           dc.name,
           dc.channel,
           cr.revenue,
           SUM(cr.revenue) OVER (ORDER BY cr.revenue DESC)  AS cum_rev,
           SUM(cr.revenue) OVER ()                          AS total_rev,
           ROW_NUMBER()    OVER (ORDER BY cr.revenue DESC)  AS rn,
           COUNT(*)        OVER ()                          AS n_clients
    FROM client_rev cr
    JOIN dim_client dc ON dc.client_key = cr.client_key
)
-- 7a. Top clients until 80% of revenue is reached
SELECT rn,
       name,
       channel,
       ROUND(revenue)                          AS revenue,
       ROUND(100 * cum_rev / total_rev, 1)     AS cum_share_pct,
       ROUND(100.0 * rn / n_clients, 1)        AS client_share_pct
FROM ranked
WHERE cum_rev / total_rev <= 0.80
ORDER BY rn;

-- 7b. One-line summary: the 80/20 split
WITH client_rev AS (
    SELECT client_key, SUM(revenue) AS revenue FROM fact_sales GROUP BY client_key
),
ranked AS (
    SELECT SUM(revenue) OVER (ORDER BY revenue DESC) / SUM(revenue) OVER () AS cum_share,
           COUNT(*) OVER () AS n_clients
    FROM client_rev
)
SELECT COUNT(*) FILTER (WHERE cum_share <= 0.80)                       AS clients_for_80pct,
       MAX(n_clients)                                                  AS total_clients,
       ROUND(100.0 * COUNT(*) FILTER (WHERE cum_share <= 0.80)
                   / MAX(n_clients), 1)                                AS pct_of_clients
FROM ranked;
