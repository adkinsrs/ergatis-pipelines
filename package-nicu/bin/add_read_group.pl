#!/usr/bin/env perl

=head1 NAME

add_read_group.pl - Wrapper script for Picard's AddOrReplaceReadGroup utility

=head1 SYNOPSIS

 USAGE: add_read_group.pl
       --input_file=/path/to/some/input.bam
       --output_file=/path/to/output.bam
	   --library=lib1
	   --platform=illumina
	   --platform_unit=abc123
	   --sample_name=sample1
     [ 
	   --id=1
	   --validation_stringency=lenient
	   --max_records_in_RAM=1000000
	   --picard_jar=/path/to/picard.jar
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

B<--id>
	Optional. Read Group ID number.  Will assign to 1 if not provided.

B<--library>
	Required. Read Group library string name

B<--platform>
	Required. Platform the reads originated from (eg. illumina or solid)

B<--platform_unit>
	Required. Platform unit (eg. run barcode)

B<--sample_name>
	Required.  Read Group sample name

B<--validation_stringency>
	Optional.  Validation stringency for all SAM/BAM files read in by Picard Tools.  Possible values are "STRICT" (default if not provided), "LENIENT", or "SILENT"

B<--max_records_stored>
	Optional.  Number of records to store in RAM before spilling to disk.  Default is 500000.

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
my $PICARD_JAR="/usr/local/packages/picard/bin/picard.jar";

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
						 "id=i",
						 "sample_name=s",
						 "library=s",
						 "platform=s",
						 "platform_unit=s",
						 "validation_stringency=s",
						 "max_records_stored=s",
						 "picard_jar=s",
						 "java_path=s",
                         "log|l=s",
                         "debug|d=s",
                         "help|h"
                          );

    &check_options(\%options);

    my %picard_args = ( 
			'INPUT' => $options{'input_file'},
			'OUTPUT' => $options{'output_file'},
			'RGID' => $options{'id'},
			'RGLB' => $options{'library'},
			'RGPL' => $options{'platform'},
			'RGPU' => $options{'platform_unit'},
			'RGSM' => $options{'sample_name'},
			'VALIDATION_STRINGENCY' => $options{'validation_stringency'},
			'MAX_RECORDS_IN_RAM' => $options{'max_records_stored'}
    );

    # Start building the Picard tools command
    my $cmd = $options{'java_path'}." ".$options{'picard_jar'}." AddOrReplaceReadGroups ";

    # Add only passed in options to command
    foreach my $arg (keys %options) {
        $cmd .= "${arg}=".$options{$arg}." " if defined $options{$arg};
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

   foreach my $req ( qw(input_file output_file library sample_name platform platform_unit) ) {
       &_log($ERROR, "Option $req is required") unless( $opts->{$req} );
   }

   $opts->{'java_path'} = $JAVA_PATH if !$opts->{'java_path'};
   $opts->{'picard_jar'} = $PICARD_JAR if !$opts->{'picard_jar'};

   if ( defined $opts->{'validation_stringency'} && none{$_ eq uc($opts->{'validation_stringency'})} @stringency ) {
       &_log($ERROR, $opts->{'validation_stringency'}." is not a valid option.  Choose from 'SILENT', 'LENIENT', or 'STRICT'");
   }
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
