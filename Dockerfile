# Tox network node
FROM alpine:latest
LABEL Description="This image is used to run Tox network node" Vendor="n/a" Version="0.0.0"

# Tox core code and nodes config download
ADD https://github.com/irungentoo/toxcore/archive/master.zip https://tox.0x10k.com/bootstrapd-conf-ipv64.txt /tmp/tox/

WORKDIR /tmp/tox

RUN set -x && \
# Disable root
	sed -i 's/^root::/root:!:/' /etc/shadow && \
# Add tox user and group, create home directory
	addgroup -S tox-bootstrapd && \
	adduser -h /var/lib/tox-bootstrapd -g "Account to run Tox's DHT bootstrap daemon" -s /sbin/nologin -G tox-bootstrapd -S -D -H tox-bootstrapd && \
	install -d -o tox-bootstrapd -g tox-bootstrapd -m 700 /var/lib/tox-bootstrapd && \
	function su_wrapper () { su -s /bin/sh -c "$@" tox-bootstrapd; return $?; } && \
# Install libs and build tools
	apk --no-cache add libsodium libconfig && \
	apk --no-cache add --virtual build-dependencies \
	autoconf \
	automake \
	check-dev \
	curl \
	build-base \
	libtool \
	libconfig-dev \
	libsodium-dev \
	libvpx-dev \
	linux-headers \
	opus-dev \
	unzip && \
# Unzip
	chown tox-bootstrapd:tox-bootstrapd /tmp/tox && \
	chmod 644 /tmp/tox/master.zip && \
	su_wrapper "unzip -tq master.zip" && \
	su_wrapper "unzip -aq master.zip" && \
# Compile
	cd toxcore-master && \
	su_wrapper "./autogen.sh" && \
	su_wrapper "./configure --prefix=/usr --enable-daemon --disable-av --disable-ntox" && \
	su_wrapper "make" && \
# Run tests (they FAIL mostly if you don't have enough compute resources)
#	for i in $(seq 1 10); do echo "=== check attempt $i ==="; su_wrapper "make check"; ret=$?; echo "=== check returned $ret ==="; if [ $ret -eq 0 ]; then echo "=== check passed ==="; break; elif [ $i -eq 10 ]; then echo "=== too many failures, aborting ==="; exit 1; fi; done && \
#
# Install tox daemon and copy base network node configuration file
	make install && \
	install -o root -g root -m 644 other/bootstrap_daemon/tox-bootstrapd.conf /etc/tox-bootstrapd.conf && \
# Remove all the example bootstrap nodes from the config file and add nodes to bootstrap from
	sed -i '/^bootstrap_nodes = /,$d' /etc/tox-bootstrapd.conf && \
	cat /tmp/tox/bootstrapd-conf-ipv64.txt >> /etc/tox-bootstrapd.conf && \
# Clean build dependencies and build files
	cd / && \
	rm -rf /tmp/tox && \
	apk del build-dependencies && \
# Tox network node daemon configuration
# Disable LAN discovery, because we are on a server
	sed -i 's/enable_lan_discovery = true/enable_lan_discovery = false/' /etc/tox-bootstrapd.conf && \
# Modify relay ports, 443/tcp is often already in use
	sed -i 's/tcp_relay_ports = \[443, 3389, 33445\]/tcp_relay_ports = \[8080, 33445\]/' /etc/tox-bootstrapd.conf && \
# MOTD
	sed -i 's/motd = "tox-bootstrapd"/motd = "tox-bootstrapd docker"/' /etc/tox-bootstrapd.conf


# Tox daemon home directory
WORKDIR /var/lib/tox-bootstrapd

# Ports
EXPOSE 33445/tcp 33445/udp 8080/tcp 8080/udp

# Run cmd
#CMD ["/bin/bash"]
USER tox-bootstrapd
CMD ["/usr/bin/tox-bootstrapd", "--config=/etc/tox-bootstrapd.conf", "--foreground", "--log-backend=stdout"]
