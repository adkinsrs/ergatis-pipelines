#!/usr/bin/env perl

=head1 NAME

haplotype_caller.pl - Wrapper script for GATK's HaplotypeCaller utility

=head1 SYNOPSIS

 USAGE: haplotype_caller.pl
       --input_file=/path/to/some/input.bam
       --output_file=/path/to/output.vcf
	   --reference_file=/path/to/ref.fa
     [ 
	   --stand_call_conf=20.0
	   --max_reads_stored=1000000
	   --no_soft_clipped_bases=1
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
	Required. File name for output VCF file

B<--reference_file>
	Required.  Path to FASTA file to serve as reference

B<--stand_call_conf>
	Optional. The minimum phred-scaled confidence threshold at which variants should be called.  Default is 30.0

B<--no_soft_clipped_bases>
	Optional.  If set to 1, will not use soft-clipped bases for analyses

B<--max_records_stored>
	Optional.  Number of records to store in RAM before spilling to disk.

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

############# GLOBALS AND CONSTANTS ################
my $debug = 1;
my ($ERROR, $WARN, $DEBUG) = (1,2,3);
my $logfh;

my $JAVA_PATH="/usr/bin/java";
my $GATK_JAR="/usr/local/packages/GATK-3.7/GenomeAnalysisTK.jar";

my @stringency = qw(STRICT LENIENT SILENT);
####################################################

my %options;

# Allow program to run as module for unit testing if necessary
main() unless caller();
exit(0);

sub main {
    my $results = GetOptions (\%options,
						 "input_file|i=s",
						 "output_file|o=s",
						 "reference_file|r=s",
						 "stand_call_conf=s",
						 "no_soft_clipped_bases=i",
						 "max_reads_stored=s",
						 "gatk_jar=s",
						 "java_path=s",
                         "log|l=s",
                         "debug|d=s",
                         "help|h"
                          );

    &check_options(\%options);

    my %picard_args = ( 
			'--input_file' => $options{'input_file'},
			'--out' => $options{'output_file'},
			'--reference_sequence' => $options{'reference_file'},
			'--maxReadsInMemory' => $options{'max_reads_stored'},
			'--standard_min_confidence_threshold_for_calling' => $options{'stand_call_conf'}
    );

    # Start building the Picard tools command
    my $cmd = $options{'java_path'}." ".$options{'gatk_jar'}." --analysis_type SplitNCigarReads ";


    # Add only passed in options to command
    foreach my $arg (keys %options) {
        $cmd .= "${arg}=".$options{$arg}." " if defined $options{$arg};
    }

	$cmd = "--dontUseSoftClippedBases " if ($options{"no_soft_clipped_bases"});

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

   foreach my $req ( qw(input_file output_file reference_file) ) {
       &_log($ERROR, "Option $req is required") unless( $opts->{$req} );
   }

   $opts->{'java_path'} = $JAVA_PATH if !$opts->{'java_path'};
   $opts->{'gatk_jar'} = $GATK_JAR if !$opts->{'gatk_jar'};

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
