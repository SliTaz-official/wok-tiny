#!/bin/sh
# /etc/init.d/network.sh - Network initialization boot script.
# Config file is: /etc/network.conf
#
. /etc/init.d/rc.functions

if [ -z "$2" ]; then
	. /etc/network.conf
else
	. $2
fi

boot() {
	# Set hostname.
	echo -n "Setting hostname..."
	hostname -F /etc/hostname
	status

	# Configure loopback interface.
	echo -n "Configuring loopback..."
	ifconfig lo 127.0.0.1 up
	route add 127.0.0.1 lo
	status
}

# Use ethernet
eth() {
	ifconfig $INTERFACE up
}

# For a dynamic IP with DHCP.
dhcp() {
	if [ "$DHCP" = "yes" ]  ; then
		echo "Starting udhcpc client on: $INTERFACE..."
		udhcpc -b -T 1 -A 12 -i $INTERFACE -p \
			/var/run/udhcpc.$INTERFACE.pid
	fi
}

# For a static IP.
static_ip() {
	if [ "$STATIC" = "yes" ] ; then
		echo "Configuring static IP on $INTERFACE: $IP..."
		ifconfig $INTERFACE $IP netmask $NETMASK up
		route add default gateway $GATEWAY
		# Multi-DNS server in $DNS_SERVER.
		mv /etc/resolv.conf /tmp/resolv.conf.$$
		for NS in $DNS_SERVER
		do
			echo "nameserver $NS" >> /etc/resolv.conf
		done
		for HELPER in /etc/ipup.d/*; do
			[ -x $HELPER ] && $HELPER $INTERFACE $DNS_SERVER
		done
	fi
}

# Stopping everything
Stop() {
	echo "Stopping all interfaces"
	ifconfig $INTERFACE down

	echo "Killing all daemons"
	killall udhcpc
}

Start() {
   eth
   dhcp
   static_ip
}

# looking for arguments:
if [ -z "$1" ]; then
	boot
	Start
else
	case $1 in
		start)
			Start ;;
		stop)
			Stop ;;
		restart)
			Stop
			Start ;;
		*)
			echo ""
			echo -e "\033[1mUsage:\033[0m /etc/init.d/`basename $0` [start|stop|restart]"
			echo ""
			echo -e "	Default configuration file is \033[1m/etc/network.conf\033[0m"
			echo -e "	You can specify another configuration file in the second argument:"
			echo -e "	\033[1mUsage:\033[0m /etc/init.d/`basename $0` [start|stop|restart] file.conf"
			echo "" ;;
	esac
fi
