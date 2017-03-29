#!/usr/bin/env perl

=head1 NAME

picard_processing.pl - Wrapper script for several Picard utilities in the dRNASeq SNP pipeline

=head1 SYNOPSIS

 USAGE: picard_processing.pl
       --config_file=/path/to/some/config
     [ 
	   --output_dir=/path/to/output/dir
	   --picard_jar=/path/to/picard.jar
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

B<--picard_jar>
	Optional. Path to picard JAR file.  If not provided, will use /usr/local/packages/picard/bin/picard.jar

B<--java_path>
	Optiona. Path to JAVA executable from Java 8 JDK.  If not provided, will use /usr/bin/java

B<--log,-l>
    Logfile.

B<--debug,-d>
    1,2 or 3. Higher values more verbose.

B<--help,-h>
    Print this message

=head1  DESCRIPTION

 This script is a wrapper script for 3 utilities from the Picard-tools suite
 1) AddOrReplaceReadGroups - Add Read Group to BAM file
 2) MarkDuplicates - Mark duplicate reads in BAM file
 3) BuildBamIndex - Index resulting BAM file
 
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
use constant PICARD_JAR => "/usr/local/packages/picard/bin/picard.jar";

my @stringency = qw(STRICT LENIENT SILENT);
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
						 "picard_jar=s",
						 "java_path=s",
                         "log|l=s",
                         "debug|d=s",
                         "help|h"
                          );


    $outdir = File::Spec->curdir();
    &check_options(\%options);

    read_config(\%options, \%config);

    if ( defined $config{'validation_stringency'} && none{$_ eq uc($config{'validation_stringency'})} @stringency ) {
        &_log($ERROR, $config{'validation_stringency'}." is not a valid option.  Choose from 'SILENT', 'LENIENT', or 'STRICT'");
    }

    my %picard_args = ( 
			'INPUT' => $config{'input_file'},
			'OUTPUT' => $outdir."/add_read_group.bam" ,
			'RGID' => $config{'id'},
			'RGLB' => $config{'library'},
			'RGPL' => $config{'platform'},
			'RGPU' => $config{'platform_unit'},
			'RGSM' => $config{'sample_name'},
			'VALIDATION_STRINGENCY' => uc($config{'validation_stringency'}),
			'MAX_RECORDS_IN_RAM' => $config{'max_records_stored'}
    );

    # Start building the Picard tools command
    my $cmd = $options{'java_path'}." ".$options{'picard_jar'}." AddOrReplaceReadGroups ";

    # Add only passed in options to command
    foreach my $arg (keys %options) {
        $cmd .= "${arg}=".$options{$arg}." " if defined $options{$arg};
    }

    exec_command($cmd);

    my $config_out = "$outdir/picard_processing." .$config{'picard_processing'}{'Prefix'}[0].".config" ;
    $config{'split_spliced_reads'}{'Prefix'}[0] = "$config{'picard_processing'}{'Prefix'}[0]";
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
   $opts->{'picard_jar'} = PICARD_JAR if !$opts->{'picard_jar'};

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
