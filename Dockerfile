FROM continuumio/miniconda3:4.12.0

# Set metadata for the image
LABEL maintainer="kyuhokim2@gmail.com"
LABEL description="Dockerfile for an RNA-Seq pipeline (FASTQ to Counts) with STAR, Salmon, and RSeQC."

# Set the working directory
WORKDIR /app

# Basic install
RUN apt-get update && \
    apt-get install -y \
    build-essential \
    procps \
    curl \
    unzip \
    && conda install -n base -c conda-forge mamba -y \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Bioinformatics tools
RUN mamba create -n rnaseq -c bioconda -c conda-forge \
    star=2.7.10b \
    salmon=1.9.0 \
    fastqc=0.11.9 \
    fastp=0.23.2 \
    rseqc=5.0.1 \
    multiqc=1.13 \
    && mamba clean -afy

# Activate the conda environment for subsequent commands
SHELL ["/bin/bash", "-c"]
ENV PATH /opt/conda/envs/rnaseq/bin:$PATH

# Install Nextflow
RUN curl -s https://get.nextflow.io | bash && \
    mv nextflow /usr/local/bin/

# Install the AWS CLI v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf awscliv2.zip aws

# Set the entrypoint to use the conda environment
ENTRYPOINT ["/bin/bash", "-c"]
