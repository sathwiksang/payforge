.PHONY: up down reset logs test test-security db-setup console up-core up-full

up:               ## Start core services (Rails + DB + Redis + Sidekiq)
	docker compose up -d db redis backend sidekiq

up-core:          ## Start only Rails + DB + Redis (no Sidekiq)
	docker compose up -d db redis backend

up-full:          ## Start everything including ML sidecar and network simulator
	docker compose --profile ml --profile full up -d

down:             ## Stop all services
	docker compose down

reset:            ## Full reset: volumes, rebuild
	docker compose down -v
	docker compose build --no-cache
	docker compose up -d db redis
	sleep 5
	docker compose up -d backend sidekiq
	sleep 10
	$(MAKE) db-setup

db-setup:         ## Create, migrate, seed
	docker compose exec backend rails db:create db:migrate db:seed

db-migrate:       ## Run pending migrations
	docker compose exec backend rails db:migrate

console:          ## Rails console
	docker compose exec backend rails console

test:             ## Run full test suite
	docker compose exec backend bundle exec rspec

test-security:    ## Security audit (Brakeman + bundler-audit)
	docker compose exec backend bundle exec brakeman -q
	docker compose exec backend bundle exec bundle-audit check

logs:             ## Tail all logs
	docker compose logs -f --tail=100

logs-backend:     ## Tail backend logs only
	docker compose logs -f --tail=100 backend

lint:             ## Run RuboCop
	docker compose exec backend bundle exec rubocop

# --- Production ---
prod-up:          ## Start production services with Cloudflare Tunnel
	docker compose -f docker-compose.production.yml up -d

prod-down:        ## Stop production services
	docker compose -f docker-compose.production.yml down

prod-logs:        ## Tail production logs
	docker compose -f docker-compose.production.yml logs -f --tail=100

prod-db-setup:    ## Set up production database
	docker compose -f docker-compose.production.yml exec backend rails db:create db:migrate db:seed

prod-secrets:     ## Generate production secrets
	@echo "SECRET_KEY_BASE=$$(openssl rand -hex 64)"
	@echo "LOCKBOX_MASTER_KEY=$$(openssl rand -hex 32)"
	@echo "JWT_SECRET=$$(openssl rand -hex 32)"
	@echo "DB_PASSWORD=$$(openssl rand -hex 16)"
	@echo "REDIS_PASSWORD=$$(openssl rand -hex 16)"

# --- Local Development (no Docker) ---
dev:              ## Start backend + frontend locally
	@echo "Starting backend on port 3200..."
	cd backend && RAILS_ENV=development bin/rails server -p 3200 &
	@echo "Starting frontend on port 3201..."
	cd frontend && npm run dev -- -p 3201 &

benchmark:        ## Run API performance benchmarks
	cd backend && bin/rails runner script/benchmark_api.rb
