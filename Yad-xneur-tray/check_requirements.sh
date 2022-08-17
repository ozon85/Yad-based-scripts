#!/bin/sh
which --help &>/dev/null ||{ xmessage 'which required';exit; }

function CheckReq(){
WHICH=`which $CMD 2>/dev/null`||{ return $?; }
WHICH=`basename $WHICH`
[ "$WHICH"  = "$CMD" ]&& return 0||echo not: '!'"$WHICH"'!'  = '!'"$CMD"'!' ;
}


while read CMD;do
CMD=${CMD%%'#'*}
if [ -n "$CMD" ];then
  for CMD in $CMD;do
    if [ -n "$CMD" ];then
      CheckReq||{ NotSatisfied=$NotSatisfied$'\n'$CMD; echo NotSatisfied found; }
    fi
  done
fi
done<requirements.txt

[ -n "$NotSatisfied" ]&& xmessage 'Not Satisfied: '$'\n'"$NotSatisfied"||xmessage 'All requirements done'