# syntax=docker.io/docker/dockerfile:1
# check=skip=FromPlatformFlagConstDisallowed

m4_changequote([[, ]])

##################################################
## "build" stage
##################################################

FROM --platform=linux/amd64 docker.io/ubuntu:26.04 AS build

SHELL ["/bin/sh", "-euc"]

# Install system packages
RUN <<-EOF
	export DEBIAN_FRONTEND=noninteractive
	apt-get update
	apt-get install -y --no-install-recommends \
		autoconf \
		automake \
		bash \
		bc \
		binutils \
		bison \
		ca-certificates \
		curl \
		device-tree-compiler \
		flex \
		g++-14 \
		gawk \
		gcc-14 \
		gcc-14-multilib \
		git \
		less \
		libc6-dev \
		libtool \
		libzstd-dev \
		make \
		moreutils \
		mtools \
		nasm \
		python3 \
		qemu-system-x86 \
		qemu-utils \
		texinfo \
		u-boot-tools \
		unzip \
		util-linux \
		wget \
		xorriso \
		zip \
		zlib1g-dev
	rm -rf /var/lib/apt/lists/*
EOF

# Set default toolchain
RUN <<-EOF
	update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-14 1 \
		--slave /usr/bin/g++ g++ /usr/bin/g++-14 \
		--slave /usr/bin/gcc-ar gcc-ar /usr/bin/gcc-ar-14 \
		--slave /usr/bin/gcc-nm gcc-nm /usr/bin/gcc-nm-14 \
		--slave /usr/bin/gcc-ranlib gcc-ranlib /usr/bin/gcc-ranlib-14 \
		--slave /usr/bin/gcov gcov /usr/bin/gcov-14 \
		--slave /usr/bin/gcov-dump gcov-dump /usr/bin/gcov-dump-14 \
		--slave /usr/bin/gcov-tool gcov-tool /usr/bin/gcov-tool-14 \
		--slave /usr/bin/lto-dump lto-dump /usr/bin/lto-dump-14
	update-alternatives --install /usr/bin/cc cc /usr/bin/gcc 1
	update-alternatives --install /usr/bin/c++ c++ /usr/bin/g++ 1
EOF

# Download noVNC
ARG NOVNC_VERSION=v1.7.0
ARG NOVNC_TARBALL_URL=https://github.com/novnc/noVNC/archive/${NOVNC_VERSION}.tar.gz
ARG NOVNC_TARBALL_CHECKSUM=b1003a11b6e6e8d8f7f5e5586daae7f8ca651d8aee0aa155ff9ac841c48f52c6
RUN <<-EOF
	curl -Lo /tmp/novnc.tgz "${NOVNC_TARBALL_URL:?}"
	printf '%s' "${NOVNC_TARBALL_CHECKSUM:?}  /tmp/novnc.tgz" | sha256sum -c
	mkdir /tmp/novnc/ && tar -xzf /tmp/novnc.tgz --strip-components=1 -C /tmp/novnc/
EOF

# Download Websockify
ARG WEBSOCKIFY_VERSION=v0.13.0
ARG WEBSOCKIFY_TARBALL_URL=https://github.com/novnc/websockify/archive/${WEBSOCKIFY_VERSION}.tar.gz
ARG WEBSOCKIFY_TARBALL_CHECKSUM=b6413e364efd04f3c92ec8c17747e3c4adc20157c2ef1c5d019a26d944a46df8
RUN <<-EOF
	curl -Lo /tmp/websockify.tgz "${WEBSOCKIFY_TARBALL_URL:?}"
	printf '%s' "${WEBSOCKIFY_TARBALL_CHECKSUM:?}  /tmp/websockify.tgz" | sha256sum -c
	mkdir /tmp/websockify/ && tar -xzf /tmp/websockify.tgz --strip-components=1 -C /tmp/websockify/
EOF

# Build Haiku
ARG HAIKU_TREEISH=r1beta6
ARG HAIKU_REMOTE=https://review.haiku-os.org/haiku.git
ARG BUILDTOOLS_TREEISH=${HAIKU_TREEISH}
ARG BUILDTOOLS_REMOTE=https://review.haiku-os.org/buildtools.git
WORKDIR /tmp/buildtools/
RUN <<-EOF
	git clone --depth 1 --revision="${BUILDTOOLS_TREEISH:?}" --recurse-submodules --shallow-submodules "${BUILDTOOLS_REMOTE:?}" ./
EOF
WORKDIR /tmp/buildtools/jam/
RUN <<-EOF
	make -j"$(nproc)"
	./jam0 install
EOF
WORKDIR /tmp/haiku/
RUN <<-EOF
	git clone "${HAIKU_REMOTE:?}" ./
	git checkout "${HAIKU_TREEISH:?}"
	git submodule update --init --recursive
EOF
RUN --mount=type=bind,source=./patches/haiku/,target=/tmp/patches/haiku/ <<-EOF
	git apply -v /tmp/patches/haiku/*.patch
EOF
RUN <<-EOF
	./configure \
		--distro-compatibility official \
		--cross-tools-source /tmp/buildtools/ \
		--build-cross-tools x86_64 \
		--use-gcc-pipe \
		-j"$(nproc)"
EOF
COPY --chown=root:root --chmod=0755 ./scripts/vm-first-login/ /tmp/haiku/data/system/boot/first_login/
RUN <<-EOF
	export HAIKU_IMAGE_SIZE=131072
	jam -qj"$(nproc)" '@release-raw'
	qemu-img convert -f raw -O qcow2 ./generated/haiku-release.image ./generated/haiku.qcow2
	rm -f ./generated/haiku-release.image
EOF
RUN <<-EOF
	timeout 3600 qemu-system-x86_64 \
		-machine q35 -smp 2 -m 512M -accel tcg,thread=single \
		-device VGA -display none -serial stdio \
		-device e1000,netdev=n0 -netdev user,id=n0,ipv4=on,ipv6=off,net=10.0.2.0/24,host=10.0.2.2,dns=10.0.2.3,dhcpstart=10.0.2.15 \
		-device ide-hd,id=disk0,bus=ide.0,drive=disk0 -blockdev driver=qcow2,node-name=disk0,file.driver=file,file.filename=./generated/haiku.qcow2
EOF

##################################################
## "base" stage
##################################################

m4_ifdef([[CROSS_ARCH]], [[FROM docker.io/CROSS_ARCH/ubuntu:26.04]], [[FROM docker.io/ubuntu:26.04]]) AS base

SHELL ["/bin/sh", "-euc"]

# Install system packages
RUN <<-EOF
	export DEBIAN_FRONTEND=noninteractive
	apt-get update
	apt-get install -y --no-install-recommends \
		catatonit \
		net-tools \
		netcat-openbsd \
		openssh-client \
		procps \
		python3 \
		qemu-system-x86 \
		qemu-utils \
		runit
	rm -rf /var/lib/apt/lists/*
EOF

# Environment
ENV VM_CPU=2
ENV VM_RAM=2048M
ENV VM_KEYBOARD=en-us
ENV VM_NET_EXTRA_OPTIONS=
ENV VM_KVM=true
ENV SVDIR=/etc/service/
ENV SVWAIT=20

# Copy noVNC
COPY --from=build --chown=root:root /tmp/novnc/ /opt/novnc/

# Copy Websockify
COPY --from=build --chown=root:root /tmp/websockify/ /opt/novnc/utils/websockify/

# Copy Haiku disk
COPY --from=build --chown=root:root /tmp/haiku/generated/haiku.qcow2 /var/lib/qemu/disk/haiku.qcow2

# Copy SSH config
COPY --chown=root:root --chmod=a+rX,u+w,go-w ./config/ssh/ /etc/ssh/

# Copy services
COPY --chown=root:root --chmod=0755 ./scripts/service/ /etc/service/

# Copy bin scripts
COPY --chown=root:root --chmod=0755 ./scripts/bin/ /usr/local/bin/

# Copy net init scripts
COPY --chown=root:root --chmod=0755 ./scripts/vm-net-init/ /etc/vm-net-init/

ENTRYPOINT ["/usr/bin/catatonit", "--", "/usr/local/bin/container-init"]

##################################################
## "test" stage
##################################################

FROM base AS test

ARG BUILDARCH
ARG TARGETARCH
RUN <<-EOF
	if [ "${BUILDARCH:?}" = "${TARGETARCH:?}" ]; then
		container-init &
		printf '%s\n' 'The quick brown fox jumps over the lazy dog' > /tmp/in || exit 1
		cat /tmp/in | timeout 900 vmshell 'cat - > /tmp/local; uname -a' || exit 1
		scp vm:/tmp/local /tmp/out || exit 1
		cmp -s /tmp/in /tmp/out || exit 1
	fi
EOF

##################################################
## "main" stage
##################################################

FROM base AS main

# Dummy instruction so BuildKit does not skip the test stage
RUN --mount=type=bind,from=test,source=/mnt/,target=/mnt/
