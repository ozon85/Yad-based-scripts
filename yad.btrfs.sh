#!/bin/bash
# требуются lsblk, mktemp, bash, btrfs, yad

Caption='Light btrfs dialog' # заголовок окна
Icon=drive-harddisk			# возможный значок окна
# символ разделитель
Dlm='|'

OKbutton=yad-ok; Closebutton=yad-close; Refreshicon=view-refresh

export Dlm OKbutton Closebutton Refreshicon

# действия при завершении скрипта
#function OnScriptExit(){ echo Завершение работы...; }

# ставим действие на выход из скрипта
#trap "OnScriptExit" exit

# получить список томов смонтированного в каталог (1) раздела btrfs
function GetSubvolumeList(){ btrfs subvolume list "$1"; }

#переводит строки (1) в одну с разделителем (2)
function ОднойСтрокой(){ echo "${1//$'\n'/$2}";}

# получить список томов смонтированного в каталог (1) раздела btrfs, объединить их в однустроку с разделителем Dlm вместо конца строки
function СписокТомов(){  list=`GetSubvolumeList "$1"`; ОднойСтрокой "$list" "$Dlm"; }

# получить том по умолчанию для точки монтирования (1)
function GetDefSubvol(){ btrfs subvolume get-default "$1"; }

# установить том btrfs по умолчанию по номеру(2) для точки монтирования (1)
function SetDefaultSubvolumeByID(){ btrfs subvolume set-default $2 "$1"; }

# монтируем раздел (1) (корневой том btrfs) в указанный каталог (2)
function MountBTRFSPartition(){ mount -o subvolid=5 "$1" "$2"; }

# создание снимка одного тома по полному пути(1) в другой по полному пути (2)
function CreateSubvolumeSnapshot(){ btrfs subvolume snapshot "$1" "$2"; }

#Удаление тома btrfs по полному пути к нему (1)
function DeleteSubVolume(){ btrfs subvolume delete "$1"; }

# получение всех строчек о статусе монтирования раздела  (1)      
function GetMounts(){ mount|grep "$1"; }     

# получение точки монтирования из строки статуса монтирования (1)   
function ExtractMountPoint(){ F1=${1%%' type '*}; echo "${F1#* on }"; }

# получение параметра subvol= из строки статуса монтирования (1) системы btrfs
function ExtractMountedSubvol()
{ 
 L2=$(echo "$1"|grep -oE '\(.+\)') #получаем подстроку с параметрами монтирования
 L3=${L2//(/};L4=${L3//)/}			# исключаем скобки ( и )
 echo "subvol=${L4#*subvol=}"				# выводим параметр монтирования subvol=...
}

# получаем одну строку для всех точек монтирования раздела(1) btrfs с указанием подключенного тома
function ПолучитьСтрокуТочекМонтирования()
{
GetMounts "$1"|while read L;do Ans=`ExtractMountPoint "$L"`'  '`ExtractMountedSubvol "$L"`;echo "$Ans";done
}

# получение всех точек монтирования раздела        
function GetMountPoints(){ mount|grep "$1"|while read F1;do F1=${F1%%' type '*};echo ${F1#* on };done; }         
         
# собрать даные о разделе(1) btrfs в массив DATA[0...]
function СобратьДанные() # partition
{ #получим все точки подключения раздела в одну строку  
  DATA[0]=`GetMountPoints "$1"` && DATA[0]=${DATA[0]//$'\n'/;   };
  DATA[0]=`ПолучитьСтрокуТочекМонтирования   "$1"` && DATA[0]=${DATA[0]//$'\n'/;   };
  #создаём случайный каталог монтирования
  MntP=`mktemp -d` || { ec=$?; echo >&2 "Не удалось создать временный каталог"; return $ec; }
  MountBTRFSPartition "$1" "$MntP" || return 2  #монтируем данный раздел для дальнейшего анализа
  DATA[1]=`GetDefSubvol "$MntP"`
  DATA[2]=$(СписокТомов "$MntP")   #список томов данного раздела, отделённых '|'

  umount "$MntP" || umount -l "$MntP"
}

# создание вкладки диалога по номеру диалога(1), порядковому номеру вкладки(2), разделу(3) btrfs и заполненому массиву данных о разделе (DATA)
function СоздатьВкладку() # plugID, tabnum, partition, DATA[]={ mountPoints, SubvolumeList, DefSubvolume }
{ 
 yad --plug="$1" --tabnum=$2 --window-icon=gtk-cdrom \
--form --scroll --item-separator="$Dlm" \
--field="1.Точки монтирования\::RO" "${DATA[0]}" \
--field="2.Том по умолчанию\::RO" "${DATA[1]}" \
--field="3.Выбрано:CB" "${DATA[2]}" \
--field="Создать снимок...:btn" 				"@bash -c 'СделатьСнимокТома 		$3 \"\$1\"' -- %3" \
--field="Удалить том...:btn" 					"@bash -c 'УдалитьТом 				$3 \"\$1\"' -- %3" \
--field="Установить том по умолчанию...:btn" 	"@bash -c 'УстановитьПоУмолчанию 	$3 \"\$1\"' -- %3" \
--field="7.Отчёт:TXT" " " \
--field='Обновить'"$Dlm$Refreshicon$Dlm":btn 							"@bash -c 'ОбновитьОкно				$3'              " \
 &

}

# установить для раздела (1) том по умолчанию из описания(2) или спросить сбросить его на корневой
function УстановитьПоУмолчанию()
{
# спросим пользователя какой том он хочет по умолчанию, выбранный или корневой
yad --width=600 --center --text="Установите том раздела $1 по умолчанию: \n $2" \
--button=$OKbutton:0 \
--button=$Closebutton:1 \
--button='установить ID=5':5 #2>/dev/null

UserChoise=$?;[ $UserChoise = 1 ]&&exit

# выберем номер тома из его описания или как корневой
[ $UserChoise -eq 0 ]&&{ SubvolumeID=${2#ID };SubvolumeID=${SubvolumeID%% *}; } || SubvolumeID=$UserChoise

# создание временного каталога для монтирования
if tmpfolder=`mktemp -d 2>&1`; then
  # монтирование раздела
  if mountAnswer=`MountBTRFSPartition "$1" "$tmpfolder" 2>&1`;then
    # установка тома по умолчанию
    if DefaultSubvolumeByID=`SetDefaultSubvolumeByID "$tmpfolder" "$SubvolumeID" 2>&1`; then
      ec=$?;
      # вернём на форму значение по умолчанию
      echo "2:"`GetDefSubvol "$tmpfolder" 2>&1` 
    fi # SetDefaultSubvolumeByID
    ec=$?; echo "7:$DefaultSubvolumeByID" # отчёт
    umount "$tmpfolder" || umount -l "$tmpfolder"
  else # не MountBTRFSPartition
     ec=$?; echo "7: $mountAnswer"; 
  fi #MountBTRFSPartition
  rm -df "$tmpfolder"
else # не mktemp
  ec=$?; echo "7: $tmpfolder"; 
fi #mktemp

return $ec;

}

function УдалитьТом() # partition, volumePath/volume description
{
SubvolumePath=${2#* path }
yad --width=600 --center --text="Подтвердите удаление тома $SubvolumePath \n из раздела $1"||return $?

# создание временного каталога для монтирования
if tmpfolder=`mktemp -d 2>&1`; then
  # монтирование раздела
  if mountAnswer=`MountBTRFSPartition "$1" "$tmpfolder" 2>&1`;then
    # удаление тома
    if SnapShotDelete=`DeleteSubVolume "$tmpfolder/$SubvolumePath" 2>&1`; then
      #получение списка всех томов раздела
      if SubvolumeListInOneLine=`СписокТомов "$tmpfolder"`;then
        ec=$?;        
        echo ec=$ec
        echo "3:$SubvolumeListInOneLine" # В поле списка всех томов раздела отправим новый список всех томов
      fi
    else # не DeleteSubVolume
      ec=$?; echo "7: $SnapShotDelete"; 
    fi # DeleteSubVolume
    umount "$tmpfolder" || umount -l "$tmpfolder"
  else # не MountBTRFSPartition
     ec=$?; echo "7: $mountAnswer"; 
  fi #MountBTRFSPartition
  rm -df "$tmpfolder"
else # не mktemp
  ec=$?; echo "7: $tmpfolder"; 
fi #mktemp

return $ec;
}

# пользователь запросил снимок тома по описанию (2) для раздела (1)
function СделатьСнимокТома() # partition, SubvolumeInfo
{
# предложим имя нового тома добавив к имени данного тома дату 
SubvolumePath=${2#* path }
Time=`date +%H-%M`
Date=`date +%d.%m.%y`
NewSubvolumeName="$SubvolumePath"'_'"$Date"

answer=`yad --width=600 --center \
--text="Создать снимок тома $SubvolumePath раздела $1" \
--form --separator="$Dlm" \
--field="имя тома без пробелов" "$NewSubvolumeName" \
2>/dev/null`||return

NewSubvolumeName=${answer//"$Dlm"/} # удаляем маркеры-разделители, особенность вывода полей формы yad
#echo answer="$answer" >&2
#echo NewSubvolumeName=$NewSubvolumeName >&2

# создание временного каталога для монтирования
if tmpfolder=`mktemp -d 2>&1`; then
  # монтирование раздела
  if mountAnswer=`MountBTRFSPartition "$1" "$tmpfolder" 2>&1`;then
    # создание снимка
    if SnapShotCreate=`CreateSubvolumeSnapshot "$tmpfolder/$SubvolumePath" "$tmpfolder/$NewSubvolumeName" 2>&1`; then
      if SubvolumeListInOneLine=`СписокТомов "$tmpfolder"`;then
        ec=$?;        
        echo "3:$SubvolumeListInOneLine" # В поле списка всех томов раздела отправим новый список всех томов
      else
        ec=$?; echo "7: $SubvolumeListInOneLine";
      fi
    else # не CreateSubvolumeSnapshot
      ec=$?; echo "7: $SnapShotCreate"; 
    fi # CreateSubvolumeSnapshot
    umount "$tmpfolder" || umount -l "$tmpfolder"
  else # не MountBTRFSPartition
     ec=$?; echo "7: $mountAnswer"; 
  fi #MountBTRFSPartition
  rm -df "$tmpfolder"
else # не mktemp
  ec=$?; echo "7: $tmpfolder"; 
fi 

return $ec;
}

# 
function ОбновитьОкно()
{
unset DATA
  СобратьДанные  "$1" ||return $?
  echo "1:${DATA[0]}"
  echo "2:${DATA[1]}"
  echo "3:${DATA[2]}"
}

export -f MountBTRFSPartition CreateSubvolumeSnapshot СделатьСнимокТома УдалитьТом DeleteSubVolume СписокТомов УстановитьПоУмолчанию SetDefaultSubvolumeByID GetDefSubvol GetSubvolumeList ОднойСтрокой ОбновитьОкно СобратьДанные GetMountPoints ПолучитьСтрокуТочекМонтирования GetMounts ExtractMountPoint ExtractMountedSubvol ExtractMountPoint ExtractMountedSubvol


function ДобавитьВкладкуРаздела() # plugID, tabnum, partition
{ unset DATA
  СобратьДанные  "$3"
  СоздатьВкладку "$1" $2 "$3"
}

#получаем список разделов btrfs
BTRFSPartitionsList=`lsblk -rpo name,fstype|grep btrfs|cut -d' ' -f1`

N=0;NOTEBOOKTABLINE=''
for A in $BTRFSPartitionsList;do
  echo $A
  N=$((N+1))
  ДобавитьВкладкуРаздела  $$ $N $A &
  NOTEBOOKTABLINE=$NOTEBOOKTABLINE' --tab='$A
done;

yad --notebook --key="$$" --button=$Closebutton --width=900 --height=600 --center \
--title="$Caption" --window-icon="$Icon" $NOTEBOOKTABLINE