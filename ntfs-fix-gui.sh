#!/bin/bash

function dclick-line(){
grep -iq ntfs<<<$*||exit
echo $'\n'ntfsfix $1':' >"$FIFO"
Ans=`ntfsfix $1 2>&1`;ERR=$?;echo "$Ans">"$FIFO"
if [ $ERR -gt 0 ];then
  if [[ "$Ans" =~ 'Windows is hibernated' ]];then
    yad --text="Windows is hibernated!!! $'\n' Желаете сбросить это состояние и потерять данные windows?" &>/dev/null
	ERR=$?
	if [ $ERR -eq 0 ];then
	  MNT="$TMP"/$$/mnt
	  mkdir -p "$MNT"
	  mount -o defaults,rw,remove_hiberfile -t ntfs $1 "$MNT" &>"$FIFO";ERR=$?
	  umount /mnt 
	fi
  fi
fi
[ $ERR -eq 0 ]&& echo $1 успешно разблокирован >"$FIFO"||echo Неудача разблокирования $1>"$FIFO"
}

function on_script_exit(){ echo 'завершение';rm -f "$FIFO";KILLJOBS; }
function KILLJOBS(){ jobs >/dev/null;jobs -p|while read K;do kill -s SIGTERM $K;echo "SIGTERM to $K";done; }
FIFO="$TMP/"$$'.'$(date +%s)
trap on_script_exit EXIT
mkfifo "$FIFO" && exec 3<>"$FIFO" && export FIFO && echo "$FIFO"||exit

Options='name,fstype,label,size,vendor,model,serial'
HEADER=`echo ${Options//,/ }|tr '[:lower:]' '[:upper:]'`
BLKLIST=`lsblk -Ppo $Options|grep -E '(FSTYPE=""|ntfs)'`
BLKLIST=`echo -e "$BLKLIST"`
BLKLIST=${BLKLIST//\"\"/X}
for A in $HEADER;do BLKLIST=${BLKLIST//$A=/:};done
BLKLIST=${BLKLIST//\"/};BLKLIST=${BLKLIST// /};BLKLIST=${BLKLIST//:/ };BLKLIST=${BLKLIST//'&'/+}

HEADER=${HEADER// /' --column='}
HEADER='--column='$HEADER

export -f dclick-line on_script_exit KILLJOBS

#GUI:
yad --plug="$$" --tabnum=1 --text="Выберите раздел ntfs:" --grid-lines=both --no-click --dclick-action='bash -c "dclick-line %s"' \
--search-column=2 \
--list $HEADER $BLKLIST &

yad --plug="$$" --tabnum=2 --text="Отчёт" --text-info --show-cursor --tail --show-uri <&3 &

yad --button=gtk-close --paned --key="$$" --splitter=300 --center --width=800 --height=500 \
--title="Разблокировать NTFS" --window-icon="drive-harddisk-system"