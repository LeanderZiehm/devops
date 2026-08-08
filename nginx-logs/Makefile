run:
	set -a && . ./.env && set +a && python ngix_logs_to_postgres.py
# 	set -a && . ./.env && set +a && uv run ngix_logs_to_postgres.py

setup:
	bash setup

container:
	podman build -t nginx-logs . && podman run --rm --network=host --group-add keep-groups --env-file .env -e HOSTNAME="$(hostname)" -v /var/log/nginx:/var/log/nginx:ro,Z nginx-logs