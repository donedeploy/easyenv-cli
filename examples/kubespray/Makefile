SHELL := /bin/bash

INVENTORY := $(HOME)/project/examples/kubespray/inventory/easyenv/hosts.yaml
KUBESPRAY := /opt/kubespray
ANSIBLE   := $(KUBESPRAY)/.venv/bin/ansible-playbook

.PHONY: deploy reset wait status

deploy: wait
	$(ANSIBLE) -i $(INVENTORY) $(KUBESPRAY)/cluster.yml -b -u easyenv

reset: wait
	$(ANSIBLE) -i $(INVENTORY) $(KUBESPRAY)/reset.yml -b -u easyenv -e reset_confirmation=yes

wait:
	@for host in worker-1 worker-2; do \
	  echo "[wait] $$host …"; \
	  until ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 -o BatchMode=yes \
	            easyenv@$$host true 2>/dev/null; do sleep 5; done; \
	  echo "[wait] $$host ready"; \
	done

status:
	@sudo kubectl get nodes -o wide
