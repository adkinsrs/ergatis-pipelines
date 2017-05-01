#!/usr/bin/env perl

=head1 NAME

preprocess_alignment.pl - Wrapper script for several Picard utilities in the dRNASeq SNP pipeline

=head1 SYNOPSIS

 USAGE: preprocess_alignment.pl
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

 This script is a wrapper script for 2 utilities from the Picard-tools suite
 1) ReorderSam - Reorder reads to match contig ordering in reference file
 2) SortSam - Sort reads in BAM file by coordinate
 
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
use List::MoreUtils qw(none);
use File::Spec;
use NICU::Config;

############# GLOBALS AND CONSTANTS ################
my $debug = 1;
my ($ERROR, $WARN, $DEBUG) = (1,2,3);
my $logfh;

use constant JAVA_PATH => "/usr/bin/java";
use constant PICARD_JAR => "/usr/local/packages/picard/bin/picard.jar";

my @stringency_arr = qw(STRICT LENIENT SILENT);
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
						 "tmpdir|t=s",
                         "log|l=s",
                         "debug|d=s",
                         "help|h"
                          );

    &check_options(\%options);

    read_config(\%options, \%config);
	my $prefix = $config{'preprocess_alignment'}{'Prefix'}[0];
	my $stringency = uc($config{'preprocess_alignment'}{'VALIDATION_STRINGENCY'}[0]);
	my $max_records = $config{'preprocess_alignment'}{'MAX_RECORDS_STORED'}[0];

    if ( defined $stringency && none{$_ eq $stringency} @stringency_arr ) {
        &_log($ERROR, $stringency." is not a valid option.  Choose from 'SILENT', 'LENIENT', or 'STRICT'");
    }

	### ReorderSam ###
    my %args = ( 
			'INPUT' => $config{'preprocess_alignment'}{'INPUT_FILE'}[0],
			'OUTPUT' => $outdir."/$prefix.reorder.bam" ,
			'REFERENCE' => $config{'preprocess_alignment'}{'REFERENCE'}[0],
			'VALIDATION_STRINGENCY' => $stringency,
			'MAX_RECORDS_IN_RAM' => $max_records,
			'CREATE_INDEX' => "TRUE"
    );

    # Start building the Picard tools command
	my $cmd = $options{'java_path'} . " -Djava.io.tmpdir=" .$options{tmpdir};
    if (defined $config{'preprocess_alignment'}{'Java_Memory'}) {
	    $cmd .= " $config{'preprocess_alignment'}{'Java_Memory'}[0]" ;
    }
	$cmd .= " -jar ".$options{'picard_jar'}." ReorderSam ";

    # Add only passed in options to command
    foreach my $arg (keys %args) {
        $cmd .= "${arg}=".$args{$arg}." " if defined $args{$arg};
    }

    exec_command($cmd);

	### SortSam ###
    %args = ( 
			'INPUT' => $outdir."/$prefix.reorder.bam",
			'OUTPUT' => $outdir."/$prefix.sorted.bam" ,
			'VALIDATION_STRINGENCY' => $stringency,
			'MAX_RECORDS_IN_RAM' => $max_records,
			'SORT_ORDER' => "coordinate"
    );

	$cmd = $options{'java_path'} . " -Djava.io.tmpdir=" .$options{tmpdir};
    if (defined $config{'preprocess_alignment'}{'Java_Memory'}) {
	    $cmd .= " $config{'preprocess_alignment'}{'Java_Memory'}[0]" ;
    }
    # Start building the Picard tools command
    $cmd .= " -jar ".$options{'picard_jar'}." SortSam ";

    # Add only passed in options to command
    foreach my $arg (keys %args) {
        $cmd .= "${arg}=".$args{$arg}." " if defined $args{$arg};
    }

    exec_command($cmd);

    my $config_out = "$outdir/preprocess_alignment." .$prefix.".config" ;
    $config{'picard_processing'}{'INPUT_FILE'}[0] = $outdir."/$prefix.sorted.bam";
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
   $opts->{'picard_jar'} = PICARD_JAR if !$opts->{'picard_jar'};

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
