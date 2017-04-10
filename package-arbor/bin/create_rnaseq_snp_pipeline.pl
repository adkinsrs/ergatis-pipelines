#!/usr/bin/env perl
package main;    # Change this to reflect name of script.  If you want to use as module, make sure to save as .pm instead of .pl

=head1 NAME

create_rnaseq_snp_pipeline.pl - Will create a pipeline.layout and pipeline.config for the RNASeq SNP pipeline

=head1 SYNOPSIS

 USAGE: create_rnaseq_snp_pipeline.pl
       --input_file=/path/to/some/input.file
       --output=/path/to/transterm.file
     [ --log=/path/to/file.log
       --debug=3
       --help
     ]

=head1 OPTIONS

B<--input_file, -i>
	Path to the input BAM file to pass to the first component

B<--template_directory,-t>
	Path of the template configuration and layout files used to create the pipeline config and layout files.

B<--output_directory, -o>
	Directory to write the pipeline.config and pipeline.layout files

B<--config_file, -c>
    Path to find the input config file that stores information for each component

B<--log,-l>
    Logfile.

B<--debug,-d>
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
use XML::Writer;
use Time::localtime;

############# GLOBALS AND CONSTANTS ################
my $debug = 1;
my ($ERROR, $WARN, $DEBUG) = (1,2,3);
my $logfh;

my $outdir = ".";
my $template_directory = "/local/projects/ergatis/package-arbor/pipeline_templates";
####################################################

my %options;
my $pipelines = {
		'rnaseq' => 'RNASeq_SNP_Pipeline',
};


# Allow program to run as module for unit testing if necessary
main() unless caller();
exit(0);

sub main {
	my $results = GetOptions (\%options,
						  "config_file|c=s",
						  "input_file|i=s",
						  "template_directory|t=s",
						  "output_directory|o=s",
						  "log|l=s",
						  "debug=i",
						  "help"
					);

    &check_options(\%options);

	mkdir( $outdir . "/" . timestamp() ) || die "Cannot create timestampped directory within $outdir\n";
	$outdir = $outdir . "/" . timestamp();
	# The file that will be written to
	my $pipeline_layout = $outdir."/pipeline.layout";
	my $pipeline_config = $outdir."/pipeline.config";
	my $sample_config = $outdir . "/input.config";

	# File handles for files to be written
	open( my $plfh, "> $pipeline_layout") or &_log($ERROR, "Could not open $pipeline_layout for writing: $!");
	# Since the pipeline.layout is XML, create an XML::Writer
	my $layout_writer = new XML::Writer( 'OUTPUT' => $plfh, 'DATA_MODE' => 1, 'DATA_INDENT' => 3 );
	# Write the pipeline.layout file
	&write_pipeline_layout( $layout_writer, sub {
		my ($writer) = @_;
		&write_include($writer, $pipelines->{'rnaseq'});
	});
	# end the writer
	$layout_writer->end();

	my %config;
	# Write the pipeline config file
	&add_config( \%config, $pipelines->{'rnaseq'} );
	$config{'extract_chromosomes'}{'$;INPUT_FILE$;'} = $sample_config;
	# open config file for writing
	open( my $pcfh, "> $pipeline_config") or &_log($ERROR, "Could not open $pipeline_config for writing: $!");
	# Write the config
	&write_config( \%config, $pcfh );

	# close the file handles
	close($plfh);
	close($pcfh);

	# Write sample.config file
	my %input_config;
	&add_config( \%input_config, $pipelines->{'rnaseq'}, basename($sample_config));
	# Add BAM input file into 'extract_chromosomes' config section
	$input_config{'extract_chromosomes'}{'$;INPUT_FILE$;'} = $options{'input_file'};
	# Write sample config file
	open( my $sfh, "> $sample_config") or &_log($ERROR, "Could not open $sample_config for writing: $!");
	&write_config(\%input_config, $sfh);
	close ($sfh);

	my $mode = 0755;
	chmod $mode, $pipeline_config;
	chmod $mode, $pipeline_layout;
	chmod $mode, $sample_config;

	print "Wrote $pipeline_layout and $pipeline_config for 'RNASeq SNP' pipeline\n";
	print "Wrote $sample_config for 'RNASeq SNP' pipeline\n";
}

### UTILITY SUBROUTINES ###

sub write_config {
    my ($config, $fh) = @_;

    # Make sure this section is first
    &write_section( 'global', $config->{'global'}, $fh );
    delete( $config->{'global'} );

    foreach my $section ( keys %{$config} ) {
        &write_section( $section, $config->{$section}, $fh );
    }
}

sub write_section {
    my ($section, $config, $fh) = @_;
    print $fh "[$section]\n";

    foreach my $k ( sort keys %{$config} ) {
      print $fh "$k=$config->{$k}\n";
    }
    print $fh "\n";
}

sub add_config {
    my ($config, $subpipeline, $config_name) = @_;
	print $template_directory, "\t", $subpipeline, "\n";
    my $pc = "$template_directory/$subpipeline/pipeline.config";
    $pc = "$template_directory/$subpipeline/$config_name" if( $config_name );
    open(IN, "< $pc") or &_log($ERROR, "Could not open $pc for reading: $!");

    my $section;
    while(my $line = <IN> ) {
        chomp( $line );
        next if( $line =~ /^\s*$/ || $line =~ /^\;/ );

        if( $line =~ /^\[(.*)\]/ ) {
            $section = $1;
        } elsif( $line =~ /(\$\;.*\$\;)\s*=\s*(.*)/ ) {
            &_log($ERROR, "Did not find section before line $line") unless( $section );
            $config->{$section} = {} unless( exists( $config->{$section} ) );
            $config->{$section}->{$1} = $2;
        }

    }

    close(IN);
}

sub write_parallel_commandSet {
    my ($writer, $block) = @_;
    $writer->startTag("commandSet", 'type' => 'parallel');
    $writer->dataElement("state","incomplete");
    $block->($writer);
    $writer->endTag("commandSet");
}

sub write_pipeline_layout {
    my ($writer, $body) = @_;
    $writer->startTag("commandSetRoot",
                      "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
                      "xsi:schemaLocation" => "commandSet.xsd",
                      "type" => "instance" );

    $writer->startTag("commandSet",
                      "type" => "serial" );

    $writer->dataElement("state", "incomplete");
    $writer->dataElement("name", "start pipeline:");

    $body->($writer);

    $writer->endTag("commandSet");
    $writer->endTag("commandSetRoot");
}

sub write_include {
    my ($writer, $sub_pipeline, $pipeline_layout) = @_;
    $pipeline_layout = "pipeline.layout" unless( $pipeline_layout );
    my $sublayout = $template_directory."/$sub_pipeline/$pipeline_layout";
    &_log($ERROR, "Could not find sub pipeline layout $sublayout\n") unless( -e $sublayout );
    $writer->emptyTag("INCLUDE", 'file' => "$sublayout");
}

sub timestamp {
    my $t = localtime;
    return sprintf ("%04d-%02d-%02d_%02d-%02d-%02d",
                  $t->year + 1900, $t->mon + 1, $t->mday,
                  $t->hour, $t->min, $t->sec );
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

    foreach my $req ( qw(input_file output_directory config_file) ) {
        die("Option $req is required: $!")  unless ($opts->{$req});
    }
   	$outdir = $opts->{'output_directory'} if( $opts->{'output_directory'} );
   	$template_directory = $opts->{'template_directory'} if( $opts->{'template_directory'} );

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
