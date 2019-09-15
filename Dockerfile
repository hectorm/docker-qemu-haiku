FROM docker.io/debian:sid

# Environment
ENV QEMU_CPU=2
ENV QEMU_RAM=1024M
ENV QEMU_DISK_SIZE=16G
ENV QEMU_DISK_FORMAT=qcow2
ENV QEMU_KEYBOARD=en-us
ENV QEMU_NET_DEVICE=e1000
ENV QEMU_NET_OPTIONS=hostfwd=tcp::10022-:22,hostfwd=tcp::15900-:5900
ENV QEMU_BOOT_ORDER=cd
ENV QEMU_BOOT_MENU=off
ENV QEMU_KVM=false

# Install system packages
RUN export DEBIAN_FRONTEND=noninteractive \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends \
		ca-certificates \
		curl \
		net-tools \
		procps \
		python3 \
		python3-numpy \
		qemu-kvm \
		qemu-system-x86 \
		qemu-utils \
		runit \
		unzip \
	&& rm -rf /var/lib/apt/lists/*

# Install noVNC
ARG NOVNC_VERSION=v1.1.0
ARG NOVNC_TARBALL_URL=https://github.com/novnc/noVNC/archive/${NOVNC_VERSION}.tar.gz
RUN mkdir /opt/novnc/
RUN curl -sSfL "${NOVNC_TARBALL_URL:?}" | tar -xz --strip-components=1 -C /opt/novnc/

# Install Websockify
ARG WEBSOCKIFY_VERSION=v0.9.0
ARG WEBSOCKIFY_TARBALL_URL=https://github.com/novnc/websockify/archive/${WEBSOCKIFY_VERSION}.tar.gz
RUN mkdir -p /opt/novnc/utils/websockify/
RUN curl -sSfL "${WEBSOCKIFY_TARBALL_URL:?}" | tar -xz --strip-components=1 -C /opt/novnc/utils/websockify/

# Create data directories
RUN mkdir -p /var/lib/qemu/images/ /var/lib/qemu/iso/

# Download Haiku ISO
ARG HAIKU_ISO_URL=https://cdn.haiku-os.org/haiku-release/r1beta1/haiku-r1beta1-x86_64-anyboot.zip
ARG HAIKU_ISO_CHECKSUM=297b1410dfd74f1a404c1d2d0e62beaee77ecde7711a71156e15f8d33f2899ed
RUN mkdir /tmp/haiku/ \
	&& curl -Lo /tmp/haiku/haiku.zip "${HAIKU_ISO_URL:?}" \
	&& echo "${HAIKU_ISO_CHECKSUM:?}  /tmp/haiku/haiku.zip" | sha256sum -c \
	&& unzip /tmp/haiku/haiku.zip -d /tmp/haiku/ \
	&& mv /tmp/haiku/*.iso /var/lib/qemu/iso/haiku.iso \
	&& rm -rf /tmp/haiku/

# Copy services
COPY --chown=root:root scripts/service/ /etc/service/

# Copy scripts
COPY --chown=root:root scripts/bin/ /usr/local/bin/

# Expose ports
## VNC
EXPOSE 5900/tcp
## noVNC
EXPOSE 6080/tcp

CMD ["/usr/local/bin/container-foreground-cmd"]
