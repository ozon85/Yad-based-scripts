#!/bin/bash

function KILLJOBS(){
 jobs >/dev/null;jobs -p|while read K;do kill -s SIGTERM $K;echo "SIGTERM to $K";done
} 
  
function PIDOfLoginctlProcName(){
fPID=`pidof "$1"`
[ -z "$fPID" ]&& return
loginctl session-status|grep -E $(echo $fPID|
		  { read K;echo ${K// /\|}; }) 2>/dev/null|grep -iv grep|tr -cd "[:digit:]\n"; }		 
      
function on_click(){
XneurPID=`PIDOfLoginctlProcName "$CMDstr"`
[ -z "$XneurPID" ]&& XNEURSTART
}

function XNEURSTART(){
  which $CMDstr &>/dev/null||{ notify-send "$CMDstr not found"; return; } 
  "$CMDstr" &>/dev/null &  XneurPID=$!;disown $XneurPID; notify-send "$CMDstr" " run $XneurPID"
}

function XNEURRESTART(){
  which $CMDstr &>/dev/null||{ notify-send "$CMDstr not found"; return; }
  XNEURCLOSE
  XNEURSTART
}

function QUITYAD(){ echo quit >"$PIPE"; }

function XNEURCLOSE(){
   XneurPID=`PIDOfLoginctlProcName "$CMDstr"`
  [ -z "$XneurPID" ]&& return
  #echo "перезапуск xneur (PID=$XneurPID)"
  if kill -s SIGKILL $XneurPID;then
    notify-send "$CMDstr" "ended $XneurPID";
  else
    notify-send "$CMDstr" "NOT ENDED $XneurPID";
  fi
}

function Open_XNEURRC(){
  [ -f ~/.xneur/xneurrc ]||
  cp /etc/xneur/xneurrc ~/.xneur/xneurrc
  [ -f ~/.xneur/xneurrc ]&&xdg-open ~/.xneur/xneurrc; }


#----------------------------------start------------------------------------

CMDstr="xneur"

# поиск раскладок языков
K=`setxkbmap -query|grep layout`;
K=${K// /};K=${K#*:};K=${K//,/ }
Langs=$K;#' fake_lang'
echo Langs:$Langs

# создание трубы для отправки команд yad и удаление временного файла при выходе
PIPE=$(mktemp -u --tmpdir "${0##*/}.XXXXXXXXXX")
function on_script_exit(){ echo 'quit'>"$PIPE";rm -f "$PIPE";KILLJOBS; }
trap on_script_exit EXIT
mkfifo "$PIPE"&& exec 3<>"$PIPE"||{ echo unable mkfifo "$PIPE", exit;exit; }

 # поиск значков флагов
declare -A LangsFlags;
LOCATION='/usr/share/gxneur/pixmaps/'$'\n'\
'/usr/share/kdeneur/pixmaps/'$'\n'\
"$PWD"'/'$'\n'`dirname $0`'/'

NameChars='(\-| |\!|\@|\#|\$|\&|\~|\%|\(|\)|\[|\]|\{|\})*'
LangsNoFlags=$Langs

#echo первичный поиск значка xneur
K='gxneur'$'\n'\
'kdeneur'

for Folder in $LOCATION;do
  FILES=`ls "$Folder" 2>/dev/null`
  if [ -n "$FILES" ];then
    for lang in $K;do
      A=`grep -E "$NameChars$lang$NameChars"'\.(png|svg)$' 2>/dev/null <<<"$FILES"|head -n 1`
      if [ -n "$A" ];then	    
	    XneurIco=$A;break
	  fi
    done
  fi
done

#echo первичный поиск файлов флагов "$LangsNoFlags"
for Folder in $LOCATION;do
  FILES=`ls "$Folder" 2>/dev/null`
  if [ -n "$FILES" ];then
    for lang in $LangsNoFlags;do
      A=`grep -E "$NameChars$lang$NameChars"'\.(png|svg)$' 2>/dev/null <<<"$FILES"|head -n 1`
      if [ -n "$A" ];then
	    LangsFlags[$lang]=$A;
		LangsNoFlags=${LangsNoFlags//$lang/}
	  fi
    done
  fi
done

NoFlags=$LangsNoFlags
LangsNoFlags=''
for A in $NoFlags;do
  LangsNoFlags=$LangsNoFlags$A
done

#echo проверка отсутствующих значков для '!'$LangsNoFlags'!'

if [ -n "$LangsNoFlags" ];then
  echo not founded pin for $LangsNoFlags, try locate
  pinEXP='('"${LangsNoFlags// /\|}"')'
  REGEX_STR_PREFIX='/(\-| |\!|\@|\#|\$|\&|\~|\%|\(|\)|\[|\]|\{|\})*'
  REGEX_STR_SUFIX='((\-| |\!|\@|\#|\$|\&|\~|\%|\(|\)|\[|\]|\{|\})+[^\/]+)*'
  FILES=`locate -e --regex "$REGEX_STR_PREFIX$pinEXP$REGEX_STR_SUFIX\.(png|svg)$" 2>/dev/null|sort`
  if [ -n "$FILES" ];then
    for lang in $LangsNoFlags;do
	  LangsFlags[$lang]=`grep -E "$NameChars$lang$NameChars"'\.(png|svg)$' 2>/dev/null <<<"$FILES"|head -n 1`
	done
  fi
fi

#заполняем нумерованный массив LangsArr именами расскладок
declare -a LangsArr
N=0;
for lang in $Langs;do
  echo flag for $lang':'
  echo ${LangsFlags[$lang]}
  LangsArr[$N]=$lang
  N=$((N+1))
done

 
# ищем значок xneur gxneur.png
[ -z "$XneurIco" ]&& which locate &>/dev/null &&
XneurIco=$(locate --regex 'scalable.*'"$CMDstr"'\.svg$'|head -n 1);# work if gxneur or kdeneur installed
NoXneurICON='NoICO'
echo -n XneurIco=
[ -z "$XneurIco" ]&& XneurIco=$NoXneurICON
echo "$XneurIco"

# устанавливаем начальный значок
function SendNoXneur(){
echo "tooltip:no $CMDstr" >"$PIPE"
echo "icon:$NoXneurICON" >"$PIPE"
}
function SendIsXneur(){
echo "tooltip:$CMDstr PID $1" >"$PIPE"
echo "icon:$XneurIco" >"$PIPE"
}
SendNoXneur

# запускаем фоновые процессы
export -f on_click XNEURRESTART PIDOfLoginctlProcName QUITYAD XNEURCLOSE KILLJOBS Open_XNEURRC SendNoXneur SendIsXneur XNEURSTART
export PIPE CMDstr XneurIco NoXneurICON LangsFlags LangsArr

## отправка состояния процесса xneur в канал для значка
function WatchXneurAndSendStatus(){
trap 'echo trap WatchXneurAndSendStatus' EXIT
while true;do
    XNEURPID=`PIDOfLoginctlProcName $CMDstr`
	if [ -n "$XNEURPID" ];then
	  SendIsXneur "$XNEURPID"
      while [ -d /proc/$XNEURPID ];do
        sleep 3s
      done
	  SendNoXneur
    else
	  sleep 3s
	fi
done
}
WatchXneurAndSendStatus &
echo WatchXneurAndSendStatus=$!

##посылаем раскладку клавиатуры в канал для значка
function SENDLAYOUT(){
  trap 'echo trap SENDLAYOUT;KILLJOBS' EXIT
  stdbuf -oL xkbevd 2>/dev/null|grep --line-buffered -o -E 'group=[^,]+,'|grep --line-buffered -o [0-9]|
  while read K;do
    if [[ "$LAYOUTLASTNUM" -ne "$K" ]];then
      LAYOUTLASTNUM=$K;
	  LangName=${LangsArr[$K]};
	  echo "icon:${LangsFlags[$LangName]}" >"$PIPE"
    fi
  done
}
#SENDLAYOUT &;echo SENDLAYOUT=$!


yad --notification --listen \
--icon-size=256 \
--command="bash -c on_click" \
--menu='перезапуск xneur!bash -c XNEURRESTART|Завершить xneur!bash -c XNEURCLOSE|xneurrc!bash -c Open_XNEURRC|Выход!bash -c QUITYAD' \
<&3
