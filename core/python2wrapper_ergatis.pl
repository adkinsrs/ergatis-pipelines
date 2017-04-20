#!/usr/bin/env perl
use File::Basename;
use File::Find;

use strict;
use warnings;

# Run script independently but allow to be used as a module
get_python_bins() unless caller();

sub get_python_bins{
    my $instdir='';
	my $workflowdocsdir='';
	my $schemadocsdir='';
	my $fname = '';

    my $python_path = `which python`;  ## can be overwritten below
    chomp $python_path;   
    foreach my $arg (@ARGV){
        if($arg =~ /INSTALL_BASE/){
            ($instdir) = ($arg =~ /INSTALL_BASE=(.*)/);
        }
        elsif($arg =~ /WORKFLOW_DOCS_DIR/){
            ($workflowdocsdir) = ($arg =~ /WORKFLOW_DOCS_DIR=(.*)/);
        }
        elsif($arg =~ /SCHEMA_DOCS_DIR/){
            ($schemadocsdir) = ($arg =~ /SCHEMA_DOCS_DIR=(.*)/);
        }
        elsif($arg =~ /PYTHON_PATH/){
            ($python_path) = ($arg =~ /PYTHON_PATH=(.*)/);
        }
		else {
			$fname = $arg;
			chomp $fname;
		}
    }

    my $envbuffer;
    my $env_hash = {'WORKFLOW_DOCS_DIR' => "$workflowdocsdir",
		    'SCHEMA_DOCS_DIR' => "$schemadocsdir",
		    'WORKFLOW_WRAPPERS_DIR'  => "$instdir/bin"
		    };
    
    foreach my $key (keys %$env_hash){
	$envbuffer .= "if [ -z \"\$$key\" ]\nthen\n    $key=$env_hash->{$key}\nexport $key\nfi\n";
    }

    my($strip_fname) = ($fname =~ /(.*)\.py$/);
	
	# Open wrapper for writing to.
	open WRAPPER, "+>$instdir/bin/$strip_fname" or die "Can't open file $instdir/bin/$strip_fname\n";
	my ($shell_args)  = q/"$@"/;
	my $addbuffer = $envbuffer;
    print WRAPPER <<_END_WRAPPER_;
#!/bin/sh
$addbuffer

umask 0000

unset PERL5LIB
unset LD_LIBRARY_PATH

export LD_LIBRARY_PATH=/usr/local/packages/tbb/lib/intel64/gcc4.7

LANG=C
export LANG
LC_ALL=C
export LC_ALL

    $python_path $instdir/bin/$fname $shell_args    

_END_WRAPPER_
   ;
   close WRAPPER;
}


1;
