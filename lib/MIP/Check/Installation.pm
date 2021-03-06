package MIP::Check::Installation;

use strict;
use warnings;
use warnings qw{ FATAL utf8 };
use utf8;
use open qw{ :encoding(UTF-8) :std };
use charnames qw{ :full :short };
use Carp;
use English qw{ -no_match_vars };
use Params::Check qw{ check allow last_error };
use Cwd;
use File::Spec::Functions qw{ catdir catfile };

## Cpanm
use Readonly;

BEGIN {
    require Exporter;
    use base qw{ Exporter };

    # Set the version for version checking
    our $VERSION = 1.00;

    # Functions and variables which can be optionally exported
    our @EXPORT_OK = qw{ check_existing_installation };
}

## Constants
Readonly my $NEWLINE => qq{\n};
Readonly my $SPACE   => q{ };

sub check_existing_installation {

## Function : Checks if the program has already been installed and optionally removes the current installation.
##          : Returns "1" if the program is found and a noupdate flag has been provided
## Returns  : $install_check
## Arguments: $program_directory_path => Path to program directory
##          : $program_name                => Program name
##          : $conda_environment      => Conda environment
##          : $conda_prefix_path      => Path to conda environment
##          : $noupdate               => Do not update
##          : $FILEHANDLE             => Filehandle to write to
##          : $log                    => Log to write messages to

    my ($arg_href) = @_;

    ## Flatten argument(s)
    my $program_directory_path;
    my $program_name;
    my $conda_environment;
    my $conda_prefix_path;
    my $noupdate;
    my $FILEHANDLE;
    my $log;

    my $tmpl = {
        program_directory_path => {
            required    => 1,
            strict_type => 1,
            store       => \$program_directory_path
        },
        program_name => {
            required    => 1,
            defined     => 1,
            strict_type => 1,
            store       => \$program_name
        },
        conda_prefix_path => {
            required    => 1,
            defined     => 1,
            strict_type => 1,
            store       => \$conda_prefix_path
        },
        conda_environment => {
            strict_type => 1,
            store       => \$conda_environment
        },
        noupdate => {
            allow       => [ undef, 0, 1 ],
            strict_type => 1,
            store       => \$noupdate
        },
        FILEHANDLE => {
            required => 1,
            defined  => 1,
            store    => \$FILEHANDLE
        },
        log => {
            required => 1,
            defined  => 1,
            store    => \$log
        },
    };

    check( $tmpl, $arg_href, 1 ) or croak q{Could not parse arguments!};

    ## Modules
    use MIP::Gnu::Coreutils qw{ gnu_rm };
    use MIP::Gnu::Findutils qw{ gnu_find };
    use MIP::Log::MIP_log4perl qw{ retrieve_log };

    ## Set default for conda environment if undef
    if ( not $conda_environment ) {
        $conda_environment = q{root};
    }

    ## Check if installation directory exists
    if ( -d $program_directory_path ) {
        $log->info( $program_name
              . $SPACE
              . q{is already installed in conda environment: }
              . $conda_environment );

        if ($noupdate) {
            $log->info( q{Skipping writting installation instructions for }
                  . $program_name );
            say {$FILEHANDLE}
              q{## Skipping writting installation instructions for }
              . $program_name;
            say {$FILEHANDLE} $NEWLINE;

            return 1;
        }

        $log->warn(
            qq{This will overwrite the current $program_name installation});

        say {$FILEHANDLE} qq{## Removing old $program_name directory};
        gnu_rm(
            {
                infile_path => $program_directory_path,
                recursive   => 1,
                force       => 1,
                FILEHANDLE  => $FILEHANDLE,
            }
        );
        say {$FILEHANDLE} $NEWLINE;

        say {$FILEHANDLE} qq{## Removing old $program_name links};
        gnu_find(
            {
                search_path   => catdir( $conda_prefix_path, q{bin} ),
                test_criteria => q{-xtype l},
                action        => q{-delete},
                FILEHANDLE    => $FILEHANDLE,
            }
        );
        say {$FILEHANDLE} $NEWLINE;
    }

    $log->info(
        qq{Writing instructions for $program_name installation via SHELL});

    return 0;
}

1;
