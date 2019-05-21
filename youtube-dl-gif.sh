#! /bin/sh

# Set variables
USAGE="usage: youtube-dl-gif [-h|-c<caption>|-l<length>|-s<start time>] URL\n\n       <length> and <start time> should be formatted ##:##:##.###\n       where each section is optional except seconds"
START=0
LENGTH=10
NAME="youtube_gif"
FONT="Source-Sans-Pro-Bold"
FONT_SIZE=35

duration_pattern='^(?:(?:([01]?\d|2[0-3]):)?([0-5]?\d):)?([0-5]?\d)(?:\.(\d+))?$'

# Options
while getopts ":hc:l:n:s:" opt; do

	case $opt in
		c)
			CAPTION="$OPTARG"
			;;
		h)
			echo "$USAGE"
			exit
			;;
		l)
			if [[ $(echo "$OPTARG" | grep -P $duration_pattern) ]]; then
				LENGTH="$OPTARG"
			elif [[ $OPTARG ]]; then
				>&2 echo -e "youtube-dl-gif: invalid duration -- '$OPTARG'\n$USAGE"
				exit 1
			fi
			;;
		n)
			NAME=$OPTARG
			;;
		s)
			if [[ $(echo "$OPTARG" | grep -P $duration_pattern) ]]; then
				START="$OPTARG"
			elif [[ $OPTARG ]]; then
				>&2 echo -e "youtube-dl-gif: invalid timestamp -- '$OPTARG'\n$USAGE"
				exit 1
			fi
			;;
		\?)
			>&2 echo -e "youtube-dl-gif: invalid option -- '$OPTARG'\n$USAGE"
			exit 1
			;;
	esac

done

#Shift argument indices
shift $((OPTIND-1))

# Store input pattern
if [[ $@ ]]; then
	URL=$@
else
	>&2 echo -e "youtube-dl-gif: no url provided\n$USAGE"
	exit 1
fi

url_regex='(https?|ftp|file)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]'

# Check URL validity
if [[ ! $URL =~ $url_regex ]]; then
	>&2 echo "youtube-dl-gif: argument is not valid url -- '$OPTARG'\n$USAGE"
	exit 1
fi

# Convert clip to mp4
if [ ! -f $NAME.mp4 ]; then
	echo -n "Converting YouTube clip ..."
	echo -e "Conversion:\n" > youtube-dl-gif.log
	ffmpeg -ss $START -t $LENGTH -i $(youtube-dl -f 18 --get-url $URL) -c:v copy -c:a copy $NAME.mp4 &>> youtube-dl-gif.log
	echo "done"
else
	>&2 echo -e "youtube-dl-gif: $NAME.mp4 already exists in working directory"
	rm --interactive=none youtube-dl-gif.log
	exit 1
fi

# Create gif
if [[ ! $? = 0 ]]; then
	>&2 echo -e "youtube-dl-gif: video conversion failed\n\nlog written to youtube-dl-gif.log"
	exit 1
elif [[ ! -f $NAME.gif ]]; then
	echo -n "Separating video into frames ..."
	mkdir youtube-dl-gif-frames
	[[ $? = 0 ]] || exit 1
	echo -e "\nSeparation:\n" >> youtube-dl-gif.log
	ffmpeg -i $NAME.mp4 -vf scale=480:-1:flags=lanczos,fps=10 ./youtube-dl-gif-frames/ffout%03d.png &>> youtube-dl-gif.log

	if [[ ! $? = 0 ]]; then
		>&2 echo -e "youtube-dl-gif: video separation failed\n\nlog written to youtube-dl-gif.log"
		exit 1
	fi

	echo -en "done\nCombining frames into GIF ..."

	if [[ $CAPTION ]]; then
		magick -loop 0 ./youtube-dl-gif-frames/ffout*.png -font $FONT -pointsize $FONT_SIZE -fill white -stroke black -strokewidth 2 -gravity south -annotate 0 "$CAPTION" $NAME.gif
	else
		magick -loop 0 ./youtube-dl-gif-frames/ffout*.png $NAME.gif
	fi

	echo "done"
	echo -n "Cleaning up ..."
	rm -r --interactive=none youtube-dl-gif-frames $NAME.mp4 youtube-dl-gif.log
	echo "done"
else
	>&2 echo -e "youtube-dl-gif: $NAME.gif already exists in working directory"
	rm --interactive=none youtube-dl-gif-frames $NAME.mp4 youtube-dl-gif.log
	exit 1
fi
