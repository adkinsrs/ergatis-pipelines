#!/usr/bin/perl 
use Getopt::Std;
use Term::ANSIColor;
use Cwd;
use File::Basename;
eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell

################################################################################
### POD Documentation
################################################################################

=head1 NAME

    wrapper_mirdeep.pl  -             wrapper for mirdeep2 

=head1 SYNOPSIS

    wrapper_mirdeep.pl               --Bin <path/to/mirdeep2> --path1 </path/to/Vienna/bin> --path2 </path/to/randfold>  
                                     --i  <fasta read file> --k <this clips the adaptor> --rg <reference genome> --g <index> 
                                     --s  <name of the output file of processed reads> --t <Name of the output file of genome mapping>
                                     --m1 </path/to/mature_reference_this_species> --m2 </path/to/mature_reference_other_species>  
                                     --pre </path/to/precursor> [--a annotation] [--gtf annotation_format] [--f feature] [--id attribute]
                                     [--score][--depth] [--rf </path/to/Rfam file>] [--bowtie_build] [--map_build] [--quant_build] 
                                     [--mirdeep_build] --o [outdir] [--v] [--args_map other_args_mapper][--bowtie_bin]
                                     [--args_quant other_args_quantifier][--args_mirdeep other_args_mirdeep]

    parameters in [] are optional
    do NOT type the carets when specifying options

=head1 OPTIONS

    --Bin                      = /path/to/mirdeep2 

    --path1                    = /path/to/Vienna/bin

    --path2                    = /path/to/randfold

    --bowtie_bin               = PAth to bowtie bin directory

    --i                        = /path/to/read file

    --io                       = input read file type

    --k                        = this clips the adaptor

    --rg                       = /path/to/reference genome 

    --pre                      = /path/to/Precursor

    --s                        = The name of the output file of processed reads

    --t                        = Name of the output file of genome mapping

    --m1                       = /path/to/mature_reference_this_species
   
    --m2                       =/path/to/mature_reference_other_species.Default [none]

    --rf                       =/path/to/Rfam file

    --g<index>                 = Path to bowite index if not specifying bowtie_build 
                                If specifying bowtie_build mention prefix to be used for bowtie_build.

    --bowtie_build             = to execute bowtie build

    --map_build                = to execute mapper.pl 

    --mirdeep_build            = to execute miRdeep.pl

    --args_map                 = Other optional parameters for mapper.pl

    --args_quantifier          = Other optional parameters for quantifier.pl 

    --args_mirdeep             = Other optional parameters for miRDeep2.pl 
    
    --a <annotation>           = annotation file for known miRNAs in either BED, GTF or GFF format.

    --gtf<annotation_format>   = annotation file format (bed, gtf or gff).

    --f <feature>              = feature type from column 3 of GTF or GFF3 file.

    --id <attribute>           = attribute id from column 9 of GTF or GFF3 file to be used as region ID.

    --score <score>            = miRDeep2 score cut-off.

    --depth <depth>            = mature miRNA read depth.

    --bb <bedtools_bin_dir>     = bedtools binary directory. Optional

    --o <output dir>           = /path/to/output directory. Optional.[PWD]

    --v                        = generate runtime messages. Optional

=head1 DESCRIPTION

The script is wrapper for mirdeep2.

=head1 AUTHOR

 Aniket Shetty
 Bioinformatics Software Engineer 
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
use FindBin qw($RealBin);

##############################################################################
### Constants
##############################################################################

use constant FALSE => 0;
use constant TRUE  => 1;

use constant BEDTOOLS_BIN_DIR => '/usr/local/packages/bedtools';
use constant PROGRAM => eval { ($0 =~ m/(\w+\.pl)$/) ? $1 : $0 };


##############################################################################
### Globals
##############################################################################

my %hCmdLineOption = ();
my $sHelpHeader = "\nThis is ".PROGRAM."\n";

GetOptions( \%hCmdLineOption,
	    'RNAfold_path|path1=s','randfold_path|path2=s','mapdir|ma=s','mirdir|mi=s',
        'outdir|o=s', 'infile|i=s','index|g=s','Precursors_ref|pre=s', 'annotation|a=s',
        'annotation_format|gtf=s','feature|f=s','attribute|id=s','score=s', 'depth=s', 
	    'mature_ref_t|m1=s','mature_ref_o|m2=s','output_read_file|s=s','Rfam_file|rf=s',
	    'output_mapping|t=s','ref_genome|rg=s','Input_option|io=s','map_build','quant_build','mirdeep_build',
        'verbose|v','Bin_Dir|Bin=s','Adaptor|k=s','bowtie_build','bowtie_bin=s', 'bb|bedtools_bin_dir=s',
        'debug','other_args_mapper|args_map=s','other_args_quantifier|args_quant=s','other_args_mirdeep|args_mirdeep=s',
        'help', 'filter_script=s',
        'man') or pod2usage(2);

## display documentation
pod2usage( -exitval => 0, -verbose => 2) if $hCmdLineOption{'man'};
pod2usage( -msg => $sHelpHeader, -exitval => 1) if $hCmdLineOption{'help'};



## make sure everything passed was peachy
check_parameters(\%hCmdLineOption);

## Define variables
my $sOutDir;
my $sOutDir1;
my $sOutDir2;
my $bDebug   = (defined $hCmdLineOption{'debug'}) ? TRUE : FALSE;
my $bVerbose = (defined $hCmdLineOption{'verbose'}) ? TRUE : FALSE;
my ($fh);
my $cmd;
my ($indexes, $Path, $tmp1, $filt_results) ;
my %h;
my @arr;

my ($sTime,$eTime,$stime,$etime,$sTimeG, $eTimeG, $stimeG, $etimeG);
my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings);

($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
$second = "0$second" if($second =~ /^\d$/);
$sTimeG = "$hour:$minute:$second";
$stimeG = time;

print "miRDeep2 started at $sTimeG\n\n\n";


my $ctime=time();

my $time=myTime();
my %options=();

getopts("a:b:cdt:uvq:s:z:r:p:g:EP",\%options);

my $max_pres=50000;
$max_pres=$options{'g'} if(defined $options{'g'});

## minimal precursor length, used for precheck of precursor file
my $minpreslen=40;
if($options{'p'}){
	$minpreslen=$options{'p'}
};

my $stack_height_min;

if($options{a}){$stack_height_min=$options{a};}
my $dir;
my $dir_tmp;





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



symlink("$hCmdLineOption{'Bin_Dir'}/miRDeep2.pl","$hCmdLineOption{'outdir'}/miRDeep2.pl" );
symlink("$hCmdLineOption{'Bin_Dir'}/Rfam_for_miRDeep.fa","$hCmdLineOption{'outdir'}/Rfam_for_miRDeep.fa");


local $ENV{PATH}="$ENV{PATH}:$hCmdLineOption{'outdir'}";
local $ENV{PATH}="$ENV{PATH}:$hCmdLineOption{'Bin_Dir'}";
local $ENV{PATH}="$ENV{PATH}:$hCmdLineOption{'RNAfold_path'}";
local $ENV{PATH}="$ENV{PATH}:$hCmdLineOption{'randfold_path'}";
local $ENV{PATH}="$ENV{PATH}:$hCmdLineOption{'bowtie_bin'}";

my $mapper="$sOutDir/mapdir";
my $mirdeep="$sOutDir/mirdir";
my $path_index="$sOutDir";

$dir_tmp = "$sOutDir/dir_tmp";
make_dir_tmp($dir_tmp);
make_dir_tmp($mapper);
make_dir_tmp($mirdeep);
if (defined $hCmdLineOption{'bowtie_build'}) {
    $indexes="$sOutDir/indexes";
    make_dir_tmp($indexes);
}
check_input(\%hCmdLineOption);


if(defined $hCmdLineOption{'bowtie_build'}) {
    my $orig_dir=cwd;
    chdir "$indexes";
    $cmd = "$hCmdLineOption{'bowtie_bin'}/bowtie-build $hCmdLineOption{'ref_genome'} $hCmdLineOption{'index'}";
    exec_command($cmd);
    chdir $orig_dir;
}

(my $basename, my $directory_path) = fileparse($hCmdLineOption{'infile'});

if(defined $hCmdLineOption{'map_build'}) {
    ($bDebug || $bVerbose) ? 
	print STDERR "\nRunning mapper.pl ...\n" : ();

    my $orig_dir=cwd;
    chdir "$mapper";
    symlink("$hCmdLineOption{'infile'}","$mapper/$basename");

    if (defined $hCmdLineOption{'bowtie_build'}) {
	$cmd= "$hCmdLineOption{'Bin_Dir'}/mapper.pl  $basename -$hCmdLineOption{'Input_option'} -j -k $hCmdLineOption{'Adaptor'}  -m  -p  $indexes/$hCmdLineOption{'index'} -s $hCmdLineOption{'output_read_file'} -t $hCmdLineOption{'output_mapping'} -v ";
  	
    }
    else {
	$cmd= "$hCmdLineOption{'Bin_Dir'}/mapper.pl  $basename -$hCmdLineOption{'Input_option'} -j -k $hCmdLineOption{'Adaptor'}  -m  -p $hCmdLineOption{'index'}  -s $hCmdLineOption{'output_read_file'} -t $hCmdLineOption{'output_mapping'} -v ";

    }
	
    if(defined $hCmdLineOption{'other_args_mapper'}){
	$cmd .= $hCmdLineOption{'other_args_mapper'};
    }

    exec_command($cmd);
    chdir $orig_dir;
}

if (defined$hCmdLineOption{'Rfam-file'}){
    (my $basename2, my $directory_path2) = fileparse($hCmdLineOption{'Rfam_file'});
    symlink("$hCmdLineOption{'Rfam-file'}","$sOutDir/Rfam_for_miRDeep.fa");
}

if(defined $hCmdLineOption{'quant_build'}) {
    ($bDebug || $bVerbose) ? 
	print STDERR "\nRunning quantifier.pl ...\n" : ();

    $cmd="$hCmdLineOption{'Bin_Dir'}/quantifier.pl -p $hCmdLineOption{'Precursors_ref'} -m $hCmdLineOption{'mature_ref_t'} -r $mapper/$hCmdLineOption{'output_read_file'} -v ";
    if(defined $hCmdLineOption{'other_args_quantifier'}) {
	$cmd .= $hCmdLineOption{'other_args_quantifier'} ;
    }
    exec_command($cmd);
}

if(defined $hCmdLineOption{'mirdeep_build'}){
    ($bDebug || $bVerbose) ? 
	print STDERR "\nRunning miRDeep2.pl ...\n" : ();
    my $orig_dir=cwd;
    chdir "$mirdeep";
    $cmd="$sOutDir/miRDeep2.pl $mapper/$hCmdLineOption{'output_read_file'} $hCmdLineOption{'ref_genome'} $mapper/$hCmdLineOption{'output_mapping'} $hCmdLineOption{'mature_ref_t'} $hCmdLineOption{'mature_ref_o'} $hCmdLineOption{'Precursors_ref'} $sOutDir/Rfam_for_miRDeep.fa  "; 
    if(defined $hCmdLineOption{'other_args_mirdeep'}) {
	$cmd .= $hCmdLineOption{'other_args_mirdeep'} ;
    }
    $cmd .= " 2> $mirdeep/report.log ";
    exec_command($cmd);
    chdir $orig_dir;
}



if (defined $hCmdLineOption{'annotation'} ) {

	$filt_results = "$sOutDir/filtered_results";
	make_dir_tmp($filt_results);
	$cmd = "$hCmdLineOption{'filter_script'} --i $mirdeep/ --a $hCmdLineOption{'annotation'} --f $hCmdLineOption{'feature'} --id $hCmdLineOption{'attribute'} --t $hCmdLineOption{'annotation_format'} --o $filt_results --bb $hCmdLineOption{'bedtools_bin_dir'}" ;
	if (defined $hCmdLineOption{'score'} ) {
		$cmd .= " --s $hCmdLineOption{score}" ;
	}
	if (defined $hCmdLineOption{'depth'} ) {
		$cmd .= " --d $hCmdLineOption{'depth'}" ;
	}	
	
	exec_command($cmd) ;
}
		

remove_dir_tmp($dir_tmp);


################################################################################
### Subroutines
################################################################################
sub check_parameters {
    my $phOptions = shift;
    
    ## make sure input files provided
    if (! (defined $phOptions->{'infile'}) ) {
	pod2usage( -msg => $sHelpHeader, -exitval => 1);
    }
    if (! (defined $phOptions->{'ref_genome'}) ) {
	pod2usage( -msg => $sHelpHeader, -exitval => 1);
    }
    if (! (defined $phOptions->{'mature_ref_t'}) ) {
	pod2usage( -msg => $sHelpHeader, -exitval => 1);
    }
    if (! (defined $phOptions->{'Precursors_ref'}) ) {
	pod2usage( -msg => $sHelpHeader, -exitval => 1);
    }
    if (! (defined $phOptions->{'bowtie_bin'}) ) {
	$phOptions->{'bowtie_bin'} = "/usr/local/bin" ;
    }
    if (! (defined $phOptions->{'RNAfold_path'}) ) {
	$phOptions->{'RNAfold_path'} = "/usr/local/packages/ViennaRNA/bin" ;
    }
    if (! (defined $phOptions->{'randfold_path'}) ) {
	$phOptions->{'randfold_path'} = "/usr/local/packages/randfold" ;
    }
    
    if (! (defined $phOptions->{'mature_ref_o'}) ) {
	$phOptions->{'mature_ref_o'} = "none" ;
    }
     if (! (defined $phOptions->{'Rfam_file'}) or $phOptions->{'Rfam_file'} eq 'none' ) {
	$phOptions->{'Rfam_file'} = "/usr/local/packages/mirdeep2/Rfam_for_miRDeep.fa" ;
    }

    if (defined $phOptions->{'other_args_mapper'}) {
        if ($phOptions->{'other_args_mapper'} eq 'none') {
            delete $phOptions->{'other_args_mapper'} 
        }
    }

    if (defined $phOptions->{'other_args_mirdeep'}) {
        if ($phOptions->{'other_args_mirdeep'} eq 'none') {
            delete $phOptions->{'other_args_mirdeep'} 
        }
    }

    if (defined $phOptions->{'other_args_quantifier'}) {
        if ($phOptions->{'other_args_quantifier'} eq 'none') {
            delete $phOptions->{'other_args_quantifier'} 
        }
    }
    
    if (! defined $phOptions->{'bedtools_bin_dir'}) {
    	$phOptions->{'bedtools_bin_dir'} = BEDTOOLS_BIN_DIR ;
    }
    	
    if (defined $phOptions->{'annotation'}) {
    	if (! (defined $phOptions->{'feature'}) ) {
		pod2usage( -msg => $sHelpHeader, -exitval => 1);
    	}
    	if (! (defined $phOptions->{'annotation_format'}) ) {
		pod2usage( -msg => $sHelpHeader, -exitval => 1);
    	}
    	if (! (defined $phOptions->{'attribute'}) ) {
		pod2usage( -msg => $sHelpHeader, -exitval => 1);
    	}
    }
    
    if (! defined $phOptions->{'filter_script'}) {
    	$phOptions->{'filter_script'} = $RealBin."/novel_known_overlap.pl" ; 
    }
}

sub check_input {
    my $phOptions = shift;
    if (defined $phOptions->{'ref_genome'} ) {
    open IN,"<$phOptions->{'ref_genome'}";
	my $line=<IN>;
	chomp $line;
    if($line !~ /^>\S+/){
        printErr();
        die "The first line of file $phOptions->{'ref_genome'} does not start with '>identifier'
Reads file  $phOptions->{'ref_genome'} is not a valid fasta file\n\n";
    }
  	if($line =~ /\s/){
	    my  $cmd =  "remove_white_space_in_id.pl $phOptions->{'ref_genome'} > $dir_tmp/ref_genome_new.fa";
	    exec_command($cmd);
	    $phOptions->{'ref_genome'} = "$dir_tmp/ref_genome_new.fa" ;
    
	}

    close IN;
}
    if (defined $phOptions->{'mature_ref_t'} ) {
	if($phOptions->{'mature_ref_t'} !~ /none/){
	    open IN,"<$phOptions->{'mature_ref_t'}";
	    my $line=<IN>;
	    chomp $line;
	    if($line !~ /^>\S+/){
        printErr();
        die "The first line of file $phOptions->{'mature_ref_t'}  does not start with '>identifier'
Reads file $phOptions->{'mature_ref_t'} is not a valid fasta file\n\n";
    }
  	    if($line =~ /\s/){
		my  $cmd =  "remove_white_space_in_id.pl $phOptions->{'mature_ref_t'} > $dir_tmp/mature_ref_t_new.fa";
		exec_command($cmd);
		$phOptions->{'mature_ref_t'} = "$dir_tmp/mature_ref_t_new.fa" ;
		}
		$line=<IN>;
        
        close IN;
    }
    }
    if (defined $phOptions->{'mature_ref_o'} ) {
	if($phOptions->{'mature_ref_o'} !~ /none/){
	    open IN,"<$phOptions->{'mature_ref_o'}";
	    my $line=<IN>;
	    chomp $line;
	    if($line !~ /^>\S+/){
		printErr();
		die "The first line of file $phOptions->{'mature_ref_o'} does not start with '>identifier'
Reads file $phOptions->{'mature_ref_o'} is not a valid fasta file\n\n";
    }
	    if($line =~ /\s/){
		my  $cmd="remove_white_space_in_id.pl $phOptions->{'mature_ref_o'} > $dir_tmp/mature_ref_o_new.fa";
		exec_command($cmd);
		$phOptions->{'mature_ref_o'} = "$dir_tmp/mature_ref_o_new.fa";
		    	
		 }
       
        close IN;
	}
    }
    if (defined $phOptions->{'Precursors_ref'} ) {
	if($phOptions->{'Precursors_ref'} !~ /none/){
	    open IN,"<$phOptions->{'Precursors_ref'}";
	    my $line=<IN>;
	    chomp $line;
	    if($line !~ /^>\S+/){
        printErr();
        die "The first line of file $phOptions->{'Precursors_ref'} does not start with '>identifier'
Reads file $phOptions->{'Precursors_ref'} is not a valid fasta file\n\n";
    }
	    if($line =~ /\s/){
		my  $cmd="remove_white_space_in_id.pl $phOptions->{'Precursors_ref'} > $dir_tmp/Precursors_ref_new.fa";
		exec_command($cmd);
		
		$phOptions->{'Precursors_ref'} = "$dir_tmp/Precursors_ref_new.fa";
		
	  
		}
	close IN;
    }
    }

}

sub make_dir_tmp{
    my $dir = shift;
    unless (-d $dir){
	mkdir $dir or die "$!";
    }
}
sub remove_dir_tmp{
    if($options{v}){
	$tmp1=shift;
        print STDERR "rmtree($dir_tmp)\n\n";
        rmtree ("$tmp1");
    }
    return;
}


sub printErr{
    print STDERR color 'bold red';
    print STDERR "Error: ";
    print STDERR color 'reset';
}



sub exec_command {
        my $sCmd = shift;

        if ((!(defined $sCmd)) || ($sCmd eq "")) {
                die "\nSubroutine::exec_command : ERROR! Incorrect command!\n";
        }

        my $nExitCode;

        print STDERR "\n$sCmd\n";
        $nExitCode = system("$sCmd");
        if ($nExitCode != 0) {
                die "\tERROR! Command Failed!\n\t$!\n";
        }
        print STDERR "\n";

        return;
}  

sub myTime{
    my ($sec,$min,$hour,$day,$month,$year) = localtime($ctime);
    $year+=1900;
    $month++;
    my $ret=sprintf "%02d_%02d_%02d_t_%02d_%02d_%02d", $day, $month, $year, $hour, $min, $sec;
    return($ret);
}

################################################################################
