NODES := $(NODE_1_NAME) $(NODE_2_NAME) $(NODE_3_NAME)

AUTOINSTALL_CONFIG_PATH =  $(PWD)/scripts/autoinstall_configs

vm.install.config.create:
	@echo $(NODE_PASSWORD)
	docker run -it --rm \
		-v $(PWD)/configuration:/workdir \
		-v $(AUTOINSTALL_CONFIG_PATH):/autoinstall \
		-v $(PWD)/ansible.cfg:/etc/ansible/ansible.cfg \
		--env-file $(PWD)/.env \
		--name $(CONTAINER_NAME) \
		$(IMAGE_NAME) ansible-playbook /workdir/autoinstall_config.yaml -i /workdir/inventory.yaml

vm.start.config.server:
	nohup busybox httpd -h $(AUTOINSTALL_CONFIG_PATH) -f -p 8080 > /dev/null 2>&1 &

vm.stop.config.server:
	pkill -9 -f "httpd" || true

vm.create:
	vboxmanage createvm \
		--name=$(NODE) \
		--ostype="Ubuntu_64" \
		--register
	vboxmanage createmedium \
		--filename="$(VM_DISKS_ROOT_PATH)/$(NODE).vdi" \
		--size=20480 \
		--format=VDI \
		--variant=Standard
	vboxmanage modifyvm $(NODE) \
		--cpus=4 \
		--memory=4096 \
		--cpuexecutioncap=50 \
		--hwvirtex=on \
		--nested-hw-virt=on \
		--boot1=dvd \
		--boot2=disk \
		--nic1=hostonly \
		--host-only-adapter1=vboxnet0 \
		--nic2=nat
	vboxmanage storagectl $(NODE) \
		--name ide-controller_$(NODE) \
		--add ide
	vboxmanage storageattach $(NODE) \
		--storagectl ide-controller_$(NODE) \
		--port 0 \
		--device 0 \
		--type hdd \
		--medium "$(VM_DISKS_ROOT_PATH)/$(NODE).vdi"

vm.install:
	vboxmanage unattended install $(NODE) \
		--iso $(VM_INSTALL_ISO_PATH) --extra-install-kernel-parameters="autoinstall cloud-config-url=http://192.168.60.1:8080/user-data.$(NODE) ds='nocloud-net;s=http://192.168.60.1:8080/'" \
		--start-vm=headless

vm.stop.hard:
	vboxmanage controlvm $(NODE) poweroff || true
	sleep 2

vm.stop.soft:
	vboxmanage controlvm $(NODE) acpipowerbutton || true
	sleep 10

vm.save.state:
	vboxmanage controlvm $(NODE) savestate || true
	sleep 2

vm.destroy: vm.stop.hard
	vboxmanage unregistervm $(NODE) --delete || true
	vboxmanage closemedium disk $(VM_DISKS_ROOT_PATH)/$(NODE).vdi --delete || true

vm.start:
	vboxmanage startvm $(NODE) --type=headless

vm.snapshot.create:
	vboxmanage snapshot $(NODE) take $(SNAPSHOT_NAME)

vm.snapshot.restore:
	vboxmanage snapshot $(NODE) restore $(SNAPSHOT_NAME)

vm.remove.nodes:
	for NODE in $(NODES) ; do \
  		$(MAKE) vm.destroy NODE=$$NODE ; \
  	done

vm.create.nodes:
	for NODE in $(NODES) ; do \
		$(MAKE) vm.create NODE=$$NODE ; \
	done

vm.install.nodes:
	for NODE in $(NODES) ; do \
  		$(MAKE) vm.install NODE=$$NODE ; \
  	done

vm.snapshot.take.nodes:
	for NODE in $(NODES) ; do \
  		$(MAKE) vm.stop.soft NODE=$$NODE ; \
  		$(MAKE) vm.snapshot.create NODE=$$NODE SNAPSHOT_NAME=$(SNAPSHOT_NAME); \
  		$(MAKE) vm.start NODE=$$NODE; \
  	done

vm.snapshot.take.initial:
	$(MAKE) vm.snapshot.take.nodes SNAPSHOT_NAME=INITIAL

vm.snapshot.take.initial_cluster:
	$(MAKE) vm.snapshot.take.nodes SNAPSHOT_NAME=INITIAL_CLUSTER

vm.snapshot.restore.nodes:
	for NODE in $(NODES) ; do \
  		$(MAKE) vm.stop.hard NODE=$$NODE ; \
  		$(MAKE) vm.snapshot.restore NODE=$$NODE SNAPSHOT_NAME=$(SNAPSHOT_NAME); \
  		$(MAKE) vm.start NODE=$$NODE; \
  	done

vm.snapshot.restore.initial:
	$(MAKE) vm.snapshot.restore.nodes SNAPSHOT_NAME=INITIAL

vm.reset.all: vm.install.config.create vm.start.config.server vm.remove.nodes vm.create.nodes vm.install.nodes
