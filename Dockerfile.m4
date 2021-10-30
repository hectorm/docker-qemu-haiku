m4_changequote([[, ]])

##################################################
## "build" stage
##################################################

FROM docker.io/ubuntu:20.04 AS build

# Install system packages
RUN export DEBIAN_FRONTEND=noninteractive \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends \
		autoconf \
		automake \
		bash \
		bison \
		build-essential \
		ca-certificates \
		curl \
		device-tree-compiler \
		flex \
		gawk \
		gcc-multilib \
		git \
		less \
		libtool \
		moreutils \
		mtools \
		nasm \
		python3 \
		qemu-utils \
		qemu-system-x86 \
		texinfo \
		u-boot-tools \
		unzip \
		util-linux \
		wget \
		xorriso \
		zip \
		zlib1g-dev \
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

# Build Haiku
ARG HAIKU_TREEISH=r1beta3
ARG HAIKU_REMOTE=https://review.haiku-os.org/haiku.git
ARG BUILDTOOLS_TREEISH=$HAIKU_TREEISH
ARG BUILDTOOLS_REMOTE=https://review.haiku-os.org/buildtools.git
WORKDIR /tmp/buildtools/
RUN git clone "${BUILDTOOLS_REMOTE:?}" ./
RUN git checkout "${BUILDTOOLS_TREEISH:?}"
RUN git submodule update --init --recursive
WORKDIR /tmp/buildtools/jam/
RUN make -j"$(nproc)"
RUN ./jam0 install
WORKDIR /tmp/haiku/
RUN git clone "${HAIKU_REMOTE:?}" ./
RUN git checkout "${HAIKU_TREEISH:?}"
RUN git submodule update --init --recursive
COPY --chown=root:root ./patches/haiku/ /tmp/patches/haiku/
RUN git apply -v /tmp/patches/haiku/*.patch
RUN ./configure \
		--distro-compatibility official \
		--cross-tools-source /tmp/buildtools/ \
		--build-cross-tools x86_64 \
		--use-gcc-pipe \
		-j"$(nproc)"
COPY --chown=root:root ./scripts/vm-first-login/ /tmp/haiku/data/system/boot/first_login/
RUN export HAIKU_IMAGE_SIZE=131072 \
	&& jam -qj"$(nproc)" '@nightly-raw' \
	&& cd ./generated/ \
	&& timeout 900 qemu-system-x86_64 \
		-accel tcg,thread=single -smp 2 -m 512 -serial stdio -display none \
		-drive file=./haiku-nightly.image,index=0,media=disk,format=raw \
		-netdev user,id=n0 -device e1000,netdev=n0 \
	&& qemu-img convert -f raw -O qcow2 ./haiku-nightly.image ./haiku.qcow2 \
	&& rm -f ./haiku-nightly.image

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
		netcat-openbsd \
		openssh-client \
		procps \
		python3 \
		qemu-kvm \
		qemu-system-x86 \
		qemu-utils \
		runit \
	&& rm -rf /var/lib/apt/lists/*

# Environment
ENV VM_CPU=2
ENV VM_RAM=1024M
ENV VM_KEYBOARD=en-us
ENV VM_NET_OPTIONS=
ENV VM_KVM=false

# Copy noVNC
COPY --from=build --chown=root:root /tmp/novnc/ /opt/novnc/

# Copy Websockify
COPY --from=build --chown=root:root /tmp/websockify/ /opt/novnc/utils/websockify/

# Copy Haiku disk
COPY --from=build --chown=root:root /tmp/haiku/generated/haiku.qcow2 /var/lib/qemu/haiku.qcow2

# Copy SSH config
COPY --chown=root:root ./config/ssh/ /etc/ssh/

# Copy services
COPY --chown=root:root ./scripts/service/ /etc/service/

# Copy bin scripts
COPY --chown=root:root ./scripts/bin/ /usr/local/bin/

# Copy net init scripts
COPY --chown=root:root ./scripts/vm-net-init/ /etc/vm-net-init/

ENTRYPOINT ["/usr/local/bin/container-init"]
