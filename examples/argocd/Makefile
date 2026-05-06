.PHONY: up deploy ssh expose down

up:
	@echo '+ easyenv here up --wait 10m'
	@easyenv here up --wait 10m

deploy: up

ssh:
	@echo '+ easyenv here ssh'
	@easyenv here ssh

expose:
	@echo '+ easyenv here expose'
	@easyenv here expose

down:
	@echo '+ easyenv here down --force'
	@easyenv here down --force
