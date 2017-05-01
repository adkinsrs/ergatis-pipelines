#!/usr/bin/env perl

=head1 NAME

run_annovar.pl - Wrapper script for table_annovar.pl, which annotates filtered variants from input

=head1 SYNOPSIS

 USAGE: run_annovar.pl
       --config_file=/path/to/some/config.txt
       --output_dir=/path/to/output/dir
     [ 
	   --tmpdir=/path/to/tmp
	   --annovar_bin=/usr/bin/annovar
	   --log=/path/to/file.log
       --debug=3
       --help
     ]

=head1 OPTIONS

B<--config_file,-c>
	Required. Path to config file that lists parameters to use in this script

B<--output_dir,-o>
	Optional. Path to directory to write output to.  If not provided, use current directory

B<--annovar_bin>
	Optional. Path to the samtools bin directory.  If not provided, will use /usr/local/packages/annovar/

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

use constant ANNOVAR_BIN => "/usr/local/packages/annovar/";
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
						 "annovar_bin=s",
                         "log|l=s",
                         "debug|d=s",
                         "help|h"
                          );

    &check_options(\%options);
    read_config(\%options, \%config);

    my $prefix = $config{'annovar'}{'Prefix'}[0];

    my %args = ( 
			'-outfile' => $outdir."/$prefix.annovar.tbl",
			'-protocol' => $config{'annovar'}{'PROTOCOL'}[0],
			'-buildver' => $config{'annovar'}{'BUILDVER'}[0],
			'-operation' => $config{'annovar'}{'OPERATION'}[0],
			'-nastring' => $config{'annovar'}{'NASTRING'}[0]
    );

    # Start building the annovar command
    my $cmd =  $options{'annovar_bin'}."/table_annovar.pl ";

	$cmd .= $config{'annovar'}{'INPUT_FILE'}[0] . ' ';
	$cmd .= $config{'annovar'}{'DB_PATH'}[0] . ' ';

    # Add only passed in options to command
    foreach my $arg (keys %args) {
        $cmd .= "${arg} ".$args{$arg}." " if defined $args{$arg};
    }

	$cmd .= "-remove" if $config{'annovar'}{'REMOVE'} == 1;
	$cmd .= "-vcfinput" if $config{'annovar'}{'VCFINPUT'} == 1;
	$cmd .= $config{'annovar'}{'OTHER_ARGS'} if $config{'annovar'}{'OTHER_ARGS'};

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

   $opts->{'annovar_bin'} = ANNOVAR_BIN if !$opts->{'annovar_bin'};

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
