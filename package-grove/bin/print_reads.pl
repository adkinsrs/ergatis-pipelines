#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell

################################################################################
### POD Documentation
################################################################################

=head1 NAME

print_reads.pl - Script to execute GATK's Print Reads on input BAM.

=head1 SYNOPSIS

print_reads.pl    --c config file
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

Script to execute Print Reads from GATK software package on input BAM file.

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
my ($sCmd, $config_out);
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
	print STDERR "\nExecuting GATK Indel Realigner on input BAM...\n" : ();

##Read config file 

read_config(\%hCmdLineOption, \%hConfig);

my $prefix = $hConfig{'global'}{'PREFIX'}[0];

$sCmd = $hCmdLineOption{'java_path'} . " -Djava.io.tmpdir=" .$hCmdLineOption{tmpdir};

if (defined $hConfig{'print_reads'}{'Java_Memory'}) {
	$sCmd .= " $hConfig{'print_reads'}{'Java_Memory'}[0]" ;
}

$sCmd  .= " -jar " . $hCmdLineOption{'gatk_jar'} . " -T PrintReads " . 
		  " -I $hConfig{'print_reads'}{'Infile'}[0] -o $sOutDir/$prefix.base_recal.bam ".
		  " -BQSR $hConfig{'print_reads'}{'BQSR'}[0] -R $hConfig{'global'}{'REFERENCE_FILE'}[0] " ;

if (defined $hConfig{'print_reads'}{'OTHER_PARAMETERS'}) {
	$sCmd .= $hConfig{'print_reads'}{'OTHER_PARAMETERS'}[0] ;
}

#print "$sCmd\n";
exec_command($sCmd);

$config_out = "$sOutDir/haplotype_caller.$prefix.config" ;
$hConfig{'haplotype_caller'}{'INPUT_FILE'}[0] = "$sOutDir/$prefix.base_recal.bam" ;

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
