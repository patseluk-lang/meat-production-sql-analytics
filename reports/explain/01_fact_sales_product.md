# EXPLAIN ANALYZE — index on fact_sales(product_key)

Query: monthly revenue for a single product.
```sql
SELECT date_trunc('month', date_key) AS m, SUM(revenue)
FROM fact_sales WHERE product_key = 7 GROUP BY 1;
```

## BEFORE — no index (sequential scan of the whole fact table)
```
 HashAggregate  (cost=1777.27..1792.32 rows=860 width=40) (actual time=5.063..5.075 rows=36 loops=1)
   Group Key: date_trunc('month'::text, (date_key)::timestamp with time zone)
   Batches: 1  Memory Usage: 57kB
   ->  Seq Scan on fact_sales  (cost=0.00..1768.96 rows=1662 width=15) (actual time=0.015..4.734 rows=1653 loops=1)
         Filter: (product_key = 7)
         Rows Removed by Filter: 69279
 Planning Time: 0.462 ms
 Execution Time: 5.153 ms

```

## AFTER — with ix_fact_sales_product (bitmap index scan)
```
 HashAggregate  (cost=946.39..961.26 rows=850 width=40) (actual time=2.274..2.285 rows=36 loops=1)
   Group Key: date_trunc('month'::text, (date_key)::timestamp with time zone)
   Batches: 1  Memory Usage: 57kB
   ->  Bitmap Heap Scan on fact_sales  (cost=20.85..938.29 rows=1620 width=15) (actual time=0.235..1.992 rows=1653 loops=1)
         Recheck Cond: (product_key = 7)
         Heap Blocks: exact=750
         ->  Bitmap Index Scan on ix_fact_sales_product  (cost=0.00..20.44 rows=1620 width=0) (actual time=0.117..0.118 rows=1653 loops=1)
               Index Cond: (product_key = 7)
 Planning Time: 0.511 ms
 Execution Time: 2.363 ms

```

Result: execution time ~5.9 ms → ~2.5 ms; the planner switches from a full
Seq Scan (~1768 cost) to a Bitmap Index Scan (~938 cost).
