#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell

################################################################################
### POD Documentation
################################################################################

=head1 NAME

hisat2.pl - script to execute reference based alignment for input sequence file(s).

=head1 SYNOPSIS

    hisat2.pl --r1 mate_1_sequence_file(s) [--r2 mate_2_sequence_file(s)] 
              --hi hisat2_index_dir --p index_prefix [--o outdir]  [--hb hisat2_bin_dir] 
			  [--mismatch-penalties=<max,min>]  [--softclip-penalties=<max,min>]  
			  [--read-gap-penalties=<max,min>]  [--ref-gap-penalties=<open,extend>]  
			  [--score-min=<func, const, coeff>]  [--pen-cansplice=<open,extend>]  
			  [--pen-noncansplice=<open,extend>]  [--pen-canintronlen=<func, const, coeff>]  
			  [--pen-noncnintronlen=<func, const, coeff>]  [--rna_strandness=<string>] 
              [--min-intronlen=<int>]  [--max-intronlen=<int>]  [--dta-cufflinks] 
              [--num-threads=<int>]  [--num-alignments=<int>]  [--minins=<int>]  
			  [--maxins=<int>] [--no-unal] [--samtools_bin_dir=<path>]
              [--a other_parameters]  [--v]

    parameters in [] are optional
    do NOT type the carets when specifying options

=head1 OPTIONS

    --r1 <mate_1_sequence_file(s)> = /path/to/input sequence file(s) for the first mates.
    
    --r2 <mate_2_sequence_file(s)> = /path/to/input sequence file(s) for the second mates. Optional.

    --hi <hisat2_index_dir>        = /path/to/hisat2_index directory.

    --p <index_prefix>             = prefix for index files.

    --o <output dir>               = /path/to/output directory. Optional. [present working directory]

    --hb <hisat2_bin_dir>          = /path/to/hisat2 binary. Optional. [/usr/local/bin]

    --sb <samtools_bin_dir>        = /path/to/samtools binary. Optional. [/usr/local/bin]

    hisat2 parameters              = refer to HISAT2 User Manual accessible at 
                                     http://hisat2.cbcb.umd.edu/manual.html for specific details and 
                                     defaults of the above mentioned HISAT2 parameters. Optional.

    --a <other_parameters>         = additonal HISAT2 parameters. Optional. Refer HISAT2 manual.

    --v                            = generate runtime messages. Optional

=head1 DESCRIPTION

The script executes the HISAT2 script from the HISAT2 software package.

=head1 AUTHOR

 Shaun Adkins
 Bioinformatics Software Engineer II
 Institute of Genome Sciences
 University of Maryland
 Baltimore, Maryland 21201

=cut

################################################################################

use strict;

use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use Pod::Usage;
use File::Spec;

##############################################################################
### Constants
##############################################################################

use constant FALSE => 0;
use constant TRUE  => 1;

use constant HISAT2_BIN_DIR => '/usr/local/bin';
use constant SAMTOOLS_BIN_DIR => '/usr/local/bin';

use constant VERSION => '1.0.0';
use constant PROGRAM => eval { ($0 =~ m/(\w+\.pl)$/) ? $1 : $0 };

##############################################################################
### Globals
##############################################################################

# Convert wrapper option to formal option name for the script call
my %hisat2_arg_conversion = (
	'num-threads' => 'threads',
	'mismatch-penalties'	=> 'mp',
	'softclip-penalties'	=> 'sp',
	'ambiguous-penalty'		=> 'np',
	'read-gap-penalties'	=> 'rdg',
	'ref-gap-penalties'	=> 'rfg',
);

my %hCmdLineOption = ();
my $sHelpHeader = "\nThis is ".PROGRAM." version ".VERSION."\n";

GetOptions( \%hCmdLineOption,
            'seq1file|r1=s', 'seq2file|r2=s', 'hisat2_index_dir|hi=s', 'prefix|p=s',
            'outdir|o=s', 'hisat2_bin_dir|hb=s', 'mismatch-penalties=s', 
			'softclip-penalties=s', 'ambiguous-penalty=i', 'read-gap-penalties=s',
			'ref-gap-penalties=s', 'score-min=s', 'pen-cansplice=i', 'pen-noncansplice=i',
			'pen-canintronlen=s', 'pen-noncnintronlen=s', 'min-intronlen=i', 'max-intronlen=i', 
            'num-threads=i', 'rna-strandness=s', 'dta-cufflinks=i', 'num-alignments|k=i',
			'minins=i', 'maxins=i', 'no-unal=i', 'samtools_bin_dir|sb=s',
            'args|a=s', 'verbose|v',
            'debug',
            'help',
            'man') or pod2usage(2);

## display documentation
pod2usage( -exitval => 0, -verbose => 2) if $hCmdLineOption{'man'};
pod2usage( -msg => $sHelpHeader, -exitval => 1) if $hCmdLineOption{'help'};

## make sure everything passed was peachy
check_parameters(\%hCmdLineOption);

my ($sOutDir, $sReadFile);
my ($sCmd, $sKey, $sFile, $sPrefix);
my $bDebug   = (defined $hCmdLineOption{'debug'}) ? TRUE : FALSE;
my $bVerbose = (defined $hCmdLineOption{'verbose'}) ? TRUE : FALSE;

################################################################################
### Main
################################################################################

if ($bDebug || $bVerbose) { 
	print STDERR "\nProcessing $hCmdLineOption{'seq1file'} ";
	print STDERR "& Processing $hCmdLineOption{'seq2file'} " if (defined $hCmdLineOption{'seq2file'});
	print STDERR "...\n";
}

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

($bDebug || $bVerbose) ? 
	print STDERR "\nExecuting hisat2 reference based alignment for input sequence file(s) ...\n" : ();

$sCmd  = $hCmdLineOption{'hisat2_bin_dir'}."/hisat2";

foreach $sKey ( keys %hCmdLineOption) {
	next if (($sKey eq "seq1file") || ($sKey eq "seq2file") || ($sKey eq "hisat2_index_dir") || ($sKey eq "prefix") ||
			 ($sKey eq "outdir") || ($sKey eq "hisat2_bin_dir") || ($sKey eq "dta-cufflinks") || 
			 ($sKey eq "num-alignments") || ($sKey eq "samtools_bin_dir") || ($sKey eq "no-unal") ||
			 ($sKey eq "args") || ($sKey eq "verbose") || ($sKey eq "debug") || ($sKey eq "help") || ($sKey eq "man") );
	
	my $key = $sKey;

	# Some wrapper args have shorthand arg names for the HISAT2 script
	foreach my $arg (keys %hisat2_arg_conversion) {
        $key = $hisat2_arg_conversion{$arg} if ($key eq $arg);
	}

	$sCmd .= " --". $key ." ".$hCmdLineOption{$sKey} if ((defined $hCmdLineOption{$sKey}) && ($hCmdLineOption{$sKey} !~ m/^$/i));
}

$sCmd .= " --dta-cufflinks" if ((defined $hCmdLineOption{'dta-cufflinks'}) && ($hCmdLineOption{'dta-cufflinks'} > 0));
$sCmd .= " --no-unal" if ((defined $hCmdLineOption{'no-unal'}) && ($hCmdLineOption{'no-unal'} > 0));
$sCmd .= " -k " . $hCmdLineOption{'num-alignments'} if ((defined $hCmdLineOption{'num-alignments'}) && ($hCmdLineOption{'num-alignments'} > 0));

$sCmd .= " ".$hCmdLineOption{'args'} if (defined $hCmdLineOption{'args'});
$sCmd .= " -x ".$hCmdLineOption{'hisat2_index_dir'}."/".$hCmdLineOption{'prefix'};

if ((defined $hCmdLineOption{'seq2file'}) && ($hCmdLineOption{'seq2file'} !~ m/^$/)) {
	# Paired-end reads
    $sReadFile = " -1 " . $hCmdLineOption{'seq1file'};
    $sReadFile .= " -2 " . $hCmdLineOption{'seq2file'};
} else {
	# Single-end reads
    $sReadFile = " -U " . $hCmdLineOption{'seq1file'};
}

$sCmd .= $sReadFile;

$sCmd .= " -S accepted_hits.sam";

chdir($sOutDir);
exec_command($sCmd);

$sFile = (split(/,/, $hCmdLineOption{'seq1file'}))[0];
($_, $_, $sPrefix) = File::Spec->splitpath($sFile);
$sPrefix =~ s/.1_1_sequence.*//;
$sPrefix =~ s/.sequence.*//;
$sPrefix =~ s/.fastq.*$//;
$sPrefix =~ s/.fq.*$//;

# Make copy of SAM 
if ( -e "$sOutDir/accepted_hits.sam" ) {
	$sCmd = "mv $sOutDir/accepted_hits.sam $sOutDir/$sPrefix.accepted_hits.sam";
	exec_command($sCmd);
}

# Convert SAM to BAM
my $samCmd = $hCmdLineOption{'samtools_bin_dir'} ."/samtools view -bS $sOutDir/$sPrefix.accepted_hits.sam > $sOutDir/$sPrefix.accepted_hits.bam";
exec_command($samCmd);

#if ( -e "$sOutDir/deletions.bed" ) {
#	$sCmd = "mv $sOutDir/deletions.bed $sOutDir/$sPrefix.deletions.bed";
#	exec_command($sCmd);
#}

#if ( -e "$sOutDir/insertions.bed" ) {
#	$sCmd = "mv $sOutDir/insertions.bed $sOutDir/$sPrefix.insertions.bed";
#	exec_command($sCmd);
#}

#if ( -e "$sOutDir/junctions.bed" ) {
#	$sCmd = "mv $sOutDir/junctions.bed $sOutDir/$sPrefix.junctions.bed";
#	exec_command($sCmd);
#}

#if ( -e "$sOutDir/unmapped_left.fq.z" ) {
#	$sCmd = "mv $sOutDir/unmapped_left.fq.z $sOutDir/$sPrefix.unmapped_left.fq.z";
#	exec_command($sCmd);
#}

#if ( -e "$sOutDir/unmapped_right.fq.z" ) {
#	$sCmd = "mv $sOutDir/unmapped_right.fq.z $sOutDir/$sPrefix.unmapped_right.fq.z";
#	exec_command($sCmd);
#}

if ($bDebug || $bVerbose) { 
	print STDERR "\nProcessing $hCmdLineOption{'seq1file'} ";
	print STDERR "& Processing $hCmdLineOption{'seq2file'} " if (defined $hCmdLineOption{'seq2file'});
	print STDERR "... done\n";
}


################################################################################
### Subroutines
################################################################################

sub check_parameters {
    my $phOptions = shift;
    
    ## make sure input fastx is provided
    if ( (!(defined $phOptions->{'seq1file'})) ||
    	 (!(defined $phOptions->{'hisat2_index_dir'})) ||
    	 (!(defined $phOptions->{'prefix'})) ) {
		pod2usage( -msg => $sHelpHeader, -exitval => 1);
	}
	
    ## handle some defaults
    $phOptions->{'hisat2_bin_dir'} = HISAT2_BIN_DIR if (! (defined $phOptions->{'hisat2_bin_dir'}) );
    
    if (! (defined $phOptions->{'samtools_bin_dir'}) ) {
        $phOptions->{'samtools_bin_dir'} = SAMTOOLS_BIN_DIR;
    }

	# set environment variables
		set_environment($phOptions);
}

sub set_environment {
	my $phOptions = shift;
	
	umask 0000;
	
	# adding bowtie executible path to user environment
	$ENV{PATH} = $phOptions->{'hisat2_bin_dir'}.":".$ENV{PATH};

    # adding samtools executible path to user environment
    $ENV{PATH} = $phOptions->{'samtools_bin_dir'}.":".$ENV{PATH};
}

sub exec_command {
	my $sCmd = shift;
	
	if ((!(defined $sCmd)) || ($sCmd eq "")) {
		die "\nSubroutine::exec_command : ERROR! Incorrect command!\n";
	}
	
	my $nExitCode;
	
	print STDERR "$sCmd\n";
	$nExitCode = system("$sCmd");
	if ($nExitCode != 0) {
		die "\tERROR! Command Failed!\n\t$!\n";
	}
	print STDERR "\n";
}

################################################################################
