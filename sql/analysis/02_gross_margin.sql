-- Q2. Gross margin by product category and sales channel.
--
-- Cost of goods is the material cost from the bill of materials (dim_product.
-- unit_cost, computed from bom × ingredient cost during ETL), so "margin" here
-- is the contribution over materials. GROUPING SETS produces the category ×
-- channel matrix together with per-category, per-channel and grand-total
-- subtotals in a single pass.
SELECT COALESCE(dp.category, '→ ВСІ категорії')          AS category,
       COALESCE(dc.channel, '→ ВСІ канали')              AS channel,
       ROUND(SUM(fs.revenue))                            AS revenue,
       ROUND(SUM(fs.cogs))                               AS cogs,
       ROUND(SUM(fs.gross_margin))                       AS gross_margin,
       ROUND(100 * SUM(fs.gross_margin)
                 / NULLIF(SUM(fs.revenue), 0), 1)        AS margin_pct
FROM fact_sales fs
JOIN dim_product dp ON dp.product_key = fs.product_key
JOIN dim_channel dc ON dc.channel_key = fs.channel_key
GROUP BY GROUPING SETS (
    (dp.category, dc.channel),   -- the full matrix
    (dp.category),               -- subtotal per category
    (dc.channel),                -- subtotal per channel
    ()                           -- grand total
)
ORDER BY GROUPING(dp.category), category,
         GROUPING(dc.channel), channel;
