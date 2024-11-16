#!/bin/bash
s= ; #неразрывный пробел

Caption='Light NTFS fix dialog' # заголовок окна
Icon=drive-harddisk				# возможный значок окна
Dlm='|' 						# символ разделитель
OKbutton=yad-ok; Closebutton=yad-close; Refreshicon=view-refresh

# Строим строку заголовков для диалога
Options='name,fstype,label,size,vendor,model,serial'
HEADER=`echo ${Options//,/ }|tr '[:lower:]' '[:upper:]'` #переводим список опций в заголовки столбцов, разделённые пробелами
HEADER=${HEADER// /' --column='}; HEADER='--column='$HEADER

# Получаем строки со значениями соответственно заголовкам
BLKLIST=$(
lsblk -Ppo $Options|grep -E '(FSTYPE=""|ntfs)'|
while read -r L;do  # читаем по строчно, что бы манипулировать, запретили работу с управляющими символами
  L2=`echo -e "$L"|grep  -oE '="[^"]*"'`; #переводим запись типа "\xd0\x9d\xd0\xbe\xd0\xb2\xd1\x8b\xd0\xb9 \xd1\x82\xd0\xbe\xd0\xbc" в юникод и 
  										  # находим все значения в кавычках после символа = на каждой строке
#	echo L2="$L2"									  
  L2=${L2//$'\n'/};						# сливаем строки в одну, значения разделены символом =
  L2=${L2//\"\"/$s}; L2=${L2//\"/};		# замена пустых значений ("") на символ пустого значения и удаление всех \"
  # теперь значения разделены символом =, но ещё имеют собственные пробелы в значениях
  L2=${L2// /$s}						## замена простых пробелов на символ пустого значения
  echo "$L2";
done
)||exit $?
BLKLIST=${BLKLIST//=/ };		# меняем разделитель параметров с = на пробел
BLKLIST=${BLKLIST//'&'/+}		# какая-то замена текста из отчёта lsblk

function on_script_exit(){ echo 'завершение';rm -f "$FIFO";KILLJOBS; }
function KILLJOBS(){ jobs >/dev/null;jobs -p|while read K;do kill -s SIGTERM $K;echo "SIGTERM to $K";done; }
trap on_script_exit EXIT

# Обработка двойного клика по строке диалога для разблокирования раздела
function dclick-line()
{

grep -iq ntfs<<<$*||exit	# проверка, что в поданых параметрах есть слово ntfs

echo ntfsfix $1':' >"$FIFO"	# сообщаем о запуске ntfsfix над разделом?
Ans=`ntfsfix $1 2>&1`;ERR=$?;echo "$Ans">"$FIFO" # запуск исправления раздела и вывод ответа в диалог

#Возможные коды возврата
#[ $ERR -eq 1 ] && устройство смонтировано, невозможно: refusing to operate on read-write mounted device /dev/sda4


if [ $ERR -gt 0 ];then		# если код возврата не 0
  if [[ "$Ans" =~ 'Windows is hibernated' ]];then	#если в тексте есть сообщение о гибернации 
    yad --text="Windows is hibernated!!! $'\n' Желаете сбросить это состояние и потерять данные windows?" &>/dev/null		#спросим пользователя о разблокирования
	ERR=$?
	if [ $ERR -eq 0 ];then
	  MNT=`mktemp -d`&&	  
	  mount -o defaults,rw,remove_hiberfile -t ntfs $1 "$MNT" &>"$FIFO"; ERR=$?
	  umount "$MNT"|| umount -l "$MNT"
	  rm -fd "$MNT"
	fi
  fi
fi
[ $ERR -eq 0 ]&& echo $1 успешно разблокирован >"$FIFO"||echo Неудача разблокирования $1>"$FIFO"
}

FIFO=`mktemp -du` && mkfifo "$FIFO" && exec <> "$FIFO" && export FIFO||exit

export -f dclick-line on_script_exit KILLJOBS

#GUI:
yad --plug="$$" --tabnum=1 --text="Выберите раздел ntfs:" --grid-lines=both --no-click --dclick-action='bash -c "dclick-line %s"' \
--search-column=2 \
--list $HEADER $BLKLIST &

yad --plug="$$" --tabnum=2 --text="Отчёт" --text-info --show-cursor --tail --show-uri <"$FIFO" &

yad --button=$Closebutton --paned --key="$$" --splitter=300 --center --width=800 --height=500 \
--title=$Caption --window-icon=$Icon