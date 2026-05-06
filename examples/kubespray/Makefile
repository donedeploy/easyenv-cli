SHELL := /bin/bash

# === LOCAL TARGETS — run from your laptop ===

.PHONY: up sync deploy reset ssh expose down status kube kctl

up:
	@echo '+ easyenv here up --wait 15m'
	@easyenv here up --wait 15m

sync:
	@echo '+ easyenv here sync'
	@easyenv here sync

deploy: sync
	@echo "+ easyenv here run --cmd 'make remote-deploy'"
	@easyenv here run --cmd 'make remote-deploy'

reset: sync
	@echo "+ easyenv here run --cmd 'make remote-reset'"
	@easyenv here run --cmd 'make remote-reset'

ssh:
	@echo '+ easyenv here ssh'
	@easyenv here ssh

expose:
	@echo '+ easyenv here expose'
	@easyenv here expose

down:
	@echo '+ easyenv here down --force'
	@easyenv here down --force

status:
	@echo "+ easyenv here run --cmd 'make remote-status'"
	@easyenv here run --cmd 'make remote-status'

KUBECONFIG_LOCAL := $(CURDIR)/kubeconfig

kube:
	@echo "+ easyenv here run --cmd 'make remote-kubeconfig'  →  $(KUBECONFIG_LOCAL)"
	@easyenv here run --cmd 'make remote-kubeconfig' \
	  | awk '/^===KUBECONFIG-BEGIN===$$/{p=1; next} /^===KUBECONFIG-END===$$/{p=0} p' \
	  | sed 's|server: https://[^[:space:]]*|server: https://127.0.0.1:6443|' \
	  > $(KUBECONFIG_LOCAL)
	@chmod 0600 $(KUBECONFIG_LOCAL)
	@echo
	@echo "Wrote $(KUBECONFIG_LOCAL)."
	@echo
	@echo "To connect kubectl from this laptop:"
	@echo "  1. In one terminal, hold the tunnel open:"
	@echo "       make expose"
	@echo "     (wait for 'forwarding ...' before continuing)"
	@echo "  2. In another terminal:"
	@echo "       export KUBECONFIG=$(KUBECONFIG_LOCAL)"
	@echo "       kubectl get nodes"
	@echo
	@echo "  Or for a one-shot, use the bundled wrapper:"
	@echo "       make kctl ARGS='get nodes'"

# Run kubectl with the local kubeconfig already set. Requires `make expose`
# to be running in another terminal. Pass args via ARGS=...
# Example:  make kctl ARGS='get pods -A'
kctl:
	@if [ ! -f $(KUBECONFIG_LOCAL) ]; then echo "missing $(KUBECONFIG_LOCAL); run 'make kube' first" >&2; exit 1; fi
	@echo "+ KUBECONFIG=$(KUBECONFIG_LOCAL) kubectl $(ARGS)"
	@KUBECONFIG=$(KUBECONFIG_LOCAL) kubectl $(ARGS)


# === REMOTE TARGETS — run on the master via `easyenv here run` ===

KUBESPRAY := /opt/kubespray
ANSIBLE   := $(KUBESPRAY)/.venv/bin/ansible-playbook
INVENTORY := $(HOME)/kubespray-inventory.yaml

.PHONY: remote-deploy remote-reset remote-status remote-kubeconfig

remote-deploy:
	cd $(KUBESPRAY) && $(ANSIBLE) -i $(INVENTORY) cluster.yml -b -u easyenv

remote-reset:
	cd $(KUBESPRAY) && $(ANSIBLE) -i $(INVENTORY) reset.yml -b -u easyenv -e reset_confirmation=yes

remote-status:
	@sudo kubectl get nodes -o wide

remote-kubeconfig:
	@echo '===KUBECONFIG-BEGIN==='
	@sudo cat /etc/kubernetes/admin.conf
	@echo '===KUBECONFIG-END==='
