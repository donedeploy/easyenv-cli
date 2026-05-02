SHELL := /bin/bash

PROJECT := $(HOME)/project/examples/postgres-cluster

.PHONY: replicate verify status

replicate:
	cd $(PROJECT) && ansible-playbook -i inventory.ini playbooks/configure-replication.yml

verify:
	@sudo -u postgres psql -c "SELECT client_addr, state, sync_state, sent_lsn, replay_lsn FROM pg_stat_replication;"

status:
	@sudo systemctl status postgresql --no-pager | head -10
