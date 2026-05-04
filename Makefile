SHELL = /bin/bash
# Work area

## system
QEMU := qemu-system-x86_64

## virtual machine
#give the first make target as the name and format as disk
NAME := vm1
FMT := qcow2
IMG := $(NAME).$(FMT)
ISO := ~/Downloads/debian-live-12.11.0-amd64-gnome.iso
MEM := 4096
MACHINE := q35
SIZE := 20

## cpu
SMP := 4
SOCKETS := 1
CORES := 4
THREADS := 1
MAXCPUS := 4

## firmware
#uefi by default, ""delete the lines of loader and nvram for bios""
UEFIPATH := ./UEFI/
LOADER := $(UEFIPATH)OVMF_CODE.fd
NVRAM := $(UEFIPATH)OVMF_VARS.fd


## networking
### hostside networking
NETIFACE := tap0
NETBRIDGE := br0
NETPATH := ./networks/
SUBNET := 24
GATEADDR := 10.10.10.1 

### guestside network
TAPDEVID := net0
MACADDR := 52:54:00:12:34:56
#mac address, the vendor specific 3 bytes should be 52:54:00:XX:XX:XX
#rest 3 bytes should could be altered in hex renge from 1 - F

#emulated network device or device
ENETDEV := virtio-net

#vectors should be 2 + 2 * QUE
QUE := 1
VEC := 4

## logs
LOG := ./logs/
ERRORLOGS := $(NAME).errors.log
STATPATH := ./tmp/

# Cook area

COMMON := -name $(NAME) \
		  -pidfile $(STATPATH)$(NAME).pid \
		  -machine $(MACHINE) \
		  -enable-kvm \
		  -m $(MEM) \
		  -smp $(SMP),sockets=$(SOCKETS),cores=$(CORES),threads=$(THREADS),maxcpus=$(MAXCPUS) \
		  -cpu host \
		  \
		  -drive file=$(NAME).qcow2,if=none,format=qcow2,id=disk0 \
		  -device virtio-blk-pci,drive=disk0 \
		  \
		  -D $(LOG)$(ERRORLOGS) \
		  -d guest_errors,mmu,invalid_mem,cpu,op \


WITHAUDIO := -audiodev pipewire,id=snd0 \
			 -device ich9-intel-hda \
			 -device hda-output,audiodev=snd0 \

WITHBOOT := -boot order=cd,menu=on \
			-drive if=pflash,file=$(LOADER),format=raw,readonly=on \
			-drive if=pflash,file=$(NVRAM),format=raw \
			\
			-device virtio-scsi,id=scsi0 \
			-drive file=$(ISO),media=cdrom,if=none,id=cd0 \
			-device scsi-cd,drive=cd0 \


WITHGRAPHICS := -display spice-app,gl=on \
				-vga qxl \
	
WITHNET := -netdev tap,id=$(TAPDEVID),ifname=$(NETIFACE),script=no,downscript=no,vhost=on,queues=$(QUE) \
		   -device $(ENETDEV),netdev=$(TAPDEVID),mac=$(MACADDR),mq=on,vectors=$(VEC) \

.PHONY: run setup-host-net delete-host-net create-host-net

#made as a target to make sure it dosen't gets overridden, name the target same as the vm
#could have created a bash script, but i hate to do that
vm1.qcow2:
	@qemu-img create --format $(FMT) $(NAME).qcow2 $(SIZE)G

run:setup-host-net
	$(QEMU) $(COMMON) $(WITHBOOT) $(WITHGRAPHICS) $(WITHNET) $(WITHAUDIO)

kill:$(STATPATH)$(NAME).pid
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
