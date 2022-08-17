#!/bin/bash

function OpenDialog(){
K=`yad --file --height=600 --width=600`;exitcode=$?
[ $exitcode -gt 0 ]&& exit
echo '1:'"$K"
}

function SaveDialog(){
FileToLink=$0
echo FileToLink=$FileToLink
[ -d "$FileToLink" ]&& Linkname="$FileToLink"'/'`basename "$FileToLink"` ||Linkname="$FileToLink"
K=`yad --file --save --confirm-overwrite --height=600 --width=500 --filename="$Linkname"`;exitcode=$?
[ $exitcode -gt 0 ]&& exit
LN=`ln -sf "$FileToLink" "$K" 2>&1`;exitcode=$?
[ $exitcode -gt 0 ]&& yad --text="$LN" --button='wtf!error'||notify-send "symlink created" "$K" "$FileToLink"
}

function RenameDialog(){
NAME=`basename "$1"`
yad --width=600 --center --text="You save symlink \n $1 \n as exist file or directory, rename file to: " --title="Rename exist file" --entry --entry-text=".$NAME"
}


#------------------start-------------------
if [ $# -gt 0 ];then
  [ `tty -s` ]&& ECHO='echo'||ECHO='notify-send'
  LinkName=`basename "$1"`
  LinkPath=${1%/*}
K=`yad --width=800 --height=800 --center --title="Save $LinkName symlink as ..." \
--filename="ln to $LinkName" --file --save `||exit
  LinkName=`basename "$K"`
  LinkPath=${K%/*}
  if [ -e "$K" ];then 
    NewK=`RenameDialog "$K"` && mv -f "$K" "$NewK"
  fi
  ln -s "$1" "$K" && $ECHO "ln" "$K" || $ECHO "Fail ln" "$K"
else
#################################
export -f OpenDialog SaveDialog

yad --form --width=800 --button='end!gtk-ok' --title='create symlink' \
--field='Link to':label "$1" \
--field='Choose target!fileopen':BTN '@bash -c OpenDialog' \
--field='save symlink...!gtk-ok':BTN '@bash -c SaveDialog %1'
fi