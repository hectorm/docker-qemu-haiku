# Haiku on Docker

A Docker image for the [Haiku](https://www.haiku-os.org) operating system.

## Start an instance
```sh
docker run --detach \
  --name qemu-haiku \
  --device /dev/kvm \
  --publish 127.0.0.1:2222:2222/tcp \
  --publish 127.0.0.1:6080:6080/tcp \
  --env VM_SSH_KEYS="$(find ~/.ssh/ -name 'id_*.pub' -exec awk 1 '{}' ';')" \
  docker.io/hectormolinero/qemu-haiku:latest
```

> The instance can be accessed from:
> * 2222/TCP (SSH): `ssh -p 2222 user@127.0.0.1`
> * 6080/TCP (noVNC): http://127.0.0.1:6080/vnc.html
> * Shell: `docker exec -it qemu-haiku vmshell`

## Environment variables
#### `VM_CPU`
Number of cores the VM is permitted to use (`2` by default).

#### `VM_RAM`
Amount of memory the VM is permitted to use (`1024M` by default).

#### `VM_KEYBOARD`
VM keyboard layout (`en-us` by default).

#### `VM_KVM`
Start QEMU in KVM mode (`true` by default).
> The `--device /dev/kvm` option is required for this variable to take effect.

#### `VM_SSH_KEY*`
SSH keys to be added to the VM at startup.

## License
See the [license](LICENSE.md) file.
