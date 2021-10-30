m4_changequote([[, ]])

##################################################
## "build" stage
##################################################

m4_ifdef([[CROSS_ARCH]], [[FROM docker.io/CROSS_ARCH/ubuntu:20.04]], [[FROM docker.io/ubuntu:20.04]]) AS build
m4_ifdef([[CROSS_QEMU]], [[COPY --from=docker.io/hectormolinero/qemu-user-static:latest CROSS_QEMU CROSS_QEMU]])

# Install system packages
RUN export DEBIAN_FRONTEND=noninteractive \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends \
		ca-certificates \
		curl \
	&& rm -rf /var/lib/apt/lists/*

# Download noVNC
ARG NOVNC_VERSION=v1.3.0
ARG NOVNC_TARBALL_URL=https://github.com/novnc/noVNC/archive/${NOVNC_VERSION}.tar.gz
ARG NOVNC_TARBALL_CHECKSUM=ee8f91514c9ce9f4054d132f5f97167ee87d9faa6630379267e569d789290336
RUN curl -Lo /tmp/novnc.tgz "${NOVNC_TARBALL_URL:?}"
RUN printf '%s' "${NOVNC_TARBALL_CHECKSUM:?}  /tmp/novnc.tgz" | sha256sum -c
RUN mkdir /tmp/novnc/ && tar -xzf /tmp/novnc.tgz --strip-components=1 -C /tmp/novnc/

# Download Websockify
ARG WEBSOCKIFY_VERSION=v0.10.0
ARG WEBSOCKIFY_TARBALL_URL=https://github.com/novnc/websockify/archive/${WEBSOCKIFY_VERSION}.tar.gz
ARG WEBSOCKIFY_TARBALL_CHECKSUM=7bd99b727e0be230f6f47f65fbe4bd2ae8b2aa3568350148bdf5cf440c4c6b4a
RUN curl -Lo /tmp/websockify.tgz "${WEBSOCKIFY_TARBALL_URL:?}"
RUN printf '%s' "${WEBSOCKIFY_TARBALL_CHECKSUM:?}  /tmp/websockify.tgz" | sha256sum -c
RUN mkdir /tmp/websockify/ && tar -xzf /tmp/websockify.tgz --strip-components=1 -C /tmp/websockify/

# Download Haiku ISO
ARG HAIKU_ISO_URL=https://cdn.haiku-os.org/haiku-release/r1beta3/haiku-r1beta3-x86_64-anyboot.iso
ARG HAIKU_ISO_CHECKSUM=33c8b58c4bd3d6479554afbd3a9b08709c8f8086e98ad339b866722e9bb1e820
RUN curl -Lo /tmp/haiku.iso "${HAIKU_ISO_URL:?}"
RUN printf '%s' "${HAIKU_ISO_CHECKSUM:?}  /tmp/haiku.iso" | sha256sum -c

##################################################
## "main" stage
##################################################

m4_ifdef([[CROSS_ARCH]], [[FROM docker.io/CROSS_ARCH/ubuntu:20.04]], [[FROM docker.io/ubuntu:20.04]]) AS main
m4_ifdef([[CROSS_QEMU]], [[COPY --from=docker.io/hectormolinero/qemu-user-static:latest CROSS_QEMU CROSS_QEMU]])

# Install system packages
RUN export DEBIAN_FRONTEND=noninteractive \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends \
		net-tools \
		procps \
		python3 \
		qemu-kvm \
		qemu-system-x86 \
		qemu-utils \
		runit \
	&& rm -rf /var/lib/apt/lists/*

# Environment
ENV QEMU_VM_CPU=2
ENV QEMU_VM_RAM=1024M
ENV QEMU_VM_DISK_SIZE=16G
ENV QEMU_VM_DISK_FORMAT=qcow2
ENV QEMU_VM_KEYBOARD=en-us
ENV QEMU_VM_NET_DEVICE=e1000
ENV QEMU_VM_NET_OPTIONS=hostfwd=tcp::10022-:22,hostfwd=tcp::15900-:5900
ENV QEMU_VM_BOOT_ORDER=cd
ENV QEMU_VM_BOOT_MENU=off
ENV QEMU_VM_KVM=false

# Create some directories for QEMU
RUN mkdir -p /var/lib/qemu/iso/ /var/lib/qemu/images/

# Copy noVNC
COPY --from=build --chown=root:root /tmp/novnc/ /opt/novnc/

# Copy Websockify
COPY --from=build --chown=root:root /tmp/websockify/ /opt/novnc/utils/websockify/

# Copy Haiku ISO
COPY --from=build --chown=root:root /tmp/haiku.iso /var/lib/qemu/iso/haiku.iso

# Copy services
COPY --chown=root:root ./scripts/service/ /etc/service/

# Copy scripts
COPY --chown=root:root ./scripts/bin/ /usr/local/bin/

# VNC
EXPOSE 5900/tcp
# noVNC
EXPOSE 6080/tcp

CMD ["/usr/local/bin/container-foreground-cmd"]
