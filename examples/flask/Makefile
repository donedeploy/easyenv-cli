# === LOCAL TARGETS — run from your laptop ===

.PHONY: up sync deploy run expose ssh down

up:
	@echo '+ easyenv here up --wait 6m'
	@easyenv here up --wait 6m

sync:
	@echo '+ easyenv here sync'
	@easyenv here sync

deploy: sync

run:
	@echo "+ easyenv here run --cmd 'make remote-run'"
	@easyenv here run --cmd 'make remote-run'

expose:
	@echo '+ easyenv here expose'
	@easyenv here expose

ssh:
	@echo '+ easyenv here ssh'
	@easyenv here ssh

down:
	@echo '+ easyenv here down --force'
	@easyenv here down --force


# === REMOTE TARGETS — run on the box via `easyenv here run` ===

.PHONY: remote-run

remote-run:
	python3 app.py
