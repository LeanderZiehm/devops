run:
	set -a && . ./.env && set +a && python ngix_logs_to_postgres.py
# 	set -a && . ./.env && set +a && uv run ngix_logs_to_postgres.py

setup:
	bash setup

container:
	podman build -t nginx-logs . && podman run --rm --network=host --env-file .env nginx-logs