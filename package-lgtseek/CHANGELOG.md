# CHANGELOG

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
