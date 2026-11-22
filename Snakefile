# We use the configuration file to read the sample list, mapping threads and filtering thresholds.
configfile: "config/config.yaml"

# When we started our project, we used fixed sample IDs in the rules. We now use a shared {sample} wildcard and restrict it to SRR followed by digits, 
# so that filtered .snvs.vcf files cannot match the rule that produces raw .vcf files. 
wildcard_constraints:
    sample=r"SRR[0-9]+"

# We request one filtered Variant Call Format (VCF) file for each configured sample. 
rule all:
    input:
        expand("results/{sample}.snvs.vcf", sample=config["samples"])

# We used greeting and count_words as examples for practicing Snakemake rules.
rule greeting:
    output: "greeting.txt"
    shell: "echo 'Snakemake works!' > {output:q}"

rule count_words: 
    input: "greeting.txt"
    output: "count_words.txt"
    shell: "wc -w < {input:q} > {output:q}"

# We build the BWA index once so all samples can use the same reference for mapping.
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

# We align the paired-end reads from both FASTQ files for each sample to the REL606 reference. 
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
    threads: config["resources"]["mapping_threads"]
    shell:
        "bwa mem -t {threads} {input.reference:q} {input.r1:q} {input.r2:q} > {output:q} 2> {log:q}"

# We sort alignments by genomic position so the BAM file can be indexed. 
rule sort_bam: 
    input: 
        "results/{sample}.sam"
    output:
        "results/{sample}.sorted.bam"
    log:
        "logs/{sample}.sort_bam.log"
    shell: 
        "samtools sort -o {output:q} {input:q} 2> {log:q}"

# We index the sorted BAM file so tools can retrieve alignments by genomic position.
rule index_bam:
    input: 
        "results/{sample}.sorted.bam"
    output:
        "results/{sample}.sorted.bam.bai"
    log:
        "logs/{sample}.index_bam.log"
    shell:
        "samtools index {input:q} {output:q} 2> {log:q}"


# We create a FASTA index so BCFtools can retrieve reference bases by position. 
rule index_fasta:
    input:
        "data/reference/REL606.fasta"
    output:
        "data/reference/REL606.fasta.fai"
    log:
        "logs/REL606.index_fasta.log"
    shell:
        "samtools faidx {input:q} 2> {log:q}"

# We compare each sample's reads with the REL606 reference and save the detected variants in a VCF file. We use ploidy 1 to model each E. coli sample as haploid. 
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

# We filter the original Variant Call Format (VCF) file and save only the single-nucleotide variants (SNVs) that meet the quality and read-depth
# thresholds set in the configuration file.
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




