package MIP::Program::Compression::Gzip;

use Carp;
use charnames qw{ :full :short };
use English qw{ -no_match_vars };
use File::Basename qw{ dirname };
use File::Spec::Functions qw{ catdir };
use FindBin qw{ $Bin };
use open qw{ :encoding(UTF-8) :std };
use Params::Check qw{ check allow last_error };
use strict;
use utf8;
use warnings;
use warnings qw{ FATAL utf8 };

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
    our $VERSION = 1.02;

    # Functions and variables which can be optionally exported
    our @EXPORT_OK = qw{ gzip };
}

## Constants
Readonly my $SPACE => q{ };

sub gzip {

## Function : Perl wrapper for writing gzip recipe to $FILEHANDLE or return commands array. Based on gzip 1.3.12.
## Returns  : @commands
## Arguments: $infile_path            => Infile path
##          : $stdout                 => Write on standard output, keep original files unchanged
##          : $decompress             => Decompress
##          : $force                  => Force overwrite of output file and compress links
##          : $outfile_path           => Outfile path. Write documents to FILE
##          : $FILEHANDLE             => Filehandle to write to (scalar undefined)
##          : $stderrfile_path        => Stderrfile path (scalar )
##          : $stderrfile_path_append => Append stderr info to file path
##          : $quiet                  => Suppress all warnings
##          : $verbose                => Verbosity

    my ($arg_href) = @_;

    ## Flatten argument(s)
    my $infile_path;
    my $stdout;
    my $decompress;
    my $force;
    my $outfile_path;
    my $FILEHANDLE;
    my $stderrfile_path;
    my $stderrfile_path_append;

    ## Default(s)
    my $quiet;
    my $verbose;

    my $tmpl = {
        infile_path => {
            required    => 1,
            defined     => 1,
            strict_type => 1,
            store       => \$infile_path
        },
        stdout => { strict_type => 1, store => \$stdout },
        decompress =>
          { allow => [ undef, 0, 1 ], strict_type => 1, store => \$decompress },
        force =>
          { allow => [ undef, 0, 1 ], strict_type => 1, store => \$force },
        outfile_path => { strict_type => 1, store => \$outfile_path },
        FILEHANDLE      => { store       => \$FILEHANDLE },
        stderrfile_path => { strict_type => 1, store => \$stderrfile_path },
        stderrfile_path_append =>
          { strict_type => 1, store => \$stderrfile_path_append },
        quiet => {
            default     => 0,
            allow       => [ 0, 1 ],
            strict_type => 1,
            store       => \$quiet
        },
        verbose => {
            default     => 0,
            allow       => [ 0, 1 ],
            strict_type => 1,
            store       => \$verbose
        },

    };

    check( $tmpl, $arg_href, 1 ) or croak q{Could not parse arguments!};

    ## Stores commands depending on input parameters
    my @commands = qw(gzip);

    ## Options
    if ($quiet) {

        push @commands, q{--quiet};
    }

    if ($verbose) {

        push @commands, q{--verbose};
    }

    if ($decompress) {

        push @commands, q{--decompress};
    }

    if ($force) {

        push @commands, q{--force};
    }

    ## Write to stdout stream
    if ($stdout) {

        push @commands, q{--stdout};
    }

    ## Infile
    push @commands, $infile_path;

    ## Outfile
    if ($outfile_path) {

        #Outfile
        push @commands, q{>} . $SPACE . $outfile_path;
    }

    push @commands,
      unix_standard_streams(
        {
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
