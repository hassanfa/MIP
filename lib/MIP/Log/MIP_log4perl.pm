package MIP::Log::MIP_log4perl;

use Carp;
use charnames qw{ :full :short };
use English qw{ -no_match_vars };
use File::Spec::Functions qw{ catfile };
use File::Path qw{ make_path };
use open qw{ :encoding(UTF-8) :std };
use Params::Check qw{ check allow last_error };
use strict;
use utf8;
use warnings;
use warnings qw{ FATAL utf8 };

## CPANM
use Log::Log4perl qw{ get_logger :levels };
use Readonly;

BEGIN {
    require Exporter;
    use base qw{ Exporter };

    # Set the version for version checking
    our $VERSION = 1.03;

    # Functions and variables which can be optionally exported
    our @EXPORT_OK =
      qw{ create_log4perl_config initiate_logger set_default_log4perl_file retrieve_log };
}

## Constants
Readonly my $COMMA      => q{,};
Readonly my $DOT        => q{.};
Readonly my $NEWLINE    => qq{\n};
Readonly my $SPACE      => q{ };
Readonly my $UNDERSCORE => q{_};

sub initiate_logger {

## Function : Initiate the logger object
## Returns  : $logger {OBJ}
## Arguments: $categories_ref => Log categories {REF}
##          : $file_path      => log4perl config file path
##          : $log_name       => Log name

    my ($arg_href) = @_;

    ## Default(s)
    my $categories_ref;

    ## Flatten argument(s)
    my $file_path;
    my $log_name;

    my $tmpl = {
        categories_ref => {
            default     => [qw{ TRACE LogFile ScreenApp }],
            strict_type => 1,
            store       => \$categories_ref
        },
        file_path => {
            required    => 1,
            defined     => 1,
            strict_type => 1,
            store       => \$file_path
        },
        log_name => {
            required    => 1,
            defined     => 1,
            strict_type => 1,
            store       => \$log_name
        },
    };

    check( $tmpl, $arg_href, 1 ) or croak q{Could not parse arguments!};

    ## Creates config for the log file
    my $config = create_log4perl_config(
        {
            categories_ref => $categories_ref,
            file_path      => $file_path,
            log_name       => $log_name,
        }
    );

    Log::Log4perl->init( \$config );
    my $logger = Log::Log4perl->get_logger($log_name);
    return $logger;
}

sub create_log4perl_config {

## Function : Create log4perl config file.
## Returns  : $config
## Arguments: $categories_ref => Log categories {REF}
##          : $file_path      => log4perl config file path
##          : $log_name       => Log name

    my ($arg_href) = @_;

    ## Default(s)
    my $categories_ref;

    ## Flatten argument(s)
    my $file_path;
    my $log_name;

    my $tmpl = {
        categories_ref => {
            default     => [qw{ TRACE LogFile ScreenApp }],
            strict_type => 1,
            store       => \$categories_ref
        },
        file_path => {
            required    => 1,
            defined     => 1,
            strict_type => 1,
            store       => \$file_path
        },
        log_name => {
            required    => 1,
            defined     => 1,
            strict_type => 1,
            store       => \$log_name
        },
    };

    check( $tmpl, $arg_href, 1 ) or croak q{Could not parse arguments!};

    my $config =
        q{log4perl.category.}
      . $log_name
      . $SPACE . q{=}
      . $SPACE
      . join $COMMA
      . $SPACE, @{$categories_ref};
    $config .= <<"EOF";
$NEWLINE log4perl.appender.LogFile = Log::Log4perl::Appender::File
$NEWLINE log4perl.appender.LogFile.filename = $file_path
$NEWLINE log4perl.appender.LogFile.layout=PatternLayout
$NEWLINE log4perl.appender.LogFile.layout.ConversionPattern = [%p] %d %c - %m%n
$NEWLINE log4perl.appender.ScreenApp = Log::Log4perl::Appender::ScreenColoredLevels
$NEWLINE log4perl.appender.ScreenApp.layout = PatternLayout
$NEWLINE log4perl.appender.ScreenApp.layout.ConversionPattern = [%p] %d %c - %m%n
$NEWLINE log4perl.appender.ScreenApp.color.DEBUG=
$NEWLINE log4perl.appender.ScreenApp.color.INFO=
$NEWLINE log4perl.appender.ScreenApp.color.WARN=yellow
$NEWLINE log4perl.appender.ScreenApp.color.ERROR=red
$NEWLINE log4perl.appender.ScreenApp.color.FATAL=red
EOF
    return $config;
}

sub set_default_log4perl_file {

## Function : Set the default Log4perl file using supplied dynamic parameters.
## Returns  : $log_file
## Arguments: $active_parameter_href => Active parameters for this analysis hash {REF}
##          : $cmd_input             => User supplied info on cmd for log_file option {REF}
##          : $script                => The script that is executed
##          : $date                  => The date
##          : $date_time_stamp       => The date and time
##          : $outdata_dir           => Outdata directory

    my ($arg_href) = @_;

    ## Default(s)
    my $outdata_dir;

    ## Flatten argument(s)
    my $active_parameter_href;
    my $cmd_input;
    my $script;
    my $date;
    my $date_time_stamp;

    my $tmpl = {
        active_parameter_href => {
            required    => 1,
            defined     => 1,
            default     => {},
            strict_type => 1,
            store       => \$active_parameter_href,
        },
        cmd_input => { strict_type => 1, store => \$cmd_input },
        script    => {
            required    => 1,
            defined     => 1,
            strict_type => 1,
            store       => \$script
        },
        date => {
            required    => 1,
            defined     => 1,
            strict_type => 1,
            store       => \$date
        },
        date_time_stamp => {
            required    => 1,
            defined     => 1,
            strict_type => 1,
            store       => \$date_time_stamp
        },
        outdata_dir => {
            default     => $arg_href->{active_parameter_href}{outdata_dir},
            strict_type => 1,
            store       => \$outdata_dir
        },
    };

    check( $tmpl, $arg_href, 1 ) or croak q{Could not parse arguments!};

    ## No input from cmd i.e. create default logging directory and set default
    if ( not defined $cmd_input ) {

        make_path( catfile( $outdata_dir, q{mip_log}, $date ) );

        ## Build log filename
        my $log_file = catfile( $outdata_dir, q{mip_log}, $date,
            $script . $UNDERSCORE . $date_time_stamp . $DOT . q{log} );

        ## Return default log file
        return $log_file;
    }

    ## Return cmd input log file
    return $cmd_input;
}

sub retrieve_log {

## Function  : Retrieves logger object and sets log level
## Returns   : $log
## Arguments : $log_name => Name of log
##           : $verbose  => Set log level to debug
##           : $quiet    => Set log level to warn
##           : $level    => Set log level

    my ($arg_href) = @_;

    ## Flatten argument(s)
    my $log_name;
    my $verbose;
    my $quiet;

    ## Default(s)
    my $level;

    my $tmpl = {
        log_name => {
            required    => 1,
            defined     => 1,
            strict_type => 1,
            store       => \$log_name,
        },
        verbose => {
            allow => [ undef, 0, 1 ],
            store => \$verbose,
        },
        quiet => {
            allow => [ undef, 0, 1 ],
            store => \$quiet,
        },
        level => {
            default => $INFO,
            allow   => [ $DEBUG, $INFO, $WARN, $ERROR, $WARN ],
            store   => \$level,
        },
    };

    check( $tmpl, $arg_href, 1 ) or croak q{Could not parse arguments!};

    ## Get logger
    my $log = get_logger($log_name);

    ## Set logger level
    if ($verbose) {
        $log->level($DEBUG);
    }
    elsif ($quiet) {
        $log->level($WARN);
    }
    else {
        $log->level($level);
    }
    return $log;
}

1;
