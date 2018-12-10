#!/usr/bin/env perl

use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use lib ("../lib/perl5");
use Ergatis::Pipeline;
use Ergatis::SavedPipeline;
use Ergatis::ConfigFile;

# If on a Docker container being run on Docker-Machine, get IP of Docker Host
my $host = 'ergatis.igs.umaryland.edu/';
if (defined $ENV{'DOCKER_HOST'}) {
    $host = $ENV{'DOCKER_HOST'} . ":8080/ergatis";
}

# If true, script will not exit until pipeline finishes
my $block = 0;

my %options;
my $results = GetOptions (\%options,
                          "layout|l=s",
                          "config|c=s",
                          "block|b",
                          "ergatis_config|e=s",
                          "repository_root|r=s",
                          "email_id|m=s"
                          );

&check_options(\%options);

my $repo_root = $options{'repository_root'};
my $id_repo = $repo_root."/workflow/project_id_repository";

my $layout = $options{'layout'};
my $config = $options{'config'};
my $user_email = "";
$user_email = $options{'email_id'} if( $options{'email_id'} );
my $ecfg; 
$ecfg = $options{'ergatis_config'} if( $options{'ergatis_config'} );

my $ergatis_config;
if( $ecfg ) {
    $ergatis_config = new Ergatis::ConfigFile( '-file' => $ecfg );
}

my $id = &make_pipeline( $layout, $repo_root, $id_repo, $config, $ergatis_config );

# Label the pipeline.
# &label_pipeline( $repo_root, $id);

my $url = "http://${host}/cgi/view_pipeline.cgi?instance=$repo_root/workflow/runtime/pipeline/$id/pipeline.xml";
print "pipeline_id -> $id | pipeline_url -> $url\n";

sub make_pipeline {
    my ($pipeline_layout, $repository_root, $id_repo, $config, $ergatis_config) = @_;
    my $template = new Ergatis::SavedPipeline( 'template' => $pipeline_layout );
    $template->configure_saved_pipeline( $config, $repository_root, $id_repo );
    my $pipeline_id = $template->pipeline_id();    
    if( $ergatis_config ) {
        my $xml = $repository_root."/workflow/runtime/pipeline/$pipeline_id/pipeline.xml";
        my $pipeline = new Ergatis::Pipeline( id => $pipeline_id,
                                              path => $xml );
        my $success;
        if(length($user_email) > 0) {
        	$success = $pipeline->run( 'ergatis_cfg' => $ergatis_config, 'email_user' => $user_email, 'block' => $block );
        }
        else {
        	$success = $pipeline->run( 'ergatis_cfg' => $ergatis_config, 'block' => $block );
        }

        # Only execute in docker
        if ($block && !$success && $host ne 'ergatis.igs.umaryland.edu/'){
            # If not successful, gather information about failed pipeline
            my $stderr = "Problem running pipeline id:$pipeline->{'id'}\n\n";
            $stderr .= "$pipeline->{'diagnostics'}->{'complete_components'} of ";
            $stderr .= "$pipeline->{'diagnostics'}->{'total_components'} completed\n";
            $stderr .= "\n";

            $stderr .= "ERROR running component(s): \n";
            foreach my $c (@{$pipeline->{'diagnostics'}->{'components'}}) {
                $stderr .= "\t$c\n";

                foreach my $t (@{$pipeline->{'diagnostics'}->{'command_info'}->{$c}}) {
                    my $c = $$t[0];
                    my $f = $$t[1];

                    if (length $f) {
                        open(FHD, "<", $f) or die "Could not open file $f\n$!";
                        while(<FHD>) {
                            $stderr .= "\t\t$_";
                        }
                        $stderr .= "\n";
                    }
                }
            }

            print STDERR $stderr;

            my $output_dir = "/mnt/output_data";
            mkdir($output_dir . "/logs");

            my $cmd = "scp /opt/projects/rnaseq/workflow/runtime/pipeline/$pipeline->{'id'}/pipeline.xml.log";
            $cmd .= " $output_dir/logs/.";
            system("$cmd");

            open(OUT, ">", "$output_dir/logs/$pipeline->{'id'}.stderr") or
                die "Could not open file to write error log $output_dir/logs/$pipeline->{'id'}.stderr\n";
            print OUT $stderr;
            close(OUT);
        }
    }
    return $pipeline_id;
}

# sub label_pipeline {
# 	my ($repository_root, $pipeline_id) = @_; 
# 	my $pipeline_runtime_folder = "$repository_root/workflow/runtime/pipeline/$pipeline_id";
# 	my $groups_file = "$pipeline_runtime_folder/pipeline.xml.groups";
#         open( GROUP, ">> $groups_file") or die("Unable to open $groups_file for writing ($!)");
#         print GROUP "$comment\n";
#         close(GROUP);
# 	my $comment_file = "$pipeline_runtime_folder/pipeline.xml.comment";
#         open( COM, ">> $comment_file") or die("Unable to open $comment_file for writing ($!)");
#         print COM "$comment";
#         close(COM);
# }

sub check_options {
    my ($opts) = @_;
    
    my @reqs = qw(layout config repository_root);
    foreach my $req ( @reqs ) {
        die("Option $req is required") unless( exists( $opts->{$req} ) );
    }

    $block = (defined $opts->{$block}) ? 1 : 0;
    
}
