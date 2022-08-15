#!/bin/bash
MountPoint='/mnt'

K=`mount|grep $MountPoint`
if [ -n "$K" ];then
  MountPoint="$TMP/$$"
  mkdir -p "$MountPoint"
fi
#Pipe=$$.pipe.XXXXXXXX;Pipe=`mktemp -u --tmpdir="$TMP" "$Pipe"`
#mkfifo "$Pipe"&& export Pipe && exec 3<>"$Pipe"&&echo "$Pipe" ||exit; #обозначить что пайп не может быть создан и общение процессов нарушено
#trap on_script_exit EXIT

declare -a BTRFSPartitionsArray
BTRFSPartitionsList=`lsblk -rpo name,fstype|grep btrfs|cut -d' ' -f1`

function unmountFolder(){ umount "$1" && echo точка "$1" отмонтирована; }
trap "unmountFolder $MountPoint" exit

function MountBTRFSPartitionToPoint(){ unmountFolder "$2";echo монтирование $1 в папку "$2";mount -o subvolid=5 "$1" "$2"; }
function GetSubvolumeListOfMountPoint(){ F=`btrfs subvolume list $MountPoint`;[ -z "$F" ]&&{ echo '-';exit 1; }||
         #while read K;do echo ${K#* path };done<<<"$F";
		 echo "${F//$'\n'/|}"
}
function GetDefaultSubvolume(){ F=`btrfs subvolume get-default "$1" 2>&1`||{ echo '-';exit 1; };echo $F; }
function SetDefaultSubvolume(){
#args: $/dev/sda1 #Subvolumestring
SubvolumeID=${2#ID };SubvolumeID=${SubvolumeID%% *}
yad --width=600 --center --text="Установите том раздела $1 по умолчанию: \n $2" \
--button=gtk-ok:0 \
--button=gtk-close:1 \
--button='установить ID=5':5 \
2>/dev/null
ERR=$?;[ $ERR = 1 ]&&exit
K=`MountBTRFSPartitionToPoint $1 "$MountPoint" 2>&1`;ERR2=$?
[ $ERR2 -gt 0 ]&&{ echo 8:$K;exit $ERR2; }
case $ERR in
0) K=`btrfs subvolume set-default $SubvolumeID "$MountPoint" 2>&1`;echo 8:$K;;
5) K=`btrfs subvolume set-default 5 "$MountPoint" 2>&1`;echo 8:$K;;
esac
echo '4:'`GetDefaultSubvolume "$MountPoint"`
}

function УдалитьТом(){ exit;btrfs subvolume delete "$MountPoint/$1";GetSubvolumeList; }
function GetMountPoint(){ F=`mount|grep $1`;[ -z "$F" ]&&{ echo '-';exit 1; }
         F=`while read F1;do F1=${F1%%' type '*};echo ${F1#* on };done<<<"$F"`;echo ${F//$'\n'/; }; }
		 
function AddYADTab(){
#args: $/dev/sda1 
#"$MountPoint"
MountBTRFSPartitionToPoint $1 "$MountPoint"||exit $?
echo чтение раздела...
mountpointfield=$(GetMountPoint $1)
#echo GetMountPoint:$mountpointfield
DefaultSubvolume=$(GetDefaultSubvolume "$MountPoint")
#echo GetDefaultSubvolume: $DefaultSubvolume
SubvolumeList=$(GetSubvolumeListOfMountPoint "$MountPoint")
#echo GetSubvolumeListOfMountPoint: $SubvolumeList
unmountFolder "$MountPoint"
yad --plug="$$" --tabnum=$N --window-icon=gtk-cdrom \
--form --scroll --item-separator='|' \
--field="раздел\::RO" "$1" \
--field="точки монтирования\::RO" "$mountpointfield" \
--field="3.Том по умолчанию\::LBL" " " \
--field="4:RO" "$DefaultSubvolume" \
--field="5:CB" "$SubvolumeList" \
--field="создать снимок:btn" '@bash -c "СделатьСнимокТома %1 %5"' \
--field="удалить том:btn" '@bash -c "УдалитьТом %1 %5"' \
--field="8:TXT" " " \
--field="Том по умолчанию:btn" '@bash -c "SetDefaultSubvolume %1 %5"' \
2>/dev/null &
}

function УдалитьТом(){
#args: $/dev/sda1 #Subvolumestring
SubvolumePath=${2#* path }
yad --width=600 --center --text="Подтвердите удаление тома $SubvolumePath \n из раздела $1"||exit $?
K=`MountBTRFSPartitionToPoint $1 "$MountPoint" 2>&1`;ERR=$?
[ $ERR -gt 0 ]&&{ echo 8:$K;exit $ERR; }
echo 8:`btrfs subvolume delete "$MountPoint/$SubvolumePath" 2>&1`
echo '5:'$(GetSubvolumeListOfMountPoint "$MountPoint")
}

function СделатьСнимокТома(){
MountBTRFSPartitionToPoint $1 "$MountPoint"||exit $?
SubvolumePath=${2#* path }
Time=`date +%H-%M`
Date=`date +%d.%m.%y`
NewSubvolumeName="$SubvolumePath"'_'"$Date"
answer=`yad --width=600 --center \
--text="Создать снимок тома $SubvolumePath в папке $MountPoint" \
--form --item-separator='|' --separator='|' \
--field="имя тома без пробелов" "$NewSubvolumeName" \
2>/dev/null`||return

NewSubvolumeName=${answer%%'|'*}
MenuEntry=`cut -d'|' -f2<<<$answer`
#MenuEntry=${answer#*'|'}
#echo '8:'$'\f'
#         echo '8:snapshot '"$MountPoint/$SubvolumePath" "$MountPoint/$NewSubvolumeName"
echo '8:'`btrfs subvolume snapshot "$MountPoint/$SubvolumePath" "$MountPoint/$NewSubvolumeName" 2>&1`
#SubvolumeList=`btrfs subvolume list $MountPoint|while read K;do echo "${K#* path }";done`|| exit
#SubvolumeList=${SubvolumeList//$'\n'/\|}
echo '5:'$(GetSubvolumeListOfMountPoint "$MountPoint")
}

export -f unmountFolder MountBTRFSPartitionToPoint GetSubvolumeListOfMountPoint GetDefaultSubvolume GetMountPoint СделатьСнимокТома УдалитьТом SetDefaultSubvolume
export MountPoint

N=1
for A in $BTRFSPartitionsList;do
echo $'\n'
#MountBTRFSPartitionToPoint $A "$MountPoint" && 
AddYADTab $A && NOTEBOOKTABLINE=$NOTEBOOKTABLINE' --tab='$A
N=$((N+1))
done
echo $'\n'---------------
echo NOTEBOOKTABLINE="$NOTEBOOKTABLINE"
yad --notebook --key="$$" --button="gtk-close" --width=900 --height=600 --center \
--title="btrfs" --window-icon=gtk-cdrom $NOTEBOOKTABLINE 2>/dev/null