#!/usr/bin/env perl

=head1 NAME

determine_lgt_from_best_hit.pl - Wrapper script to find LGT hits between donor and host

=head1 SYNOPSIS

 USAGE: determine_lgt_from_best_hit.pl
       --euk_hits=/path/to/euk_hits.m8
       --bac_hits=/path/to/bac_hits.m8
       --output_dir=/path/to/output/dir
       --aligned_list=/path/to/reads.list
       --aligned_reference=donor/recipient
	     [
       --output_prefix=lgt
	     --log=/path/to/file.log
       --debug=3
       --help
       ]

=head1 OPTIONS

B<--euk_hits, -e>
  Path to Blast m8 file of read hits to Eukaryota lineage.  Alternatively a list file pointing to this file can be provided.

B<--bac_hits, -b>
  Path to Blast m8 file of read hits to Bacteria lineage. Alternatively a list file pointing to this file can be provided.

B<--aligned_list, -a>
  List of LGT reads known to align to a particular reference.  Alternatively accepts a list file pointing to an ".aligned.reads" file.  Currently designed with the assumption only one file is in the list file.

B<--aligned_reference, -r>
  Choose from 'donor' or 'recipient'.  The type of reference the reads from --aligned_list aligned to.

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
    2 files - Can be a list file pointing to a file
    1) Hits to the Eukaryota lineage
    2) Hits to the Bacteria lineage

	List of reads in the read pair that aligned to the reference
	Can be a list file

	Identity of the reference (donor or recipient)

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
use LGT::Common;

############# GLOBALS AND CONSTANTS ################
my $debug = 1;
my ( $ERROR, $WARN, $DEBUG ) = ( 1, 2, 3 );
my $logfh;
my $read_scores;  #hashref
my $read_hits;  #hashref

####################################################
my %options;
my $REFERENCE = 'donor';
my $infile;

my ( $euk_file, $bac_file );

my $results = GetOptions(
    \%options,          'euk_hits|e=s',
    'bac_hits|b=s',     "output_dir|o=s",
    "aligned_list|a=s", "aligned_reference|r=s",
    "log|l=s",          "debug|d=s",
    "help|h"
);

&check_options( \%options );

# This this is a pipeline-specific script, making assumption list file points to one output file or has the output directly.
open IN, $options{'aligned_list'}
  or &_log( $ERROR, "Cannot open for reading:$!\n" );
while (<IN>) {
    chomp;
    # List file will have a ".reads" file but ".reads" files will have alignments for first line
    if (/.reads$/) {
      &_log($DEBUG, "Determined " . $options{'aligned_list'} . " to be a list file");
      $infile = $_;
    } else {
        $infile = $options{'aligned_list'};
    }
    last;
}
close IN;
my $aligned_reads = store_aligned_reads($infile);

store_m8_hits( $bac_file, 'bac' );
store_m8_hits( $euk_file, 'euk' );

# Right now, the only use-cases where a read may have hits in both lineages would be use-case 1 and 2
calc_hscore_of_reads( $options{'output_dir'} );
write_final_LGT( $options{'output_dir'}, $aligned_reads, $REFERENCE );

exit(0);

sub calc_hscore_of_reads {
    my $outfile = shift . "/scores.txt";
	&_log( $DEBUG, "Now calculating h-score of reads ..." );
    open OFH,
      ">$outfile" || &_log( $ERROR, "Cannot open $outfile for writing: $!" );
    print OFH "#read\th_score\teuk/prok_ratio\n";
    foreach my $read ( keys %{$read_scores} ) {
		#
        # Does a read have hits in both lineage types?
        if ( defined $read_scores->{$read}->{'bac'}
            && defined $read_scores->{$read}->{'euk'} )
        {
            my $h_score =
              $read_scores->{$read}->{'euk'} - $read_scores->{$read}->{'bac'};
            my $ratio =
              $read_scores->{$read}->{'euk'} / $read_scores->{$read}->{'bac'};
            print OFH "$read\t$h_score\t$ratio\n";
        }
    }
    close OFH;
}

sub store_aligned_reads {
    my $reads_file = shift;
    my %aligned_reads;
	&_log( $DEBUG, "Now storing $reads_file ..." );
    open ALN,
      $reads_file || &_log( $ERROR, "Cannot open $reads_file for reading: $!" );
    while (<ALN>) {
        chomp;
        $aligned_reads{$_} = 1;
    }
    close ALN;
    return \%aligned_reads;
}

sub store_m8_hits {
    my ( $m8_hits, $ref ) = @_;
	&_log( $DEBUG, "Now storing $m8_hits ..." );
    open M8,
      $m8_hits || &_log( $ERROR, "Cannot open $m8_hits for reading: $!" );
    while (<M8>) {
        chomp;
        my @fields = split(/\t/);
        my $id     = $fields[0];
        my $bit    = $fields[11];
        $read_scores->{$id}->{$ref} = $bit;

        # There can be multiple best hits, tied for bitscore.
        push @{ $read_hits->{$id}->{$ref} }, $_;
    }
    close M8;
}

sub write_final_LGT {
    my ( $outdir, $aligned_reads, $aligned_ref ) = @_;
    my $outfile = $outdir . "/lgt_by_clone.txt";
    my %seen_hits;
	&_log( $DEBUG, "Writing final LGT information to $outfile ...");
    open OFH,
      ">$outfile" || &_log( $ERROR, "Cannot open $outfile for writing: $!" );
    foreach my $read ( keys %{$read_hits} ) {

        # Only want to process unseen readpairs
        if ( !exists $seen_hits{$read} ) {
            if ( exists $aligned_reads->{$read} ) {

              my $read_mate;
              my $clone;
              if ( $read =~ /(.*)([\_\/])(\d)/ ) {
                  $clone = $1;
                  if ( $3 eq '1' ) {
                      $read_mate = $1 . $2 . "2";
                  } elsif ( $3 eq '2' ) {
                      $read_mate = $1 . $2 . "1";
                  } else {
                      &_log( $ERROR,
                          "Read $read did not end in '1' or '2'.  This read may be unpaired.  Cannot proceed unless mate can be determined."
                      );
                  }
                }

                my ( $d_trace, $r_trace );
                if ( $aligned_ref eq 'donor' ) {
                    $d_trace = $read;
                    $r_trace = $read_mate;
                } else {
                    $d_trace = $read_mate;
                    $r_trace = $read;
                }

				print "$d_trace\t$r_trace\n";
                next if ! defined $read_hits->{$d_trace}->{'euk'}
                  || ! defined $read_hits->{$r_trace}->{'bac'};

                # Want donors found in Euks and recipients found in Bacs from Blastn
                my (@d_fields, @r_fields);    # Can have multiple m8 entries for 'best_hit'
                foreach my $hit ( @{$read_hits->{$d_trace}->{'euk'}} ) {
                  my @entry = split( /\t/, $hit );
                  push( @d_fields, \@entry );
                }
                foreach my $hit ( @{$read_hits->{$r_trace}->{'bac'}} ) {
                  my @entry = split( /\t/, $hit );
                  push( @r_fields, \@entry );
                }

                #Donor hit info
                my @d_generas;
                my $d_lca;
                my $d_evalue;
                my $d_align_len;
                foreach my $entry (@d_fields) {
                  push @d_generas, $entry->[13];
                  $d_lca = $entry->[14] if ( !defined $d_lca );
                  $d_lca = find_lca( [$entry->[14], $d_lca] );
                  # Ideally e_value and length of alignment should be same for all tied hits
                  $d_evalue = $entry->[10];
                  $d_align_len = $entry->[3];
                }
                my $d_genera = join( ",", @d_generas );

                my $d_filter_hit = 0;    # For now not filtering lineage
                my @d_parts =
                  ( $d_trace, $d_evalue, $d_align_len, $d_lca, $d_filter_hit );

                #Recipient hit info
                my @r_generas;
                my $r_lca;
                my $r_evalue;
                my $r_align_len;
                foreach my $entry (@r_fields) {
                  push @r_generas, $entry->[13];
                  $r_lca = $entry->[14] if ( !defined $r_lca );
                  $r_lca       = find_lca( [$entry->[14], $r_lca] );
                  $r_evalue    = $entry->[10];
                  $r_align_len = $entry->[3];
                }
                my $r_genera = join( ",", @r_generas );

                my $r_filter_hit = 0;
                my @r_parts =
                  ( $r_trace, $r_evalue, $r_align_len, $r_lca, $r_filter_hit );

                # Putting it all together...
                print OFH "$clone\t$d_genera\t$r_genera\t";
                print OFH join( "\t", @d_parts ) . "\t";
                print OFH join( "\t", @r_parts ) . "\n";

                $seen_hits{$read}      = 1;
                $seen_hits{$read_mate} = 1;
            }
        }
    }
    close OFH;
}

sub check_options {
    my $opts = shift;
    if ( $opts->{'help'} ) {
        &_pod;
    }

    if ( $opts->{'log'} ) {
        open( $logfh, "> $opts->{'log'}" ) or die("Can't open log file ($!)");
    }

    $debug = $opts->{'debug'} if ( $opts->{'debug'} );

    foreach
      my $req (qw( output_dir euk_hits bac_hits aligned_list aligned_reference))
    {
        &_log( $ERROR, "Option $req is required" ) unless ( $opts->{$req} );
    }

# If hits are in lists.  Extract them.  Assuming only 1 hits file is in a given list.
    if ( $opts->{'euk_hits'} =~ /\.list$/ ) {
        open LIST, $opts->{'euk_hits'}
          || die "Cannot open $opts->{'euk_hits'} for reading: $!";
        while (<LIST>) {
            chomp;
            &_log($DEBUG, "Determined " . $opts->{'euk_hits'} . " to be a list file");
            $euk_file = $_;
        }
        close LIST;
    } else {
        $euk_file = $opts->{'euk_hits'};
    }

    if ( $opts->{'bac_hits'} =~ /\.list$/ ) {
        open LIST, $opts->{'bac_hits'}
          || die "Cannot open $opts->{'bac_hits'} for reading: $!";
        while (<LIST>) {
            chomp;
            &_log($DEBUG, "Determined " . $opts->{'bac_hits'} . " to be a list file");
            $bac_file = $_;
        }
        close LIST;
    } else {
        $bac_file = $opts->{'bac_hits'};
    }

    if ( lc( $opts->{'aligned_reference'} ) !~ /donor|host|recipient/ ) {
        &_log( $ERROR,
            "--aligned_reference argument must be 'donor' or 'recipient'." );
    }

    if ( lc( $opts->{'aligned_reference'} ) =~ /host|recipient/ ) {
        $REFERENCE = 'recipient';
    }

}

sub _log {
    my ( $level, $msg ) = @_;
    if ( $level <= $debug ) {
        print STDOUT "$msg\n";
    }
    print $logfh "$msg\n" if ( defined($logfh) );
    exit(1) if ( $level == $ERROR );
}

sub _pod {
    pod2usage( { -exitval => 0, -verbose => 2, -output => \*STDERR } );
}
