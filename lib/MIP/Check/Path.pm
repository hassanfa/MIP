package MIP::Check::Path;

#### Copyright 2017 Henrik Stranneheim

use strict;
use warnings;
use warnings qw{ FATAL utf8 };
use utf8;    #Allow unicode characters in this script
use open qw{ :encoding(UTF-8) :std };
use charnames qw{ :full :short };
use Carp;
use autodie;
use Params::Check qw{ check allow last_error };
$Params::Check::PRESERVE_CASE = 1;    #Do not convert to lower case

BEGIN {

    use base qw{ Exporter };
    require Exporter;

    # Set the version for version checking
    our $VERSION = 1.01;

    # Functions and variables which can be optionally exported
    our @EXPORT_OK = qw{ check_file_version_exist check_dir_path_exist };
}

sub check_file_version_exist {

##check_file_version_exist

##Function : Check if a file with with a filename consisting of $file_path_prefix_ref.$file_counter.$file_path_suffix_ref exist. If so bumps the version number and return new file path and version number.
##Returns  : "$file_path, $file_name_counter"
##Arguments: $file_path_prefix_ref, $file_path_suffix_ref
##         : $file_path_prefix_ref => The file path {REF}
##         : $file_path_suffix_ref => The file ending {REF}

    my ($arg_href) = @_;

    ## Flatten argument(s)
    my $file_path_prefix_ref;
    my $file_path_suffix_ref;

    my $tmpl = {
        file_path_prefix_ref => {
            required    => 1,
            defined     => 1,
            default     => \$$,
            strict_type => 1,
            store       => \$file_path_prefix_ref
        },
        file_path_suffix_ref => {
            required    => 1,
            defined     => 1,
            default     => \$$,
            strict_type => 1,
            store       => \$file_path_suffix_ref
        },
    };

    check( $tmpl, $arg_href, 1 ) or croak q{Could not parse arguments!};

    # Nr of sbatch scripts with identical filenames i.e. version number
    my $file_name_counter = 0;

    my $file_path =
      ${$file_path_prefix_ref} . $file_name_counter . ${$file_path_suffix_ref};

  FILE_PATHS:
    while ( -e $file_path ) {

        $file_name_counter++;

        # New file_path to test for existence
        $file_path =
            ${$file_path_prefix_ref}
          . $file_name_counter
          . ${$file_path_suffix_ref};
    }
    return ( $file_path, $file_name_counter );
}

sub check_dir_path_exist {

## conda_check

## Function  : Checks if any of the supplied paths exists. Returns an array that holds the existing paths.
## Returns   : @existing_dir_paths
## Arguments : $dir_paths_ref
##           : $dir_paths_ref => Ref to array of supplied paths

    my ($arg_href) = @_;

    ## Flatten argument(s)
    my $dir_paths_ref;

    my $tmpl = {
        dir_paths_ref => {
            default     => [],
            required    => 1,
            strict_type => 1,
            store       => \$dir_paths_ref,
        },
    };

    check( $tmpl, $arg_href, 1 ) or croak q{Could not parse arguments!};

    my @existing_dir_paths;

    # Search for directory in supplied paths
    @existing_dir_paths = grep { -d $_ } @{$dir_paths_ref};
    
    return @existing_dir_paths;
}

1;