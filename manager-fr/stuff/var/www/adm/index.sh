#!/bin/sh

. /usr/bin/httpd_helper.sh

command="$GET__NAMES"
case "$command" in
start|restart|stop) command="/etc/init.d/$(GET $command) $command";;
esac
cat <<EOT
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
	"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="fr" lang="fr">
<head>
	<title>status tiny server $(hostname) - $HTTP_HOST
	</title>
	<meta http-equiv="content-type" content="text/html; charset=ISO-8859-1" />
	<meta HTTP-EQUIV="Refresh" CONTENT="5;URL=/index.sh"> 
	<meta name="description" content="Tiny server manager" />
	<meta name="expires" content="never" />
	<meta name="modified" content="2008-03-05 16:33:00" />
	<link rel="shortcut icon" href="/css/favicon.ico" />
	<link rel="stylesheet" type="text/css" href="/css/slitaz.css" />
</head>
<body bgcolor="#ffffff">
<div id="header">
	<a href="http://www.slitaz.org/"><img id="logo"
	   src="/css/pics/website/logo.png" title="www.slitaz.org"
	   alt="www.slitaz.org"
	   style="border: 0px solid ; width: 200px; height: 74px;" /></a>
	<p id="titre">#!/tinyserver/command</p>
</div>
<div id="content">
<h4>$(date "+%d/%m/%Y %H:%M")</h4>
<h2>$command</h2>
<pre>
$($command)
</pre>
<h4>Commande terminée</h4>
</div>
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
