-- Load the generated CSVs into the OLTP tables. Server-side COPY reads from
-- /csv, which docker-compose mounts from ./data/csv. Empty fields (e.g. an
-- open-ended price validity, an undelivered shipment) load as NULL.
TRUNCATE write_offs, shipments, order_items, orders, production_batches,
    prices, bom, clients, products, ingredients RESTART IDENTITY CASCADE;

COPY ingredients        FROM '/csv/ingredients.csv'        WITH (FORMAT csv, HEADER true, NULL '');
COPY products           FROM '/csv/products.csv'           WITH (FORMAT csv, HEADER true, NULL '');
COPY bom                FROM '/csv/bom.csv'                 WITH (FORMAT csv, HEADER true, NULL '');
COPY prices             FROM '/csv/prices.csv'             WITH (FORMAT csv, HEADER true, NULL '');
COPY clients            FROM '/csv/clients.csv'            WITH (FORMAT csv, HEADER true, NULL '');
COPY production_batches FROM '/csv/production_batches.csv' WITH (FORMAT csv, HEADER true, NULL '');
COPY orders             FROM '/csv/orders.csv'             WITH (FORMAT csv, HEADER true, NULL '');
COPY order_items        FROM '/csv/order_items.csv'        WITH (FORMAT csv, HEADER true, NULL '');
COPY shipments          FROM '/csv/shipments.csv'          WITH (FORMAT csv, HEADER true, NULL '');
COPY write_offs         FROM '/csv/write_offs.csv'          WITH (FORMAT csv, HEADER true, NULL '');
