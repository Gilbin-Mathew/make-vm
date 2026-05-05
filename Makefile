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
NBDBLK := nbd0

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
HOSTGATEADDR := 10.10.10.1 
NATNETADDR := 192.168.100.0/24
NATDHCPSTRT := 192.168.100.10

### guestside network
TAPDEVID := net1
NATDEVID := net0
NATMACADDR := 52:54:00:10:11:12
HOSTMACADDR := 52:54:00:11:12:13
#mac address, the vendor specific 3 bytes should be 52:54:00:XX:XX:XX
#rest 3 bytes could be altered in hex renge from 1 - F

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
		  -monitor stdio \
		  \
		  -device virtio-scsi-pci,id=scsi0 \
		  -drive file=$(NAME).qcow2,if=none,format=qcow2,id=disk0 \
		  -device scsi-hd,drive=disk0,bus=scsi0.0 \
		  \
		  -D $(LOG)$(ERRORLOGS) \
		  -d guest_errors,mmu,invalid_mem,cpu,op \

#audio devices for the vm first device is a controller device next is the audio output device
WITHAUDIO := -audiodev pipewire,id=snd0 \
			 -device ich9-intel-hda \
			 -device hda-output,audiodev=snd0 \


#firmware defaults are here, varies on architecture "default is for x86_64"
#or dump the custom firmware on the UEFI directory, interface and nvram
WITHBOOT := -boot order=d,menu=on,strict=on \
			-drive if=pflash,file=$(LOADER),format=raw,readonly=on \
			-drive if=pflash,file=$(NVRAM),format=raw \
			\
			-cdrom $(ISO) \

#IO devices for the vm
WITHIODEV := -device virtio-keyboard-pci \


WITHGRAPHICS := -display spice-app,gl=on \
				-device qxl-vga \


WITHNET := -netdev tap,id=$(TAPDEVID),ifname=$(NETIFACE),script=no,downscript=no,vhost=on,queues=$(QUE) \
		   -device $(ENETDEV),netdev=$(TAPDEVID),mac=$(HOSTMACADDR),mq=on,vectors=$(VEC) \
		   \
		   -netdev user,id=$(NATDEVID),net=$(NATNETADDR),dhcpstart=$(NATDHCPSTRT) \
		   -device $(ENETDEV),netdev=$(NATDEVID),mac=$(NATMACADDR),mq=on,vectors=$(VEC) \


#WITHPCIPASSDEV := 
#WITHUSBPASSDEV := -device qemu-xhci,id=usb0 \
#				  -device usb-host,bus=usb0.0,port=1,vendorid=0x346d,productid=0x5678,hostbus=2,hostaddr=6 \

# just taking rest for a while, I'm continuing it later

.PHONY: run run-all setup-host-net delete-host-net create-host-net connect-nbd mount-nbd

#name made as a target to make sure it dosen't gets overridden, name the target same as the vm name and format.
#could have created a bash script, but i hate to do that
vm1.qcow2:
	@qemu-img create --format $(FMT) $(NAME).qcow2 $(SIZE)G

run:
	$(QEMU) $(COMMON) $(WITHBOOT)

run-all:setup-host-net
	$(QEMU) $(COMMON) $(WITHBOOT) $(WITHGRAPHICS) $(WITHNET) $(WITHAUDIO) $(WITHIODEV)

kill:$(STATPATH)$(NAME).pid
	@kill -9 $$(cat $(STATPATH)$(NAME).pid)
	@rm $(STATPATH)$(NAME).pid

# host only network setup
create-host-net:
	@$(NETPATH)bridge.sh $(NETBRIDGE) create
	@$(NETPATH)tap.sh $(NETIFACE) create

setup-host-net: create-host-net
	@$(NETPATH)bridge.sh $(NETBRIDGE) master $(NETIFACE)
	@$(NETPATH)address.sh $(NETBRIDGE) add $(HOSTGATEADDR) $(SUBNET)
	@sleep 1
	@$(NETPATH)tap.sh $(NETIFACE) up
	@$(NETPATH)bridge.sh $(NETBRIDGE) up

delete-host-net:
	@$(NETPATH)tap.sh $(NETIFACE) delete
	@$(NETPATH)bridge.sh $(NETBRIDGE) delete

connect-nbd: $(NAME).$(FMT)
	@sudo modprobe nbd
	@sudo qemu-nbd --connect=/dev/$(NBDBLK) $(NAME).$(FMT)

mount-nbd:
	@sudo mkdir -p /mnt/$(NAME)-$(FMT)-$(NBDBLK)-mnt
	@sudo mount /dev/$(NBDBLK) /mnt/$(NAME)-$(FMT)-$(NBDBLK)-mnt
	@echo "Mounted $(NBDBLK) to /mnt/$(NAME)-$(FMT)-$(NBDBLK)-mnt"

disconnect-nbd:
	@sudo umount /mnt/$(NAME)-$(FMT)-$(NBDBLK)-mnt
	@sleep 5
	@sudo rmdir /mnt/$(NAME)-$(FMT)-$(NBDBLK)-mnt
	@sudo qemu-nbd --disconnect /dev/$(NBDBLK)
	@sudo modprobe -r nbd
