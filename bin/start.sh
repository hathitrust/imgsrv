#!/bin/sh

XPPID=$1; shift;
CMD=$1; shift
OUTPUT=$1; shift;

echo "STARTING: $HTTP_HOST $$ : $XPPID : $CMD $*" >$OUTPUT.err

DIR=`dirname $0`
# nohup $DIR/$CMD $* 2>>$OUTPUT.err >$OUTPUT < /dev/null &
nohup nice -n 20 $DIR/$CMD $* 2>>$OUTPUT.err < /dev/null &

exit;
