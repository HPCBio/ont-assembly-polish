
all: $(PILON_CONTIGS)
	@echo
	@echo Analysis finishes.
	@echo Pilon corrected contigs are at: $(PILON_CONTIGS)

# Pipeline targets:

# Nanopore assembly by canu:

CANU_PREFIX=canu
CANU_DIR=$(WDIR)/canu-assembly
CANU_CONTIGS=$(CANU_DIR)/$(CANU_PREFIX).contigs.fasta

canu_assembly: $(CANU_CONTIGS) $(WDT)
$(CANU_CONTIGS): $(NANOPORE_READS)
	@echo Assembling nanopore reads using canu.
	@canu\
		 -p $(CANU_PREFIX) \
		 -d $(CANU_DIR) \
		 genomeSize=$(CANU_GENOME_SIZE) \
		 -nanopore-raw $(NANOPORE_READS)

# Map nanopore reads to canu contings and use racon to perform correction based on nanopore reads only:

RACON_CONTIGS=$(WDIR)/racon.contigs.fasta
MINIMAP_OVERLAPS=$(WIDR)/minimap_overlaps.paf

racon_correct: $(RACON_CONTIGS)
$(RACON_CONTIGS): $(NANOPORE_READS) $(CANU_CONTIGS)
	@echo Mapping nanopore reads onto canu contings using minimap.
	@minimap $(RACON_CONTIGS) $(NANOPORE_READS) > $(MINIMAP_OVERLAPS)

# Index contigs, map Illumina reads to contigs by BWA, sorting and indexing using samtools:

BWA_BAM_PREFIX=$(WDIR)/bwa_aligned_reads
BWA_BAM=$(BWA_BAM_PREFIX).bam

bwa_align: $(BWA_BAM)
$(BWA_BAM): $(CANU_CONTIGS) $(ILLUMINA_READS_PAIR1) $(ILLUMINA_READS_PAIR2)
	@echo Indexing contigs.
	@bwa index $(CANU_CONTIGS)
	@echo Aligning Illumina reads using BWA mem.
	@bwa mem -t $(CORES) $(BWA_PARAMETERS) $(CANU_CONTIGS)  $(ILLUMINA_READS_PAIR1) $(ILLUMINA_READS_PAIR2)\
		| samtools view -S -b -u - | samtools sort -@ $(CORES) - $(BWA_BAM_PREFIX)
	@samtools index $(BWA_BAM)

# Correct contigs using pilon based on the Illumina reads:

PILON_CONTIGS=$(WDIR)/pilon.contigs.fasta

pilon_correct: $(PILON_CONTIGS)
$(PILON_CONTIGS): $(CANU_CONTIGS) $(BWA_BAM)
	@echo Correcting contigs using pilon.
	@pilon --threads $(CORES) --genome $(CANU_CONTIGS) --bam $(BWA_BAM) --outdir $(WDIR) --output pilon.contigs $(PILON_PARAMETERS)
