container:
	podman build -t nginx-logs . && podman run --replace --rm --name nginx-logs --network=host --group-add keep-groups --env-file .env -e HOSTNAME="$(hostname)" -v /var/log/nginx:/var/log/nginx:ro,Z nginx-logs
# 	podman build -t nginx-logs . && podman run --rm --network=host --group-add keep-groups --env-file .env -e HOSTNAME="$(hostname)" -v "$PWD/test-nginx-logs":/var/log/nginx:ro,Z nginx-logs

local:
	podman build -t nginx-logs . && podman run --name nginx-logs --rm --network=host --group-add keep-groups --env-file .env -e HOSTNAME="$$(hostname)" -v "$(PWD)/test-nginx-logs:/var/log/nginx:ro,z" nginx-logs


nginx:
	mkdir -p $(CURDIR)/test-nginx-logs && podman run --replace --rm -d --name nginx -p 8080:80 -p 4430:443 -v $(CURDIR)/test-nginx-logs:/var/log/nginx:z nginx:alpine
# 	mkdir -p "$PWD/test-nginx-logs" && podman run --replace -d --name nginx -p 8080:80 -p 4430:443 -v "$PWD/test-nginx-logs:/var/log/nginx:Z" nginx:alpine

run:
	set -a && . ./.env && set +a && python ngix_logs_to_postgres.py
# 	set -a && . ./.env && set +a && uv run ngix_logs_to_postgres.py

setup:
	. ./.env && psql $$DATABASE_URL -f  ./sql/schema.sql
