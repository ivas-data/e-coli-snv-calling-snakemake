configfile: "config/config.yaml"

wildcard_constraints:
    sample=r"SRR[0-9]+"

rule all:
    input:
        expand("results/{sample}.snvs.vcf", sample=config["samples"])

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
        r1="data/reads/{sample}_1.trim.sub.fastq",
        r2="data/reads/{sample}_2.trim.sub.fastq"
    output:
        "results/{sample}.sam"
    log:
        "logs/{sample}.bwa.log"
    shell:
        "bwa mem {input.reference:q} {input.r1:q} {input.r2:q} > {output:q} 2> {log:q}"

rule sort_bam: 
    input: 
        "results/{sample}.sam"
    output:
        "results/{sample}.sorted.bam"
    log:
        "logs/{sample}.sort_bam.log"
    shell: 
        "samtools sort -o {output:q} {input:q} 2> {log:q}"

rule index_bam:
    input: 
        "results/{sample}.sorted.bam"
    output:
        "results/{sample}.sorted.bam.bai"
    log:
        "logs/{sample}.index_bam.log"
    shell:
        "samtools index {input:q} {output:q} 2> {log:q}"


# I index the reference so bcftools can look up bases by position.
rule index_fasta:
    input:
        "data/reference/REL606.fasta"
    output:
        "data/reference/REL606.fasta.fai"
    log:
        "logs/REL606.index_fasta.log"
    shell:
        "samtools faidx {input:q} 2> {log:q}"

# I compare the sample's reads with the REL606 reference and save the detected variants in a VCF file.
rule call_variants:
    input:
        bam="results/{sample}.sorted.bam",
        bai="results/{sample}.sorted.bam.bai",
        ref="data/reference/REL606.fasta",
        fai="data/reference/REL606.fasta.fai"
    output:
        "results/{sample}.vcf"
    log:
        "logs/{sample}.variant_calling.log"
    shell:
        """
        (bcftools mpileup -Ou -f {input.ref:q} {input.bam:q} |
         bcftools call --ploidy 1 -m -v -Ov -o {output:q}) 2> {log:q}
        """

# I use Snakemake to filter the original Variant Call Format (VCF) file and save the single-nucleotide variants (SNVs) that pass the filters.
rule filter_variants:
    input:
        "results/{sample}.vcf"
    output:
        "results/{sample}.snvs.vcf"
    log:
        "logs/{sample}.filter_variants.log"
    params:
        min_qual=config["variant_filter"]["min_qual"],
        min_dp=config["variant_filter"]["min_dp"]
    shell:
         """
        bcftools view -i 'TYPE="snp" && QUAL>={params.min_qual} && INFO/DP>={params.min_dp}' \
            -Ov -o {output:q} {input:q} 2> {log:q}
        """




