plugin="<a href=\"?action=upload\" title=\"Upload a file\">Upload</a>"
description_fr="Télécharge des fichiers complémentaires (ex: images)"
description="Upload page extra files (ex: images)"
      
case "$LANG" in
fr) UPLOAD="Chargement" ;;
*)  UPLOAD="Upload" ;;
esac

template()
{
	case "$(GET action)" in
	edit)	UPLOAD="<a href=\"$urlbase?action=upload\">$UPLOAD</a>"
		html="$(sed "s|HISTORY|$(sedesc "$UPLOAD") / HISTORY|" <<EOT
$html
EOT
)" ;;
	upload*) html="$(sed 's| / <a href.*recent.*</a>||;s|.*name="query".*||' <<EOT
$html
EOT
)" ;;
	*)	return 1 ;;
	esac
	return 0
}

action()
{
	case "$1" in
	upload) CONTENT="$(cat <<EOT
<form method="post" enctype="multipart/form-data" action="?action=uploadfile">
<input type="file" name="file" value="file"/>
<input type="submit"/>
<table>
EOT
		for i in pages/data/* ; do
			[ -e $i ] || continue
			echo -n "<tr><td><input type=checkbox "
			grep -qs "$i" pages/*.txt &&  echo "checked=checked "
			echo "disabled=disabled /><a href="$i">$(basename $i)</a></td></tr>"
		done
		cat <<EOT
</table>
</form>
EOT
)"
		PAGE_TITLE_link=false
		editable=false
		lang="${HTTP_ACCEPT_LANGUAGE%%[,;_-]*}"
		PAGE_TITLE="$UPLOAD" ;;
	uploadfile)
		mkdir -p pages/data 2> /dev/null
		name=$(FILE file name)
		if [ -z "$name" ]; then
			CONTENT="<script> history.go(-2); </script>"
			return 1
		fi
		n=''
		while [ -e pages/data/$n$name ]; do
			n=$(($n+1))
		done
		filesize=$(stat -c "%s" $(FILE file tmpname))
		ls pages/data | while read file; do
			stat -c "%s %n" pages/data/$file
		done | while read size file; do
			[ $filesize = $size ] && 
			cmp $(FILE file tmpname) $file > /dev/null &&
			ln -s $(basename $file) pages/data/$n$name && break
		done
		if [ -L pages/data/$n$name ]; then
			n=pages/data/$n$name
			name="$(readlink $n)"
			rm -f $n
			n=""
		else
			mv $(FILE file tmpname) pages/data/$n$name
		fi
		rm -rf $(dirname $(FILE file tmpname) )
		URL=pages/data/$n$name
		PAGE_TITLE_link=false
		editable=false
		PAGE_TITLE="$UPLOAD"
		CONTENT="$(cat <<EOT
<h1><a href="javascript:history.go(-2)">$EDIT_BUTTON</a></h1>
<p>
The file $(FILE file name) ($(FILE file size) bytes, $(FILE file type)) is
stored at <a href="$URL">$URL</a>.
</p>
EOT
)"
		case "$(FILE file type)" in
		image*) CONTENT="$(cat <<EOT
$CONTENT
<p>
You can insert this image with <b>[$URL]</b> see
<a href="?page=$HELP_BUTTON">$HELP_BUTTON</a> for details
</p>
<img src="$URL" alt="$URL" />
EOT
)"
		esac ;;
	*)	return 1 ;;
	esac
	return 0
}

formatEnd()
{
	CONTENT="$(sed 's|href="[^"]*page=pages/data/|href="pages/data/|g' <<EOT
$CONTENT
EOT
)"
}
