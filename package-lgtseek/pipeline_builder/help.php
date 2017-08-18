
<?php
$page_title = 'Pipeline Builder - Help';
$extra_head_tags = '<meta http-equiv="Content-Language" content="en-us">' . "\n";
$extra_head_tags .= '<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1">' . "\n";
$extra_head_tags .= '<link rel="stylesheet" type="text/css" href="./css/documentation.css">';
include_once('header.php');
/*
<html>
	<head>
	</head>
	<body>
		<div id='page_container'>

			<div id='content_container'>
*/  ?>
				<h2><a href="help.php">Documentation</a></h2>
				<p>
					This is a simple interface build to create and configure the lateral gene transfer (LGTSeek) pipeline in
					<a href="http://ergatis.igs.umaryland.edu" target="_blank"><strong>Ergatis</strong></a>. It involves the following steps :
				</p>
				<ol>
					<li>Specifying the reference files that will be used in the pipeline
						The reference files include:
						<ul>
							<li>
								Donor genome reference - One or more fasta sequences.  If the "Build BWA Indexes" checkbox is not checked, then all the files associated with the reference index must be uploaded instead.  This reference is required for Use Cases 1 or 2.
							</li>
							<li>
								Recipient genome reference - One or more fasta sequences.  If the "Build BWA Indexes" checkbox is not checked, then all the files associated with the reference index must be uploaded instead.  This reference is required for Use Cases 1 or 3.
							</li>
							<li>
								RefSeq reference - One or more annotated nucleotide sequences located within the NCBI Reference Sequence database. If the "Build BWA Indexes" checkbox is not checked, then all the files associated with the reference index must be uploaded instead.  This reference is required for Use Case 3.
							</li>
						</ul>
					</li>
					<li>Specifying the input type (one is required):
						<ul>
							<li>
							The SRA ID provided is downloaded from the Sequence Read Archive.  This field can be any of the following:
							<ul>
								<li>SRP - Study ID</li>
								<li>SRR - Run ID</li>
								<li>SRS - Sample ID</li>
								<li>SRX - Experiment ID</li>
							</ul>
							</li>
							<li>
							A FASTQ input file or files associated with a single sample.  If passing paired-end files, these files should end in "_1.fastq"/"_2.fastq" or "R1.fastq"/"R2.fastq".  Can be compressed with GZIP before uploading
							</li>
							<li>
							A BAM input file or files.  Can be compressed with GZIP before uploading
							</li>
						</ul>
					</li>
					<li>Click Submit when ready</li>
				</ol>
				<p>
					An output directory will be created and listed on the next page after Submit is clicked.  This output directory will contain the requisite pipeline.config and pipeline.layout files needed to create the pipeline in addition to a log file.  For the LGTSeek pipeline, the config file parameters will be automatically configured.
				</p>
				<p>
					The last page will display a link to the newly created Ergatis pipeline. Clicking on the link will take you directly to the Ergatis interface to run the and monitor the pipeline.
				</p>
				<p>
					If there are any issues with the Pipeline Builder interface, or if you have any questions, comments, etc. then feel free to send an e-mail to <strong>sadkins [at] som.umaryland.edu</strong>
				</p>
<?php
include_once('footer.php');
/*			</div>
		</div>
	</body>
</html>
*/
?>
