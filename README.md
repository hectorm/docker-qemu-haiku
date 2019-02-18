# Haiku on Docker

A Docker image for the [Haiku](https://www.haiku-os.org) operating system.

## Start an instance
```sh
docker run --detach \
  --name qemu-haiku \
  --restart on-failure:3 \
  --publish 127.0.0.1:6080:6080/tcp \
  --privileged --env QEMU_KVM=true \
  hectormolinero/qemu-haiku:latest
```
> The instance will be available through a web browser from: http://localhost:6080/vnc_auto.html

## Environment variables
#### `QEMU_CPU`
Number of cores the VM is permitted to use (`2` by default).

#### `QEMU_RAM`
Amount of memory the VM is permitted to use (`1024M` by default).

#### `QEMU_KVM`
Start QEMU in KVM mode (`false` by default).
> The `--privileged` option is required to use KVM in the container.

## License
See the [license](LICENSE.md) file.
