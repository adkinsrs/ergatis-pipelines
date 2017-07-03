#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell

use strict;
use warnings;
use Getopt::Long;

my $options = {};

GetOptions( $options, 'input_file_list|l:s', 'input_files|f:s', 'makeblastdb_path|p=s', 'protein=s', 'database_name|n=s' );

my $files = "";

if( $$options{'input_files'} ) {
	$files .= $$options{'input_files'}." ";
} 

if( $$options{'input_file_list'} ) {
	$files .= get_files( $$options{'input_file_list'} );
}

my $dbtype = $$options{'protein'} eq 'T' ? "prot" : "nucl";

my $command = "$$options{'makeblastdb_path'} -dbtype $dbtype -parse_seqids -hash_index -in '$files' -out $$options{'database_name'}";

print $command,"\n";
system( $command ) == 0 or die "Error in executing the command, $command, $!\n";

exit $?;


sub get_files {
	my ($list) = @_;
    # In case list is really a space-separated string of lists
    my @list_arr = split(/\s+/, $list);
    my @files = ();
    foreach my $l (@list_arr) {
        open( FH, "<$l" ) or die "Error in opening the file, $l, $!\n";
        while( my $file = <FH> ) {
            chomp $file;
            if( -e $file ) { push @files, $file; }
            else { print STDERR "$file : No such file exists\n"; }
        }
    }
	return join($", @files);
}
