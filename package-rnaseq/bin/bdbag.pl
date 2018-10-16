#! usr/bin/perl

=head1 NAME

  BDBAG CLOUD Version for AWS

=head1 VERSION

  Version 0.9
	Changes: *Added new functionality for AWS
		 *Added new flags for alignment
		 *add strict option to die if files dont exist
		 *Changed -all to no stop if folder doesnt exist
		 *Separated the ge and de commands
		 

=head1 DESCRIPTION
  Perl script to automate BDBag Generation for Report generation pipeline

=head1 SYNOPSIS
USAGE: 
  -p=path/to/outputrepository
  -o=path/to/store/bdbag

=head1 OPTIONS

B<--path, -p>
  Path to repository
B<--out, -o>
  Path to output location
B<--pid, -pid>
  Pipeline ID
B<--name, -n>
  Name of project
B<--align, -align>
  Pull Alignment files only
B<--fastqc, -fqc>
  Pull only FastQC files
B<--ge, -ge>
  Pull GE files only
B<--de, -de>
  Pull DE files only
B<--cloud, -cloud>
  Pull xml files
B<--include, -include-files>
  sam or bam or sam,bam 
B<--includesam, -sam>
  Include SAM files
B<--includebam, -bam>
  Include BAM files
B<--all, -all>
  Pull all files from this pipeline
B<--rb, -rb>
  Use this r binary
B<--rs, -rs>
  Use this bdbag.R script 
B<-frs, --filers>
  Use this rename_de.R script
B<-crs, --countsrs>
  Use this Generate_all_counts.R script
B<--rp,-rp>
  Use these r parameters
B<--makebag, -make>
  Make BD bag
B<--update, -update>
  Update Bag


=head1 CONTACT  

  Apaala Chatterjee at achatterjee@som.umaryland.edu
  
=head1 EXAMPLE

perl bdbag_generator.pl -p /local/projects-t3/XYZ/rhl7/rnaseq/ergatis -o /local/projects/RNASEQ/Report_Generation/Beta/ -pid 13898000001 -n XYZ -fqc 

perl bdbag_generator.pl -p /local/projects-t3/XYZ/rhl7/rnaseq/ergatis -o /local/projects/RNASEQ/Report_Generation/Beta/ -pid 13898000002 -n XYZ -ge -de

perl bdbag_generator.pl -p /local/projects-t3/XYZ/rhl7/rnaseq/ergatis -o /local/projects/RNASEQ/Report_Generation/Beta/ -n XYZ -cloud -bam -sam -make
=cut

use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use English qw( -no_match_vars );
use File::Basename;
use Pod::Usage;
use Cwd;
use FindBin qw($RealBin);
use Cwd 'abs_path';
use MIME::Lite;

####################################################################
###                             User Input
#####################################################################

my $results = GetOptions ('path|p=s' => \my $path,
                          'out|o=s' => \my $outpath,
			  'pid|pid=s' => \my $pid,
			  'name|n=s' => \my $bag,
			  'fastqc|fqc' => \my $dofqc,
			  'ge|ge' => \my $doge,
			  'align|align' => \my $doalign,
			  'e|email' => \my $email,
			  'de|de' => \my $dode,
			  'all|all' => \my $all,
			  'cloud|cloud'=> \my $cloud,
			  'include|include-files=s' => \my $include,
			  'bam|includebam' => \my $bam,
			  'sam|includesam' => \my $sam,
			  'rb|rb=s' => \my $rb,
			  'rp|rp=s' => \my $rp,
			  'rs|rs=s' => \my $rs,
			  'crs|countsrs=s' => \my $crs,
			  'frs|filers=s' => \my $frs,
			  'makebag|make' => \my $makebag,
			  'strict|strict' => \my $strict,
			  'update|u' => \my $update,
			  'help|h' => \my $help)|| pod2usage();

if( $help ){
  pod2usage( {-exitval => 0, -verbose => 2, -output => \*STDERR} );
}

###############################################################
## MAIN
################################################################
chdir $outpath;
my $syscmd="";
print("Setting directory to: ");
system 'pwd';
#print(defined $rb);

if (! defined $rb )
{
$rb="/usr/local/packages/r-3.4.0/bin/Rscript";
#print($rb);
}

if (! defined $rs )
{

$rs=$RealBin."/bdbag.R";
#print($rp);
}

if (! defined $crs )
{

$crs=$RealBin."/Generate_all_counts.R";
#print($rp);
}

if (! defined $frs )
{
$frs=$RealBin."/rename_de.R";
#print($rp);
}

if (! defined $rp )
{
$rp="";
#print($rs);
}

#my $bag="bdBag".$pid;
if (! -e $bag) {
 mkdir($bag) or die "Can't create /path/to/dir:$!\n";
}

###############################################################
### Directory set up
################################################################
chdir $bag;
my $rep_path=$path."/output_repository";

if($doalign)
{
my $align=$rep_path."/wrapper_align/".$pid."_wrap/Summary.txt";                                                                                                                                                                       
my $syscmd="cp ".$align." .";                                                                                                                                                                                                         
system($syscmd) == 0 or die "system($syscmd) failed:$?\n";    
}


###############################################################
#### bdbag report
###############################################################
my $timestamp = getLoggingTime();
my $filename1 = 'bdbag_details.txt';
open(my $fh, '>>', $filename1) or die "Could not open file '$filename1' $!";
my $str1=$rb."\n".$rs."\n".$crs."\n".$frs."\n".$rep_path."\n".$bag."\n".$timestamp."\n";
print $fh $str1;
close $fh;

###############################################################
#### GE Report
###############################################################

if($doge)
{
	print "Copying and Generating GE Files \n";
	my $checkrpkm=$rep_path."/rpkm_coverage_stats/".$pid."_rpkm_cvg";
	if(-e $checkrpkm)
	{

        	print("\nCopying RPMK Files \n");
        	if (! -e 'RPKM') {
                	mkdir('RPKM') or die "Can't create /path/to/dir:$!\n";
        	}

        	my $ge=$rep_path."/rpkm_coverage_stats/".$pid."_rpkm_cvg/i1/g*/genic_coverage/*.txt";
        	$syscmd="cp ".$ge." RPKM";
        	system($syscmd) == 0 or die "system($syscmd) failed:$?\n";
	}

	if (! -e 'Counts') 
	{                                                                                                                                       
 		mkdir('Counts') or die "Can't create /path/to/dir:$!\n";                                                                                                  
	}                                                                                                
	my $counts=$rep_path."/htseq/".$pid."*_counts/i1/g*/*.counts";                                                                                             
	$syscmd="cp ".$counts." Counts";                                                                                                                           
	system($syscmd) == 0 or die "system($syscmd) failed:$?\n"; 
	$syscmd=$rb." ".$crs;
	system($syscmd) == 0 or die "system($syscmd) failed:$?\n";
	#print($syscmd);
	#system("/usr/local/packages/r-3.4.0/bin/Rscript /home/apaala.chatterjee/RNA_Report/Generate_all_counts.R");
}

###############################################################
##### DE Report
################################################################

if($dode)
{
	if (! -e 'DE') 
	{
 		mkdir('DE') or die "Can't create /path/to/dir:$!\n";
	}
	if(! -e 'OutputTables/logCPM_RPKM.txt')
	{
		my $copyCounts=$rep_path."/deseq/".$pid."_differential_expression/i1/g*/";
		#print($copyCounts);
		my $copysyscmd=$rb." ".$frs." ".$copyCounts." DE";
		#print($copysyscmd);
		system($copysyscmd) == 0 or die "system($syscmd) failed:$?\n";
	}

	my $de=$rep_path."/deseq/".$pid."_differential_expression/i1/g*/*de_genes.txt";
	$syscmd="cp ".$de." DE";
	system($syscmd) == 0 or die "system($syscmd) failed:$?\n";
}

###############################################################
###### FASTQC Report
###############################################################

if($dofqc)
{
	if (! -e 'Files')
	{
 		mkdir('Files') or die "Can't create /path/to/dir:$!\n";
	}
	if (! -e 'Files/KmerProfiles') 
	{
 		mkdir('Files/KmerProfiles') or die "Can't create /path/to/dir:$!\n";
	}
	if (! -e 'Files/BaseQuality') 
	{
 		mkdir('Files/BaseQuality') or die "Can't create /path/to/dir:$!\n";
	}
	print "Copying FASTQC Images\n";
	my $fqc= $rep_path."/fastqc_stats/".$pid."_fastqc/i1/g*/*/Images/";
	#print $fqc;
	$syscmd="cp ".$fqc."*_sequence.kmer_profiles.png Files/KmerProfiles/";
	#print $syscmd;
	system($syscmd) == 0 or die "system($syscmd) failed:$?\n";
	$syscmd="cp ".$fqc."*_base_quality.png Files/BaseQuality/"; 
	#print $syscmd;                                                                                                                                                                                                                                                                               
	system($syscmd) == 0 or die "system($syscmd) failed:$?\n";
}


###############################################################
####### Strict Options
###############################################################


if($strict)
{
print "Generating Directory structure \n";
if (! -e 'Files') {
 mkdir('Files') or die "Can't create /path/to/dir:$!\n";
}
if (! -e 'Files/KmerProfiles') {
 mkdir('Files/KmerProfiles') or die "Can't create /path/to/dir:$!\n";
}
if (! -e 'Files/BaseQuality') {                                                                                                                                                                                                                                                               
 mkdir('Files/BaseQuality') or die "Can't create /path/to/dir:$!\n";                                                                                                                                                                                                                          
}
print "Copying FASTQC Images\n";                                                                                                                                                                                                                                                              
my $fqc= $rep_path."/fastqc_stats/".$pid."_fastqc/i1/g*/*/Images/";                                                                                                                                                                                                                               
$syscmd="cp ".$fqc."*_sequence.kmer_profiles.png Files/KmerProfiles/";                                                                                                                                                                                                                                 
system($syscmd) == 0 or die "system($syscmd) failed:$?\n";                                                                                                                                                                                                                                    
$syscmd="cp ".$fqc."*_base_quality.png Files/BaseQuality/";                                                                                                                                                                                                                                   
system($syscmd) == 0 or die "system($syscmd) failed:$?\n";

my $align=$rep_path."/wrapper_align/".$pid."_wrap/Summary.txt";
$syscmd="cp ".$align." .";
system($syscmd) == 0 or die "system($syscmd) failed:$?\n";

if (! -e 'DE') {
 mkdir('DE') or die "Can't create /path/to/dir:$!\n";
}

if(! -e 'OutputTables/logCPM_RPKM.txt')
        {
                my $copyCounts=$rep_path."/deseq/".$pid."_differential_expression/i1/g*/";
                my $copysyscmd=$rb." ".$frs." ".$copyCounts." DE";
                system($copysyscmd) == 0 or die "system($syscmd) failed:$?\n";
        }
if (! -e 'RPKM') {
 mkdir('RPKM') or die "Can't create /path/to/dir:$!\n";
}
print "Generating GE Files \n";
my $ge=$rep_path."/rpkm_coverage_stats/".$pid."_rpkm_cvg/i1/g*/genic_coverage/*.txt";
$syscmd="cp ".$ge." RPKM";
system($syscmd) == 0 or die "system($syscmd) failed:$?\n";
my $de=$rep_path."/deseq/".$pid."_differential_expression/i1/g*/*de_genes.txt";
$syscmd="cp ".$de." DE";
system($syscmd) == 0 or die "system($syscmd) failed:$?\n";
if (! -e 'Counts') {
 mkdir('Counts') or die "Can't create /path/to/dir:$!\n";
}
my $counts=$rep_path."/htseq/".$pid."*_counts/i1/g*/*.counts";
$syscmd="cp ".$counts." Counts";
system($syscmd) == 0 or die "system($syscmd) failed:$?\n";
$syscmd=$rb." ".$crs;
system($syscmd) == 0 or die "system($syscmd) failed:$?\n";
#system("/usr/local/packages/r-3.4.0/bin/Rscript /home/apaala.chatterjee/RNA_Report/Generate_all_counts.R");
}

###############################################################
######## All Option
################################################################


if($all)
{
print "Generating Directory structure \n";
if (! -e 'Files') {
 mkdir('Files') or die "Can't create /path/to/dir:$!\n";
}
if (! -e 'Files/KmerProfiles') {
 mkdir('Files/KmerProfiles') or die "Can't create /path/to/dir:$!\n";
}
if (! -e 'Files/BaseQuality') {                                                                                                                                                                                                                           
 mkdir('Files/BaseQuality') or die "Can't create /path/to/dir:$!\n";                                                                                                                                                                                      
}

####FastQC check
print "Copying FASTQC Images\n";                                                                                                                                                                                                                          
my $fqc= $rep_path."/fastqc_stats/".$pid."_fastqc/i1/g*/*/Images/";                                                                                                                                                                                      
my $fqc_check= $rep_path."/fastqc_stats/".$pid."_fastqc/";
if( -d $fqc_check)
{
#base sequence content instead of Kmer
#change the fastqc option to 11.7v of fastqc in config file
#fastqc.pl script change


$syscmd="cp ".$fqc."*_sequence.kmer_profiles.png Files/KmerProfiles/";                                                                                                                                                                                             
system($syscmd) == 0 or die "system($syscmd) failed:$?\n";                                                                                                                                                                                                
$syscmd="cp ".$fqc."*_base_quality.png Files/BaseQuality/";                                                                                                                                                                                               
system($syscmd) == 0 or die "system($syscmd) failed:$?\n";
}
else
{
print("FastQC Files not Found at $fqc \n Proceeding to next step \n");
print(-d $fqc);
}

###Alignment Check
my $align=$rep_path."/wrapper_align/".$pid."_wrap/Summary.txt";
if(-e $align)
{
$syscmd="cp ".$align." .";
print("Copying Summary.txt from $align \n");
system($syscmd) == 0 or die "system($syscmd) failed:$?\n";
}
else
{
print("Summary.txt not found at $align \n Proceeding to next step \n");
}
if (! -e 'DE') {
 mkdir('DE') or die "Can't create /path/to/dir:$!\n";
}

#print "Generating GE DE Files \n";
#####GE
my $checkrpkm=$rep_path."/rpkm_coverage_stats/".$pid."_rpkm_cvg";
my $ge=$rep_path."/rpkm_coverage_stats/".$pid."_rpkm_cvg/i1/g*/genic_coverage/*.txt";
my $ge_check=$rep_path."/rpkm_coverage_stats/".$pid."_rpkm_cvg/i1/";
if(-d $ge_check)
{
print "Generating GE Files \n";
if(-e $checkrpkm)
{

        print("\nCopying RPMK Files \n");
        if (! -e 'RPKM') {
                mkdir('RPKM') or die "Can't create /path/to/dir:$!\n";
        }

        my $ge=$rep_path."/rpkm_coverage_stats/".$pid."_rpkm_cvg/i1/g*/genic_coverage/*.txt";
        $syscmd="cp ".$ge." RPKM";
        system($syscmd) == 0 or die "system($syscmd) failed:$?\n";
}

#$syscmd="cp ".$ge." RPKM";
#system($syscmd) == 0 or die "system($syscmd) failed:$?\n";
}
else
{
print("GE Files not found at $ge_check \n Proceeding with next step \n");
}
my $de=$rep_path."/deseq/".$pid."_differential_expression/i1/g*/*de_genes.txt";
my $de_check=$rep_path."/deseq/".$pid."_differential_expression/i1/";
if(-d $de_check)
{
print "Generating DE Files \n";
$syscmd="cp ".$de." DE";
system($syscmd) == 0 or die "system($syscmd) failed:$?\n";
}
else
{
print("DE Files not Found at $de_check \n Proceeding to next step \n");
}

if (! -e 'Counts') {
 mkdir('Counts') or die "Can't create /path/to/dir:$!\n";
}
###Check Counts
my $count_check=$rep_path."/htseq/".$pid."_exon_counts/i1/";
my $counts=$rep_path."/htseq/".$pid."*_counts/i1/g*/*.counts";
if (-e $count_check)
{
print("Copying Count File and generating all counts\n");
$syscmd="cp ".$counts." Counts";
system($syscmd) == 0 or die "system($syscmd) failed:$?\n";
$syscmd=$rb." ".$crs;
system($syscmd) == 0 or die "system($syscmd) failed:$?\n";
#system("/usr/local/packages/r-3.4.0/bin/Rscript /home/apaala.chatterjee/RNA_Report/Generate_all_counts.R");
}
else
{
print("Counts files not found at $count_check\n");
}
}

###############################################################
######## CLOUD Option-xml files
################################################################

if ($cloud)
{

	my $ppath=$outpath."/".$bag;
	print("Setting directory to $ppath \n");
	chdir($ppath);
		if (! -e 'XML')
		{
			 mkdir('XML') or die "Can't create /path/to/dir:$!\n";
		}
	print("Gathering files for cloud and putting then in $outpath \n");
	my $pipelineXML=$path."workflow/runtime/pipeline/".$pid."/pipeline.xml";
	if(-e $pipelineXML)
	{
		print("Copying pipeline.xml from $pipelineXML\n");
		$syscmd="cp ".$pipelineXML." XML";
		system($syscmd) == 0 or die "system($syscmd) failed:$?\n";
	}
	$syscmd="ls ".$path."/workflow/runtime/*/".$pid."*/component.xml > comp.list";
	system($syscmd) == 0 or die "system($syscmd) failed:$?\n";
	$syscmd="ls ".$path."/workflow/runtime/*/".$pid."*/i1/*.xml.gz > i1.list";
	system($syscmd) == 0 or die "system($syscmd) failed:$?\n";
	$syscmd="ls ".$path."/workflow/runtime/*/".$pid."*/i1/g*/g*.xml.gz > g_all.list";
	system($syscmd) == 0 or die "system($syscmd) failed:$?\n";
	my $componentXML=$path."workflow/runtime/wrapper_align/".$pid."_wrap/component.xml";
	$syscmd=$rb."/Rscript ".$rp." ".$rs." ".$path." ".$ppath."/ ".$pid." cloud";
	print("\n");
	print($rs);
	print("\n");
	print($syscmd);
	system($syscmd) == 0 or die "system($syscmd) failed:$?\n";
}

if(defined($include))
{
if($include eq "bam")
{
	print("Copying bam files");
	my $ppath=$outpath."/".$bag;
	chdir($ppath);
	print("current directory is $ppath");
	if (! -e 'XML')
        {
                 mkdir('XML') or die "Can't create /path/to/dir:$!\n";
        }
	$syscmd="ls ".$path."/output_repository/samtools_file_convert/".$pid."_sorted_name/i1/g*/*sorted_by_name.bam > sorted_by_name.bam.list";
	system($syscmd) == 0 or die "system($syscmd) failed:$?\n";
	$syscmd="ls ".$path."/output_repository/samtools_file_convert/".$pid."_sorted_position/i1/g*/*sorted_by_position.bam  > sorted_by_position.bam.list";
	system($syscmd) == 0 or die "system($syscmd) failed:$?\n";
#$syscmd="/usr/local/packages/r-3.3.1/bin/Rscript /home/apaala.chatterjee/AWS/bdbag.R ".$path." ".$ppath."/ ".$pid." bam";

	$syscmd=$rb."/Rscript ".$rp." ".$rs." ".$path." ".$ppath."/ ".$pid." bam";
	system($syscmd) == 0 or die "system($syscmd) failed:$?\n";
	print($syscmd);
}

if($include eq "sam")
{
	print("Copying sam files");
	my $ppath=$outpath."/".$bag;
	chdir($ppath);
	if (! -e 'XML')
        {
                 mkdir('XML') or die "Can't create /path/to/dir:$!\n";
        }

	$syscmd="ls ".$path."/output_repository/samtools_file_convert/".$pid."_sorted_name/i1/g*/*sorted_by_name.sam > sorted_by_name.sam.list";
	system($syscmd) == 0 or die "system($syscmd) failed:$?\n";
	#print($syscmd);

#$syscmd="/usr/local/packages/r-3.3.1/bin/Rscript /home/apaala.chatterjee/AWS/bdbag.R ".$path." ".$ppath."/ ".$pid." sam";
	$syscmd=$rb."/Rscript ".$rp." ".$rs." ".$path." ".$ppath."/ ".$pid." sam";
	system($syscmd) == 0 or die "system($syscmd) failed:$?\n";
}

if($include eq "bam,sam")
{
	print("Copying SAM and BAM files");
	my $ppath=$outpath."/".$bag;
        chdir($ppath);
        if (! -e 'XML')
        {
                 mkdir('XML') or die "Can't create /path/to/dir:$!\n";
        }
        $syscmd="ls ".$path."/output_repository/samtools_file_convert/".$pid."_sorted_name/i1/g*/*sorted_by_name.bam > sorted_by_name.bam.list";
        system($syscmd) == 0 or die "system($syscmd) failed:$?\n";
        $syscmd="ls ".$path."/output_repository/samtools_file_convert/".$pid."_sorted_position/i1/g*/*sorted_by_position.bam  > sorted_by_position.bam.list";
        system($syscmd) == 0 or die "system($syscmd) failed:$?\n";
	$syscmd=$rb."/Rscript ".$rp." ".$rs." ".$path." ".$ppath."/ ".$pid." bam";
        system($syscmd) == 0 or die "system($syscmd) failed:$?\n";


	$syscmd="ls ".$path."/output_repository/samtools_file_convert/".$pid."_sorted_name/i1/g*/*sorted_by_name.sam > sorted_by_name.sam.list";
        system($syscmd) == 0 or die "system($syscmd) failed:$?\n";
	$syscmd=$rb."/Rscript ".$rp." ".$rs." ".$path." ".$ppath."/ ".$pid." sam";
        system($syscmd) == 0 or die "system($syscmd) failed:$?\n";
}
}

if($makebag)
{
print("Setting directory to $outpath \n");
chdir($outpath);
print("Making Bag: \n");
$syscmd="bdbag ".$bag." --archiver zip";
print ($syscmd);
system($syscmd) == 0 or die "system($syscmd) failed:$?\n";   
}

if($update)
{
print "Updating Bag \n";
chdir($outpath);
$syscmd="bdbag ".$bag." --archiver zip --update";
system($syscmd) == 0 or die "system($syscmd) failed:$?\n";
}

sub getLoggingTime {

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
    my $nice_timestamp = sprintf ( "%04d%02d%02d %02d:%02d:%02d",
                                   $year+1900,$mon+1,$mday,$hour,$min,$sec);
    return $nice_timestamp;
}
