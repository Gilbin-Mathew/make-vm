SHELL = /bin/bash
# system
QEMU := qemu-system-x86_64

# virtual machine
##give the first make target as the name and format as disk
NAME := vm1
FMT := qcow2
IMG := $(NAME).$(FMT)
ISO := ~/Downloads/archlinux-2026.03.01-x86_64.iso
MEM := 4096
SIZE := 20

# cpu
SMP := 4
SOCKETS := 1
CORES := 4
THREADS := 1
MAXCPUS := 4

# firmware
##uefi by default, ""delete the lines of loader and nvram for bios""
UEFIPATH := ./UEFI/
LOADER := $(UEFIPATH)OVMF_CODE.fd
NVRAM := $(UEFIPATH)OVMF_VARS.fd


# networking
## hostside networking
NETIFACE := tap0
NETBRIDGE := br0
NETPATH := ./networks/
SUBNET := 24
GATEADDR := 10.10.10.1 

## guestside network
TAPDEVID := net0
MACADDR := 52:54:00:12:34:56
# mac address, the vendor specific 3 bytes should be 52:54:00:XX:XX:XX
# rest 3 bytes should could be altered in hex renge from 1 - F

#emulated network device or device
ENETDEV := virtio-net

#vectors should be 2 + 2 * QUE
QUE := 1
VEC := 4

# logs
LOG := ./logs/
ERRORLOGS := $(NAME).errors.log
STATPATH := ./tmp/


COMMON := $(QEMU) \
		  -name $(NAME) \
		  -pidfile $(STATPATH)$(NAME).pid \
		  -enable-kvm \
		  \
		  -m $(MEM) \
		  -smp $(SMP),sockets=$(SOCKETS),cores=$(CORES),threads=$(THREADS),maxcpus=$(MAXCPUS) \
		  -cpu host \
		  \
		  -boot order=cd,menu=on\
		  -drive if=pflash,file=$(LOADER),format=raw,readonly=on \
		  -drive if=pflash,file=$(NVRAM),format=raw \
		  -cdrom $(ISO) \
		  \
		  -drive file=$(NAME).qcow2,if=virtio,format=qcow2 \
		  \
		  -display gtk \
		  -vga std \
		  \
		  -netdev tap,id=$(TAPDEVID),ifname=$(NETIFACE),script=no,downscript=no,vhost=on\
		  -device $(ENETDEV),netdev=$(TAPDEVID),mac=$(MACADDR) \
		  \
		  -D $(LOG)$(ERRORLOGS) \
		  -d guest_errors,mmu,invalid_mem,cpu,op \
		  \
		  -daemonize 

.PHONY: run setup-net vm3.qcow2

#made as a target to make sure it dosen't gets overridden, name the target same as the vm
#could have created a bash script, but i hate to do that
vm1.qcow2:
	@qemu-img create --format $(FMT) $(NAME).qcow2 $(SIZE)G

run:vm1.qcow2 setup-host-net
	$(COMMON)

kill:
	@kill -9 $$(cat $(STATPATH)$(NAME).pid)
	@rm $(STATPATH)$(NAME).pid

#firmware defaults live here, varies on architecture "default is for x86_64"
#or dump the custom firmware on the name_CODE.fd and name_VARS.fd as interface and nvram

create-host-net:
	@$(NETPATH)bridge.sh $(NETBRIDGE) create
	@$(NETPATH)tap.sh $(NETIFACE) create

setup-host-net: create-host-net
	@$(NETPATH)bridge.sh $(NETBRIDGE) master $(NETIFACE)
	@$(NETPATH)address.sh $(NETBRIDGE) add $(GATEADDR) $(SUBNET)
	@sleep 1
	@$(NETPATH)tap.sh $(NETIFACE) up
	@$(NETPATH)bridge.sh $(NETBRIDGE) up

delete-host-net:
	@$(NETPATH)tap.sh $(NETIFACE) delete
	@$(NETPATH)bridge.sh $(NETBRIDGE) delete
