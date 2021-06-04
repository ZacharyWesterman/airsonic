#!/usr/bin/bash

begin=$(date +%s)
beginDate=$(date)

mkdir /mnt/backup || exit 1

for dev in /dev/sdb /dev/sdc
do
	mount $dev /mnt/backup || continue
	for dir in Music Audiobooks Soundtracks
	do
		[ -d /mnt/backup/$dir ] && rsync -a /home/airsonic/$dir /mnt/backup/ --exclude $dir/Incoming
	done
	umount /mnt/backup
done >> /home/airsonic/backup.log 2>&1

rm -rf /mnt/backup

finish=$(date +%s)
elapsed=$((finish - begin))
[ "$elapsed" -gt 59 ] && elapsed="$((elapsed/60))m $((elapsed%60))"

echo "$beginDate backup completed in ${elapsed}s." >> /home/airsonic/backup.log

chown airsonic:airsonic /home/airsonic/backup.log
