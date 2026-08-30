#!/usr/bin/env bash
# One command to build everything: generate data, start PostgreSQL, and load
# the schema + data + star schema via the container's init scripts.
set -euo pipefail
cd "$(dirname "$0")"

echo "[1/3] Generating synthetic dataset (data/csv/) ..."
if ! python3 -c "import faker" 2>/dev/null; then
    echo "      installing Faker..."
    pip install -q -r requirements.txt
fi
python3 data/generate.py

echo "[2/3] Starting PostgreSQL on a fresh volume ..."
docker compose down -v >/dev/null 2>&1 || true
docker compose up -d

echo "[3/3] Waiting for the warehouse to build ..."
for _ in $(seq 1 60); do
    if docker compose exec -T db psql -U meat -d meat -tAc \
         "SELECT count(*) FROM fact_sales" 2>/dev/null | grep -qE '^[1-9]'; then
        break
    fi
    sleep 3
done

docker compose exec -T db psql -U meat -d meat -c \
  "SELECT 'fact_sales' AS table, count(*) FROM fact_sales
   UNION ALL SELECT 'fact_production', count(*) FROM fact_production
   UNION ALL SELECT 'clients', count(*) FROM clients;"

cat <<'EOF'

Done. The database is up on localhost:5432 (meat / meat).

Run an analysis query, e.g.:
  docker compose exec db psql -U meat -d meat -f /sql/analysis/01_abc_xyz.sql

Run them all:
  make analyze

Open a psql shell:
  make psql
EOF
