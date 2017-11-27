#!/usr/bin/env perl
=head1 NAME

determine_lgt_from_best_hit.pl - Wrapper script to find LGT hits between donor and host

=head1 SYNOPSIS

 USAGE: determine_lgt_from_best_hit.pl
       --euk_hits=/path/to/euk_hits.m8
       --bac_hits=/path/to/bac_hits.m8
       --output_dir=/path/to/output/dir
	     [
       --output_prefix=lgt
	     --log=/path/to/file.log
       --debug=3
       --help
       ]

=head1 OPTIONS

B<--euk_hits, -e>
  Path to Blast m8 file of read hits to Eukaryota lineage

B<--bac_hits, -b>
  Path to Blast m8 file of read hits to Bacteria lineage

B<--output_dir,-o>
	Path name to output directory.

B<--log,-l>
    Logfile.

B<--debug>
    1,2 or 3. Higher values more verbose.

B<--help>
    Print this message

=head1  DESCRIPTION

 DESCRIPTION

=head1  INPUT

    BlastN results that have been formatted into the m8 format.
    2 files
    1) Hits to the Eukaryota lineage
    2) Hits to the Bacteria lineage

=head1 OUTPUT

  Tab-delimited output file with the following fields:
  1) Read name
  2) Best Euk hit bitscore
  3) Best Bacteria hit bitscore
  4) Euk bit / Bac bit
  5) Euk bit - Bac bit (also known as h-score)

=head1  CONTACT

    Shaun Adkins
    sadkins@som.umaryland.edu

=cut

use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use Pod::Usage;
use LGT::LGTFinder;

############# GLOBALS AND CONSTANTS ################
my $debug = 1;
my ($ERROR, $WARN, $DEBUG) = (1,2,3);
my $logfh;

####################################################

my %options;

my $results = GetOptions (\%options,
             'euk_hits|e=s',
             'bac_hits|b=s',
             "output_dir|o=s",
                         "log|l=s",
                         "debug|d=s",
                         "help|h"
                          );

&check_options(\%options);

exit(0);

sub check_options {
   my $opts = shift;
   if( $opts->{'help'} ) {
       &_pod;
   }

   if( $opts->{'log'} ) {
       open( $logfh, "> $opts->{'log'}") or die("Can't open log file ($!)");
   }

   $debug = $opts->{'debug'} if( $opts->{'debug'} );

   foreach my $req ( qw( output_dir euk_hits bac_hits ) ) {
       &_log($ERROR, "Option $req is required") unless( $opts->{$req} );
   }

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
