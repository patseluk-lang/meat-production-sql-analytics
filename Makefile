.PHONY: build generate analyze psql down

# Build everything (data + database) with one command.
build:
	./build.sh

# Regenerate the synthetic dataset only.
generate:
	python3 data/generate.py

# Run every analysis query against the running database.
analyze:
	@for f in sql/analysis/*.sql; do \
		echo "==================== $$f ===================="; \
		docker compose exec -T db psql -U meat -d meat -f /$$f; \
	done

# Open an interactive psql shell.
psql:
	docker compose exec db psql -U meat -d meat

# Stop and wipe the database volume.
down:
	docker compose down -v
