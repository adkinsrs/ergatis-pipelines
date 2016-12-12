#!/usr/bin/bash

# create_wrappers.sh - Create wrapper files based on the executable scripts present in the bin directory
# Args - [1] - Base path of Ergatis package

for file in `ls -1 $1/bin`; do
	fileext=${filename##*.}
	case $fileext in
		pl)
			/usr/bin/perl perl2wrapper_ergatis.pl INSTALL_BASE=$1 $file
			;;
		py)
			/usr/bin/perl python2wrapper_ergatis.pl INSTALL_BASE=$1 $file
			;;
		jl)
			/usr/bin/perl julia2wrapper_ergatis.pl INSTALL_BASE=$1 $file
			;;
		*)
			echo "$file is not a Perl, Python, or Julia file... skipping\n"
			;;
	esac
done
