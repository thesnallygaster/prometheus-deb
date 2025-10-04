#!/bin/bash

PROMETHEUS_VERSION="3.5.0"
DEB_REVISION="4"
ARCHITECTURE="$(dpkg --print-architecture)"

GO_VERSION="1.25.1"
NODE_VERSION="22.20.0"
NPM_VERSION="10.9.4"

if [ "${DISTRO}" == "debian" ]; then
cat << EOF > /etc/apt/sources.list.d/debian.sources
Types: deb
URIs: http://ftp.pl.debian.org/debian
Suites: ${SUITE} ${SUITE}-updates
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: http://security.debian.org/debian-security
Suites: ${SUITE}-security
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF
elif [ "${DISTRO}" == "ubuntu" ] && [ "${PLATFORM}" == "amd64" ]; then
cat << EOF > /etc/apt/sources.list.d/ubuntu.sources
Types: deb
URIs: http://archive.ubuntu.com/ubuntu
Suites: ${SUITE} ${SUITE}-updates
Components: main universe
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: http://archive.ubuntu.com/ubuntu
Suites: ${SUITE}-security
Components: main
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF
elif [ "${DISTRO}" == "ubuntu" ] && [[ "${PLATFORM}" == *"arm"* ]]; then
cat << EOF > /etc/apt/sources.list.d/ubuntu.sources
Types: deb
URIs: http://ports.ubuntu.com/ubuntu-ports
Suites: ${SUITE} ${SUITE}-updates
Components: main universe
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: http://ports.ubuntu.com/ubuntu-ports
Suites: ${SUITE}-security
Components: main
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF
fi

if [ -n "${APT_PROXY_URL}" ]; then
	echo "Acquire::http { Proxy \"${APT_PROXY_URL}\"; }" > /etc/apt/apt.conf.d/01proxy
fi

apt update
apt upgrade -y
apt install -y --no-install-recommends \
	ca-certificates \
	curl \
	xz-utils \
	bzip2 \
	zstd \
	make \
	git \
	tree

mkdir -p /work
cd /work
curl -LO https://go.dev/dl/go"${GO_VERSION}".linux-"${PLATFORM}".tar.gz
tar -C /usr/local -xzf go"${GO_VERSION}".linux-"${PLATFORM}".tar.gz
export PATH="/usr/local/go/bin:${PATH}"

mkdir -p /work
cd /work
if [ "${PLATFORM}" == "amd64" ]; then
    NODE_PLATFORM="x64"
else
    NODE_PLATFORM="${PLATFORM}"
fi
curl -LO https://nodejs.org/dist/v"${NODE_VERSION}"/node-v"${NODE_VERSION}"-linux-"${NODE_PLATFORM}".tar.xz
tar -C /usr/local -xf node-v"${NODE_VERSION}"-linux-"${NODE_PLATFORM}".tar.xz
export PATH="/usr/local/node-v${NODE_VERSION}-linux-${NODE_PLATFORM}/bin:${PATH}"

npm install -g npm@"${NPM_VERSION}"

mkdir -p /build
cd /build
curl -LO https://github.com/prometheus/prometheus/archive/refs/tags/v"${PROMETHEUS_VERSION}".tar.gz
tar -xzf v"${PROMETHEUS_VERSION}".tar.gz
cd prometheus-"${PROMETHEUS_VERSION}"
make build
mkdir -p /build/destdir/usr/bin \
	/build/destdir/etc/prometheus
install -Dm 755 prometheus /build/destdir/usr/bin/prometheus
install -Dm 755 promtool /build/destdir/usr/bin/promtool
install -Dm 644 /distrib/config.yml /build/destdir/etc/prometheus/config.yml
tree /build/destdir
 
cd /build
 apt install -y --no-install-recommends \
 	build-essential \
 	ruby-rubygems \
 	openssh-client
 gem install fpm
 cd destdir
 fpm -a native -s dir -t deb -p ../prometheus_"${PROMETHEUS_VERSION}"-"${DEB_REVISION}"\~"${SUITE}"_"${ARCHITECTURE}".deb --name prometheus --version "${PROMETHEUS_VERSION}" --iteration "${DEB_REVISION}" --deb-compression zst --after-install /distrib/postinst --after-remove /distrib/postrm --deb-systemd /distrib/prometheus.service --deb-systemd-auto-start --deb-systemd-enable --description "Description=monitoring system and time series database" --url "https://prometheus.io" --maintainer "Damian Duży <dame@zakonfeniksa.org>" .
