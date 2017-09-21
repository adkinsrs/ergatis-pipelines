#!/usr/bin/env perl

=head1 NAME

split_spliced_reads.pl - Wrapper script for GATK's SplitNCigarReads utility

=head1 SYNOPSIS

 USAGE: split_spliced_reads.pl
       --config_file=/path/to/some/config/file
       --output_dir=/path/to/output/dir
     [ 
	   --gatk_jar=/path/to/gatk.jar
	   --java_path=/path/to/java
	   --log=/path/to/file.log
       --debug=3
       --help
     ]

=head1 OPTIONS

B<--config_file,-c>
	Required. Path to config file that lists parameters to use in this script

B<--output_dir,-o>
	Optional. Path to directory to write output to.  If not provided, use current directory

B<--gatk_jar>
	Optional. Path to the GATK JAR file.  If not provided, will use /usr/local/packages/GATK-3.7/GenomeAnalysisTK.jar

B<--java_path>
	Optional. Path to JAVA executable from Java 8 JDK.  If not provided, will use /usr/bin/java

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
						 "config_file|c=s",
						 "output_dir|o=s",
						 "gatk_jar=s",
						 "java_path=s",
						 "tmpdir|t=s",
                         "log|l=s",
                         "debug|d=s",
                         "help|h"
                          );

    &check_options(\%options);

    read_config(\%options, \%config);
	my $prefix = $config{'global'}{'PREFIX'}[0];

    my %args = ( 
			'--input_file' => $config{'split_spliced_reads'}{'INPUT_FILE'}[0],
			'--out' => $outdir."/$prefix.split.bam",
			'--reference_sequence' => $config{'global'}{'REFERENCE_FILE'}[0],
			'--maxReadsInMemory' => $config{'global'}{'MAX_READS_STORED'}[0],
			'--unsafe' => uc($config{'split_spliced_reads'}{'UNSAFE'}[0]),
			'--reassign_mapping_quality_from' => $config{'split_spliced_reads'}{'ORIG_MAPPING_QUALITY'}[0],
            '--reassign_mapping_quality_to' => $config{'split_spliced_reads'}{'DESIRED_MAPPING_QUALITY'}[0]
    );

	$config{'split_spliced_reads'}{'OTHER_OPTS'}[0] = '' if ! $config{'split_spliced_reads'}{'OTHER_OPTS'}[0];

	my $cmd = $options{'java_path'} . " -Djava.io.tmpdir=" .$options{tmpdir};
    if (defined $config{'split_spliced_reads'}{'Java_Memory'}) {
	    $cmd .= " $config{'split_spliced_reads'}{'Java_Memory'}[0]" ;
    }
    # Start building the Picard tools command
    $cmd .= " -jar ".$options{'gatk_jar'}." --analysis_type SplitNCigarReads -rf ReassignOneMappingQuality ";

    # Add only passed in options to command
    foreach my $arg (keys %args) {
        $cmd .= "${arg} ".$args{$arg}." " if defined $args{$arg};
	}

	# Add other misc parameters via a string
	$cmd .= $config{'split_spliced_reads'}{'OTHER_OPTS'}[0];

    exec_command($cmd);

	print STDOUT "GATK finished.  Now writing config file\n";
    my $config_out = "$outdir/split_spliced_reads." .$prefix.".config" ;
    $config{'realigner_target_creator'}{'Infile'}[0] = $outdir."/$prefix.split.bam";
    write_config(\%options, \%config, $config_out);
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
   $opts->{'gatk_jar'} = GATK_JAR if !$opts->{'gatk_jar'};

   $outdir = File::Spec->curdir();
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
