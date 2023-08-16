# !/bin/bash

# gb82's Compression Plotter
# Usage: ./compression-plotter [brotli|zstd|7z|xz|zip|zpaq] input_dir/ output.csv
# Plots a ratio of speed to compressed size for different compression algorithms
# Output is a .csv file

# Check if the correct number of arguments are provided
if [ $# -ne 3 ]; then
    echo "Usage: ./compression-plotter.sh [brotli|zstd|7z|xz|zip|zpaq] input_dir/ output.csv"
    exit 1
fi

# Algorithm selection
algorithm=$1
# Input directory
input_dir=$2
# Input dir size
input_dir_size=$(du -b "$input_dir" | tr -d "$input_dir")
# Output CSV file
output_file=$3

# Create CSV header
echo "Uncompressed Size: $input_dir_size" >> $output_file
echo "step time $algorithm" >> $output_file

case $algorithm in
	brotli)
		algorithm=1
		;;
	zstd)
		algorithm=2
		;;
	7z)
		algorithm=3
		;;
	xz)
		algorithm=4
		;;
	zip)
		algorithm=5
		;;
	zpaq)
		algorithm=6
		;;
	*)
		algorithm=0
		;;
esac

extension=${2##*.}
noextension=${2%.*}
noextension=${noextension##*/}
rand=$(openssl rand --hex 4)
outdir="$noextension-$rand"
mkdir "$outdir"

threads=$(nproc)

# Create uncompressed tar file for compression algorithms that need it
tar -cf "$outdir/uncompressed.tar" "$input_dir"

# Effort levels for different compression algorithms
brotli_effort_levels=(1 2 3 4 5 6 7 8 9 10 11)
zstd_effort_levels=(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22)
sevzip_effort_levels=(1 2 3 4 5 6 7 8 9)
xz_effort_levels=(1 2 3 4 5 6 7 8 9 1e 2e 3e 4e 5e 6e 7e 8e 9e)
zpaq_effort_levels=(1 2 3 4 5)

# Compression functions

compress_brotli () {
	# Single threaded
	s=$( /usr/bin/time -f "%e" brotli -q "$1" "$outdir/uncompressed.tar" -o "$outdir/brotli-$1.tar.br" 2>&1)
	echo "$s"
}

compress_zstd () {
	# Change to -T$2 to specify # of threads. Multithreading set by -T0
	s=$( /usr/bin/time -f "%e" zstd -q --ultra -"$1" -T0 "$outdir/uncompressed.tar" -o "$outdir/zstd-$1.tar.zst" 2>&1)
	echo "$s"
}

compress_7zip () {
	# Add -mmt$2 to specify # of threads. Multithreaded by default
	s=$( /usr/bin/time -f "%e" 7zzs a -bso0 -mx$1 "$outdir/7zip-$1.7z" "$input_dir" 2>&1)
	echo "$s"
}

compress_xz () {
	# Change to -T$2 to specify # of threads. Multithreading set by -T0
	u=$( /usr/bin/time -f "%e" xz -q -q -T0 -k -$1 "$outdir/uncompressed.tar" "$outdir/uncompressed.tar.xz" 2>&1)
	echo "$u" >> "$outdir/tail-$1.txt"
	mv "$outdir/uncompressed.tar.xz" "$outdir/xz-$1.tar.xz"
	s=$( cat "$outdir/tail-$1.txt" | tail -n 1 2>&1)
	echo "$s"
}

compress_zip () {
	# Add -mmt$2 to specify # of threads. Multithreaded by default
	s=$( /usr/bin/time -f "%e" 7zzs a -bso0 -tzip -mx$1 "$outdir/7z-zip-$1.zip" "$input_dir" 2>&1)
	echo "$s"
}

compress_zpaq () {
	# Add -t$2 to specify # of threads. Multithreaded by default
	u=$( /usr/bin/time -f "%e" zpaq a "$outdir/zpaq-$1.tar.zpaq" "$outdir/uncompressed.tar" -m$1 2>&1)
	echo "$u" >> "$outdir/tail-$1.txt"
	s=$( cat "$outdir/tail-$1.txt" | tail -n 1 2>&1)
	echo "$s"
}

get_size () {
	stat --printf="%s" "$1"
}

if [ $algorithm -eq 1 ] ; then
	for step in "${brotli_effort_levels[@]}"; do
		time=$(compress_brotli $step)
		fname=$(echo "$outdir/brotli-$step.tar.br")
		size=$(get_size $fname)
		echo -n "$step " >> $output_file
		echo -n "$time " >> $output_file
		echo "$size" >> $output_file
		echo "Compressed with effort $step of 11"
	done
elif [ $algorithm -eq 2 ] ; then
	for step in "${zstd_effort_levels[@]}"; do
		time=$(compress_zstd $step $threads)
		fname=$(echo "$outdir/zstd-$step.tar.zst")
		size=$(get_size $fname)
		echo -n "$step " >> $output_file
		echo -n "$time " >> $output_file
		echo "$size" >> $output_file
		echo "Compressed with effort $step of 22"
	done
elif [ $algorithm -eq 3 ] ; then
	for step in "${sevzip_effort_levels[@]}"; do
		time=$(compress_7zip $step $threads)
		fname=$(echo "$outdir/7zip-$step.7z")
		size=$(get_size $fname)
		echo -n "$step " >> $output_file
		echo -n "$time " >> $output_file
		echo "$size" >> $output_file
		echo "Compressed with effort $step of 9"
	done
elif [ $algorithm -eq 4 ] ; then
	for step in "${xz_effort_levels[@]}"; do
		time=$(compress_xz $step)
		fname=$(echo "$outdir/xz-$step.tar.xz")
		size=$(get_size $fname)
		echo -n "$step " >> $output_file
		echo -n "$time " >> $output_file
		echo "$size" >> $output_file
		echo "Compressed with effort $step of 9e"
	done
elif [ $algorithm -eq 5 ] ; then
	for step in "${sevzip_effort_levels[@]}"; do
		time=$(compress_zip $step $threads)
		fname=$(echo "$outdir/7z-zip-$step.zip")
		size=$(get_size $fname)
		echo -n "$step " >> $output_file
		echo -n "$time " >> $output_file
		echo "$size" >> $output_file
		echo "Compressed with effort $step of 9"
	done
elif [ $algorithm -eq 6 ] ; then
	for step in "${zpaq_effort_levels[@]}"; do
		time=$(compress_zpaq $step $threads)
		fname=$(echo "$outdir/zpaq-$step.tar.zpaq")
		size=$(get_size $fname)
		echo -n "$step " >> $output_file
		echo -n "$time " >> $output_file
		echo "$size" >> $output_file
		echo "Compressed with effort $step of 5"
	done
elif [ $algorithm -eq 0 ] ; then
	echo "Incorrect algorithm argument."
	rm $output_file
fi
		
rm -rf $outdir

if [ $algorithm -ne 0 ] ; then
	echo "Compression & plotting complete. Results saved to $output_file"
fi
