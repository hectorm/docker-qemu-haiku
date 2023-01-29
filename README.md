# Haiku on Docker

A Docker image for the [Haiku](https://www.haiku-os.org) operating system.

## Start an instance
```sh
docker run --detach \
  --name qemu-haiku \
  --device /dev/kvm \
  --publish 127.0.0.1:2222:2222/tcp \
  --publish 127.0.0.1:5900:5900/tcp \
  --publish 127.0.0.1:6080:6080/tcp \
  --env VM_SSH_KEYS="$(find ~/.ssh/ -name 'id_*.pub' -exec awk 1 '{}' ';')" \
  docker.io/hectorm/qemu-haiku:latest
```

The instance can be accessed from:
 * **SSH** (`2222/TCP`), user `user`, public key authentication.
 * **VNC** (`5900/TCP`), without password.
 * **noVNC** (`6080/TCP`), http://127.0.0.1:6080/vnc.html
 * `docker exec -it qemu-haiku vmshell`

## Environment variables
#### `VM_CPU`
Number of cores the VM is permitted to use (`2` by default).

#### `VM_RAM`
Amount of memory the VM is permitted to use (`2048M` by default).

#### `VM_KEYBOARD`
VM keyboard layout (`en-us` by default).

#### `VM_KVM`
Start QEMU in KVM mode (`true` by default).
> The `--device /dev/kvm` option is required for this variable to take effect.

#### `VM_SSH_KEY*`
SSH keys to be added to the VM at startup.

## Use in CI

### GitHub Actions:

```yaml
test-haiku:
  name: 'Test on Haiku'
  runs-on: 'ubuntu-latest'
  container: 'docker.io/hectorm/qemu-haiku:latest'
  steps:
    - name: 'Wait until the VM is ready'
      run: 'container-init & timeout 600 vmshell exit 0'
    - name: 'Install packages'
      run: 'vmshell pkgman install -y make'
    - name: 'Checkout project'
      uses: 'actions/checkout@main'
    - name: 'Copy project to VM'
      run: 'vmshell mkdir ./src/; tar -cf - ./ | vmshell tar -xf - -C ./src/'
    - name: 'Test project'
      run: 'vmshell make -C ./src/ test'
```

### GitLab CI:

```yaml
test-haiku:
  stage: 'test'
  image:
    name: 'docker.io/hectorm/qemu-haiku:latest'
    entrypoint: ['']
  before_script:
    - 'container-init & timeout 600 vmshell exit 0'
    - 'vmshell pkgman install -y make'
    - 'vmshell mkdir ./src/; tar -cf - ./ | vmshell tar -xf - -C ./src/'
  script:
    - 'vmshell make -C ./src/ test'
```

> Please note that at the time of writing GitHub and GitLab hosted runners do not support nested virtualization, so a high performance loss is expected. Consider using this image in an CI environment as a proof of concept.

> Sometimes after installing packages a reboot may be necessary, `pkgman` will print a message like "`A reboot is necessary to complete the installation process`". In such scenario you can add a step in your CI to reboot and wait until the VM is ready, "`sv force-restart qemu & timeout 600 vmshell exit 0`".

## License
See the [license](LICENSE.md) file.
