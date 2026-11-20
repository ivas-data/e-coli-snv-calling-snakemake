rule greeting:
    output: "greeting.txt"
    shell: "echo 'Snakemake works!' > {output:q}"

rule count_words: 
    input: "greeting.txt"
    output: "count_words.txt"
    shell: "wc -w < {input:q} > {output:q}"

rule index_reference:
    input:
        "data/reference/REL606.fasta"
    output:
        "data/reference/REL606.fasta.amb",
        "data/reference/REL606.fasta.ann",
        "data/reference/REL606.fasta.bwt",
        "data/reference/REL606.fasta.pac",
        "data/reference/REL606.fasta.sa"
    log:
        "logs/REL606.index_reference.log"
    shell:
        "bwa index {input:q} 2> {log:q}"

rule map_reads:
    input:
        reference="data/reference/REL606.fasta",
        index=rules.index_reference.output,
        r1="data/reads/SRR2589044_1.trim.sub.fastq",
        r2="data/reads/SRR2589044_2.trim.sub.fastq"
    output:
        "results/SRR2589044.sam"
    log:
        "logs/SRR2589044.bwa.log"
    shell:
        "bwa mem {input.reference:q} {input.r1:q} {input.r2:q} > {output:q} 2> {log:q}"

rule sort_bam: 
    input: 
        "results/SRR2589044.sam"
    output:
        "results/SRR2589044.sorted.bam"
    log:
        "logs/SRR2589044.sort_bam.log"
    shell: 
        "samtools sort -o {output:q} {input:q} 2> {log:q}"

rule index_bam:
    input: 
        "results/SRR2589044.sorted.bam"
    output:
        "results/SRR2589044.sorted.bam.bai"
    log:
        "logs/SRR2589044.index_bam.log"
    shell:
        "samtools index {input:q} {output:q} 2> {log:q}"


