.PHONY: up deploy expose ssh down

up:
	@echo '+ easyenv here up --wait 6m'
	@easyenv here up --wait 6m

deploy: up

expose:
	@echo '+ easyenv here expose'
	@easyenv here expose

ssh:
	@echo '+ easyenv here ssh'
	@easyenv here ssh

down:
	@echo '+ easyenv here down --force'
	@easyenv here down --force
