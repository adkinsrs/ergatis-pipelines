#!/usr/bin/perl

use strict;
use Config::IniFiles;
use File::Path;

umask(0022);

##########################################

die "Need to provide argument for install path: $!\n" if (scalar @ARGV < 1);

my $branch_name='arbor';
my $install_base=$ARGV[0];
my $ergatis_git_export_path='https://github.com/adkinsrs/ergatis-pipelines.git';	# This uses Git currently.  Others use SVN.

## this directory will be created.  If it exists already, it and everything under it
#   will be removed
my $tmp_area = "/tmp/build_${branch_name}";

## if this is set this script will keep any settings from this config file, overwriting
#   the defaults from the SVN one.
my $software_config_kept = '/usr/local/projects/ergatis/software.config';

##########################################

my $software_config;
if ( $software_config_kept ) {
    $software_config = new Config::IniFiles( -file => $software_config_kept ) ||
                        die "failed to open old software config: $!";
}

clear_export_area($tmp_area);
clear_install_area($install_base);

install_ergatis($install_base);

replace_software_config_values($software_config);
set_idgen_configuration($install_base);
print STDERR "DONE!!!... exiting\n";
exit(0);

sub clear_export_area {
    my $base = shift;
    
    rmtree($tmp_area);
    mkdir($tmp_area) || die "failed to create temp directory: $tmp_area";
}

sub clear_install_area {
    my $base = shift;

    for my $subdir ( qw( bin docs lib pipeline_templates) ) {
        rmtree("$base/$subdir");
    }
    
    for my $file ( qw( software.config CHANGELOG.md) ) {
        if ( -e "$base/$file" ) {
            unlink( "$base/$file" );
        }
    }
};

sub install_ergatis {
    my $base = shift;
    
    print STDERR "Cloning the repo $ergatis_git_export_path (branch $branch_name) into $base ...\n";
	# Git options
	# -b <name of branch>
	# -depth 1  (only get latest revision history - speeds up cloning)
	#
    my $cmd = "echo p | git clone -b $branch_name --depth 1 $ergatis_git_export_path $base";
    system($cmd);

	print STDERR "Removing .git related files ...\n";
	run_command("rm -rf $base/.git");

	print STDERR "Rearranging package-$branch_name files ...\n";
	# Move all package-lgtseek contents to parent dir, and merge core Ergatis lib files there
    run_command("mv $base/package-${branch_name}/* $base; mv $base/core/lib/perl5/Ergatis $base/lib/perl5/");

	# Create the wrapper scripts within the "bin" directory from the executable scripts
    print STDERR "Creating wrapper scripts ...\n";
	run_command("sh $base/core/create_wrappers.sh $base");

	# Lastly remove extraneous directories
	print STDERR "Removing useless directories ...\n";
	run_command("rm -rf $base/core; rm -rf $base/package-${branch_name}; rm -rf $base/pipeline_builder; rm $base/README.md");

}

sub replace_software_config_values {
    my $old_config = shift;
    
    my $new_config_path = "$install_base/software.config";
    
    my $new_config = new Config::IniFiles( -file => $new_config_path ); 
#                        die "failed to open old software config: $!";

    my $reset_permission_to = undef;

    if ( ! -w $new_config_path ) {
        $reset_permission_to = (stat $new_config_path)[2] & 07777;
        chmod(0644, $new_config_path) || die "couldn't chmod $new_config_path for writing";
    }  
                              
    for my $section ( $new_config->Sections() ) {
        if ( $old_config->SectionExists($section) ) {
            
            for my $parameter ( $new_config->Parameters($section) ) {
                if ( defined $old_config->val($section, $parameter) ) {
                    $new_config->setval( $section, $parameter, $old_config->val($section, $parameter) );
                }
            }
        }
    }
    
    $new_config->RewriteConfig;
    
    if ( defined $reset_permission_to ) {
        chmod($reset_permission_to, $new_config_path) || die "couldn't restore permissions on $new_config_path (tried to set to $reset_permission_to)";
    } 
};

sub run_command {
    my $cmd = shift;
    
    system($cmd);
    
    if ( $? == -1 ) {
        die "failed to execute command ($cmd): $!\n";
    } elsif ( $? & 127 ) {
         my $out = sprintf "command ($cmd): child died with signal %d, %s coredump\n",
                    ($? & 127),  ($? & 128) ? 'with' : 'without';
         die($out);
    }
}

sub set_idgen_configuration {
    my $base = shift;
    
	print STDERR "Changing default ID generation to IGS-style ID generation...\n";
    
	for my $conf_file ( "$base/lib/perl5/Ergatis/IdGenerator/Config.pm" ) {
    
        my $reset_permission_to = undef;
    
        if ( ! -w $conf_file ) {
            $reset_permission_to = (stat $conf_file)[2] & 07777;
            chmod(0644, $conf_file) || die "couldn't chmod $conf_file for writing";
        }
    
        my @lines = ();
    
        ## change $base/lib/perl5/Ergatis/IdGenerator/Config.pm
        open(my $cfh, $conf_file) || die "couldn't open $conf_file for reading";

        while ( my $line = <$cfh> ) {
            if ( $line !~ /^\#/ ) {
                $line =~ s/\:\:DefaultIdGenerator/\:\:IGSIdGenerator/g;
            }
            
            push @lines, $line;
        }

        close $cfh;
        
        ## now stomp it with our current content
        open(my $ofh, ">$conf_file") || die "couldn't open $conf_file for writing\n";
            print $ofh join('', @lines);
        close $ofh;
        
        if ( defined $reset_permission_to ) {
            chmod($reset_permission_to, $conf_file) || die "couldn't restore permissions on $conf_file (tried to set to $reset_permission_to)";
        }
    }
}
