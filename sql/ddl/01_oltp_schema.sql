-- ============================================================================
-- OLTP source layer (normalized). This is the "system of record" the business
-- would run day to day; the analytical star schema is derived from it by ETL.
-- ============================================================================
DROP TABLE IF EXISTS write_offs, shipments, order_items, orders,
    production_batches, prices, bom, clients, products, ingredients CASCADE;

CREATE TABLE ingredients (
    id            INTEGER PRIMARY KEY,
    name          TEXT NOT NULL,
    unit          TEXT NOT NULL DEFAULT 'kg',
    cost_per_unit NUMERIC(10, 2) NOT NULL CHECK (cost_per_unit >= 0)
);

CREATE TABLE products (
    id               INTEGER PRIMARY KEY,
    sku              TEXT NOT NULL UNIQUE,
    name             TEXT NOT NULL,
    category         TEXT NOT NULL,
    shelf_life_days  INTEGER NOT NULL CHECK (shelf_life_days > 0),
    launch_date      DATE NOT NULL
);

-- Bill of materials: how much of each ingredient goes into 1 kg of product.
CREATE TABLE bom (
    id            INTEGER PRIMARY KEY,
    product_id    INTEGER NOT NULL REFERENCES products(id),
    ingredient_id INTEGER NOT NULL REFERENCES ingredients(id),
    qty_per_kg    NUMERIC(10, 4) NOT NULL CHECK (qty_per_kg > 0),
    UNIQUE (product_id, ingredient_id)
);

-- Sale price history per product (valid_to IS NULL = current price).
CREATE TABLE prices (
    id         INTEGER PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES products(id),
    price      NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
    valid_from DATE NOT NULL,
    valid_to   DATE
);

CREATE TABLE clients (
    id      INTEGER PRIMARY KEY,
    name    TEXT NOT NULL,
    channel TEXT NOT NULL CHECK (channel IN ('shop', 'horeca', 'distributor')),
    region  TEXT NOT NULL,
    since   DATE NOT NULL
);

CREATE TABLE production_batches (
    id         INTEGER PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES products(id),
    batch_date DATE NOT NULL,
    planned_kg NUMERIC(12, 2) NOT NULL CHECK (planned_kg > 0),
    actual_kg  NUMERIC(12, 2) NOT NULL CHECK (actual_kg >= 0)
);

CREATE TABLE orders (
    id         INTEGER PRIMARY KEY,
    client_id  INTEGER NOT NULL REFERENCES clients(id),
    order_date DATE NOT NULL
);

CREATE TABLE order_items (
    id         INTEGER PRIMARY KEY,
    order_id   INTEGER NOT NULL REFERENCES orders(id),
    product_id INTEGER NOT NULL REFERENCES products(id),
    qty_kg     NUMERIC(12, 2) NOT NULL CHECK (qty_kg > 0),
    unit_price NUMERIC(10, 2) NOT NULL CHECK (unit_price >= 0)
);

CREATE TABLE shipments (
    id             INTEGER PRIMARY KEY,
    order_id       INTEGER NOT NULL REFERENCES orders(id),
    shipped_date   DATE NOT NULL,
    delivered_date DATE,
    status         TEXT NOT NULL CHECK (status IN ('delivered', 'in_transit'))
);

CREATE TABLE write_offs (
    id            INTEGER PRIMARY KEY,
    product_id    INTEGER NOT NULL REFERENCES products(id),
    writeoff_date DATE NOT NULL,
    qty_kg        NUMERIC(12, 2) NOT NULL CHECK (qty_kg >= 0),
    reason        TEXT NOT NULL
);
