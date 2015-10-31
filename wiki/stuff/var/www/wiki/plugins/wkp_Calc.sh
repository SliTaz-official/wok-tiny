plugin="Calc"
description_fr="Feuille de calcul au format CSV"
description="CSV format spreadsheet"
help_fr="AideCalc"
help="HelpCalc"

case "$1" in
showhead) cat <<EOT
<!-- Based on http://jsfiddle.net/ondras/hYfN3/ by Ondřej Žára -->
<script type="text/javascript">
<!--
function csv(id,rows,cols) {
    var data = "";
    for (var i=1; i<=rows; i++) {
	for (var j=1; j<=cols; j++) {
            var letter = String.fromCharCode("A".charCodeAt(0)+j-1);
	    data += document.getElementById(id+letter+i).title+';';
	}
	data += "\\n";
    }
    alert(data);
}

function cnt(from,to) {
    return (to.charCodeAt(0) - from.charCodeAt(0) + 1) *
           (parseInt(to.substring(1)) - parseInt(from.substring(1)) + 1)
}

function zone(id,from,to,init,func) {
    var result=init
    for (var l=from.charCodeAt(0);;l++) {
        for (var n=parseInt(from.substring(1));
        	 n <= parseInt(to.substring(1));n++) {
            var e=document.getElementById(id+String.fromCharCode(l)+n)
            result=func(result,parseFloat(e.value))
        }
        if (l == to.charCodeAt(0)) break
    }
    return result;
}

var DATA={};
function buildCalc(id, rows, cols) {
    DATA[id] = {};
    var maths = [ "abs", "acos", "asin", "atan", "atan2", "ceil", "cos", "exp",
		  "floor", "log", "pow", "random", "round", "sin",
		  "tan", "sqrt", "PI", "E" ];
    for (var i=0; v = maths[i]; i++)
	eval("DATA[id]."+v+" = DATA[id]."+v.toUpperCase()+" = Math."+v);
    DATA[id].rand = DATA[id].RAND = Math.random;
    DATA[id].ln   = DATA[id].LN   = Math.log;
    DATA[id].log10= DATA[id].LOG10= function(n){return Math.log(n)/Math.LN10;};
    DATA[id].log2 = DATA[id].LOG2 = function(n){return Math.log(n)/Math.LN2;};
    DATA[id].fact = DATA[id].FACT = 
	function(n){var x=1;while(n>1)x*=n--;return x;};
    DATA[id].fib  = DATA[id].FIB  = 
	function(n){var c=0,p=1;while(n-->0){var x=c;c+=p;p=x};return c;};
    DATA[id].sum  = DATA[id].SUM  =
	function(a,b){return zone(id,a,b,0,function(a,b){return a+b});};
    DATA[id].min  = DATA[id].MIN  =
	function(a,b){return zone(id,a,b,Number.MAX_VALUE,Math.min);};
    DATA[id].max  = DATA[id].MAX  =
	function(a,b){return zone(id,a,b,Number.MIN_VALUE,Math.max);};
    DATA[id].cnt  = DATA[id].CNT  = cnt
    for (var i=0; i<=rows; i++) {
        var row = document.getElementById(id).insertRow(-1);
        for (var j=0; j<=cols && j<=26; j++) {
            var letter = String.fromCharCode("A".charCodeAt(0)+j-1);
	    var cell = row.insertCell(-1);
	    if (i&&j) {
		cell.className = "cellcalc";
		cell.innerHTML = "<input id='"+ id+letter+i +"' class='inputcalc'/>";
	    }
	    else {
		cell.className = "bordercalc";
		cell.title = "Show CSV";
		cell.onclick = function(){csv(id,rows,cols);};
		cell.innerHTML = (i||j) ? i||letter : "&radic;";
	    }
        }
    }
}

function getWidth(s)
{
	var e = document.getElementById("widthcalc");
	e.innerHTML = s;
	return (e.offsetWidth < e.minWidth || s.charAt(0) == "=") ?
		 e.minWidth : e.offsetWidth;
}

function setCell(e, v)
{
    e.style.width = getWidth(v)+"px";
    e.style.textAlign = 
	(isNaN(parseFloat(v)) && v.charAt(0) != "=") ? "left" : "right";
    e.title = v;
}
//-->
</script>
<span id="widthcalc" class="cellcalc" style="visibility:hidden;"></span>
EOT
	exit 0 ;;
showtail) cat <<EOT
<script type="text/javascript">
<!--
var INPUTS=[].slice.call(document.getElementsByClassName("inputcalc"));
INPUTS.forEach(function(elm) {
    elm.onfocus = function(e) {
        e.target.value = e.target.title || "";
    };
    elm.onblur = function(e) {
	setCell(e.target, e.target.value);
        computeAll();
    };
    var calcid = elm.id.substring(0,4), cellid = elm.id.substring(4);
    var getter = function() {
        var value = elm.title || "";
        if (value.charAt(0) == "=")
		with (DATA[calcid]) return eval(value.substring(1));
        else return (value == "" || isNaN(value)) ? value : parseFloat(value);
    };
    Object.defineProperty(DATA[calcid], cellid, {get:getter});
    Object.defineProperty(DATA[calcid], cellid.toLowerCase(), {get:getter});
});
(window.computeAll = function() {
    INPUTS.forEach(function(elm) {
	var calcid = elm.id.substring(0,4), cellid = elm.id.substring(4);
	try { elm.value = DATA[calcid][cellid]; } catch(e) {} });
})();
//-->
</script>
EOT
	exit 0 ;;
esac

formatEnd()
{
CONTENT=$(awk -v prg=$plugins_dir/wkp_$plugin.sh '
function showcalc()
{
	if (lines > 1 && rows > 1) {
		id="C" (100+cnt++)
		print "<noscript><a href=\"http://www.enable-javascript.com/\" target=\"_blank\">Enable javascript to see the spreadsheet " id "</a></noscript>"
		print "<table id=\"" id "\" class=\"tablecalc\"></table>"
		print "<script type=\"text/javascript\">"
		print "<!--"
		print "buildCalc(\"" id "\"," lines "," rows ");"
		for (i = 1; i <= lines; i++) {
			gsub("&lt;","<",line[i])
			for (j = 1; j < split(line[i],tmp,";"); j++) {
				if (tmp[j] == "") continue
				gsub("\"","\\\\\"",tmp[j])
				s = "setCell(document.getElementById(\"" id
				c = substr("ABCDEFGHIJKLMNOPQRSTUVWXYZ",j,1)
				print s c i "\"), \"" tmp[j] "\")";
			}
		}
		print "//-->"
		print "</script>"
	}
	else for (i = 1; i <= lines; i++) print line[i]
	rows = lines = gotcalc = 0
}
{
	if (/;<br \/>$/) {
		gotcalc = 1
		if (!headdone) {
			headdone = 1
			showtail = 1
			system("/bin/sh " prg " showhead")
		}
		line[++lines] = $0
		gsub("&lt;","<",$0)
		i = split($0,tmp,";")-1
		if (lines == 1) rows = i
		if (i != rows) rows = -1
	}
	else {
		if (gotcalc) showcalc()
		print
	}
}
END {
	if (gotcalc) showcalc()
	if (showtail) system("/bin/sh " prg " showtail")
}
' <<EOT
$CONTENT
EOT
)
}

template()
{
	html=$(sed 's|</head>|\t<style type="text/css"> @import "plugins/wkp_Calc.css"; </style>\n&|' <<EOT
$html
EOT
)
}
