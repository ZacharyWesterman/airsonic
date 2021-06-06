#!/usr/bin/env bash

declare -a req=(
	basename
	date
	exiftool
	ffmpeg
	file
	find
	grep
	mkdir
	mv
	python3
	read
	rm
	sed
	sort
	sox
	uniq
)

failed=""

for i in ${req[*]}
do
	if ! which "$i" &>/dev/null
	then
		failed+=$'\n'"    $i"
	fi
done

if [ "$failed" != '' ]
then
	>&2 echo "Failed to start due to missing dependencies."
	>&2 echo "Please install the following to continue:$failed"
	exit 1
fi

exit 0
