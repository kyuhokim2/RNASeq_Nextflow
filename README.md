# Basic RNASeq pipeline using Nextflow and AWS Batch

## Pipeline workflow:
```mermaid
graph LR
    subgraph "Sample Processing (Parallel)"
        subgraph "Sample 1"
            A1[FASTQ] --> B1[QC] --> C1[Align] --> D1[Quantify]
        end
        
        subgraph "Sample 2"
            A2[FASTQ] --> B2[QC] --> C2[Align] --> D2[Quantify]
        end
        
        subgraph "Sample N"
            A3[FASTQ] --> B3[QC] --> C3[Align] --> D3[Quantify]
        end
    end
    
    D1 & D2 & D3 --> E[MultiQC]
```

## References
Before running the pipeline, you need to download reference and annotation files. 
I have included a script (download_references.sh) to download necessary reference and annotation files. For explanation on how to run the script, please run the following command:
```Bash 
chmod +x download_references.sh
./download_references.sh 
```
*Note*:
All the references are from AWS iGenomes S3 bucket.
- s3://ngi-igenomes/igenomes/Homo_sapiens/UCSC/hg38 for Human
- s3://ngi-igenomes/igenomes/Mus_musculus/UCSC/mm10 for Mouse

