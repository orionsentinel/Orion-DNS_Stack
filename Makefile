# Makefile for Orion Sentinel HA DNS
# Production-ready High Availability DNS with Pi-hole + Unbound
#
# Usage:
#   make up-core          - Start core DNS services (pihole + unbound + keepalived)
#   make down             - Stop all services
#   make logs             - Show logs from all services
#   make health-check     - Run comprehensive health check
#   make restart          - Restart all services
#   make clean            - Remove all containers and volumes (DESTRUCTIVE)

.PHONY: help up-core down restart logs logs-follow health-check test backup clean validate-env configure-nic list-nics selfcheck test-failover block-private-relay setup-blocklists

# Default target
.DEFAULT_GOAL := help

# Load environment variables from .env if it exists
ifneq (,$(wildcard .env))
    include .env
    export
endif

# Colors for output
BOLD := \033[1m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m

help: ## Show this help message
	@echo "$(BOLD)Orion Sentinel HA DNS - Makefile Commands$(NC)"
	@echo ""
	@echo "$(GREEN)Core Operations:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Environment:$(NC)"
	@if [ -f .env ]; then \
		echo "  ✓ .env file found"; \
	else \
		echo "  ✗ .env file NOT found - copy .env.primary.example or .env.secondary.example to .env first"; \
	fi

configure-nic: ## Configure the USB-C/2.5-10G NIC on a fixed IP (reads .env; needs sudo)
	@echo "$(BOLD)Configuring dedicated NIC from .env...$(NC)"
	@sudo bash scripts/configure-nic.sh

list-nics: ## List candidate Ethernet interfaces (name / MAC / state / speed)
	@bash scripts/configure-nic.sh --list

validate-env: ## Validate environment configuration
	@echo "$(BOLD)Validating environment configuration...$(NC)"
	@if [ ! -f .env ]; then \
		echo "$(RED)Error: .env file not found.$(NC)"; \
		echo "$(YELLOW)For PRIMARY node: cp .env.primary.example .env$(NC)"; \
		echo "$(YELLOW)For SECONDARY node: cp .env.secondary.example .env$(NC)"; \
		exit 1; \
	fi
	@if [ -f scripts/validate-env.sh ]; then \
		bash scripts/validate-env.sh; \
	else \
		echo "$(GREEN)✓ .env file exists$(NC)"; \
	fi

up-core: validate-env ## Start core DNS services (pihole + unbound + keepalived)
	@echo "$(BOLD)Starting core DNS services...$(NC)"
	@if grep -q "NODE_ROLE=MASTER" .env 2>/dev/null || grep -q "NODE_ROLE=BACKUP" .env 2>/dev/null; then \
		if grep -q "NODE_ROLE=MASTER" .env 2>/dev/null; then \
			docker compose --profile two-node-ha-primary up -d; \
		else \
			docker compose --profile two-node-ha-backup up -d; \
		fi; \
	else \
		docker compose --profile single-node up -d; \
	fi
	@echo "$(GREEN)✓ Core services started$(NC)"
	@echo ""
	@if [ -n "$${VIP_ADDRESS:-}" ]; then \
		echo "DNS server available at: $${VIP_ADDRESS}"; \
		echo "Access Pi-hole admin at: http://$${VIP_ADDRESS}/admin"; \
	else \
		echo "Access Pi-hole admin at: http://$${NODE_IP:-localhost}/admin"; \
	fi

down: ## Stop all services
	@echo "$(BOLD)Stopping all services...$(NC)"
	docker compose --profile single-node --profile two-node-ha-primary --profile two-node-ha-backup down
	@echo "$(GREEN)✓ All services stopped$(NC)"

restart: down up-core ## Restart all services

logs: ## Show logs from all running services
	docker compose logs --tail=100

logs-follow: ## Follow logs from all running services
	docker compose logs -f

health-check: ## Run comprehensive health check
	@echo "$(BOLD)Running health checks...$(NC)"
	@if [ -f ops/orion-dns-health.sh ]; then \
		bash ops/orion-dns-health.sh; \
	elif [ -f scripts/dns-health.sh ]; then \
		bash scripts/dns-health.sh; \
	elif [ -f scripts/health-check.sh ]; then \
		bash scripts/health-check.sh; \
	else \
		echo "$(YELLOW)No health check script found$(NC)"; \
	fi

test: health-check ## Run health check (alias)

selfcheck: ## Validate configuration files
	@echo "$(BOLD)Running self-check...$(NC)"
	@bash scripts/selfcheck.sh

test-failover: ## Integration test: force VRRP failover and verify recovery (disruptive)
	@bash scripts/test-failover.sh

block-private-relay: ## Block iCloud Private Relay (highest-ROI iPhone ad fix; run on primary)
	@bash scripts/block-private-relay.sh

setup-blocklists: ## Apply recommended blocklists (Hagezi Multi PRO + TIF; run on primary)
	@bash scripts/setup-blocklists.sh

bootstrap: ## Create required directories and files
	@echo "$(BOLD)Bootstrapping directories...$(NC)"
	@bash scripts/bootstrap_dirs.sh

health: health-check ## Run health check (standardized alias)

ps: ## Show running containers
	@docker compose ps

stats: ## Show container resource usage
	@docker stats --no-stream

backup: ## Create backup of configuration
	@echo "$(BOLD)Creating backup...$(NC)"
	@bash ops/orion-dns-backup.sh
	@echo "$(GREEN)✓ Backup complete$(NC)"

restore: ## Restore from latest backup
	@echo "$(BOLD)Restoring from backup...$(NC)"
	@bash ops/orion-dns-restore.sh
	@echo "$(GREEN)✓ Restore complete$(NC)"

sync: ## Sync Pi-hole config to secondary node (run on primary)
	@echo "$(BOLD)Syncing Pi-hole configuration to secondary node...$(NC)"
	@bash ops/pihole-sync.sh
	@echo "$(GREEN)✓ Sync complete$(NC)"

clean: ## Remove all containers and volumes (DESTRUCTIVE - asks for confirmation)
	@echo "$(RED)$(BOLD)WARNING: This will remove all containers, volumes, and data!$(NC)"
	@read -p "Are you sure? Type 'yes' to continue: " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		docker compose --profile single-node --profile two-node-ha-primary --profile two-node-ha-backup down -v; \
		echo "$(GREEN)✓ Cleaned up$(NC)"; \
	else \
		echo "Cancelled."; \
	fi

pull: ## Pull latest container images
	@echo "$(BOLD)Pulling latest images...$(NC)"
	docker compose pull
	@echo "$(GREEN)✓ Images updated$(NC)"

update: pull restart ## Update and restart services

# Development targets
dev-logs: ## Show detailed logs with timestamps
	docker compose logs -f --timestamps

dev-shell-pihole: ## Open shell in pihole container
	docker compose exec pihole_unbound bash

# Information targets
info: ## Show deployment information
	@echo "$(BOLD)Deployment Information:$(NC)"
	@if [ -f .env ]; then \
		set -a && . ./.env && set +a; \
		echo "  Node Role: $${NODE_ROLE:-single-node}"; \
		echo "  Node IP: $${NODE_IP:-not set}"; \
		echo "  VIP Address: $${VIP_ADDRESS:-not set}"; \
		echo "  Network Interface: $${NETWORK_INTERFACE:-eth0}"; \
		echo "  Keepalived Priority: $${KEEPALIVED_PRIORITY:-not set}"; \
	else \
		echo "  No .env file found"; \
		echo "  Copy .env.primary.example or .env.secondary.example to .env first"; \
	fi

# Systemd Integration
install-systemd-primary: ## Install systemd units for PRIMARY node
	@echo "$(BOLD)Installing systemd units for PRIMARY node...$(NC)"
	sudo cp systemd/orion-dns-ha-primary.service /etc/systemd/system/
	sudo cp systemd/orion-dns-ha-health.service /etc/systemd/system/
	sudo cp systemd/orion-dns-ha-health.timer /etc/systemd/system/
	sudo cp systemd/orion-dns-ha-backup.service /etc/systemd/system/
	sudo cp systemd/orion-dns-ha-backup.timer /etc/systemd/system/
	sudo cp systemd/orion-dns-ha-sync.service /etc/systemd/system/
	sudo cp systemd/orion-dns-ha-sync.timer /etc/systemd/system/
	sudo systemctl daemon-reload
	@echo "$(GREEN)✓ Systemd units installed$(NC)"
	@echo ""
	@echo "Enable and start services with:"
	@echo "  sudo systemctl enable --now orion-dns-ha-primary.service"
	@echo "  sudo systemctl enable --now orion-dns-ha-health.timer"
	@echo "  sudo systemctl enable --now orion-dns-ha-backup.timer"
	@echo "  sudo systemctl enable --now orion-dns-ha-sync.timer"

install-systemd-secondary: ## Install systemd units for SECONDARY node
	@echo "$(BOLD)Installing systemd units for SECONDARY node...$(NC)"
	sudo cp systemd/orion-dns-ha-backup-node.service /etc/systemd/system/
	sudo cp systemd/orion-dns-ha-health.service /etc/systemd/system/
	sudo cp systemd/orion-dns-ha-health.timer /etc/systemd/system/
	sudo cp systemd/orion-dns-ha-backup.service /etc/systemd/system/
	sudo cp systemd/orion-dns-ha-backup.timer /etc/systemd/system/
	sudo systemctl daemon-reload
	@echo "$(GREEN)✓ Systemd units installed$(NC)"
	@echo ""
	@echo "Enable and start services with:"
	@echo "  sudo systemctl enable --now orion-dns-ha-backup-node.service"
	@echo "  sudo systemctl enable --now orion-dns-ha-health.timer"
	@echo "  sudo systemctl enable --now orion-dns-ha-backup.timer"

version: ## Show versions of components
	@echo "$(BOLD)Component Versions:$(NC)"
	@echo -n "  Docker: "
	@docker version --format '{{.Server.Version}}' 2>/dev/null || echo "not available"
	@echo -n "  Docker Compose: "
	@docker compose version --short 2>/dev/null || echo "not available"
	@echo -n "  Pi-hole: "
	@docker compose exec pihole_unbound pihole -v 2>/dev/null | head -n1 || echo "not running"
