#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell

################################################################################
### POD Documentation
################################################################################

=head1 NAME

base_recalibration.pl - Script to execute GATK's Base Recalibration on input BAM.

=head1 SYNOPSIS

base_recalibration.pl --c config file
		                    [--o outdir] [-t tmpdir]
							[--gatk_jar path] [--java_path path]
                            [--v]

    parameters in [] are optional
    do NOT type the carets when specifying options

=head1 OPTIONS

    --c <config> =    Path to config file with input parameters.

    --gatk_jar   =    Optional. Path to the GATK JAR file.  If not provided, will use /usr/local/packages/GATK-3.7/GenomeAnalysisTK.jar

    --java_path  =    Optional. Path to JAVA executable from Java 8 JDK.  If not provided, will use /usr/bin/java
    
    --o          =    Output directory
    
    --t          =    Temp directory
    
    --v          =    Generate runtime messages. Optional

=head1 DESCRIPTION

Script to execute Base Recalibration from GATK software package on input BAM file.

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


use constant JAVA_PATH => "/usr/bin/java";
use constant GATK_JAR => "/usr/local/packages/GATK-3.7/GenomeAnalysisTK.jar";

use constant VERSION => '1.0.0';
use constant PROGRAM => eval { ($0 =~ m/(\w+\.pl)$/) ? $1 : $0 };

##############################################################################
### Globals
##############################################################################

my %hCmdLineOption = ();
my $sHelpHeader = "\nThis is ".PROGRAM." version ".VERSION."\n";

GetOptions( \%hCmdLineOption,
            'config_file|c=s', 
			'gatk_jar=s',
			'java_path=s',
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
my ($sCmd, $config_out, $fh);
my $bDebug   = (defined $hCmdLineOption{'debug'}) ? TRUE : FALSE;
my $bVerbose = (defined $hCmdLineOption{'verbose'}) ? TRUE : FALSE;
my (%hConfig);

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
	print STDERR "\nExecuting GATK Base Recalibration on input BAM...\n" : ();


##Read config file 
read_config(\%hCmdLineOption, \%hConfig);

my $prefix = $hConfig{'global'}{'PREFIX'}[0];

$sCmd = $hCmdLineOption{'java_path'} . " -Djava.io.tmpdir=" .$hCmdLineOption{tmpdir};

if (defined $hConfig{'base_recalibration'}{'Java_Memory'}) {
	$sCmd .= " $hConfig{'base_recalibration'}{'Java_Memory'}[0]" ;
}

$sCmd  .= " -jar " . $hCmdLineOption{'gatk_jar'} . " -T BaseRecalibrator " . 
		  " -I $hConfig{'base_recalibration'}{'Infile'}[0] -o $sOutDir/Merged.base.recal.grp ".
		  " -knownSites $hConfig{'base_recalibration'}{'KnownSites'}[0] -R $hConfig{'global'}{'REFERENCE_FILE'}[0] " ;

if (defined $hConfig{'base_recalibration'}{'OTHER_PARAMETERS'}) {
	$sCmd .= $hConfig{'base_recalibration'}{'OTHER_PARAMETERS'}[0] ;
}

#print "$sCmd\n";
exec_command($sCmd);

#Write config file out..
$config_out = "$sOutDir/print_reads.$prefix.config" ;
$hConfig{'print_reads'}{'Infile'}[0] = $hConfig{'base_recalibration'}{'Infile'}[0];
$hConfig{'print_reads'}{'BQSR'}[0] = "$sOutDir/Merged.base.recal.grp" ;
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
  
    $phOptions->{'gatk_jar'} = GATK_JAR if !defined $phOptions->{'gatk_jar'};
    $phOptions->{'java_path'} = JAVA_PATH if !defined $phOptions->{'java_exec'};
    
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
