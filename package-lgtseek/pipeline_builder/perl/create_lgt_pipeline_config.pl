#!/usr/bin/env perl
package main;    # Change this to reflect name of script.  If you want to use as module, make sure to save as .pm instead of .pl

=head1 NAME

create_lgt_pipeline_config.pl - Will create a pipeline.layout and pipeline.config for selected sub-pipelines of the automated lateral gene transfer pipeline

=head1 SYNOPSIS

 USAGE: create_lgt_pipeline_config.pl
       --input_file=/path/to/some/input.file
       --output=/path/to/transterm.file
     [ --log=/path/to/file.log
       --debug=3
       --help
     ]

=head1 OPTIONS

B<--sra_id,-s>
	Valid ID from the Sequence Read Archive

B<--bam_input,-b>
	Valid path to a BAM input file.  Either this, the fastq input, or the SRA ID must be provided

B<--fastq_input,-f>
	Valid path to paired FASTQ input files.  If single-paired, provide full pathname.
	For paired-end, make sure both reads have the same name prefix and reside in the same directory.
	Provide full path, but replace the <R1/R2.fastq> parts with .pair as bwa_aln.pl will recognize this as paired-end

B<--donor_reference,-d>
	Path to the donor reference fasta file, or list file (ends in .list).  If not provided, the script assumes this is a host-only LGTSeek run.  If the reference has already been indexed by BWA, the index files must be in the same directory as the reference(s).

B<--host_reference,-h>
	Path to the recipient reference fasta file, or list file (ends in .list).  If not provided, the script assumes this is a donor-only LGTSeek run.If the reference has already been indexed by BWA, the index files must be in the same directory as the reference(s).

B<--bac_lineage>
	Taxon name to search for in bacterial hits.  Will only consider best hits within that taxon lineage.

	B<--euk_lineage>
	Taxon name to search for in eukaryotic hits.  Will only consider best hits within that taxon lineage.

B<--lgt_infected, -i>
	Flag to indicate that the recipient reference is infected with LGT from the donor reference.  This will enable a different pipeline layout compared to the LGT-free use-case

B<--refseq_reference,-r>
	Path to the RefSeq reference fasta file, or list file (ends in .list).  If the reference has already been indexed by BWA, the index files must be in the same directory as the reference(s).

B<--build_indexes,-B>
	If the flag is enabled, will build indexes using BWA in the pipeline.  If you are using pre-build indexes it is important they are compatible with the version of BWA running in the pipeline (0.7.12 for internal Ergatis, 0.7.15 for Docker Ergatis).

B<--skip_alignment,-S>
	If the flag is enabled, then assumes the BAM input file has already been aligned to a reference, and will skipthe "bwa_aln" alignment step.  The input will instead be passed straight to the "lgtseek_classify_reads" component.  Note that this can only apply in the good donor/unknown recipient use case or the good recipient/unknown donor use case.  Furthermore, the genome reference will still be required for mpileup coverage downstream in the pipeline.

B<--template_directory,-t>
	Path of the template configuration and layout files used to create the pipeline config and layout files.

B<--output_directory, -o>
	Directory to write the pipeline.config and pipeline.layout files

B<--no_pipeline_ids, -p>
	If the flag is enabled, do not add process IDs to the pipeline config and layout file names and just use whatever lgt.config and lgt.layout.

B<--log, -l>
    Logfile.

B<--debug,-d>
    1,2 or 3. Higher values more verbose.

B<--help,-h>
    Print this message

=head1  DESCRIPTION

 DESCRIPTION

=head1  INPUT

    Describe the input

=head1 OUTPUT

    Describe the output

=head1  CONTACT

    Shaun Adkins
    sadkins@som.umaryland.edu

=cut

use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use Pod::Usage;
use File::Basename;
use XML::Writer;

############# GLOBALS AND CONSTANTS ################
my $debug = 1;
my ($ERROR, $WARN, $DEBUG) = (1,2,3);
my $logfh;

my $outdir = ".";
my $template_directory = "/local/projects/ergatis/package-lgtseek-devel/pipeline_templates";
my %included_subpipelines = ();
my @gather_output_skip;	# array to keep track of which steps to skip if Post-Analysis components are enabled
my $donor_only = 0;
my $host_only = 0;
my $lgt_infected = 0;
my $skip_alignment = 0;
####################################################

my %options;
my $pipelines = {
		'sra' => 'LGT_Seek_Pipeline_SRA',
		'indexing' => 'LGT_Seek_Pipeline_BWA_Index',
		'lgtseek' => 'LGT_Seek_Pipeline',
		'post' => 'LGT_Seek_Pipeline_Post_Analysis'
};

# Allow program to run as module for unit testing if necessary
main() unless caller();
exit(0);

sub main {
	my $results = GetOptions (\%options,
						  "sra_id|s=s",
						  "bam_input|b=s",
						  "fastq_input|f=s",
						  "host_reference|h=s",
						  "lgt_infected|i",
						  "donor_reference|d=s",
						  "refseq_reference|r=s",
							"bac_lineage=s",
							"euk_lineage=s",
						  "build_indexes|B",
						  "skip_alignment|S",
						  "template_directory|t=s",
						  "output_directory|o=s",
						  "data_directory|O=s",
						  "no_pipeline_id|p",
						  "log|l=s",
						  "debug=i",
						  "help"
					);

    &check_options(\%options);

	my $pipeline_layout;
	my $pipeline_config;
	# The file that will be written to
	if ($options{no_pipeline_id}){
		$pipeline_layout = $outdir."/lgt.layout";
		$pipeline_config = $outdir."/lgt.config";
	} else {
		$pipeline_layout = $outdir."/pipeline.$$.layout";
		$pipeline_config = $outdir."/pipeline.$$.config";
	}
	# File handles for files to be written
	open( my $plfh, "> $pipeline_layout") or &_log($ERROR, "Could not open $pipeline_layout for writing: $!");

	# Since the pipeline.layout is XML, create an XML::Writer
	my $layout_writer = new XML::Writer( 'OUTPUT' => $plfh, 'DATA_MODE' => 1, 'DATA_INDENT' => 2 );

	# Write the pipeline.layout file
	&write_pipeline_layout( $layout_writer, sub {
		my ($writer) = @_;
		&write_include($writer, $pipelines->{'sra'}) if( $included_subpipelines{'sra'} );
		# Use the right layout file if this run is donor-only, or both donor/host alignment
		if ($donor_only) {
			&write_include($writer, $pipelines->{'indexing'}, "pipeline.donor_only.layout") if( $included_subpipelines{'indexing'} );
			unless ($skip_alignment) {
				&write_include($writer, $pipelines->{'lgtseek'}, "pipeline.donor_aln.layout") if( $included_subpipelines{'lgtseek'} );
			}
			&write_include($writer, $pipelines->{'lgtseek'}, "pipeline.donor_only.layout") if( $included_subpipelines{'lgtseek'} );
		} elsif ($host_only) {
			&write_include($writer, $pipelines->{'indexing'}, "pipeline.recipient_only.layout") if( $included_subpipelines{'indexing'} );
			unless ($skip_alignment) {
				&write_include($writer, $pipelines->{'lgtseek'}, "pipeline.recipient_aln.layout") if( $included_subpipelines{'lgtseek'} );
			}
			&write_include($writer, $pipelines->{'lgtseek'}, "pipeline.recipient_only.layout") if( $included_subpipelines{'lgtseek'} );
		} else {
			&write_include($writer, $pipelines->{'indexing'}) if( $included_subpipelines{'indexing'} );
			if ($lgt_infected){
				&write_include($writer, $pipelines->{'lgtseek'}, "pipeline.lgt_infected.layout") if( $included_subpipelines{'lgtseek'} );
			} else {
				&write_include($writer, $pipelines->{'lgtseek'}) if( $included_subpipelines{'lgtseek'} );
			}
		}
		&write_include($writer, $pipelines->{'post'}) if( $included_subpipelines{'post'} );
	});

	# end the writer
	$layout_writer->end();

	my %config;

	# Write the pipeline config file
	foreach my $sp ( keys %included_subpipelines ) {
		if ($sp eq 'lgtseek') {
			if ($donor_only) {
			    &add_config( \%config, $pipelines->{ $sp }, "pipeline.donor_only.config" );
			} elsif ($host_only) {
			    &add_config( \%config, $pipelines->{ $sp }, "pipeline.recipient_only.config" );
			} else {
				if ($lgt_infected){
					&add_config( \%config, $pipelines->{ $sp }, "pipeline.lgt_infected.config" );
				} else {
			    &add_config( \%config, $pipelines->{ $sp } );
				}
			}
		} elsif ($sp eq 'indexing') {
			if ($donor_only) {
			    &add_config( \%config, $pipelines->{$sp}, "pipeline.donor_only.config" );
			} elsif ($host_only) {
				&add_config( \%config, $pipelines->{$sp}, "pipeline.recipient_only.config" );
			} else {
				&add_config( \%config, $pipelines->{$sp} );

			}
		} else {
			&add_config( \%config, $pipelines->{ $sp } ) if $included_subpipelines{$sp};
		}
	}

	$config{"global"}->{'$;BAC_LINEAGE$;'} = defined $options{'bac_lineage'} ? $options{'bac_lineage'} : "Bacteria";
	$config{"global"}->{'$;EUK_LINEAGE$;'} = defined $options{'euk_lineage'} ? $options{'euk_lineage'} : "Eukaryota";


	# If the starting point is BAM input, then use that.
	# Default is to point bwa_aln.recipient to use the sra2fastq output list

	if ($options{bam_input}) {
		# If starting from BAM instead of SRA, then change QUERY_FILE to use BAM input
		if ($skip_alignment) {
			if ( $donor_only ) {
				$config{"lgtseek_classify_reads default"}->{'$;DONOR_FILE_LIST$;'} = '';
				$config{"lgtseek_classify_reads default"}->{'$;DONOR_FILE$;'} = $options{bam_input};
				delete $config{"bwa_aln donor"};
			} elsif ( $host_only ) {
				$config{"lgtseek_classify_reads default"}->{'$;RECIPIENT_FILE_LIST$;'} = '';
				$config{"lgtseek_classify_reads default"}->{'$;RECIPIENT_FILE$;'} = $options{bam_input};
				delete $config{"bwa_aln recipient"};
			} else {
				&_log($ERROR, "ERROR: --skip_alignment only works with the good donor/unknown recipient use-case or the good recipient/unknown donor use-case. Exiting: $!");
			}
		} else {
			if ($donor_only) {
				$config{"bwa_aln donor"}->{'$;QUERY_FILE$;'} = $options{bam_input};
				$config{"bwa_aln donor"}->{'$;PAIRED$;'} = 1;
			} else {
				$config{"bwa_aln recipient"}->{'$;QUERY_FILE$;'} = $options{bam_input};
				$config{"bwa_aln recipient"}->{'$;PAIRED$;'} = 1;
			}
		}
	} elsif ($options{fastq_input}) {
		&_log($WARN, "WARNING: Ignoring --skip_alignment option since input file was not BAM") if ($skip_alignment);
		# If starting from FASTQ then change QUERY_FILE to use FASTQ input
		if ($donor_only) {
			$config{"bwa_aln donor"}->{'$;QUERY_FILE$;'} = $options{fastq_input};
		} else {
			$config{"bwa_aln recipient"}->{'$;QUERY_FILE$;'} = $options{fastq_input};
		}
	} else {
		&_log($WARN, "WARNING: Ignoring --skip_alignment option since input file was not BAM") if ($skip_alignment);
		$config{"global"}->{'$;SRA_RUN_ID$;'} = $options{sra_id};
		$config{"bwa_aln donor"}->{'$;QUERY_FILE$;'} = '$;REPOSITORY_ROOT$;/output_repository/sra2fastq/$;PIPELINEID$;_default/sra2fastq.list' if $donor_only;
	}

# If SRA ID was not input type, then remove that step from array
	push @gather_output_skip, 'move SRA metadata output' unless $options{sra_id};

	if ($donor_only) {
		# In donor-only alignment cases, we do not keep the 'MM' matches

		$config{"lgtseek_classify_reads default"}->{'$;RECIPIENT_FILE_LIST$;'} = '';
		$config{"lgtseek_classify_reads default"}->{'$;LGT_DONOR_TOKEN$;'} = 'single_map';
		$config{"lgtseek_classify_reads default"}->{'$;ALL_DONOR_TOKEN$;'} = 'all_map';
		$config{"lgtseek_classify_reads default"}->{'$;ALL_RECIPIENT_TOKEN$;'} = 'no_map';

		$config{"filter_dups_lc_seqs lgt_donor"}->{'$;INPUT_FILE_LIST$;'} = '$;REPOSITORY_ROOT$;/output_repository/lgtseek_classify_reads/$;PIPELINEID$;_default/lgtseek_classify_reads.single_map.bam.list';
		$config{"filter_dups_lc_seqs lgt_recipient"}->{'$;INPUT_FILE_LIST$;'} = '$;REPOSITORY_ROOT$;/output_repository/lgtseek_classify_reads/$;PIPELINEID$;_default/lgtseek_classify_reads.no_map.bam.list';
		$config{"filter_dups_lc_seqs all_donor"}->{'$;INPUT_FILE_LIST$;'} = '$;REPOSITORY_ROOT$;/output_repository/lgtseek_classify_reads/$;PIPELINEID$;_default/lgtseek_classify_reads.all_map.bam.list';
		$config{'sam2fasta fasta_d'}->{'$;INPUT_FILE$;'} ='$;REPOSITORY_ROOT$;/output_repository/filter_dups_lc_seqs/$;PIPELINEID$;_lgt_donor/filter_dups_lc_seqs.bam.list';
		$config{'sam2fasta fasta_r'}->{'$;INPUT_FILE$;'} ='$;REPOSITORY_ROOT$;/output_repository/filter_dups_lc_seqs/$;PIPELINEID$;_lgt_recipient/filter_dups_lc_seqs.bam.list';

		push @gather_output_skip, 'move all recipient BAM';
		push @gather_output_skip, 'move all donor BAM';
		push @gather_output_skip, 'move all recipient mpileup';
		push @gather_output_skip, 'move LGT recipient mpileup';

	} else {
		# Only add host-relevant info to config if we are aligning to a host
		if ($options{host_reference} =~ /list$/) {
			$config{"global"}->{'$;HOST_LIST$;'} = $options{host_reference};
		} else {
			$config{"global"}->{'$;HOST_REFERENCE$;'} = $options{host_reference};
		}

		# The mpileup component needs the recipient reference to serve as a reference here too
		$config{'lgt_mpileup lgt_recipient'}->{'$;FASTA_REFERENCE$;'} = $options{host_reference};
	}

	if ($host_only) {
		if ($options{refseq_reference} =~ /list$/) {
			$config{"global"}->{'$;REFSEQ_LIST$;'} = $options{refseq_reference};
		} else {
			$config{"global"}->{'$;REFSEQ_REFERENCE$;'} = $options{refseq_reference};
		}

		$config{"lgtseek_classify_reads default"}->{'$;DONOR_FILE_LIST$;'} = '';
		$config{"lgtseek_classify_reads default"}->{'$;LGT_RECIPIENT_TOKEN$;'} = 'single_map';
		$config{"lgtseek_classify_reads default"}->{'$;ALL_DONOR_TOKEN$;'} = 'no_map';
		$config{"lgtseek_classify_reads default"}->{'$;ALL_RECIPIENT_TOKEN$;'} = 'all_map';
		$config{"determine_final_lgt final"}->{'$;REFERENCE_TYPE$;'} = 'recipient';
		$config{"determine_final_lgt final"}->{'$;INPUT_FILE_LIST$;'} = '$;REPOSITORY_ROOT$;/output_repository/get_aligned_reads_list/$;PIPELINEID$;_lgt_recipient/get_aligned_reads_list.list';

		$config{"filter_dups_lc_seqs lgt_recipient"}->{'$;INPUT_FILE_LIST$;'} = '$;REPOSITORY_ROOT$;/output_repository/lgtseek_classify_reads/$;PIPELINEID$;_default/lgtseek_classify_reads.single_map.bam.list';
		$config{"filter_dups_lc_seqs lgt_donor"}->{'$;INPUT_FILE_LIST$;'} = '$;REPOSITORY_ROOT$;/output_repository/lgtseek_classify_reads/$;PIPELINEID$;_default/lgtseek_classify_reads.no_map.bam.list';
		$config{'sam2fasta fasta_r'}->{'$;INPUT_FILE$;'} ='$;REPOSITORY_ROOT$;/output_repository/filter_dups_lc_seqs/$;PIPELINEID$;_lgt_recipient/filter_dups_lc_seqs.bam.list';
		$config{'sam2fasta fasta_d'}->{'$;INPUT_FILE$;'} ='$;REPOSITORY_ROOT$;/output_repository/filter_dups_lc_seqs/$;PIPELINEID$;_lgt_donor/filter_dups_lc_seqs.bam.list';

		push @gather_output_skip, 'move LGT donor mpileup';
		push @gather_output_skip, 'move all donor mpileup';
		push @gather_output_skip, 'move all recipient mpileup';
	} else {
		# Only add donor-relevant info to config if we are aligning to a donor
		if ($options{donor_reference} =~/list$/) {
			$config{"global"}->{'$;DONOR_LIST$;'} = $options{donor_reference};
		} else {
			$config{"global"}->{'$;DONOR_REFERENCE$;'} = $options{donor_reference};
		}

		# The mpileup component needs the donor reference to serve as a reference here too
		$config{'lgt_mpileup lgt_donor'}->{'$;FASTA_REFERENCE$;'} = $options{donor_reference};
		$config{'lgt_mpileup all_donor'}->{'$;FASTA_REFERENCE$;'} = $options{donor_reference};
	}

# If we have a use case where there is a good donor and good reference...
	if (! ($donor_only || $host_only) ) {

		$config{'lgt_mpileup all_recipient'}->{'$;FASTA_REFERENCE$;'} = $options{host_reference};

		# Donor and recipient reads are the same in the sam2fasta output so we just run split_multifasta once
		$config{'blastn_plus nt_r'}->{'$;INPUT_FILE_LIST$;'} = '$;REPOSITORY_ROOT$;/output_repository/split_multifasta/$;PIPELINEID$;_fasta_d/split_multifasta.fsa.list';
		$config{'bwa_aln validation_r'}->{'$;QUERY_FILE$;'} = '$;REPOSITORY_ROOT$;/output_repository/lgt_create_validated_bam/$;PIPELINEID$;_lgt_d/lgt_create_validate_bam.bam.list';

		# If recipient is infected with LGT, change mpileup to use LGT-infected BAM list
		if ($lgt_infected) {
			$config{'sam2fasta fasta_d'}->{'$;INPUT_FILE$;'} ='$;REPOSITORY_ROOT$;/output_repository/samtools_merge/$;PIPELINEID$;_lgt_infected_d/samtools_merge.bam.list';
			$config{'determine_final_lgt'}->{'$;INPUT_FILE_LIST$;'} = '$;REPOSITORY_ROOT$;/output_repository/get_aligned_reads_list/$;PIPELINEID$;_merged_donor/get_aligned_reads_list.list';
			$config{'gather_lgtseek_files'}->{'RECIPIENT_LGT_BAM_OUTPUT'} = '$;REPOSITORY_ROOT$;/output_repository/samtools_merge/$;PIPELINEID$;_lgt_infected_r/samtools_merge.bam.list' if $included_subpipelines{'post'};
			$config{'gather_lgtseek_files'}->{'DONOR_LGT_BAM_OUTPUT'} = '$;REPOSITORY_ROOT$;/output_repository/samtools_merge/$;PIPELINEID$;_lgt_infected_d/samtools_merge.bam.list' if $included_subpipelines{'post'};
        }
	}

# If we are indexing references in the pipeline, we need to change some config inputs
	if ($included_subpipelines{'indexing'}) {

		if ($donor_only){
			$config{'bwa_aln validation_d'}->{'$;INPUT_FILE$;'} = '';
			$config{'bwa_aln validation_d'}->{'$;INPUT_FILE_LIST$;'} = '$;REPOSITORY_ROOT$;/output_repository/lgt_build_bwa_index/$;PIPELINEID$;_donor/lgt_build_bwa_index.fsa.list';
		} else {
			unless ($skip_alignment) {
				# Change the host reference for bwa_aln
				$config{'bwa_aln recipient'}->{'$;INPUT_FILE$;'} = '';
				$config{'bwa_aln recipient'}->{'$;INPUT_FILE_LIST$;'} = '$;REPOSITORY_ROOT$;/output_repository/lgt_build_bwa_index/$;PIPELINEID$;_recipient/lgt_build_bwa_index.fsa.list';
			}
		}

		# If host only, add no-mapped alignment and post-NT blast alignment
		if ($host_only) {
			# Each individual genome is small enough to use 'is' instead of 'btwsw'
			$config{"lgt_build_bwa_index refseq"}->{'$;ALGORITHM$;'} = "is";

			$config{'bwa_aln validation_r'}->{'$;INPUT_FILE$;'} = '';
			$config{'bwa_aln validation_r'}->{'$;INPUT_FILE_LIST$;'} = '$;REPOSITORY_ROOT$;/output_repository/lgt_build_bwa_index/$;PIPELINEID$;_recipient/lgt_build_bwa_index.fsa.list';

			# Change the Refseq reference for bwa_aln
			$config{'bwa_aln lgt'}->{'$;INPUT_FILE$;'} = '';
			$config{'bwa_aln lgt'}->{'$;INPUT_FILE_LIST$;'} = '$;REPOSITORY_ROOT$;/output_repository/lgt_build_bwa_index/$;PIPELINEID$;_refseq/lgt_build_bwa_index.fsa.list';
		} else {
			unless ($skip_alignment) {
				# Change the donor reference for bwa_aln if not host-only run
				$config{'bwa_aln donor'}->{'$;INPUT_FILE$;'} = '';
				$config{'bwa_aln donor'}->{'$;INPUT_FILE_LIST$;'} = '$;REPOSITORY_ROOT$;/output_repository/lgt_build_bwa_index/$;PIPELINEID$;_donor/lgt_build_bwa_index.fsa.list';
			}
		}
	}

# If we are passing a directory to store important output files, then change a few parameters
	if ($included_subpipelines{'post'}){
		$config{'global'}->{'$;DATA_DIR$;'} = $options{data_directory};
		$config{"gather_lgtseek_files default"}->{'$;SKIP_WF_COMMAND$;'} = join ',', @gather_output_skip;
	}

	# open config file for writing
	open( my $pcfh, "> $pipeline_config") or &_log($ERROR, "Could not open $pipeline_config for writing: $!");

	# Write the config
	&write_config( \%config, $pcfh );

	# close the file handles
	close($plfh);
	close($pcfh);

	my $mode = 0755;
	chmod $mode, $pipeline_config;
	chmod $mode, $pipeline_layout;

	print "Wrote $pipeline_layout and $pipeline_config for LGT pipeline\n";
}

### UTILITY SUBROUTINES ###

sub write_config {
    my ($config, $fh) = @_;

    # Make sure this section is first
    &write_section( 'global', $config->{'global'}, $fh );
    delete( $config->{'global'} );

    foreach my $section ( keys %{$config} ) {
        &write_section( $section, $config->{$section}, $fh );
    }
}

sub write_section {
    my ($section, $config, $fh) = @_;
    print $fh "[$section]\n";

    foreach my $k ( sort keys %{$config} ) {
      print $fh "$k=$config->{$k}\n";
    }
    print $fh "\n";
}

sub add_config {
    my ($config, $subpipeline, $config_name) = @_;
	print $template_directory, "\t", $subpipeline, "\n";
    my $pc = "$template_directory/$subpipeline/pipeline.config";
    $pc = "$template_directory/$subpipeline/$config_name" if( $config_name );
    open(IN, "< $pc") or &_log($ERROR, "Could not open $pc for reading: $!");

    my $section;
    while(my $line = <IN> ) {
        chomp( $line );
        next if( $line =~ /^\s*$/ || $line =~ /^\;/ );

        if( $line =~ /^\[(.*)\]/ ) {
            $section = $1;
        } elsif( $line =~ /(\$\;.*\$\;)\s*=\s*(.*)/ ) {
            &_log($ERROR, "Did not find section before line $line") unless( $section );
            $config->{$section} = {} unless( exists( $config->{$section} ) );
            $config->{$section}->{$1} = $2;
        }
    }
    close(IN);
}

sub write_parallel_commandSet {
    my ($writer, $block) = @_;
    $writer->startTag("commandSet", 'type' => 'parallel');
    $writer->dataElement("state","incomplete");
    $block->($writer);
    $writer->endTag("commandSet");
}

sub write_pipeline_layout {
    my ($writer, $body) = @_;
    $writer->startTag("commandSetRoot",
                      "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
                      "xsi:schemaLocation" => "commandSet.xsd",
                      "type" => "instance" );

    $writer->startTag("commandSet",
                      "type" => "serial" );

    $writer->dataElement("state", "incomplete");
    $writer->dataElement("name", "start pipeline:");

    $body->($writer);

    $writer->endTag("commandSet");
    $writer->endTag("commandSetRoot");
}

sub write_include {
    my ($writer, $sub_pipeline, $pipeline_layout) = @_;
    $pipeline_layout = "pipeline.layout" unless( $pipeline_layout );
    my $sublayout = $template_directory."/$sub_pipeline/$pipeline_layout";
    &_log($ERROR, "Could not find sub pipeline layout $sublayout\n") unless( -e $sublayout );
    $writer->emptyTag("INCLUDE", 'file' => "$sublayout");
}

sub check_options {
   	my $opts = shift;
   	if( $opts->{'help'} ) {
       &_pod;
   	}

   	if( $opts->{'log'} ) {
       open( $logfh, "> $opts->{'log'}") or die("Can't open log file ($!)");
   	}

   	$debug = $opts->{'debug'} if( $opts->{'debug'} );

   	foreach my $req ( qw() ) {
       &_log($ERROR, "Option $req is required") unless( $opts->{$req} );
   	}

   	$outdir = $opts->{'output_directory'} if( $opts->{'output_directory'} );
   	$template_directory = $opts->{'template_directory'} if( $opts->{'template_directory'} );
   	$included_subpipelines{lgtseek} = 1;	# LGTSeek is required... duh!

	my $num_inputs = 0;
	foreach my $req ( qw(sra_id bam_input fastq_input) ) {
		$num_inputs++ if ($opts->{$req});
	}
	&_log($ERROR, "ERROR - Choose only one from an SRA ID, FASTQ file, and a BAM input file.") if $num_inputs > 1;
	&_log($ERROR, "ERROR - Must specify either an SRA ID, FASTQ file, or a BAM input file.") if $num_inputs < 1;

	if ($opts->{'sra_id'}) {
   		$included_subpipelines{sra} = 1;
	}
	if ($opts->{'bam_input'} || $opts->{'fastq_input'}) {
		$included_subpipelines{sra} = 0;
	}

	# If a data_dir is specified (like in Docker container), add post-analysis components
	$included_subpipelines{post} = 1 if $opts->{'data_directory'};

	# If donor reference is not present, then we have a host-only run
	$host_only = 1 unless ($opts->{'donor_reference'});

	# If host reference is not present, then we have a donor-only run
	$donor_only = 1 unless ($opts->{'host_reference'});

	# Specify LGT-infected option if provided
	$lgt_infected = 1 if ($opts->{'lgt_infected'});
	if ($lgt_infected && ($donor_only || $host_only)) {
		&_log($WARN, "WARNING - Must have both donor and recipient references in order to use 'lgt_infected' option ... ignoring");
		$lgt_infected = 0;
	}

	# If we need to build BWA reference indexes, then set option
	$included_subpipelines{indexing} = 1 if ( $opts->{'build_indexes'} );
	$skip_alignment = 1 if ( $opts->{'skip_alignment'} );

	&_log($ERROR, "ERROR - Need either a host_reference, a donor_reference or both provided") if ($donor_only && $host_only);

   print STDOUT "Perform alignments to the donor reference only.\n" if ($donor_only);
   print STDOUT "Perform alignments to the recipient reference only.\n" if ($host_only);
   print STDOUT "Recipient reference is infected with LGT.\n" if ($lgt_infected);
   print STDOUT "Perform BWA reference indexing in pipeline.\n" if ($included_subpipelines{indexing});
   print STDOUT "Starting point is BAM input.\n" if $opts->{bam_input};
   print STDOUT "Starting point is FASTQ input.\n" if $opts->{fastq_input};
   print STDOUT "Starting point is SRA ID. \n" if $opts->{sra_id};

}

sub _log {
   my ($level, $msg) = @_;
   if( $level <= $debug ) {
      print STDOUT "$msg\n";
   }
   print $logfh "$msg\n" if( defined( $logfh ) );
   exit(1) if( $level == $ERROR );
}

sub _pod {
    pod2usage( {-exitval => 0, -verbose => 2, -output => \*STDERR} );
}
