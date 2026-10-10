COMPOSE=docker compose \
	--env-file .env \
	-f compose/00-networks.yml \
	-f compose/10-infra.yml \
	-f compose/20-php-auth.yml \
	-f compose/21-php-verification.yml \
	-f compose/22-php-email.yml \
	-f compose/24-php-dictionaries.yml \
	-f compose/26-php-catalog.yml \
	-f compose/30-java-services.yml \
	-f compose/35-web.yml -f compose/36-node.yml \
	-f compose/40-nginx.yml

POSTGRES_SERVICE=postgres
POSTGRES_USER=symfony

EVENT_API_CONTAINER=event_api_service
EVENT_WORKER_CONTAINER=event_worker_service
NGINX_CONTAINER=gateway_nginx

.PHONY: \
	up down restart logs ps \
	wait-db wait-event-api wait-event-worker wait-nginx \
	migrate status bootstrap clean-db rebuild-db rebuild-db-hard up-debug

up-debug:
	pwd
	ls -la ./config/jwt
up:
	@echo "Starting environment..."
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down

restart:
	$(COMPOSE) restart

logs:
	$(COMPOSE) logs -f

ps:
	$(COMPOSE) ps

wait-db:
	@echo ""
	@echo "[1/5] Waiting for PostgreSQL (server readiness)..."

	@timeout=90; \
	elapsed=0; \
	container_id=$$($(COMPOSE) ps -q $(POSTGRES_SERVICE)); \
	until docker exec $$container_id pg_isready -U $(POSTGRES_USER) >/dev/null 2>&1; do \
		sleep 2; \
		elapsed=$$((elapsed+2)); \
		if [ $$elapsed -ge $$timeout ]; then \
			echo "✗ PostgreSQL did not become ready in time"; \
			docker inspect $$container_id; \
			exit 1; \
		fi; \
	done

	@echo "✓ PostgreSQL is ready"

wait-event-api:
	@echo ""
	@echo "[2/5] Waiting for Event API..."
	@deadline=$$(( $$(date +%s) + 600 )); \
	until [ "$$(docker inspect -f '{{.State.Health.Status}}' $(EVENT_API_CONTAINER))" = "healthy" ]; do \
		if [ $$(date +%s) -ge $$deadline ]; then echo "Event API readiness timed out after 600 seconds"; exit 1; fi; \
		echo "Event API is not healthy yet..."; \
		sleep 2; \
	done
	@echo "✓ Event API is healthy"

wait-event-worker:
	@echo ""
	@echo "[3/5] Waiting for Event Worker..."
	@deadline=$$(( $$(date +%s) + 600 )); \
	until [ "$$(docker inspect -f '{{.State.Health.Status}}' $(EVENT_WORKER_CONTAINER))" = "healthy" ]; do \
		if [ $$(date +%s) -ge $$deadline ]; then echo "Event Worker readiness timed out after 600 seconds"; exit 1; fi; \
		echo "Event Worker is not healthy yet..."; \
		sleep 2; \
	done
	@echo "✓ Event Worker is healthy"

wait-nginx:
	@echo ""
	@echo "[4/5] Waiting for Nginx..."
	@until docker ps --format '{{.Names}}' | grep -q '^$(NGINX_CONTAINER)$$'; do \
		echo "Nginx is not running yet..."; \
		sleep 2; \
	done
	@echo "✓ Nginx is running"

migrate:
	@echo ""
	@echo "[5/5] Running migrations..."

	@echo "→ AUTH"
	$(COMPOSE) exec -T auth-service \
		php bin/console doctrine:migrations:migrate -v --no-interaction

	@echo "→ VERIFICATION"
	$(COMPOSE) exec -T verification-service \
		php bin/console doctrine:migrations:migrate -v --no-interaction

	@echo "→ EMAIL"
	$(COMPOSE) exec -T email-service \
		php bin/console doctrine:migrations:migrate -v --no-interaction

	@echo "→ DICTIONARIES(refbook)"
	$(COMPOSE) exec -T dictionaries-service \
		php bin/console doctrine:migrations:migrate -v --no-interaction

	@echo "→ CATALOG(catalog)"
	$(COMPOSE) exec -T catalog-service \
		php bin/console doctrine:migrations:migrate -v --no-interaction

	@echo "✓ All migrations completed"

status:
	@echo ""
	@echo "========================================="
	@echo " Docker Containers"
	@echo "========================================="
	@docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

bootstrap: up wait-db wait-event-api wait-event-worker wait-nginx migrate status
	@echo ""
	@echo "========================================="
	@echo " Environment is ready"
	@echo "========================================="

POSTGRES_STORAGE=storage/postgresql

clean-db:
	@echo ""
	@echo "========================================="
	@echo " Cleaning PostgreSQL storage"
	@echo "========================================="

	$(COMPOSE) down --remove-orphans

	@rm -rf $(POSTGRES_STORAGE)
	@mkdir -p $(POSTGRES_STORAGE)

	@echo "✓ PostgreSQL storage cleaned"

rebuild-db:
	@echo ""
	@echo "========================================="
	@echo " Rebuilding database (FINAL STABLE MODE)"
	@echo "========================================="

	@$(MAKE) clean-db

	@echo ""
	@echo "[1/5] Starting infrastructure (postgres only)..."
	@$(COMPOSE) up -d --build postgres redis kafka

	@$(MAKE) wait-db

	@echo ""
	@echo "[2/5] Starting backend services..."
	@$(COMPOSE) up -d --build \
		auth-service \
		verification-service \
		email-service \
		catalog-service \
		dictionaries-service \
        web-service\
		event-api-service \
		event-worker-service

	@echo ""
	@echo "[3/5] Starting gateway (nginx)..."
	@$(COMPOSE) up -d --build nginx

	@echo ""
	@echo "[4/5] Waiting for services..."
	@$(MAKE) wait-event-api || true
	@$(MAKE) wait-event-worker || true
	@$(MAKE) wait-nginx || true

	@echo ""
	@echo "[5/5] Running migrations..."
	@$(MAKE) migrate

	@echo ""
	@echo "========================================="
	@echo " Database rebuilt successfully"
	@echo "========================================="

rebuild-db-hard:
	@echo ""
	@echo "========================================="
	@echo " Rebuilding database (HARD MODE)"
	@echo "========================================="

	@echo ""
	@echo "[0/5] Force removing ALL containers..."

	-docker stop $$(docker ps -aq)
	-docker rm -f $$(docker ps -aq)

	@echo ""
	@echo "[0/5] Cleaning PostgreSQL storage..."

	@rm -rf $(POSTGRES_STORAGE)
	@mkdir -p $(POSTGRES_STORAGE)

	@echo ""
	@echo "[1/5] Starting infrastructure (postgres only)..."
	@$(COMPOSE) up -d --build postgres redis kafka

	@$(MAKE) wait-db

	@echo ""
	@echo "[2/5] Starting backend services..."
	@$(COMPOSE) up -d --build \
		auth-service \
		verification-service \
		email-service \
		catalog-service \
		dictionaries-service \
		event-api-service \
		event-worker-service

	@echo ""
	@echo "[3/5] Starting gateway (nginx)..."
	@$(COMPOSE) up -d --build nginx

	@echo ""
	@echo "[4/5] Waiting for services..."
	@$(MAKE) wait-event-api || true
	@$(MAKE) wait-event-worker || true
	@$(MAKE) wait-nginx || true

	@echo ""
	@echo "[5/5] Running migrations..."
	@$(MAKE) migrate

	@echo ""
	@echo "========================================="
	@echo " Database rebuilt successfully (HARD MODE)"
	@echo "========================================="

.PHONY: web-up web-down web-logs
# The web app uses the same gateway and dependencies as local registration.
web-up: registration-up
web-down: registration-down
web-logs:
	$(REGISTRATION_COMPOSE) logs --tail=100 web-service nginx

REGISTRATION_COMPOSE=docker compose --env-file .env -p mesto-web \
 -f compose/00-networks.yml -f compose/10-infra.yml \
 -f compose/20-php-auth.yml -f compose/21-php-verification.yml \
 -f compose/22-php-email.yml -f compose/24-php-dictionaries.yml \
 -f compose/26-php-catalog.yml -f compose/30-java-services.yml -f compose/35-web.yml -f compose/36-node.yml \
 -f compose/40-nginx.yml -f compose/registration-local.yml
.PHONY: registration-up registration-migrate registration-down
registration-up:
	$(REGISTRATION_COMPOSE) up -d --build --remove-orphans --scale node-service=0 --wait --wait-timeout 600
	$(MAKE) registration-deps
	$(MAKE) registration-migrate
	$(MAKE) chat-migrate
	$(REGISTRATION_COMPOSE) up -d --wait --wait-timeout 600 node-service
	$(REGISTRATION_COMPOSE) exec -T nginx nginx -t
	$(REGISTRATION_COMPOSE) exec -T nginx nginx -s reload
registration-migrate:
	$(REGISTRATION_COMPOSE) exec -T auth-service php bin/console doctrine:migrations:migrate --no-interaction
	$(REGISTRATION_COMPOSE) exec -T verification-service php bin/console doctrine:migrations:migrate --no-interaction
	$(REGISTRATION_COMPOSE) exec -T email-service php bin/console doctrine:migrations:migrate --no-interaction
	$(REGISTRATION_COMPOSE) exec -T dictionaries-service php bin/console doctrine:migrations:migrate --no-interaction
	$(REGISTRATION_COMPOSE) exec -T catalog-service php bin/console doctrine:migrations:migrate --no-interaction
registration-down:
	$(REGISTRATION_COMPOSE) down
.PHONY: registration-test
registration-test:
	../services/verification-service/tests/run-contracts.sh

.PHONY: assessment-test
assessment-test:
	$(REGISTRATION_COMPOSE) exec -T catalog-service php tests/gigachat-isolation.php
	$(REGISTRATION_COMPOSE) exec -T catalog-service php tests/catalog-schema-contract.php
	$(REGISTRATION_COMPOSE) exec -T catalog-service php tests/assessment-contract.php
	$(REGISTRATION_COMPOSE) exec -T web-service php tests/task-template-contract.php

.PHONY: registration-deps
registration-deps:
	@for service in auth-service verification-service email-service dictionaries-service catalog-service; do \
	 $(REGISTRATION_COMPOSE) run --rm --no-deps $$service sh -c 'test -f .env || cp .env.example .env; composer install --no-interaction --prefer-dist --no-scripts' || exit $$?; \
	done

# Diagnostics use the same local project/files as registration-up, never the legacy stack.
.PHONY: registration-check registration-ps registration-logs registration-restart registration-cache
registration-check:
	$(REGISTRATION_COMPOSE) config --quiet
registration-ps:
	$(REGISTRATION_COMPOSE) ps
registration-logs:
	$(REGISTRATION_COMPOSE) logs --tail=100 $(SERVICE)
registration-restart:
	$(REGISTRATION_COMPOSE) restart $(SERVICE)
registration-cache:
	@for service in auth-service verification-service email-service dictionaries-service catalog-service web-service; do \
	 $(REGISTRATION_COMPOSE) exec -T $$service php bin/console cache:clear --env=prod --no-debug || exit $$?; \
	done

.PHONY: chat-migrate chat-test
chat-migrate:
	$(REGISTRATION_COMPOSE) exec -T catalog-service php bin/console doctrine:migrations:migrate --no-interaction
	$(REGISTRATION_COMPOSE) run --rm --no-deps chat-db
	$(REGISTRATION_COMPOSE) build node-service
	$(REGISTRATION_COMPOSE) run --rm --no-deps node-service node dist/migrate.js
chat-test:
	$(REGISTRATION_COMPOSE) run --rm --no-deps chat-test
	$(REGISTRATION_COMPOSE) exec -T catalog-service php tests/chat-transfer-contract.php

.PHONY: chat-e2e
# Optional Python 3 test runner on the host; synthetic accounts are always cleaned up.
chat-e2e:
	@set -eu; task_dir=$$(mktemp -d); \
	 $(REGISTRATION_COMPOSE) exec -T catalog-service php tests/chat-live-fixture.php setup > "$$task_dir/fixture.json"; \
	 trap '$(REGISTRATION_COMPOSE) exec -T catalog-service php tests/chat-live-fixture.php cleanup; rm -f "$$task_dir/fixture.json"; rmdir "$$task_dir"' EXIT; \
	 python3 ../services/web-service/tests/chat-live.py --fixture "$$task_dir/fixture.json"

.PHONY: auth-session-test
auth-session-test:
	$(REGISTRATION_COMPOSE) exec -T web-service php tests/auth-session-contract.php
	@set -eu; task_dir=$$(mktemp -d); \
	 $(REGISTRATION_COMPOSE) exec -T catalog-service php tests/chat-live-fixture.php setup > "$$task_dir/fixture.json"; \
	 trap '$(REGISTRATION_COMPOSE) exec -T catalog-service php tests/chat-live-fixture.php cleanup; rm -f "$$task_dir/fixture.json"; rmdir "$$task_dir"' EXIT; \
	 candidate_email=$$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["candidateEmail"])' "$$task_dir/fixture.json"); \
	 $(REGISTRATION_COMPOSE) exec -T auth-service php tests/persistent-session-contract.php "$$candidate_email"; \
	 python3 ../services/web-service/tests/auth-session-live.py --fixture "$$task_dir/fixture.json"
