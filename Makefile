.DEFAULT_GOAL := help
.PHONY: help keys up down logs verify shell ansible-check clean

help:
	@echo "up             build and start the three hosts"
	@echo "keys           generate the lab key pair and print the ssh config"
	@echo "down           stop everything"
	@echo "logs           follow the logs of every host"
	@echo "verify         run the network isolation checks"
	@echo "shell          open a session on the bastion"
	@echo "ansible-check  syntax check the playbook"
	@echo "clean          stop everything and remove the volumes and keys"

keys:
	./scripts/setup-keys.sh

up: keys
	docker compose up -d --build

down:
	docker compose down

logs:
	docker compose logs -f

verify:
	./scripts/verify-isolation.sh

shell:
	ssh -i ssh/lab_key -p 2222 jump@127.0.0.1

ansible-check:
	cd ansible && cp -n inventory.example.yml inventory.yml && ansible-playbook --syntax-check playbook.yml

clean:
	docker compose down -v
	rm -f ssh/lab_key ssh/lab_key.pub ssh/authorized_keys
