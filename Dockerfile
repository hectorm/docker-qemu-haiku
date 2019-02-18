FROM ubuntu:18.04

# Environment
ENV QEMU_CPU=2
ENV QEMU_RAM=1024M
ENV QEMU_KVM=false

# Install system packages
RUN export DEBIAN_FRONTEND=noninteractive \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends \
		ca-certificates \
		curl \
		net-tools \
		novnc \
		qemu-kvm \
		qemu-system-x86 \
		qemu-utils \
		runit \
		unzip \
	&& rm -rf /var/lib/apt/lists/*

# Create data directories
RUN mkdir -p /var/lib/qemu/images/ /var/lib/qemu/iso/

# Download Haiku ISO
ARG HAIKU_ISO_URL=https://cdn.haiku-os.org/haiku-release/r1beta1/haiku-r1beta1-x86_64-anyboot.zip
ARG HAIKU_ISO_CHECKSUM=297b1410dfd74f1a404c1d2d0e62beaee77ecde7711a71156e15f8d33f2899ed
RUN mkdir /tmp/haiku/ \
	&& curl -Lo /tmp/haiku/haiku.zip "${HAIKU_ISO_URL}" \
	&& echo "${HAIKU_ISO_CHECKSUM}  /tmp/haiku/haiku.zip" | sha256sum -c \
	&& unzip /tmp/haiku/haiku.zip -d /tmp/haiku/ \
	&& mv /tmp/haiku/*.iso /var/lib/qemu/iso/haiku.iso \
	&& rm -rf /tmp/haiku/

# Create Haiku disk
RUN qemu-img create -f qcow2 /var/lib/qemu/images/haiku.img 32G

# Copy services
COPY --chown=root:root scripts/service/ /etc/service/

# Expose noVNC port
EXPOSE 6080/tcp

CMD ["runsvdir", "-P", "/etc/service/"]
