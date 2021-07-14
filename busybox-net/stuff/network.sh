#!/bin/sh
# /etc/init.d/network.sh - Network initialization boot script.
# Config file is: /etc/network.conf
#
. /etc/init.d/rc.functions
. /etc/network.conf

# Stopping everything
Stop() {
	echo "Stopping all interfaces"
	ifconfig $INTERFACE down

	echo "Killing all daemons"
	killall udhcpc

}

Start() {
	ifconfig $INTERFACE up
	if [ "$DHCP" = "yes" ] ; then
		echo "Starting udhcpc client on: $INTERFACE..."
		udhcpc -b -T 1 -A 12 -i $INTERFACE -p \
		/var/run/udhcpc.$INTERFACE.pid
	fi
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

# looking for arguments:
case $1 in
'')
	ifconfig lo 127.0.0.1 up
	route add 127.0.0.1 lo
	Start ;;
start)
	Start ;;
stop)
	Stop ;;
restart)
	Stop
	Start ;;
esac
