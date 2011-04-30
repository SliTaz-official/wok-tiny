#!/bin/sh

. /usr/bin/httpd_helper.sh

cpu()
{
grep '^model name' /proc/cpuinfo | head -n 1 | \
sed -e 's/.*Intel(R) //' -e 's/.*AMD //' -e 's/.*: //' \
    -e 's/@//' -e 's/(R)//' -e 's/(TM)//' -e 's/CPU //' -e 's/Processor //'
}

header

cat <<EOT
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
	"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="fr" lang="fr">
<head>
	<title>status tiny server $(hostname) - $HTTP_HOST
	</title>
	<meta http-equiv="content-type" content="text/html; charset=ISO-8859-1" />
	<meta name="description" content="Tiny server manager" />
	<meta name="expires" content="never" />
	<meta name="modified" content="2008-03-05 16:33:00" />
	<link rel="shortcut icon" href="css/favicon.ico" />
	<link rel="stylesheet" type="text/css" href="css/slitaz.css" />
</head>
<body bgcolor="#ffffff">
<div id="header">
	<a name="top"></a>
<!-- Access -->
<div id="access">
$([ -d /var/www/wiki ] && echo "<a href="/wiki/index.sh" title="Wiki">Wiki</a> |")
$([ -n "$GET__NAMES" ] && echo "<a href="$SCRIPT_NAME" title="Status">Status</a> |")
	<a href="adm/index.sh?/sbin/poweroff" title="Poweroff">Power down</a> |
	<a href="adm/index.sh?/sbin/reboot" title="Reboot">Reboot</a>
</div>
	<a href="http://www.slitaz.org/"><img id="logo"
	   src="css/pics/website/logo.png" title="www.slitaz.org"
	   alt="www.slitaz.org"
	   style="border: 0px solid ; width: 200px; height: 74px;" /></a>
	<p id="titre">#!/tinyserver/status</p>
	
</div>
<!-- Navigation menu -->
<div id="nav">

<div class="nav_box">
<h4>Services</h4>

<!-- Start content -->
<table>
EOT

for svr in $( . ../../etc/rcS.conf ; cd /usr/sbin ; ls pppd 2> /dev/null ; echo $RUN_DAEMONS | sed 's/ /\n/g' | sort) ; do
	status="<td>$svr</td><td><a href=\"adm/index.sh?stop=$svr\">stop</a></td><td><a href=\"adm/index.sh?restart=$svr\">restart</a></td>"
	grep -vs ^\# /etc/inetd.conf | grep -q $(which $svr) &&
	[ -n "$(ps | grep -v grep | grep /usr/sbin/inetd)" ] ||
	[ -n "$(ps | grep -v grep | grep $(which $svr) )" ] || 
	status="<td><strike>$svr</strike></td><td><a href=\"adm/index.sh?start=$svr\">start</a></td><td></td>"
	case "$svr" in
	pppd)	info="<td><a href=\"$SCRIPT_NAME?show=/etc/ppp/scripts/ppp-on,/etc/ppp/scripts/ppp-on-dialer,/etc/ppp/options\">scripts</a></td>";;
	tftpd)	info="<td><a href=\"$SCRIPT_NAME?list=/boot\">files</a></td>";;
	ftpd)	info="<td><a href=\"$SCRIPT_NAME?list=/var/ftp\">files</a></td>";;
	udhcpd)	info="<td><a href=\"$SCRIPT_NAME?leases\">leases</a></td>";;
	httpd)	info="<td><a href=\"$SCRIPT_NAME?httpinfo\">info</a></td>";;
	*)	info="<td></td>";;
	esac
	echo -e "	<tr>\n	$status$info\n	</tr>"
done 
cat <<EOT
</table>
</div>

<div class="nav_box">
<h4>Log files</h4>
<table>
EOT
for i in $(ls /var/log); do
	case "$i" in
	boot-time|wtmp) continue;;
	esac
	cat <<EOT
<tr>
<td><a href="$SCRIPT_NAME?show=/var/log/$i" title="Show file /var/log/$i">
$i</a></td><td>$(du -h /var/log/$i | cut -f1)</td>
</tr>
EOT
done
cat <<EOT
</table>
</div>

<div class="nav_box">
<h4>Configuration files</h4>
<table>
EOT
for i in $(cd /etc ; ls *.conf); do
	cat <<EOT
<tr>
<td><a href="$SCRIPT_NAME?show=/etc/$i" title="Show file /etc/$i">
$i</a></td><td>$(du -h /etc/$i | cut -f1)</td>
</tr>
EOT
done
cat <<EOT
</table>
</div>

</div>

<div id="content">
<h4>$(date) - $(hostname) - $(cpu) - $HTTP_HOST</h4>
EOT
case "$GET__NAMES" in
show)	for i in $(GET show | sed 's/,/ /g'); do
		cat <<EOT
<h2>File $i</h2>
<pre>
EOT
		case "$i" in
		/etc/ppp*)	cat $i ;;
		*boot.log)	sed -e s'/\[^Gm]*.//g' \
		    -e ':a;s/^\(.\{1,68\}\)\(\[ [A-Za-z]* \]\)/\1 \2/;ta' $i ;;
		*)		su -c "cat $i" tux ;;
		esac
		cat <<EOT
</pre>
EOT
	done
	;;
list)	cat <<EOT
<h2>Files in $(GET list)</h2>
<pre>
$( su -c "cd $(GET list) && find * | xargs ls -ld" tux )
</pre>
EOT
	;;
leases) cat <<EOT
<h2>DHCP Leases</h2>
<pre>
$(cat /var/lib/misc/udhcpd.leases)
</pre>
EOT
	;;
httpinfo) cat <<EOT
<h2>HTTP Infos</h2>
<pre>
$(httpinfo)
</pre>
EOT
	;;
*) cat <<EOT
<a name="disk"></a>
<h2>Disk usage</h2>
<pre>
$(df -h | sed '/^rootfs/d' | grep  '\(^/dev\|Filesystem\)')
</pre>
<a name="network"></a>
<h2>Network</h2>
<h3>Interfaces</h3>
<pre>
$(ifconfig)
</pre>
<h3>Routing table</h3>
<pre>
$(route)
</pre>
<h3>Connexions</h3>
<pre>
$(netstat -ap)
</pre>
EOT
	[ -f /proc/net/ip_conntrack ] && cat <<EOT
<h3>Active connexions</h3>
<pre>
$(cat /proc/net/ip_conntrack)
</pre>
EOT
	cat <<EOT
<h3>Arp table</h3>
<pre>
$(arp)
</pre>
<a name="processes"></a>
<h2>Processes</h2>
<h3>Memory</h3>
<pre>
$(free)
</pre>
<h3>Process list</h3>
<pre>
Uptime $(uptime | sed 's/^\s*//')
</pre>
<pre>
$(top -n1 -b)
</pre>
<a name="boot"></a>
<h2>Boot command args</h2>
<pre>
$(cat /proc/cmdline)
</pre>
<a name="users"></a>
<h2>Users</h2>
<pre>
$(last)
</pre>
EOT
	;;
esac

cat <<EOT
</div>
<!-- End content -->
<!-- Start of footer and copy notice -->
<div id="copy">
<p>
Copyright © $(date +%Y) <a href="http://www.slitaz.org/">SliTaz</a> -

<a href="http://www.gnu.org/licenses/gpl.html">GNU General Public License</a>
</p>
<!-- End of copy -->
</div>

</body>
</html>
EOT
