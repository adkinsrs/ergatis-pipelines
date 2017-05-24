#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell

################################################################################
### POD Documentation
################################################################################

=head1 NAME

indel_realigner.pl - Script to execute GATK's Indel Realigner on input BAM.

=head1 SYNOPSIS

indel_realigner.pl    --c config file
		              [--o outdir] [-t tmpdir]
                      [--v]

    parameters in [] are optional
    do NOT type the carets when specifying options

=head1 OPTIONS

    --c <config> =    Path to config file with input parameters.
    
    --o          =    Output directory
    
    --t          =    Temp directory
    
    --v          =    Generate runtime messages. Optional

=head1 DESCRIPTION

Script to execute Indel Realigner from GATK software package on input BAM file.

=head1 AUTHOR

 Priti Kumari
 Bioinformatics Software Engineer 
 Institute of Genome Sciences
 University of Maryland
 Baltimore, Maryland 21201

=cut

################################################################################

use strict;
use warnings;

use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use Pod::Usage;
use File::Spec;
use NICU::Config;

##############################################################################
### Constants
##############################################################################

use constant FALSE => 0;
use constant TRUE  => 1;


use constant GATK_BIN => '/usr/local/packages/GenomeAnalysisTK-3.1.1' ;
use constant JAVA_EXEC => '/usr/local/packages/jdk1.7.0_40' ;

use constant VERSION => '1.0.0';
use constant PROGRAM => eval { ($0 =~ m/(\w+\.pl)$/) ? $1 : $0 };

##############################################################################
### Globals
##############################################################################

my %hCmdLineOption = ();
my $sHelpHeader = "\nThis is ".PROGRAM." version ".VERSION."\n";

GetOptions( \%hCmdLineOption,
            'config_file|c=s', 
            'outdir|o=s', 'verbose|v',
            'debug', 'tmpdir|t=s',
            'help',
            'man') or pod2usage(2);

## display documentation
pod2usage( -exitval => 0, -verbose => 2) if $hCmdLineOption{'man'};
pod2usage( -msg => $sHelpHeader, -exitval => 1) if $hCmdLineOption{'help'};

## make sure everything passed was peachy
check_parameters(\%hCmdLineOption);

my ($sOutDir);
my ($sCmd, $config_out);
my $bDebug   = (defined $hCmdLineOption{'debug'}) ? TRUE : FALSE;
my $bVerbose = (defined $hCmdLineOption{'verbose'}) ? TRUE : FALSE;
my (%hConfig);
my ($prefix);

################################################################################
### Main
################################################################################

if ($bDebug || $bVerbose) { 
	print STDERR "\nProcessing $hCmdLineOption{'config_file'} ";
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
	print STDERR "\nExecuting GATK Indel Realigner on input BAM...\n" : ();

##Read config file 

read_config(\%hCmdLineOption, \%hConfig);

if (!defined $hConfig{'indel_realigner'}{'GATK_BIN'}[0]) {
    $hConfig{'indel_realigner'}{'GATK_BIN'}[0] = GATK_BIN;
}

$sCmd = "java ";

if (defined $hConfig{'indel_realigner'}{'Java_Memory'}) {
	$sCmd .= "$hConfig{'indel_realigner'}{'Java_Memory'}[0]" ;
}

$sCmd  .= " -Djava.io.tmpdir=$hCmdLineOption{tmpdir} -jar " .  $hConfig{'indel_realigner'}{'GATK_BIN'}[0] . "/GenomeAnalysisTK.jar -T IndelRealigner " . 
		  " -I $hConfig{'indel_realigner'}{'Infile'}[0] -o $sOutDir/$hConfig{'indel_realigner'}{'Prefix'}[0].realigned.bam ".
		  " -targetIntervals $hConfig{'indel_realigner'}{'TargetInterval'}[0] -R $hConfig{'indel_realigner'}{'Reference'}[0] " ;

if (defined $hConfig{'indel_realigner'}{'OTHER_PARAMETERS'}) {
	$sCmd .= $hConfig{'indel_realigner'}{'OTHER_PARAMETERS'}[0] ;
}



#print "$sCmd\n";
exec_command($sCmd);

$config_out = "$sOutDir/indel_realigner.$hConfig{'indel_realigner'}{'Prefix'}[0].config" ;
$hConfig{'base_recalibration'}{'Infile'}[0] = "$sOutDir/$hConfig{'indel_realigner'}{'Prefix'}[0].realigned.bam" ;

write_config(\%hCmdLineOption,\%hConfig,$config_out);




################################################################################
### Subroutines
################################################################################

sub check_parameters {
    my $phOptions = shift;
    
    ## make sure input fastx is provided
    if ( (!(defined $phOptions->{'config_file'}))){
	 pod2usage( -msg => $sHelpHeader, -exitval => 1);
     }
  
    
    # set environment variables
    set_environment($phOptions);
}

sub set_environment {
	my $phOptions = shift;
	
	umask 0000;
	
	# adding speedseq executible path to user environment
	$ENV{PATH} = GATK_BIN .":".$ENV{PATH} ;
	$ENV{PATH} = JAVA_EXEC ."/bin" .":".$ENV{PATH} ;
	$ENV{JAVA_HOME} = JAVA_EXEC ;
	$ENV{CLASSPATH} = JAVA_EXEC . "/jre/lib/ext" . ":" . JAVA_EXEC . "/lib/tools.jar" ;
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
