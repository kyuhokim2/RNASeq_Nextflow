#!/bin/bash

# This script downloads, indexes, and optionally uploads reference genome files
# for hg38 (human) or mm10 (mouse) from the public AWS iGenomes S3 bucket.
#
# It performs the following steps:
# 1. Downloads the genome FASTA, GTF, and BED files locally.
# 2. Unzips the downloaded files.
# 3. Builds a STAR index for alignment.
# 4. Builds a Salmon index for quantification.
# 5. If an S3 bucket is provided, it uploads the final assets. Otherwise, it
#    leaves them in the local directory.
#
# Usage:
# ./download_and_index_genome.sh <species> [s3_bucket_uri] [threads]
#
# Example (Upload to S3):
# ./download_and_index_genome.sh hg38 s3://my-rnaseq-references 8
#
# Example (Save Locally):
# ./download_and_index_genome.sh mm10 16

set -e # Exit immediately if a command exits with a non-zero status.

# --- Configuration & Argument Parsing ---
SPECIES=$1
TARGET_S3_BUCKET=""
THREADS=""

# Check if the second argument is an S3 path or the number of threads
if [[ "$2" == s3://* ]]; then
    TARGET_S3_BUCKET=$2
    THREADS=${3:-4} # Third arg is threads, or default to 4
else
    # The second argument is threads (or empty), so no S3 upload
    THREADS=${2:-4}
fi

BASE_S3_URL="s3://ngi-igenomes/igenomes"
LOCAL_DIR="./reference_genomes"

# --- Validation ---
if [[ "$SPECIES" != "hg38" && "$SPECIES" != "mm10" ]]; then
    echo "Error: Invalid species specified."
    echo "Please use 'hg38' for human or 'mm10' for mouse."
    echo "Usage: ./download_and_index_genome.sh <hg38|mm10> [s3_bucket_uri] [threads]"
    exit 1
fi

if ! command -v aws &> /dev/null || ! command -v STAR &> /dev/null || ! command -v salmon &> /dev/null; then
    echo "Error: Required command not found."
    echo "Please ensure 'aws-cli', 'STAR', and 'salmon' are installed and in your PATH."
    exit 1
fi


# --- Set Species-Specific Paths ---
if [ "$SPECIES" == "hg38" ]; then
    S3_PATH="${BASE_S3_URL}/Homo_sapiens/UCSC/hg38"
    OUTPUT_DIR="${LOCAL_DIR}/hg38"
elif [ "$SPECIES" == "mm10" ]; then
    S3_PATH="${BASE_S3_URL}/Mus_musculus/UCSC/mm10"
    OUTPUT_DIR="${LOCAL_DIR}/mm10"
fi

# --- Create Local Directories ---
echo "Creating local directory structure under ${OUTPUT_DIR}..."
mkdir -p "${OUTPUT_DIR}/Sequence/WholeGenomeFasta"
mkdir -p "${OUTPUT_DIR}/Annotation/Genes"
mkdir -p "${OUTPUT_DIR}/Sequence/STAR_index"
mkdir -p "${OUTPUT_DIR}/Sequence/Salmon_index"
echo "Done."
echo ""

# --- Download Files ---
# The --no-sign-request flag is required to access this public S3 bucket.
FASTA_GZ_PATH="${OUTPUT_DIR}/Sequence/WholeGenomeFasta/genome.fa.gz"
GTF_GZ_PATH="${OUTPUT_DIR}/Annotation/Genes/genes.gtf.gz"
BED_GZ_PATH="${OUTPUT_DIR}/Annotation/Genes/genes.bed.gz"

echo "Downloading Genome FASTA for ${SPECIES}..."
aws s3 cp --no-sign-request "${S3_PATH}/Sequence/WholeGenomeFasta/genome.fa.gz" "${FASTA_GZ_PATH}"
echo "Downloading Gene Annotation GTF for ${SPECIES}..."
aws s3 cp --no-sign-request "${S3_PATH}/Annotation/Genes/genes.gtf.gz" "${GTF_GZ_PATH}"
echo "Downloading Gene Annotation BED for ${SPECIES}..."
aws s3 cp --no-sign-request "${S3_PATH}/Annotation/Genes/genes.bed.gz" "${BED_GZ_PATH}"
echo "All files downloaded."
echo ""

# --- Unzip Files ---
echo "Unzipping reference files..."
gunzip -f "${FASTA_GZ_PATH}"
gunzip -f "${GTF_GZ_PATH}"
gunzip -f "${BED_GZ_PATH}"
FASTA_PATH="${FASTA_GZ_PATH%.gz}"
GTF_PATH="${GTF_GZ_PATH%.gz}"
BED_PATH="${BED_GZ_PATH%.gz}"
echo "Unzipping complete."
echo ""

# --- Build STAR Index ---
echo "Building STAR index... (This may take a while)"
STAR --runMode genomeGenerate \
     --runThreadN ${THREADS} \
     --genomeDir "${OUTPUT_DIR}/Sequence/STAR_index" \
     --genomeFastaFiles "${FASTA_PATH}" \
     --sjdbGTFfile "${GTF_PATH}" \
     --sjdbOverhang 100
echo "STAR index built successfully."
echo ""

# --- Build Salmon Index ---
echo "Building Salmon index..."
salmon index \
    -t "${FASTA_PATH}" \
    -i "${OUTPUT_DIR}/Sequence/Salmon_index" \
    -p ${THREADS}
echo "Salmon index built successfully."
echo ""

# --- Conditional Upload or Final Local Message ---
if [[ -n "$TARGET_S3_BUCKET" ]]; then
    # --- Upload to S3 ---
    S3_UPLOAD_PATH="${TARGET_S3_BUCKET}/${SPECIES}"
    echo "Uploading final assets to ${S3_UPLOAD_PATH}..."

    aws s3 cp --recursive "${OUTPUT_DIR}/Sequence/STAR_index" "${S3_UPLOAD_PATH}/STAR_index/"
    echo "STAR index uploaded."

    aws s3 cp --recursive "${OUTPUT_DIR}/Sequence/Salmon_index" "${S3_UPLOAD_PATH}/Salmon_index/"
    echo "Salmon index uploaded."

    aws s3 cp "${BED_PATH}" "${S3_UPLOAD_PATH}/Annotation/genes.bed"
    echo "BED file uploaded."
    echo ""

    # --- Final Message (S3) ---
    echo "--------------------------------------------------"
    echo "✅ Success! All reference files and indices for ${SPECIES} have been uploaded to S3."
    echo "--------------------------------------------------"
    echo ""
    echo "You can now use these S3 paths as parameters for your Nextflow pipeline:"
    echo "  --star_index '${S3_UPLOAD_PATH}/STAR_index/'"
    echo "  --salmon_index '${S3_UPLOAD_PATH}/Salmon_index/'"
    echo "  --bed '${S3_UPLOAD_PATH}/Annotation/genes.bed'"
    echo ""
    echo "You can now safely delete the local directory: rm -rf ${LOCAL_DIR}"
else
    # --- Final Message (Local) ---
    echo "--------------------------------------------------"
    echo "✅ Success! All reference files and indices for ${SPECIES} are ready locally."
    echo "--------------------------------------------------"
    echo ""
    echo "You can now use these local paths:"
    echo "  STAR Index:   ${OUTPUT_DIR}/Sequence/STAR_index/"
    echo "  Salmon Index: ${OUTPUT_DIR}/Sequence/Salmon_index/"
    echo "  BED File:     ${BED_PATH}"
fi
