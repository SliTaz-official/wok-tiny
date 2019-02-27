plugin="Password"
description_fr="Ajoute un mot de passe &agrave; une page avec {PASSWORD=code}"
description="Add a password to a page with {PASSWORD=something}"
   
pagepass_hash()
{
	echo $1 | md5sum | cut -c1-8
}

init()
{
	if grep -qs '{HASHPASSWORD=' $1; then
		case "$(GET action)" in
			pagepass|'') return ;;
		esac
		hash="$(sed '/{HASHPASSWORD=.*}/!d;s/.*{HASHPASSWORD=\([^}]*\)}.*/\1/;q' <$1)"
		cookie="pagepass$(pagepass_hash $PWD$PAGE_txt)"
		[ "$(COOKIE $cookie)" = "$hash" ] && return
		header
		echo "<script> history.go(-1); </script>"
		exit 0
	fi
}

action()
{
	[ "$1" = "pagepass" ] || return 1
	uri="$SCRIPT_NAME?page=$(POST page)&auth=$(POST auth)"
	if [ "$(pagepass_hash $(POST pass))" = "$(POST hash)" ]; then
		header  "HTTP/1.0 302 Found" \
			"location: $uri" \
			"Set-Cookie: $(POST cookie)=$(POST hash)"
##			"Set-Cookie: $(POST cookie)=$(POST hash); Max-Age=3600; Path=$(dirname $SCRIPT_NAME); HttpOnly"
	else
		header  "HTTP/1.0 302 Found" \
			"location: $uri&error=1"
	fi
	exit 0
}

formatBegin()
{
	hash="$(sed '/{HASHPASSWORD=.*}/!d;s/.*{HASHPASSWORD=\([^}]*\)}.*/\1/;q' <<EOT
$CONTENT
EOT
)"
	cookie="pagepass$(pagepass_hash $PWD$PAGE_txt)"
	if [ "$(COOKIE $cookie)" != "$hash" ]; then
		editable=false
		CONTENT="<form method=\"post\" action=\"?action=pagepass\">
<input type=\"hidden\" name=\"page\" value=\"$(GET page)\" /> \
<input type=\"hidden\" name=\"auth\" value=\"$(GET auth)\" /> \
<input type=\"hidden\" name=\"hash\" value=\"$hash\" /> \
<input type=\"hidden\" name=\"cookie\" value=\"$cookie\" /> \
$MDP <input type=\"text\" name=\"pass\" /> \
<input type=\"submit\" value=\"$DONE_BUTTON\" />
</form>"
	else
		CONTENT="$(sed 's/{HASHPASSWORD=[^}]*}//' <<EOT
$CONTENT
EOT
)"
	fi
}

pagepass_sedexpr()
{
	sed '/{PASSWORD=.*}/!d;s/.*{PASSWORD=\([^}]*\)}.*/\1/' $1 | \
	while read pass; do
		echo -n "-e 's|{PASSWORD=$pass|{HASHPASSWORD=$(pagepass_hash $pass)|' "
	done
	echo -n "-e 's|{PASSWORD=}||' "
}

writedPage()
{
	eval sed -i $(pagepass_sedexpr $1) $1 $BACKUP_DIR$PAGE_TITLE/\*.bak
}
