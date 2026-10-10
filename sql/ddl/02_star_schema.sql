-- Analytical layer: a star schema. Facts hold measures at a single grain;
-- dimensions hold the descriptive attributes to slice by. Populated by
-- sql/etl/02_build_star.sql entirely with SQL (no application code).
DROP TABLE IF EXISTS fact_sales, fact_production,
    dim_date, dim_product, dim_client, dim_channel CASCADE;

CREATE TABLE dim_date (
    date_key   DATE PRIMARY KEY,
    year       INTEGER NOT NULL,
    quarter    INTEGER NOT NULL,
    month      INTEGER NOT NULL,
    month_name TEXT NOT NULL,
    day        INTEGER NOT NULL,
    dow        INTEGER NOT NULL,          -- 0=Sunday .. 6=Saturday
    iso_week   INTEGER NOT NULL,
    is_weekend BOOLEAN NOT NULL
);

CREATE TABLE dim_channel (
    channel_key SERIAL PRIMARY KEY,
    channel     TEXT NOT NULL UNIQUE
);

CREATE TABLE dim_product (
    product_key     INTEGER PRIMARY KEY,   -- same as products.id
    sku             TEXT NOT NULL,
    name            TEXT NOT NULL,
    category        TEXT NOT NULL,
    shelf_life_days INTEGER NOT NULL,
    unit_cost       NUMERIC(12, 4) NOT NULL  -- derived from BOM at build time
);

CREATE TABLE dim_client (
    client_key INTEGER PRIMARY KEY,        -- same as clients.id
    name       TEXT NOT NULL,
    channel    TEXT NOT NULL,
    region     TEXT NOT NULL,
    since      DATE NOT NULL
);

-- Grain: one row per order line.
CREATE TABLE fact_sales (
    sale_id      BIGINT PRIMARY KEY,       -- = order_items.id
    date_key     DATE NOT NULL REFERENCES dim_date(date_key),
    product_key  INTEGER NOT NULL REFERENCES dim_product(product_key),
    client_key   INTEGER NOT NULL REFERENCES dim_client(client_key),
    channel_key  INTEGER NOT NULL REFERENCES dim_channel(channel_key),
    qty_kg       NUMERIC(12, 2) NOT NULL,
    unit_price   NUMERIC(10, 2) NOT NULL,
    revenue      NUMERIC(14, 2) NOT NULL,
    unit_cost    NUMERIC(12, 4) NOT NULL,
    cogs         NUMERIC(14, 2) NOT NULL,  -- cost of goods sold = qty * unit_cost
    gross_margin NUMERIC(14, 2) NOT NULL   -- revenue - cogs
);

-- Grain: one row per production batch.
CREATE TABLE fact_production (
    prod_key    BIGINT PRIMARY KEY,        -- = production_batches.id
    date_key    DATE NOT NULL REFERENCES dim_date(date_key),
    product_key INTEGER NOT NULL REFERENCES dim_product(product_key),
    planned_kg  NUMERIC(12, 2) NOT NULL,
    actual_kg   NUMERIC(12, 2) NOT NULL,
    yield_pct   NUMERIC(6, 4) NOT NULL     -- actual_kg / planned_kg
);
