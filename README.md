## Just making this for my understanding

* This is not a software, it is an automation

Made this just to know about qemu virtualization, haven't gone too far on emulation, but studied a lot,
haven't covered like for passthrough devices like usb and pci devices

I would like to use this for my vms instead of that damn libvirt

### running and making

1: make log


>[!NOTE]
> edit the global variables $(NAME) and $(FMT) as required if there for not to have conflict with other disk imgs
> then run make [vmname].[fmt]

2: make run-all or make run

3: run it with sudo
