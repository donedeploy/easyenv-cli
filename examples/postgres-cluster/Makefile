SHELL := /bin/bash

# === LOCAL TARGETS — run from your laptop ===

.PHONY: up sync deploy verify ssh down

up:
	@echo '+ easyenv here up --wait 10m'
	@easyenv here up --wait 10m

sync:
	@echo '+ easyenv here sync'
	@easyenv here sync

deploy: sync
	@echo "+ easyenv here run --cmd 'make remote-replicate'"
	@easyenv here run --cmd 'make remote-replicate'

verify:
	@echo "+ easyenv here run --cmd 'make remote-verify'"
	@easyenv here run --cmd 'make remote-verify'

ssh:
	@echo '+ easyenv here ssh'
	@easyenv here ssh

down:
	@echo '+ easyenv here down --force'
	@easyenv here down --force


# === REMOTE TARGETS — run on the primary via `easyenv here run` ===

PROJECT := $(HOME)/project

.PHONY: remote-replicate remote-verify remote-status

remote-replicate:
	cd $(PROJECT) && ansible-playbook -i inventory.ini playbooks/configure-replication.yml

remote-verify:
	@sudo -u postgres psql -c "SELECT client_addr, state, sync_state, sent_lsn, replay_lsn FROM pg_stat_replication;"

remote-status:
	@sudo systemctl status postgresql --no-pager | head -10
