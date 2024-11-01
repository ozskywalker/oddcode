#!/bin/sh
# stat behaves differently on macOS/fBSD
get_file_size() {
    if [ "$(uname)" = "Darwin" ] || [ "$(uname)" = "FreeBSD" ]; then
        stat -f%z "$1"
    else
        stat -c%s "$1"
    fi
}

show_usage() {
    echo "Usage: $0 [-video] <input_file> [-keepaudio] [-nooverwrite] [-h|-help]"
}

if [ $# -eq 0 ]; then
    show_usage
    exit 1
fi

#
# INIT
#
input_file=""
audio_flag=false
overwrite_flag=true

while [ "$1" != "" ]; do
    case $1 in
        -video)
            shift
            input_file="$1"
            ;;
        -keepaudio)
            audio_flag=true
            ;;
        -nooverwrite)
            overwrite_flag=false
            ;;
        -help | -h)
            show_usage
            exit 0
            ;;
        *)
            input_file="$1"
            ;;
    esac
    shift
done

# Check if the input file is provided and exists
if [ -z "$input_file" ]; then
    echo "[!!] Error: No input file specified."
    show_usage
    exit 1
else
    echo "[+] Checking if '$input_file' exists... \c"
fi

if [ ! -f "$input_file" ]; then
    echo "FAIL"
    echo "[!!] Error: File '$input_file' does not exist."
    exit 1
else
    echo "OK"
fi

# Check if the file is a valid movie file (checking file type)
echo "[+] Checking if '$input_file' is a valid movie file... \c"
file_type=$(file --mime-type -b "$input_file")
if [[ "$file_type" != video/* ]]; then
    echo "FAIL ($file_type detected)"
    echo "[!!] Error: '$input_file' is not considered a valid video file."
    exit 1
else
    echo "OK ($file_type)"
fi

# Set output file name
output_file="${input_file%.*}.mp4"

# Check if destination file already exists, remove by default
if [ -f "$output_file" ]; then
    if [ "$overwrite_flag" = false ]; then
        read -p "[!!] The output file '$output_file' already exists. \nOverwrite? (y/n) or specify new name: " user_input
        case $user_input in
            [yY]|[yY][eE][sS])
                rm "$output_file"
                ;;
            [nN]|[nN][oO])
                echo "[!!] Operation cancelled."
                exit 0
                ;;
            *)
                output_file="$user_input"
                ;;
        esac
    else
        echo "[+] Output file exists, overwriting... (use -nooverwrite in future if this behavior isnt desirable)"
        rm "$output_file"
    fi
fi

# Set base ffmpeg arguments
ffmpeg_args=(-hide_banner -loglevel warning -i "$input_file" -c:v libx264 -crf 23 -preset medium)

# Add audio settings if audio_flag is true
if [ "$audio_flag" = true ]; then
    echo "[+] Keeping audio stream..."
    ffmpeg_args+=(-c:a aac -b:a 128k)
else
    ffmpeg_args+=(-an)
fi

# Execute the ffmpeg command
ffmpeg "${ffmpeg_args[@]}" "$output_file"
result=$?
if [ $? -eq 0 ]; then
    # Calculate file sizes using the cross-platform function
    original_size=$(get_file_size "$input_file")
    new_size=$(get_file_size "$output_file")
    reduction=$(( (original_size - new_size) * 100 / original_size ))

    echo ""
    echo "[*] Conversion Successful!"
    echo "[*] Output File:      $output_file"
    echo "[*] Original Size:    $((original_size / 1024)) KB"
    echo "[*] New Size:         $((new_size / 1024)) KB"
    echo "[*] Space Reduction:  $reduction%"
    echo ""
else
    echo ""
    echo "[!!] Conversion failed! Check Logs"
    echo ""
fi
