#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell

################################################################################
### POD Documentation
################################################################################

=head1 NAME

cuffquant.pl - script to generate transcript expression profiles for Cufflinks/Cuffcompare results.

=head1 SYNOPSIS

    cuffquant.pl --a annotation.gtf --i alignments.sam [--o outdir] 
            	[--num-threads threads] [--fdr FDR cut-off]
                [--cb cufflinks_bin_dir] [--args other_parameters] [--v] 

    parameters in [] are optional
    do NOT type the carets when specifying options

=head1 OPTIONS

    --a <annotations.gtf>          = /path/to/annotation in GTF/GFF format from Cufflinks or Cuffcompare.

    --i <alignments.sam> 		   = /path/to/SAMfile. A single SAM/BAM alignment file.

    --o <output dir>               = /path/to/output directory. Optional. [present working directory]

    --num-threads <# threads>      = Use # threads to align reads. Optional. [1]

    --cb <cufflinks_bin_dir>       = /path/to/cufflinks bin directory. Optional. [/usr/local/bin]

    --args <other_params>          = additional Cuffquant parameters. Optional. Refer Cufflinks manual.

    --v                            = generate runtime messages. Optional

=head1 DESCRIPTION

The script executes the cuffquant script from the Cufflinks RNA-Seq Analysis package

=head1 AUTHOR

 Amol Carl Shetty
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

use constant BIN_DIR => '/usr/local/bin';

use constant VERSION => '1.0.0';
use constant PROGRAM => eval { ($0 =~ m/(\w+\.pl)$/) ? $1 : $0 };

##############################################################################
### Globals
##############################################################################

my %hCmdLineOption = ();
my $sHelpHeader = "\nThis is ".PROGRAM." version ".VERSION."\n";

GetOptions( \%hCmdLineOption,
            'gtffile|a=s', 'samfile|i=s', 'outdir|o=s', 
            'num-threads|p=i', 'fdr=f', 
            'library-type=s', 'max-mle-iterations=i', 'max-bundle-frags=i', 
            'cufflinks_bin_dir|cb=s', 'args=s', 
            'verbose|v',
            'debug',
            'help',
            'man') or pod2usage(2);

## display documentation
pod2usage( -exitval => 0, -verbose => 2) if $hCmdLineOption{'man'};
pod2usage( -msg => $sHelpHeader, -exitval => 1) if $hCmdLineOption{'help'};

## make sure everything passed was peachy
check_parameters(\%hCmdLineOption);

my ($sOutDir, $sSamFile, $sPrefix);
my ($fpLST);
my ($sCmd, $sKey, $nI);
my $bDebug   = (defined $hCmdLineOption{'debug'}) ? TRUE : FALSE;
my $bVerbose = (defined $hCmdLineOption{'verbose'}) ? TRUE : FALSE;

################################################################################
### Main
################################################################################

($bDebug || $bVerbose) ? 
	print STDERR "\nProcessing $hCmdLineOption{'listfile'} ...\n" : ();

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
	print STDERR "\nCreating expression profiles using Cuffquant for input $hCmdLineOption{'samfile'} ...\n" : ();

my ($foo, $bar, $sFile) = File::Spec->splitpath($hCmdLineOption{'samfile'});
my $sSamFile = "${sOutDir}/${sFile}";
if ($sFile =~ m/\.(s|b)am$/ ) {
	# If input is SAM/BAM file, then symlink to output_dir and write path to list
	$sCmd = "ln -sf $hCmdLineOption{'samfile'} $sSamFile";
	exec_command($sCmd);
}
else {
	die "ERROR! File is not a recognized SAM or BAM-formatted file.  Exiting!\n";
}


($bDebug || $bVerbose) ? 
	print STDERR "\nInitiating Cuffquant Analysis ...\n" : ();

# Start building the CuffQuant command
$sCmd  = $hCmdLineOption{'cufflinks_bin_dir'}."/cuffquant".
		 " -o ".$sOutDir;

foreach $sKey ( keys %hCmdLineOption) {
	next if (($sKey eq "gtffile") || ($sKey eq "samfile") || ($sKey eq "outdir") || 
			 ($sKey eq "cufflinks_bin_dir") || ($sKey eq "library-type") || ($sKey eq "fdr") || ($sKey eq "args") || 
			 ($sKey eq "verbose") || ($sKey eq "debug") || ($sKey eq "help") || ($sKey eq "man") );
	
	$sCmd .= " --".$sKey." ".$hCmdLineOption{$sKey} if ((defined $hCmdLineOption{$sKey}) && ($hCmdLineOption{$sKey} !~ m/^$/i));
}

$sCmd .= " --library-type ".$hCmdLineOption{'library-type'} if ((defined $hCmdLineOption{'library-type'}) && ($hCmdLineOption{'library-type'} !~ m/^$/i));
$sCmd .= " ".$hCmdLineOption{'args'} if (defined $hCmdLineOption{'args'});
$sCmd .= " ".$hCmdLineOption{'gtffile'};
$sCmd .= " ".$sSamFile;

exec_command($sCmd);

($bDebug || $bVerbose) ? 
	print STDERR "\nRenaming Cuffquant output file ...\n" : ();

($_, $_, $sPrefix) = File::Spec->splitpath($hCmdLineOption{'samfile'});

# The input may have a .sam or .bam extension, and it needs to go
$sPrefix =~ s/.(sam|bam)//;

rename_files($sOutDir, "abundances.cxb", $sPrefix);

($bDebug || $bVerbose) ? 
	print STDERR "\nProcessing $hCmdLineOption{'samfile'} ... done\n" : ();


################################################################################
### Subroutines
################################################################################

sub check_parameters {
    my $phOptions = shift;
    
    ## make sure input parameters are provided
    if ((! (defined $phOptions->{'gtffile'}) ) ||
    	(! (defined $phOptions->{'samfile'}) )) {
		pod2usage( -msg => $sHelpHeader, -exitval => 1);
	}
	
    ## handle some defaults
    $phOptions->{'cufflinks_bin_dir'} = BIN_DIR if (! (defined $phOptions->{'cufflinks_bin_dir'}) );
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

sub rename_files {
    my $sOutDir = shift;
    my $sSuffix	= shift;
    my $sPrefix = shift;
    
    ## make sure input parameters are provided
    if ((! (defined $sOutDir) ) ||
    	(! (defined $sSuffix) ) ||
    	(! (defined $sPrefix) )) {
		print STDERR "\nSubroutine::rename_files\n\tIncomplete parameter list!!!!!\n";
	}
	
	my (@aInputFiles);
	my ($sBasename);
	
	@aInputFiles = glob("$sOutDir/*$sSuffix");
	
	foreach $sFile (@aInputFiles) {
		($_, $_, $sBasename) = File::Spec->splitpath($sFile);
		
		rename ($sFile, "$sOutDir/$sPrefix.$sBasename") or printf STDERR "\tError! Cannot rename $sFile !!!\n";
	}
}

################################################################################
