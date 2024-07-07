#!/bin/bash

echo "Script to align paired-end reads to reference sequence."

# Function to create bowtie2 index if not exists
create_index_if_not_exists() {
	local bt2_index="$1"
	local ref_genome="$2"
	
	# Check if all necessary index files are present
	for ext in ".1.bt2" ".2.bt2" ".3.bt2" ".4.bt2" ".rev.1.bt2" ".rev.2.bt2"; do
		if [ ! -f "${bt2_index}${ext}" ]; then
			echo "Bowtie2 index files not found. Creating index..."
			bowtie2-build "${ref_genome}" "${bt2_index}"
			break
		fi
	done
}

# Function to align reads
align_reads() {
	local fq_dir="$1"
	local bt2_index="$2"
 	local threads="$3"
	cd "$fq_dir" || exit
	for fq in *_R1.fastq.gz; do
		fq_base=$(basename "$fq" .fastq.gz | sed 's/_R1//g')
		echo "Aligning ${fq_base}..."
		
		# Align reads and directly create sorted BAM
		bowtie2 -p "$threads" --local -x "${bt2_index}" -1 "${fq_base}_R1.fastq.gz" -2 "${fq_base}_R2.fastq.gz" 2>"${fq_base}.log" | \
		samtools view -h -b - | \
		samtools sort -@ "$threads" -o "./${fq_base}.sorted.bam"
		
		# Index sorted BAM
		echo "Indexing ${fq_base}.sorted.bam ..."
		samtools index -@ "$threads" "${fq_base}.sorted.bam"
	done
}

# Parse options
while getopts "f:i:r:t" flag; do
	case ${flag} in
		f) fqdir="${OPTARG}" ;;
		i) bt_index="${OPTARG}" ;;
		r) ref_genome="${OPTARG}" ;;
  		t) threads="${OPTARG}";;
		\?) echo "Usage: $0 [-f fastq-directory] [-i bowtie2_index_path] [-r reference_genome] [-t number-of-threads]" >&2; exit 1 ;;
	esac
done

# Check if required options are set
if [ -z "$fqdir" ] || [ -z "$bt_index" ] || [ -z "$ref_genome" ]; then
	echo "Usage: $0 [-f fastq-path] [-i bowtie2-index-path] [-r reference-genome-path]" >&2
	exit 1
fi

# Create bowtie2 index if it does not exist
create_index_if_not_exists "$bt_index" "$ref_genome"

# Run the alignment function
align_reads "$fqdir" "$bt_index"

exit
