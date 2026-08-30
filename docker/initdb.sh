#!/bin/bash
# Runs once, the first time the postgres container initializes an empty data
# directory. Builds the whole warehouse: schema -> load CSVs -> star schema ->
# indexes. The SQL lives under /sql and the generated CSVs under /csv (both
# bind-mounted by docker-compose).
set -e

run() {
    echo ">>> $1"
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -f "$1"
}

run /sql/ddl/01_oltp_schema.sql
run /sql/ddl/02_star_schema.sql
run /sql/etl/01_load_csv.sql
run /sql/etl/02_build_star.sql
run /sql/ddl/03_indexes.sql

echo "Warehouse built successfully."
