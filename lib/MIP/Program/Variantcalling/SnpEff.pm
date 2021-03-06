package MIP::Program::Variantcalling::SnpEff;

use strict;
use warnings;
use warnings qw{ FATAL utf8 };
use utf8;
use open qw{ :encoding(UTF-8) :std };
use charnames qw{ :full :short };
use Carp;
use English qw{ -no_match_vars };
use Params::Check qw{ check allow last_error };
use Readonly;
use Cwd;
use File::Spec::Functions qw{ catdir };

## MIPs lib/
use MIP::Gnu::Coreutils qw{ gnu_rm };
use MIP::Language::Java qw{ java_core };
use MIP::Script::Utils qw{ create_temp_dir };
use MIP::Unix::Standard_streams qw{ unix_standard_streams };
use MIP::Unix::Write_to_file qw{ unix_write_to_file };

## Constants
Readonly my $SPACE      => q{ };
Readonly my $NEWLINE    => qq{\n};
Readonly my $UNDERSCORE => q{_};

BEGIN {

    use base qw{ Exporter };
    require Exporter;

    # Set the version for version checking
    our $VERSION = 1.0.2;

    # Functions and variables which can be optionally exported
    our @EXPORT_OK = qw{ snpeff_download };

}

sub snpeff_download {

## snpeff_download

## Function : Write instructions to download snpeff database
## Returns  : @commands
## Arguments: $FILEHANDLE              => FILEHANDLE to write to
##          : $memory_allocation       => Java memory allocation
##          : $config_file_path        => Path to snpeff config file
##          : $genome_version_database => Database to be downloaded
##          : $jar_path                => Path to snpeff jar
##          : $verbose                 => Verbose output
##          : $stderrfile_path         => Stderrfile path
##          : $stderrfile_path_append  => Append to stderrinfo to file
##          : $stdoutfile_path         => Stdoutfile path

    my ($arg_href) = @_;

    ## Flatten argument(s)
    my $FILEHANDLE;
    my $genome_version_database;
    my $jar_path;
    my $config_file_path;
    my $stderrfile_path;
    my $stderrfile_path_append;
    my $stdoutfile_path;
    my $memory_allocation;
    my $verbose;
    my $temp_directory;

    my $tmpl = {
        FILEHANDLE => {
            required => 1,
            store    => \$FILEHANDLE,
        },
        genome_version_database => {
            required    => 1,
            defined     => 1,
            strict_type => 1,
            store       => \$genome_version_database,
        },
        jar_path => {
            required    => 1,
            defined     => 1,
            strict_type => 1,
            store       => \$jar_path,
        },
        config_file_path => {
            defined     => 1,
            strict_type => 1,
            store       => \$config_file_path,
        },
        stderrfile_path => {
            strict_type => 1,
            store       => \$stderrfile_path
        },
        stderrfile_path_append => {
            strict_type => 1,
            store       => \$stderrfile_path_append
        },
        stdoutfile_path => {
            strict_type => 1,
            store       => \$stdoutfile_path
        },
        memory_allocation => {
            default     => q{Xmx2g},
            defined     => 1,
            strict_type => 1,
            store       => \$memory_allocation,
        },
        verbose => {
            default     => 1,
            allow       => [ 0, 1 ],
            strict_type => 1,
            store       => \$verbose,
        },
        temp_directory => {
            default => 0,
            allow   => [ 0, 1 ],
            store   => \$temp_directory,
        },
    };

    check( $tmpl, $arg_href, 1 ) or croak q{Could not parse arguments!};

    ## Create optional temporary directory
    if ($temp_directory) {
        $temp_directory = create_temp_dir( { FILEHANDLE => $FILEHANDLE } );
        say {$FILEHANDLE} $NEWLINE;
    }

    ## Build base command
    my @base = java_core(
        {
            memory_allocation => $memory_allocation,
            java_jar          => $jar_path,
            temp_directory    => $temp_directory,
        }
    );
    my @commands = ( @base, qw{download} );

    ## Add database to be downloaded
    push @commands, $genome_version_database;

    ## Add verbose flag
    if ($verbose) {
        push @commands, q{-v};
    }

    ## Add otional path to config file
    if ($config_file_path) {
        push @commands, q{-c} . $SPACE . $config_file_path;
    }

    ## Optionally capture output
    push @commands,
      unix_standard_streams(
        {
            stdoutfile_path        => $stdoutfile_path,
            stderrfile_path        => $stderrfile_path,
            stderrfile_path_append => $stderrfile_path_append,
        }
      );

    ## Write rest of java commadn to $FILEHANDLE
    unix_write_to_file(
        {
            commands_ref => \@commands,
            separator    => $SPACE,
            FILEHANDLE   => $FILEHANDLE,
        }
    );

    if ($temp_directory) {
        say {$FILEHANDLE} $NEWLINE;
        gnu_rm(
            {
                infile_path => $temp_directory,
                recursive   => 1,
                FILEHANDLE  => $FILEHANDLE,
            }
        );
    }

    return @commands;
}

1;
