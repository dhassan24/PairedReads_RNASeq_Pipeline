# Paired-End RNA-seq Pipeline

A reproducible pipeline for processing paired-end RNA-seq data from raw SRA reads through to a gene-level counts table ready for differential expression analysis.

## Workflow

```
SRA Download (fastq-dump)
        ↓
Quality Trimming (cutadapt)
        ↓
Genome Alignment (HISAT2)
        ↓
Read Counting (featureCounts)
        ↓
counts.txt → DEG Analysis (DESeq2 / edgeR in R)
```

## Repository Contents

| File | Description |
|------|-------------|
| `paired_rnaseq_pipeline.ipynb` | Jupyter notebook version of the pipeline |
| `paired_rnaseq_pipeline.sh` | Standalone shell script version |

## Dependencies

| Tool | Version tested | Install |
|------|---------------|---------|
| [SRA Toolkit](https://github.com/ncbi/sra-tools) | 3.1.0 | See link |
| [cutadapt](https://cutadapt.readthedocs.io/) | 5.2 | `pip install cutadapt` |
| [HISAT2](https://daehwankimlab.github.io/hisat2/) | 2.2.1 | `apt-get install hisat2` |
| [subread / featureCounts](https://subread.sourceforge.net/) | 2.0.3 | `apt-get install subread` |

## Usage

### Jupyter Notebook

Open `paired_rnaseq_pipeline.ipynb` and edit the configuration cell at the top:

```python
SRR_IDS = [
    "SRR000001",
    "SRR000002",
    ...
]
HISAT2_INDEX = "mm10/genome"   # path to your HISAT2 index
GTF           = "annotation.gtf"
THREADS       = 4
MAX_READS     = 5_000_000      # set to None to download all reads
```

Then run all cells.

### Shell Script

```bash
# 1. Edit the configuration block at the top of the script
nano paired_rnaseq_pipeline.sh

# 2. Make executable and run
chmod +x paired_rnaseq_pipeline.sh
./paired_rnaseq_pipeline.sh
```

## Reference Data

Pre-built HISAT2 genome indexes: https://daehwankimlab.github.io/hisat2/download/

Ensembl GTF annotations: https://ftp.ensembl.org/pub/

Example (mouse mm10, used in development):
```bash
wget https://genome-idx.s3.amazonaws.com/hisat/mm10_genome.tar.gz
wget https://ftp.ensembl.org/pub/release-102/gtf/mus_musculus/Mus_musculus.GRCm38.102.gtf.gz
```

## Output

`counts.txt` — a tab-delimited matrix of raw read pair counts per gene per sample. Load directly into R for downstream DEG analysis:

```r
counts <- read.table("counts.txt", header = TRUE, skip = 1, row.names = 1)
```

## Notes

- Both the notebook and script are idempotent — already-completed steps are skipped on re-run.
- The pipeline uses `-p --countReadPairs` in featureCounts to count fragments (read pairs) rather than individual reads, which is appropriate for paired-end data.
- Trimming parameters (`-q 20`, `--minimum-length 30`) can be adjusted in the configuration section based on library quality.
