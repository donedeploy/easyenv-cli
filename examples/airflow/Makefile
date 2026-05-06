.PHONY: up sync deploy expose ssh down

up:
	@echo '+ easyenv here up --wait 12m'
	@easyenv here up --wait 12m

sync:
	@echo '+ easyenv here sync'
	@easyenv here sync

deploy: sync

expose:
	@echo '+ easyenv here expose'
	@easyenv here expose

ssh:
	@echo '+ easyenv here ssh'
	@easyenv here ssh

down:
	@echo '+ easyenv here down --force'
	@easyenv here down --force
