# CHANGELOG
6/20/17
* Renamed 'lgt_bwa_post_process' to 'lgtseek_classify_reads'
* Made 'filter_dups_lc_seqs' fail if no reads were in the input SAM file.
  * NOTE: This will prevent the 'gather_lgtseek_files' component from executing if the pipeline fails
* Added 'formatdb' component to run Blast+ makeblastdb command
* Added BlastN+ components to Use Cases 1 and 2 but they will use the donor/recipient references as the database instead of NT

5/29/17
* lgt_mpileup.lgt_donor now reads from a 'lgt_donor' BAM instead of an 'lgt_recipient' file
* Changed mpileup output to note the name of the reference in the output file in addition to the input file
* Renamed several component output tokens since the 'lgt_bwa_post_process' output 'lgt_donor' file is being used downstream
* Fixed TMP_DIR being full when doing a Unix sort in the prinseq section of 'filter_dups_lc_seqs' (usually from the 'all_recipient' side)

4/27/17
* Fixed bug in 'concatenate_files' component where it was passing in the wrong argument name to the Perl script
* Added option to skip alignments and go straight to 'lgt_bwa_post_process' component (with caveats)
* Modifications to software.config

3/23/17
* Fixed bug with missing param in XML file for blastn_plus
* Edited 'concatenate_files' component to use perl script instead of 'cat' Unix command.  This gives greater flexibility in either concatenating a string of files, or files in one or more lists together.
* Adding 'samtools_merge' component to use in the good donor/lgt-infected recipient use case
* Editing pipeline\_builder code to incorporate new use-case

3/20/17
* Adding classification for LGT-infected recipient in 'lgt_bwa_post_process' component (for last use-case)

3/5/17
* Lots of renaming and rearranging in lgt\_bwa\_post\_process component
* Changing split\_multifasta component to have 2000 seqs per file instead of 500

2/27/17
* Adding more lgt\_mpileup components and filter\_dups\_lc\_seqs components per use case
* Renaming many outputs from 'host' to 'recipient' and from 'microbiome' to 'donor'

2/20/17
* Going to provide path for components that use taxonomy dumps in MongoDB to do so.
* Refining the good donor/host use case to not run Refseq and Blast steps
* Run filter\_dups\_lc\_seqs after post-processing regardless of use-case
* Removed algorithm default from bwa index config file params.  BWA Indexing chooses the right algo anyways
* Expanded the data that is output from the gather\_lgtview\_files component

12/8/16
* Corrected option typo in blast2lca.pl
* Added option 'tmp\_dir' to change the TMP\_DIR env variable in lgt\_bwa.pl
* Added Ergatis::Utils, and synchronous pipeline running via Ergatis::Pipeline
* Renamed 'global\_pipeline\_templates' to 'pipeline\_templates'

Note: This CHANGELOG for LGTSeek scripts starts from https://github.com/jorvis/ergatis/tree/6dbeed4e39d85bee9d16a634c480c969b61fb0d4
