1 run_podman:
	podman compose up

# 2 run_podman:
# 	podman compose -f prom-compose.yml up

# 3 run_podman:
# 	podman compose -f prom-compose2.yml up

# podman compose -f podman-compose.yml up

run_docker:
	docker compose up -d

0 env:
	bash ./create_env.sh


remove_podman_containers:
	podman rm -f $(podman ps -aq) 