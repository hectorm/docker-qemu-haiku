##################################################
## "qemu-haiku" stage
##################################################

FROM docker.io/ubuntu:20.04 AS qemu-haiku

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
		qemu-kvm \
		qemu-system-x86 \
		qemu-utils \
		runit \
		unzip \
	&& rm -rf /var/lib/apt/lists/*

# Install noVNC
ARG NOVNC_VERSION=v1.1.0
ARG NOVNC_TARBALL_URL=https://github.com/novnc/noVNC/archive/${NOVNC_VERSION}.tar.gz
ARG NOVNC_TARBALL_CHECKSUM=2c63418b624a221a28cac7b9a7efecc092b695fc1b7dd88255b074ab32bc72a7
RUN mkdir -p /opt/novnc/ \
	&& curl -Lo /tmp/novnc.tgz "${NOVNC_TARBALL_URL:?}" \
	&& printf '%s' "${NOVNC_TARBALL_CHECKSUM:?}  /tmp/novnc.tgz" | sha256sum -c \
	&& tar -xzf /tmp/novnc.tgz --strip-components=1 -C /opt/novnc/ \
	&& rm -f /tmp/novnc.tgz

# Install Websockify
ARG WEBSOCKIFY_VERSION=v0.9.0
ARG WEBSOCKIFY_TARBALL_URL=https://github.com/novnc/websockify/archive/${WEBSOCKIFY_VERSION}.tar.gz
ARG WEBSOCKIFY_TARBALL_CHECKSUM=6ebfec791dd78be6584fb5fe3bc27f02af54501beddf8457368699f571de13ae
RUN mkdir -p /opt/novnc/utils/websockify/ \
	&& curl -Lo /tmp/websockify.tgz "${WEBSOCKIFY_TARBALL_URL:?}" \
	&& printf '%s' "${WEBSOCKIFY_TARBALL_CHECKSUM:?}  /tmp/websockify.tgz" | sha256sum -c \
	&& tar -xzf /tmp/websockify.tgz --strip-components=1 -C /opt/novnc/utils/websockify/ \
	&& rm -f /tmp/websockify.tgz

# Download Haiku ISO
ARG HAIKU_ISO_URL=https://cdn.haiku-os.org/haiku-release/r1beta2/haiku-r1beta2-x86_64-anyboot.zip
ARG HAIKU_ISO_CHECKSUM=24ea1839930a48828387797a4f4b2a142bafd71da4d86788e2dbe51f4eb68aff
RUN mkdir -p /tmp/haiku/ /var/lib/qemu/iso/ /var/lib/qemu/images/ \
	&& curl -Lo /tmp/haiku/haiku.zip "${HAIKU_ISO_URL:?}" \
	&& printf '%s' "${HAIKU_ISO_CHECKSUM:?}  /tmp/haiku/haiku.zip" | sha256sum -c \
	&& unzip /tmp/haiku/haiku.zip -d /tmp/haiku/ \
	&& mv /tmp/haiku/*.iso /var/lib/qemu/iso/haiku.iso \
	&& rm -rf /tmp/haiku/

# Copy services
COPY --chown=root:root ./scripts/service/ /etc/service/

# Copy scripts
COPY --chown=root:root ./scripts/bin/ /usr/local/bin/

# Expose ports
## VNC
EXPOSE 5900/tcp
## noVNC
EXPOSE 6080/tcp

CMD ["/usr/local/bin/container-foreground-cmd"]
