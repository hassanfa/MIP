package MIP::Program::Download::Wget;

use strict;
use warnings;
use warnings qw{ FATAL utf8 };
use utf8;
use open qw{ :encoding(UTF-8) :std };
use charnames qw{ :full :short };
use Carp;
use English qw{ -no_match_vars };
use Params::Check qw{ check allow last_error };
use FindBin qw{ $Bin };
use File::Basename qw{ dirname };
use File::Spec::Functions qw{ catdir };

## CPANM
use Readonly;

## MIPs lib/
use lib catdir( dirname($Bin), q{lib} );
use MIP::Unix::Standard_streams qw{ unix_standard_streams };
use MIP::Unix::Write_to_file qw{ unix_write_to_file };

BEGIN {
    require Exporter;
    use base qw{ Exporter };

    # Set the version for version checking
    our $VERSION = 1.01;

    # Functions and variables which can be optionally exported
    our @EXPORT_OK = qw{ wget };
}

## Constants
Readonly my $SPACE => q{ };

sub wget {

## wget

## Function : Perl wrapper for writing wget recipe to $FILEHANDLE or return commands array. Based on GNU Wget 1.12, a non-interactive network retriever.
## Returns  : @commands
## Arguments: $outfile_path, $url, $stdoutfile_path, $stderrfile_path, stderrfile_path_append, $FILEHANDLE, $quiet, $verbose
##          : $stdoutfile_path        => Stdoutfile path
##          : $stderrfile_path        => Stderrfile path
##          : $stderrfile_path_append => Append stderr info to file path
##          : $FILEHANDLE             => Filehandle to write to
##          : $outfile_path           => Outfile path. Write documents to FILE
##          : $url                    => Url to use for download
##          : $quiet                  => Quiet (no output)
##          : $verbose                => Verbosity

    my ($arg_href) = @_;

    ## Default(s)
    my $quiet;
    my $verbose;

    ## Flatten argument(s)
    my $stdoutfile_path;
    my $stderrfile_path;
    my $stderrfile_path_append;
    my $FILEHANDLE;
    my $outfile_path;
    my $url;

    my $tmpl = {
        outfile_path => { strict_type => 1, store => \$outfile_path },
        url =>
          { required => 1, defined => 1, strict_type => 1, store => \$url },
        stdoutfile_path => { strict_type => 1, store => \$stdoutfile_path },
        stderrfile_path => { strict_type => 1, store => \$stderrfile_path },
        stderrfile_path_append =>
          { strict_type => 1, store => \$stderrfile_path_append },
        FILEHANDLE => { store => \$FILEHANDLE },
        quiet      => {
            default     => 0,
            allow       => [ undef, 0, 1 ],
            strict_type => 1,
            store       => \$quiet
        },
        verbose => {
            default     => 1,
            allow       => [ undef, 0, 1 ],
            strict_type => 1,
            store       => \$verbose
        },
    };

    check( $tmpl, $arg_href, 1 ) or croak q{Could not parse arguments!};

    ## Wget
    # Stores commands depending on input parameters
    my @commands = qw{ wget };

    if ($quiet) {

        push @commands, q{--quiet};
    }
    if ($verbose) {

        push @commands, q{--verbose};
    }
    else {

        push @commands, q{--no-verbose};
    }

    ## URL
    push @commands, $url;

    ## Outfile
    if ($outfile_path) {

        push @commands, q{-O} . $SPACE . $outfile_path;
    }

    push @commands,
      unix_standard_streams(
        {
            stdoutfile_path        => $stdoutfile_path,
            stderrfile_path        => $stderrfile_path,
            stderrfile_path_append => $stderrfile_path_append,
        }
      );

    unix_write_to_file(
        {
            commands_ref => \@commands,
            separator    => $SPACE,
            FILEHANDLE   => $FILEHANDLE,
        }
    );

    return @commands;
}

1;
