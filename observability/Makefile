COMPOSE=podman compose

run:
	podman compose up

up:
	$(COMPOSE) up -d
down:
	$(COMPOSE) down
logs:
	$(COMPOSE) logs -f
restart:
	$(COMPOSE) restart
status:
	$(COMPOSE) ps
pull:
	$(COMPOSE) pull
clean:
	$(COMPOSE) down -v