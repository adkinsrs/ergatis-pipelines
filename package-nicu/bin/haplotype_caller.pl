#!/usr/bin/env perl

=head1 NAME

haplotype_caller.pl - Wrapper script for GATK's HaplotypeCaller utility

=head1 SYNOPSIS

 USAGE: haplotype_caller.pl
       --config_file=/path/to/some/config.txt
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
						 "config_file|c=s",
						 "output_dir|o=s",
						 "gatk_jar=s",
						 "java_path=s",
                         "log|l=s",
                         "debug|d=s",
                         "help|h"
                          );

    &check_options(\%options);
    read_config(\%options, \%config);

    my %picard_args = ( 
			'--input_file' => $config{'input_file'},
			'--out' => $outdir,
			'--reference_sequence' => $config{'reference_file'},
			'--maxReadsInMemory' => $config{'max_reads_stored'},
			'--standard_min_confidence_threshold_for_calling' => $config{'stand_call_conf'}
    );

    # Start building the Picard tools command
    my $cmd = $options{'java_path'}." ".$options{'gatk_jar'}." --analysis_type HaplotypeCaller ";


    # Add only passed in options to command
    foreach my $arg (keys %config) {
        $cmd .= "${arg}=".$config{$arg}." " if defined $config{$arg};
    }

	$cmd = "--dontUseSoftClippedBases " if ($config{"no_soft_clipped_bases"} == 1);

    exec_command($cmd);

    my $config_out = "$outdir/haplotype_caller." .$config{'haplotype_caller'}{'Prefix'}[0].".config" ;
    $config{'variant_filtration'}{'Prefix'}[0] = "$config{'haplotype_caller'}{'Prefix'}[0]";
    write_config($options, \%config, $config_out);
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
