#!/usr/bin/env perl

use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use lib ("/usr/local/projects/ergatis/package-arbor/lib/perl5");
use Ergatis::Pipeline;
use Ergatis::SavedPipeline;
use Ergatis::ConfigFile;

my $ergatis_config = "/local/projects/ergatis/ergatis.ini";

my %options;
my $results = GetOptions (\%options,
                          "layout|l=s",
                          "config|c=s",
                          "ergatis_ini|e=s",
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
my $ecfg = $ergatis_config; 
$ecfg = $options{'ergatis_ini'} if( $options{'ergatis_ini'} );

my $ergatis_ini;
if( $ecfg ) {
    $ergatis_ini = new Ergatis::ConfigFile( '-file' => $ecfg );
}

my $id = &make_pipeline( $layout, $repo_root, $id_repo, $config, $ergatis_ini );

# Label the pipeline.
# &label_pipeline( $repo_root, $id);

my $url = "http://ergatis.igs.umaryland.edu/cgi/view_pipeline.cgi?instance=$repo_root/workflow/runtime/pipeline/$id/pipeline.xml";
print "pipeline_id -> $id | pipeline_url -> $url\n";

sub make_pipeline {
    my ($pipeline_layout, $repository_root, $id_repo, $config, $ergatis_ini) = @_;
    my $template = new Ergatis::SavedPipeline( 'template' => $pipeline_layout );
    $template->configure_saved_pipeline( $config, $repository_root, $id_repo );
    my $pipeline_id = $template->pipeline_id();    
    if( $ergatis_ini ) {
        my $xml = $repository_root."/workflow/runtime/pipeline/$pipeline_id/pipeline.xml";
        my $pipeline = new Ergatis::Pipeline( id => $pipeline_id,
                                              path => $xml );
        if(length($user_email) > 0) {
        	$pipeline->run( 'ergatis_cfg' => $ergatis_ini, 'email_user' => $user_email );
        }
        else {
        	$pipeline->run( 'ergatis_cfg' => $ergatis_ini );
        }
    }
    return $pipeline_id;
}

sub check_options {
    my ($opts) = @_;
    
    my @reqs = qw(layout config repository_root);
    foreach my $req ( @reqs ) {
        die("Option $req is required") unless( exists( $opts->{$req} ) );
    }

    
}
