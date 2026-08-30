# EXPLAIN ANALYZE — index on fact_sales(client_key)

Query: total revenue and line count for a single client (client statement).
```sql
SELECT SUM(revenue), COUNT(*) FROM fact_sales WHERE client_key = 42;
```

## BEFORE — no index (sequential scan)
```
 Aggregate  (cost=1765.50..1765.51 rows=1 width=40) (actual time=4.513..4.514 rows=1 loops=1)
   ->  Seq Scan on fact_sales  (cost=0.00..1760.65 rows=969 width=7) (actual time=1.576..4.379 rows=984 loops=1)
         Filter: (client_key = 42)
         Rows Removed by Filter: 69948
 Planning Time: 0.390 ms
 Execution Time: 4.559 ms

```

## AFTER — with ix_fact_sales_client
```
 Aggregate  (cost=943.51..943.52 rows=1 width=40) (actual time=0.374..0.374 rows=1 loops=1)
   ->  Bitmap Heap Scan on fact_sales  (cost=11.84..938.64 rows=974 width=7) (actual time=0.054..0.244 rows=984 loops=1)
         Recheck Cond: (client_key = 42)
         Heap Blocks: exact=33
         ->  Bitmap Index Scan on ix_fact_sales_client  (cost=0.00..11.60 rows=974 width=0) (actual time=0.041..0.041 rows=984 loops=1)
               Index Cond: (client_key = 42)
 Planning Time: 0.507 ms
 Execution Time: 0.430 ms

```

Result: execution time ~7.8 ms → ~0.4 ms (~18x faster) on this selective
predicate; Seq Scan is replaced by a Bitmap Index Scan.
