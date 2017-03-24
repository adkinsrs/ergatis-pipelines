#!/usr/bin/env perl

=head1 NAME

split_spliced_reads.pl - Wrapper script for GATK's SplitNCigarReads utility

=head1 SYNOPSIS

 USAGE: split_spliced_reads.pl
       --input_file=/path/to/some/input.bam
       --output_file=/path/to/output.bam
	   --reference_file=/path/to/ref.fa
     [ 
	   --read_filter=ReassignOneMappingQuality
	   --max_reads_stored=1000000
	   --unsafe=ALLOW_N_CIGAR_READS
	   --gatk_jar=/path/to/gatk.jar
	   --java_path=/path/to/java
	   --log=/path/to/file.log
       --debug=3
       --help
     ]

=head1 OPTIONS

B<--input_file,-i>
	Required. Path to BAM file to serve as input

B<--output_file,-o>
	Required. File name for output BAM file

B<--reference_file>
	Required.  Path to FASTA file to serve as reference

B<--read_filter>
	Optional. Reads that fail the specified filters will not be used in the analysis.  Pass in each filter as a comma-separated list.

B<--max_records_stored>
	Optional.  Number of records to store in RAM before spilling to disk.

B<--unsafe>
	Optional.  Enable unsafe operations: nothing will be checked at runtime.  For RNAseq analysis, "ALLOW_N_CIGAR_READS" should be passed in.

B<--gatk_jar>
	Optional. Path to the GATK JAR file.  If not provided, will use /usr/local/packages/GATK-3.7/GenomeAnalysisTK.jar

B<--java_path>
	Optiona. Path to JAVA executable from Java 8 JDK.  If not provided, will use /usr/bin/java

B<--log,-l>
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
use List::Util;
use File::Spec;
use NICU::Config;

############# GLOBALS AND CONSTANTS ################
my $debug = 1;
my ($ERROR, $WARN, $DEBUG) = (1,2,3);
my $logfh;

use constant JAVA_PATH => "/usr/bin/java";
use constant GATK_JAR => "/usr/local/packages/GATK-3.7/GenomeAnalysisTK.jar";
####################################################

my %options;
my %config;
my $outdir;

# Allow program to run as module for unit testing if necessary
main() unless caller();
exit(0);

sub main {
    my $results = GetOptions (\%options,
						 "input_file|i=s",
						 "output_file|o=s",
						 "reference_file|r=s",
						 "read_filter=s",
						 "max_reads_stored=s",
						 "unsafe=s",
						 "gatk_jar=s",
						 "java_path=s",
                         "log|l=s",
                         "debug|d=s",
                         "help|h"
                          );

    $outdir = File::Spec->curdir();
    &check_options(\%options);

    my %picard_args = ( 
			'--input_file' => $options{'input_file'},
			'--out' => $options{'output_file'},
			'--reference_sequence' => $options{'reference_file'},
			'--maxReadsInMemory' => $options{'max_reads_stored'},
			'--unsafe' => uc($options{'unsafe'}
    );

    # Start building the Picard tools command
    my $cmd = $options{'java_path'}." ".$options{'gatk_jar'}." --analysis_type SplitNCigarReads ";

    # Add only passed in options to command
    foreach my $arg (keys %options) {
        $cmd .= "${arg}=".$options{$arg}." " if defined $options{$arg};
    }

	# Split csv list of filters and add as individual options
    if ($options{'read_filter'}) {
		$cmd .= '--read_filter ';
		my @filters = split(/,/, $options{'read_filter'});
		$cmd .= join '--read_filter ', @filters;
	}

    exec_command($cmd);

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

   foreach my $req ( qw(config_file) ) {
       &_log($ERROR, "Option $req is required") unless( $opts->{$req} );
   }

   $opts->{'java_path'} = JAVA_PATH if !$opts->{'java_path'};
   $opts->{'gatk_jar'} = GATK_JAR if !$opts->{'picard_jar'};

    if (defined $opts->{'output_dir'}) {
        $outdir = $opts->{'output_dir'};

        if (! -e $outdir) {
           mkdir($opts->{'output_dir'}) ||
            die "ERROR! Cannot create output directory\n";
        } elsif (! -d $opts->{'output_dir'}) {
            die "ERROR! $opts->{'output_dir'} is not a directory\n";
        }
    }
    $outdir = File::Spec->canonpath($outdir);
}
sub exec_command {
	my $sCmd = shift;
	
	if ((!(defined $sCmd)) || ($sCmd eq "")) {
		&_log($ERROR,"\nSubroutine::exec_command : ERROR! Incorrect command!\n");
	}
	
	my $nExitCode;
	
	print STDERR "$sCmd\n";
	$nExitCode = system("$sCmd");
	if ($nExitCode != 0) {
		&_log($ERROR, "\tERROR! Command Failed!\n\t$!\n");
	}
	print STDERR "\n";
}

sub _log {
   my ($level, $msg) = @_;
   if( $level <= $debug ) {
      print STDERR "$msg\n";
   }
   print $logfh "$msg\n" if( defined( $logfh ) );
   exit(1) if( $level == $ERROR );
}

sub _pod {
    pod2usage( {-exitval => 0, -verbose => 2, -output => \*STDERR} );
}
