plugin="<a href=\"?action=admin\" title=\"Wiki administration\">Administration</a>"
description_fr="Administration du Wiki"
description="Wiki administration"
      
admin_enable()
{
	[ -n "$(POST $1)" ] || return
	chmod 444 $4/$2*
	for i in $(POST); do
		case "$i" in $3*) chmod 755 $4/${i/$3/$2}.* ;; esac
	done
}

admin_download()
{
	cat - $1 <<EOT
Content-Type: application/octet-stream
Content-Length: $(stat -c %s $1)
Content-Disposition: attachment; filename=${2:-$1}

EOT
}

action()
{
	case "$1" in
	list|config|admin);;
	backup)	file=$(FILE file tmpname)
		if [ -z "$file" ]; then
			file=$(mktemp -p /tmp)
			find */ | cpio -o -H newc | gzip -9 > $file
			admin_download $file wiki-$(date '+%Y%m%d%H%M').cpio.gz
			rm -f $file
			exit 0
		else
			zcat $file | cpio -idmu $(echo */ | sed 's|/||g')
			rm -rf $(dirname $file)
			return 1
		fi ;;
	*)	return 1 ;;
	esac
	PAGE_TITLE_link=false
	editable=false
	lang="${HTTP_ACCEPT_LANGUAGE%%[,;_-]*}"
	PAGE_TITLE="Administration"
	curpass="$(POST curpass)"
	secret="admin.secret"
	if [ -n "$(POST setpass)" ]; then
		if [ -z "$curpass" ]; then	# unauthorized
			if [ ! -s $secret -o "$(cat $secret 2> /dev/null)" == \
				  "$(echo $(POST password) | md5sum)" ]; then
				curpass="$(POST password)"
			fi
		fi
		[ -n "$curpass" ] && echo $curpass | md5sum > $secret &&
		chmod 400 $secret
	fi
	if [ -n "$(POST save)" ]; then
		admin_download $(POST file)
		exit 0
	fi
	[ -n "$(POST restore)" ] && mv -f $(FILE data tmpname) $(POST file)
	admin_enable Locales config- config_ .
	admin_enable Plugins wkp_ wkp_ plugins
	admin_enable Pages '' page pages
	disabled="disabled=disabled"
	[ -n "$curpass" ] && disabled="" && 
	curpass="<input type=\"hidden\" name=\"curpass\" value=\"$curpass\" />
"
	hr="$curpass<tr><td colspan=2><hr /></td><tr />"
	CONTENT="
<table width=\"100%\">
<form method=\"post\" action=\"?action=admin\">
<tr><td><h2>$MDP</h2></td>
<td><input type=\"text\" name=\"password\" />$curpass
<input type=\"submit\" value=\"$DONE_BUTTON\" name=\"setpass\" /></td></tr>
</form>
"
	mform="form method=\"post\" enctype=\"multipart/form-data\" action=\"?action"
	while read section files test; do
		CONTENT="$CONTENT
<$mform=admin\">
$hr
<tr><td><h2>$section</h2></td>
<td><input type=\"submit\" $disabled value=\"$DONE_BUTTON\" name=\"$section\" /></td></tr>
"
		for i in $files ; do
			case "$section" in
			Plugins)
				plugin=
				eval $(grep ^plugin= $i)
				[ -n "$plugin" ] || continue
				eval $(grep ^description= $i)
				alt="$(grep ^description_$lang= $i)"
				[ -n "$alt" ] && eval $(echo "$alt" | sed 's/_..=/=/')
				help=
				eval $(grep ^help= $i)
				alt="$(grep ^help_$lang= $i)"
				[ -n "$alt" ] && eval $(echo "$alt" | sed 's/_..=/=/')
				name="$(basename $i .sh)"
				[ -n "$help" ] && description=" <a href='?page=$help' title='$plugin help page'>$description</a>"
				;;
			Locales)
				j=${i#config-}
				j=${j%.sh}
				[ -n "$j" ] || continue
				name="config_$j"
				plugin="$j"
				description="$(. ./$i ; echo $WIKI_TITLE)"
				;;
			Pages)
				j="$(basename $i .txt)"
				plugin="<a href=\"?page=$j\">$j</a>"
				name="page$j"
				description="$([ -w $i ] || echo -n $PROTECTED_BUTTON)"
				;;
			esac
			CONTENT="$CONTENT
<tr><td><b>
<input type=checkbox $disabled $([ $test $i ] && echo 'checked=checked ') name=\"$name\" />
$plugin</b></td><td><i>$description</i></td></tr>"
		done
		CONTENT="$CONTENT</form>"
	done <<EOT
Plugins	$plugins_dir/*.sh	-x
Locales	config-*.sh		-x
Pages	pages/*.txt		-w
EOT
	CONTENT="$CONTENT
<$mform=admin\">
$hr
<tr><td><h2>Configuration</h2></td>
<td><select name="file" $disabled>
$(for i in template.html style.css config*.sh; do
  [ -x $i ] && echo "<option>$i</option>"; done)
</select>
<input type=\"submit\" $disabled value=\"$DONE_BUTTON\" name=\"save\" />
<input type=\"file\" $disabled name=\"data\" />
<input type=\"submit\" $disabled value=\"$RESTORE\" name=\"restore\" /></td></tr>
</form>
<$mform=backup\">
$hr
<tr><td><h2>Data</h2></td>
<td><input type=\"submit\" $disabled name=\"save\" value=\"$DONE_BUTTON\" />
<input type=\"file\" $disabled name=\"file\" value=\"file\" />
<input type=\"submit\" $disabled name=\"restore\" value=\"$RESTORE\" />
</td></tr>
$(du -hs */ | sed 's|\(.*\)\t\(.*\)|<tr><td><b>\1</b></td><td><i>\2</i></td></tr>|')
</form>
</table>
"
}
