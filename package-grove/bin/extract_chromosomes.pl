#!/usr/bin/env perl

=head1 NAME

extract_chromosomes.pl - Use samtools view to filter reads to those only from chromosomes

=head1 SYNOPSIS

 USAGE: extract_chromosomes.pl
       --config_file=/path/to/some/config.txt
       --output_dir=/path/to/output/dir
     [ 
	   --tmp_dir=/path/to/tmp
	   --samtools_bin=/path/to/samtools
	   --log=/path/to/file.log
       --debug=3
       --help
     ]

=head1 OPTIONS

B<--config_file,-c>
	Required. Path to config file that lists parameters to use in this script

B<--output_dir,-o>
	Optional. Path to directory to write output to.  If not provided, use current directory

B<--tmpdir,-t>
	Optional. Path to directory to write temporary files to.  If not provided, use /tmp

B<--samtools_bin>
	Optional. Path to the samtools bin directory.  If not provided, will use /usr/local/bin/

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

use constant SAMTOOLS_BIN => "/usr/local/bin/";
use constant TMP_DIR => "/tmp";
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
						 "tmpdir|t=s",
						 "samtools_bin=s",
                         "log|l=s",
                         "debug|d=s",
                         "help|h"
                          );

    &check_options(\%options);
    read_config(\%options, \%config);

    my $prefix = $config{'global'}{'PREFIX'}[0];

    my %args = ( 
			'-o' => $outdir."/$prefix.extract_chromosomes.bam",
    );

    # Start building the Samtools command
	my $tmp_dir_env = "TMP_DIR=".$options{'tmpdir'} . " ";
	my $groups_str = " 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 X Y MT";

    my $cmd = $tmp_dir_env . $options{'samtools_bin'}."/samtools view -b ";

    # Add only passed in options to command
    foreach my $arg (keys %args) {
        $cmd .= "${arg} ".$args{$arg}." " if defined $args{$arg};
    }

	$cmd .= $config{'extract_chromosomes'}{'INPUT_FILE'}[0] . " $groups_str";

    exec_command($cmd);

    my $config_out = "$outdir/extract_chromosomes." .$prefix.".config" ;
    $config{'preprocess_alignment'}{'INPUT_FILE'}[0] = $outdir."/$prefix.extract_chromosomes.bam";
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

   $opts->{'samtools_bin'} = SAMTOOLS_BIN if !$opts->{'samtools_bin'};
   $opts->{'tmp_dir'} = TMP_DIR if !$opts->{'tmp_dir'};

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
