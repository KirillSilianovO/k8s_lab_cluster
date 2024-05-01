include .env
include ./makefiles/vm.mk
export

ifdef TAGS
	VAR_TAGS := --tags $(TAGS)
endif

IMAGE_NAME = kirillsilianov/deploy-image:2.1
CONTAINER_NAME = deploy-container

.pre:
	chmod 0600 $(PWD)/configuration/private_key.pem || true
	python3 $(PWD)/scripts/create_password_hash/create.py $(NODE_PASS) $(PWD)/.env

.check_nodes_is_available:
	rm -rf $(PWD)/.venv || true
	python3 -m venv .venv
	$(PWD)/.venv/bin/pip install -r $(PWD)/scripts/check_nodes_is_available/requirements.txt
	$(PWD)/.venv/bin/python $(PWD)/scripts/check_nodes_is_available/check.py $(NODE_1_ADDRESS) $(NODE_2_ADDRESS) $(NODE_3_ADDRESS) $(NODE_USER) $(NODE_PASS)
	rm -rf $(PWD)/.venv || true

.set_join_data:
	python3 $(PWD)/scripts/set_join_command_data/set.py $(PWD)/configuration/temp/node_1/etc/kubernetes/init.log $(PWD)/.env

.copy_k8s_config_file:
	cp $(PWD)/configuration/temp/node_1/home/kube/.kube/config $(PWD)/cluster_config.yaml

.cleanup:
	docker run -it --rm \
		-v $(PWD)/configuration:/workdir \
		-v $(PWD)/ansible.cfg:/etc/ansible/ansible.cfg \
		--env-file .env \
		--name $(CONTAINER_NAME) \
		$(IMAGE_NAME) rm -rf /workdir/temp

lint:
	docker run -it --rm \
		-v $(PWD)/configuration:/workdir \
		-v $(PWD)/ansible-lint.yaml:/ansible-lint.yaml \
		--name $(CONTAINER_NAME) \
		$(IMAGE_NAME) ansible-lint -c /ansible-lint.yaml

configure:
	docker run -it --rm \
		-v $(PWD)/configuration:/workdir \
		-v $(PWD)/ansible.cfg:/etc/ansible/ansible.cfg \
		--env-file .env \
		--name $(CONTAINER_NAME) \
		$(IMAGE_NAME) ansible-playbook /workdir/deploy.yaml -i /workdir/inventory.yaml --tags $(VAR_TAGS)

node_update:
	$(MAKE) configure VAR_TAGS=system_update

node_initial:
	$(MAKE) configure VAR_TAGS=initial_config,network_config,cri_o,k8s_initial

control_plane:
	$(MAKE) configure VAR_TAGS=k8s_control_plane

join:
	$(MAKE) configure VAR_TAGS=k8s_join

reset_vm: .pre vm.reset.all .check_nodes_is_available vm.snapshot.take.initial
	$(MAKE) .check_nodes_is_available

config_cluster: node_update node_initial control_plane .set_join_data join vm.snapshot.take.initial_cluster
	$(MAKE) .check_nodes_is_available
	$(MAKE) .copy_k8s_config_file
	$(MAKE) .cleanup

reset_config_cluster: vm.snapshot.restore.initial .check_nodes_is_available config_cluster

reset_cluster: reset_vm config_cluster vm.stop.config.server
