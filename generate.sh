#!/bin/bash

# This scripts generates preview samples for long audio recodings such as
# mixes or dj sets.
#
# From this file structure containing the recordings:
#
# sets
# └── a
#     ├── ab
#     │   └── ab.x.mp3
#     └── ac
#         └── ac.y.mp3
#
# it writes 10 second samples to:
#
# samples
# └── a
#     ├── ab
#     │   └── ab.x.mp3
#     └── ac
#         └── ac.y.mp3
#
# Samples are 2 seconds from 10%, 30%, 50%, 70% and 90% of the recording.

# Check installed software
if [ -z $(which sox) ]; then
	echo ERROR: Install sox
	exit
fi
if [ -z $(which ffmpeg) ]; then
	echo ERROR: Install ffmpeg
	exit
fi
if [ -z $(which mp3info) ]; then
	echo ERROR: Install mp3info
	exit
fi

# Set up test files
mkdir -p sets/a/ab
mkdir -p sets/a/ac
if [ ! -e sets/a/ab/ab.x.mp3 ]; then
	sox -r 44100 -n -c 2 sets/a/ab/ab.x.wav synth 600 sin 200+1000
	ffmpeg -v quiet -i sets/a/ab/ab.x.wav -acodec mp3 sets/a/ab/ab.x.mp3
	rm -f sets/a/ab/ab.x.wav
fi
if [ ! -e sets/a/ac/ac.y.mp3 ]; then
	sox -r 44100 -n -c 2 sets/a/ac/ac.y.wav synth 600 sin 1000+200
	ffmpeg -v quiet -i sets/a/ac/ac.y.wav -acodec mp3 sets/a/ac/ac.y.mp3
	rm -f sets/a/ac/ac.y.wav
fi

#TODO Consider using OGG as output file to use in-page FOSS audio player

# Create samples
SAVEIFS=$IFS
IFS=$(echo -en "\n\b")
rm -f 1.mp3 2.mp3 3.mp3 4.mp3 5.mp3
SRC=sets
DST=samples
for in in $(cd $SRC; find * -name *.mp3); do
	out=$DST'/'$in
	if [ -e $out -a $out -nt $SRC/$in ]; then
		# sample exists and is newer
		continue
	fi
	duration=$(mp3info -p "%S\n" $SRC/$in)
	if [ $duration -le 60 ]; then
		# set is less than 1 minute or mp3info failed
		continue
	fi
	echo Procesing $in
	step1=$(echo "$duration/10"|bc)
	step2=$(echo "$step1*3"|bc)
	step3=$(echo "$step1*5"|bc)
	step4=$(echo "$step1*7"|bc)
	step5=$(echo "$step1*9"|bc)
	#FIXME Using `-codec:a libmp3lame -b:a 128k` makes it much slower.
	# Did not yet find other options to reduce rate and file size.
	ffmpeg -v quiet -i $SRC/$in -ss $step1 -t 2 -vn -c copy 1.mp3
	ffmpeg -v quiet -i $SRC/$in -ss $step2 -t 2 -vn -c copy 2.mp3
	ffmpeg -v quiet -i $SRC/$in -ss $step3 -t 2 -vn -c copy 3.mp3
	ffmpeg -v quiet -i $SRC/$in -ss $step4 -t 2 -vn -c copy 4.mp3
	ffmpeg -v quiet -i $SRC/$in -ss $step5 -t 2 -vn -c copy 5.mp3
	dir=$(dirname $out)
	mkdir -p $dir
	# INFO No fade in/out/cross because sample is very short. This would
	# also result in extra ffmpeg command as copy and filter don't combine.
	#FIXME See warning without `-v quiet` and fix those.
	if [ -e $out ]; then
		#TODO better find force overwrite for ffmpeg
		rm -f $out
	fi
	ffmpeg -i "concat:1.mp3|2.mp3|3.mp3|4.mp3|5.mp3" -c copy $out #TODO add -v quiet
	rm -f 1.mp3 2.mp3 3.mp3 4.mp3 5.mp3
done
IFS=$SAVEIFS
