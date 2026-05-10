#!/usr/bin/env bash
# =============================================================================
# Paired-End RNA-seq Pipeline
# -----------------------------------------------------------------------------
# Workflow: SRA download → quality trimming (cutadapt) → alignment (HISAT2)
#           → read counting (featureCounts)
#
# Dependencies (must be installed / available on PATH):
#   sratoolkit (fastq-dump), cutadapt, hisat2, featureCounts (subread package)
#
# Usage:
#   chmod +x paired_rnaseq_pipeline.sh
#   ./paired_rnaseq_pipeline.sh
# =============================================================================

set -euo pipefail

# =============================================================================
# CONFIGURATION — edit these variables before running
# =============================================================================

# Space-separated list of SRA run accessions to process
SRR_IDS=(
    "SRR000001"
    "SRR000002"
    "SRR000003"
    "SRR000004"
    "SRR000005"
    "SRR000006"
)

# Maximum number of reads to download per accession (set to 0 for all reads)
MAX_READS=5000000

# HISAT2 genome index prefix (directory + base name, e.g. mm10/genome or hg38/genome)
HISAT2_INDEX="mm10/genome"

# Ensembl GTF annotation file path
GTF="Mus_musculus.GRCm38.102.gtf"

# Number of threads for alignment
THREADS=4

# Output directory for counts table
OUTDIR="."

# =============================================================================
# 1. ENVIRONMENT SETUP
# =============================================================================

echo "========================================"
echo " Paired-End RNA-seq Pipeline"
echo "========================================"
echo ""

# Verify required tools are available
for tool in fastq-dump cutadapt hisat2 featureCounts; do
    if ! command -v "$tool" &>/dev/null; then
        echo "ERROR: '$tool' not found on PATH. Please install it before running." >&2
        exit 1
    fi
done

# =============================================================================
# 2. DOWNLOAD FASTQ FILES (paired-end)
# =============================================================================

echo "[Step 1/4] Downloading FASTQ files from SRA..."

for SRR in "${SRR_IDS[@]}"; do
    if [[ -f "${SRR}_1.fastq" && -f "${SRR}_2.fastq" ]]; then
        echo "  Skipping $SRR — FASTQ files already exist."
        continue
    fi

    echo "  Downloading $SRR..."
    if [[ "$MAX_READS" -gt 0 ]]; then
        fastq-dump --split-files -X "$MAX_READS" "$SRR"
    else
        fastq-dump --split-files "$SRR"
    fi
done

echo ""

# =============================================================================
# 3. QUALITY TRIMMING (cutadapt)
# =============================================================================
# -q 20              : trim low-quality bases from 3' ends (Phred < 20)
# --minimum-length 30: discard reads shorter than 30 bp after trimming

echo "[Step 2/4] Quality trimming with cutadapt..."

for SRR in "${SRR_IDS[@]}"; do
    R1="${SRR}_1.fastq"
    R2="${SRR}_2.fastq"
    R1_TRIM="${SRR}_1_trimmed.fastq"
    R2_TRIM="${SRR}_2_trimmed.fastq"

    if [[ -f "$R1_TRIM" && -f "$R2_TRIM" ]]; then
        echo "  Skipping $SRR — trimmed files already exist."
        continue
    fi

    echo "  Trimming $SRR..."
    cutadapt \
        -q 20 \
        --minimum-length 30 \
        -o "$R1_TRIM" \
        -p "$R2_TRIM" \
        "$R1" "$R2"
done

echo ""

# =============================================================================
# 4. ALIGNMENT (HISAT2 → SAM)
# =============================================================================

echo "[Step 3/4] Aligning reads to reference genome with HISAT2..."

SAM_FILES=()

for SRR in "${SRR_IDS[@]}"; do
    R1_TRIM="${SRR}_1_trimmed.fastq"
    R2_TRIM="${SRR}_2_trimmed.fastq"
    SAM="${SRR}.sam"
    SAM_FILES+=("$SAM")

    if [[ -f "$SAM" ]]; then
        echo "  Skipping $SRR — SAM file already exists."
        continue
    fi

    echo "  Aligning $SRR..."
    hisat2 \
        -p "$THREADS" \
        -x "$HISAT2_INDEX" \
        -1 "$R1_TRIM" \
        -2 "$R2_TRIM" \
        -S "$SAM"
done

echo ""

# =============================================================================
# 5. READ COUNTING (featureCounts)
# =============================================================================
# -p              : paired-end mode
# --countReadPairs: count read pairs (fragments) rather than individual reads

echo "[Step 4/4] Counting reads per gene with featureCounts..."

featureCounts \
    -p \
    --countReadPairs \
    -T "$THREADS" \
    -a "$GTF" \
    -o "${OUTDIR}/counts.txt" \
    "${SAM_FILES[@]}"

echo ""
echo "========================================"
echo " Pipeline complete."
echo " Counts table: ${OUTDIR}/counts.txt"
echo "========================================"
