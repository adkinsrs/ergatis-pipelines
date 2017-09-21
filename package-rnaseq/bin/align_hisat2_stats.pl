#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell

################################################################################
### POD Documentation
################################################################################

=head1 NAME

    align_hisat2_stats.pl  - script to calculate alignment statistics.

=head1 SYNOPSIS

    align_hisat2_stats.pl  --i <path to mapstats list file>   
                           [--o outdir --h <hisat2.bam.list] [--s --v]

    parameters in [] are optional
    do NOT type the carets when specifying options

=head1 OPTIONS
    
    --i  <mapstats list file>   = /list of mapstats files.

	--h <hisat2_bam_list> = Path to HISAT2 BAM output list.  Optional

    --o <output dir>       = /path/to/output directory. Optional.[PWD]

	--s					   = Enable flag for single-stranded reads.  Default is double-stranded.

    --v                    = generate runtime messages. Optional

=head1 DESCRIPTION

The script generates summary of alignment statistics from HISAT2 output.

=head1 AUTHOR

 Shaun Adkins
 Bioinformatics Software Engineer II
 Institute for Genome Sciences
 University of Maryland
 Baltimore, Maryland 21201

=cut

################################################################################

use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use Pod::Usage;
use File::Spec;

##############################################################################
### Constants
##############################################################################

use constant FALSE => 0;
use constant TRUE  => 1;

#use constant BIN_DIR => '/usr/local/bin';
use constant PROGRAM => eval { ($0 =~ m/(\w+\.pl)$/) ? $1 : $0 };

##############################################################################
### Globals
##############################################################################
#
my %hCmdLineOption = ();
my $sHelpHeader = "\nThis is ".PROGRAM."\n";
my $singleStranded = 0;

GetOptions( \%hCmdLineOption,
            'outdir|o=s', 'infile|i=s', 'hisat2_list|h=s', 'single_stranded|s',
            'verbose|v',
            'debug',
            'help',
            'man') or pod2usage(2);

## display documentation
pod2usage( -exitval => 0, -verbose => 2) if $hCmdLineOption{'man'};
pod2usage( -msg => $sHelpHeader, -exitval => 1) if $hCmdLineOption{'help'};

## make sure everything passed was peachy
check_parameters(\%hCmdLineOption);

my ($sOutDir,$prefix);
my ($mapstat_list, $mapstat_file, $f1, $path,$key,$pipeline1,$pipeline2);
my %bam; 
my ($cfile,$mfile,$lfile,$rfile,$pfile,$readcount,@arr,@arr1,$p_paired,$left_count,$tot_reads,$p_mapped,$fout,$out_all);
my $right_count=0;
my $bDebug   = (defined $hCmdLineOption{'debug'}) ? TRUE : FALSE;
my $bVerbose = (defined $hCmdLineOption{'verbose'}) ? TRUE : FALSE;

################################################################################
### Main
################################################################################

($bDebug || $bVerbose) ? 
	print STDERR "\nProcessing $hCmdLineOption{'infile'} ...\n" : ();

$sOutDir = File::Spec->curdir();
if (defined $hCmdLineOption{'outdir'}) {
    $sOutDir = $hCmdLineOption{'outdir'};

    if (! -e $sOutDir) {
        mkdir($hCmdLineOption{'outdir'}) ||
            die "ERROR! Cannot create output directory\n";
    }
    elsif (! -d $hCmdLineOption{'outdir'}) {
            die "ERROR! $hCmdLineOption{'outdir'} is not a directory\n";
    }
}

$sOutDir = File::Spec->canonpath($sOutDir);


#### Processing mapstats list file 
$mapstat_list = $hCmdLineOption{'infile'};

open ($mapstat_file, "<$mapstat_list") or die "Error! Cannot open the mapstat list file $mapstat_list: $!\n";

while (<$mapstat_file>) {
    chomp($_);
    ($f1,$path,$prefix) = File::Spec->splitpath($_);
    @arr = split(/\./,$prefix);
    $prefix =~ s/.accepted_hits.*//;

    if (!exists $bam{$prefix}) {
	    $bam{$prefix}{"mapstats"} = $_;
	    $_ =~ s/mapstats.txt/mapped_reads.count/;
	    $bam{$prefix}{"count"} = $_;
    }
}

close $mapstat_file;

open ($out_all, ">$sOutDir/All_Samples.txt") or die "Error Cannot open output file";

foreach $key (sort keys (%bam)) {

    open ($cfile, "<$bam{$key}{'count'}") or die "Error! Cannot open read count file";
    open ($mfile, "<$bam{$key}{'mapstats'}") or die "Error! Cannot open mapstats file";

    ###Reading read count file:
    while(<$cfile>) {
	    chomp ($_);
	    if ($_ eq 'mapped count') {
	        $readcount=<$cfile>;
	        chomp ($readcount);
	        last;
	    }
    }

    ###Reading mapstat file to obtain properly paired:
    while (<$mfile>) {
	    chomp ($_);
	    if ($_ =~ m/properly paired/) {
	        $p_paired =(split(/[(:]/,$_))[1] ; 
	        $p_paired =~s/%//;
		}
        if ($_ =~ m/in total/) {
            $tot_reads =(split(/[(+]/,$_))[0] ; 
	    }	    
    }
    
	# Find HISAT2 stderr file that corresponds to this prefix, if list provided
	# Use 'total_reads' value instead of the default value from samtools_alignment_stats
    if (defined $hCmdLineOption{'hisat2_list'}) {
        open HISAT, $hCmdLineOption{'hisat2_list'} or die "Cannot open HISAT2 BAM list for reading";
        while (<HISAT>) {
            chomp;
			if (/$key\.accepted_hits\.bam$/) {
				my $file = $_;
				# NOTE - could fail if there is 2+ BAM outputs in a group
                $file =~ s/$key\.accepted_hits\.bam/hisat2.stderr/;
				$tot_reads = get_total_reads_from_hisat_stderr($file, $singleStranded);
				last;
			}
		}
		close HISAT
	}

    ###Percent mapped..
    $p_mapped = sprintf("%.2f",eval(($readcount/$tot_reads ) * 100)); 

    ###Write to Output Directory..
    open ($fout, ">$sOutDir/$key.txt") or die "Error Cannot open output file";
 
    print $fout "\#Sample Id\t$key\n";
    print $fout "\#Total.reads\tMapped.reads\tPercent.Mapped\tPercent.Properly.Paired\n";
    print $fout  "$tot_reads\t$readcount\t$p_mapped\t$p_paired\n";

    print $out_all "\#Sample Id\t$key\n";
    print $out_all "\#Total.reads\tMapped.reads\tPercent.Mapped\tPercent.Properly.Paired\n";
    print $out_all  "$tot_reads\t$readcount\t$p_mapped\t$p_paired\n\n";
    
    close $fout;
    close $mfile;
    close $cfile;

}   
close $out_all;

sub get_total_reads_from_hisat_stderr {
    my $hisat_stderr = shift;
	my $ss = shift;
	my $total_reads;
    open HS_IN, $hisat_stderr or die "Cannot open HISAT2 stderr file for reading:#!\n";
    while (<HS_IN>) {
      chomp;
	  if (/(\d+) reads; of these:$/) {
        $total_reads = $1;
		$total_reads *= 2 if $ss;
	  }
	}
	close HS_IN;
	return $total_reads;
}

################################################################################
### Subroutines
################################################################################

sub check_parameters {
    my $phOptions = shift;
    
    ## make sure input files provided
    if (! (defined $phOptions->{'infile'}) ) {
	pod2usage( -msg => $sHelpHeader, -exitval => 1);
    }

	$singleStranded = 1 if defined $phOptions->{'single_stranded'};
}

################################################################################
