#!/usr/bin/bash

[ "$1" == '' ] && exit 1
[ ! -f "$1" ] && exit 1

ffmpeg -i "$1" /tmp/long.wav -loglevel warning -y || exit $?
sox /tmp/long.wav /tmp/short.wav trim 0 10 || exit $?

/home/airsonic/scripts/audd.py /tmp/short.wav

