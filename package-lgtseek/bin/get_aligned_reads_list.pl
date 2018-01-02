#!/usr/bin/env perl
=head1 NAME

get_aligned_reads_list.pl - Create list of reads that aligned to the reference in the BAM

=head1 SYNOPSIS

 USAGE: get_aligned_reads_list.pl
       --input_file=/path/to/some/input.bam
       --output_dir=/path/to/output/dir
     [
       --input_list=/path/to/input.list
       --samtools_path=/usr/bin/samtools
       --log=/path/to/file.log
       --debug=3
       --help
     ]

=head1 OPTIONS

B<--input_file,-i>
	A paired-end BAM file

B<--input_list,-I>
  A list of BAM files

B<--output_dir, -o>
  Output directory to write list to

B<--samtools_path, -s>
  Location of the samtools executable

B<--log,-l>
    Logfile.

B<--debug>
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
use File::Basename;
use LGT::Common;

my $debug = 1;
my ($ERROR, $WARN, $DEBUG) = (1,2,3);
my $logfh;

my $SAMTOOLS_BIN = "/usr/local/bin/samtools";
my $UNMAPPED_BIT = 4;
my @input_files;
my @empty_files;

my %options;
my $results = GetOptions (\%options,
                         "input_file|i=s",
                         "input_list|I=s",
                         "output_dir|o=s",
                         "samtools_path|s=s",
                         "log|l=s",
                         "debug=s",
                         "help|h"
                          );

&check_options(\%options);

# Ensure all input BAMs have reads.
foreach my $bam (@input_files) {
  my $count = check_empty_file($bam);
  push @empty_files, $bam if ($count == 0);
}
if (scalar @empty_files > 0) {
  print STDERR "The following BAM files were empty. Exiting and not creating output.\n";
  print STDERR "$_\n" foreach  @empty_files ;
  exit(1);
}

foreach my $bam (@input_files) {
  process_bam($bam, $options{'output_dir'})
}

sub process_bam {
  my $bam = shift;
  my $outdir = shift;

  my($filename, $dirs, $suffix) = fileparse($bam);
  my $outfile = "$outdir/$filename.aligned.reads";

  # Only show BAM reads that are mapped
  open( my $bam_fh, "$SAMTOOLS_BIN view -F $UNMAPPED_BIT $bam |") or &_log($ERROR, "Could not open $bam for reading: $!");
  open my $out_fh, ">$outfile" or &_log("Cannot open $outfile for writing: $!");

  # Print readnames to output if read mapped to this BAM's reference
  while (<$bam_fh>) {
    my ($name, $bitflag, $rest) = split /\t/, $_, 3;
    my $flags = parse_flag($bitflag);
    my $final_name;
    if ( $flags->{paired} }
      if ( $flags->{first} ) {
        $final_name = $name . "/1";
      } else {
        $final_name = $name . "/2";
      }
    } else {
      # For the LGTSeek pipeline, unpaired data will not pass the 'determine_final_lgt' component
      $final_name = $name;
    }

    print $out_fh "$final_name\n";
  }

  close $out_fh;
  close $bam_fh;
}

# Check if input BAM file is empty and return if any output is in head
# The chk_empty subroutine in LGT::LGTSeek works but we want to silently exit without making output
sub check_empty_file {
  my $file = shift;
	return `$SAMTOOLS_BIN view $file | head | wc -l`;
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

   foreach my $req ( qw( output_dir) ) {
       &_log($ERROR, "Option $req is required") unless( $opts->{$req} );
   }

   &_log( $ERROR, "Either --input_file or --input_list are required" )
     if ( !( defined $opts->{'input_file'} || defined $opts->{'input_list'} ) );

    $SAMTOOLS_BIN = $opts->{'samtools_path'} if $opts->{'samtools_path'};

    if ($opts->{'input_list'}) {
      open IN, $opts->{'input_list'} or &_log($ERROR, "Cannot open input list for reading: $!");
      while (<IN>) {
        chomp;
        push @input_files, $_;
      }
      close IN;
    } else {
      push @input_files, $opts->{'input_file'};
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
