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
    shell:
        "bwa index {input:q}"








