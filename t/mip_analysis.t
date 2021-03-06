#!/usr/bin/env perl

### Will test perl modules and some selected funtions as well as vcf keys both in header and body. Adjusts dynamically according to supplied config file.

use Modern::Perl qw{ 2014 };
use warnings qw{ FATAL utf8 };
use autodie qw{ open close :all };
use 5.018;
use utf8;
use open qw{ :encoding(UTF-8) :std };
use charnames qw{ :full :short };
use Carp;
use English qw{ -no_match_vars };

use Cwd qw{ abs_path };
use File::Basename qw{ dirname basename };
use File::Spec::Functions qw{ catdir catfile devnull };
use FindBin qw{ $Bin };
use Getopt::Long;
use Params::Check qw{ check allow last_error };
use Test::More;

## CPANM
use List::Util qw{ any };
use Readonly;

##MIPs lib/
use lib catdir( dirname($Bin), q{lib} );
use MIP::File::Format::Yaml qw{ load_yaml };
use MIP::Log::MIP_log4perl qw{ initiate_logger };
use MIP::Check::Modules qw{ check_perl_modules };
use MIP::Script::Utils qw{ help };

our $USAGE = build_usage( {} );

BEGIN {

    require MIP::Check::Modules;

    my @modules = (
        q{Modern::Perl},               # MIP
        q{autodie},                    # MIP
        q{IPC::System::Simple},        # MIP
        q{Path::Iterator::Rule},       # MIP
        q{YAML},                       # MIP
        q{MIP::File::Format::Yaml},    # MIP
        q{Log::Log4perl},              # MIP
        q{MIP::Log::MIP_log4perl},     # MIP
        q{List::Util},                 # MIP
        q{Readonly},                   # MIP
        q{Try::Tiny},                  # MIP
        q{Set::IntervalTree},          # MIP/vcfParser.pl
        q{Net::SSLeay},                # VEP
        q{LWP::Simple},                # VEP
        q{LWP::Protocol::https},       # VEP
        q{PerlIO::gzip},               # VEP
        q{IO::Uncompress::Gunzip},     # VEP
        q{HTML::Lint},                 # VEP
        q{Archive::Zip},               # VEP
        q{Archive::Extract},           # VEP
        q{DBI},                        # VEP
        q{JSON},                       # VEP
        q{DBD::mysql},                 # VEP
        q{CGI},                        # VEP
        q{Sereal::Encoder},            # VEP
        q{Sereal::Decoder},            # VEP
        q{Bio::Root::Version},         # VEP
        q{Module::Build},              # VEP
        q{File::Copy::Recursive},      # VEP
    );

    ## Evaluate that all modules required are installed
    check_perl_modules(
        {
            modules_ref  => \@modules,
            program_name => $PROGRAM_NAME,
        }
    );
}

## Constants
Readonly my $COMMA     => q{,};
Readonly my $NEWLINE   => qq{\n};
Readonly my $PIPE      => q{|};
Readonly my $SEMICOLON => q{;};
Readonly my $SPACE     => q{ };
Readonly my $TAB       => qq{\t};

my ( $infile, $config_file );
my ( %parameter, %active_parameter, %pedigree, %vcfparser_data, );

our $VERSION = '2.0.0';

if ( scalar @ARGV == 0 ) {

    say {*STDOUT} $USAGE;
    exit;
}

############
####MAIN####
############

$infile      = $ARGV[0];
$config_file = $ARGV[1];

###User Options
GetOptions(

    # Display help text
    q{h|help} => sub { say {*STDOUT} $USAGE; exit; },

    # Display version number
    q{v|version} => sub {
        say {*STDOUT} $NEWLINE . basename($PROGRAM_NAME) . $SPACE . $VERSION,
          $NEWLINE;
        exit;
    },
  )
  or help(
    {
        USAGE     => $USAGE,
        exit_code => 1,
    }
  );

if ( not defined $infile ) {

    say {*STDERR} q{Please supply an infile};
    exit 1;
}

if ( not defined $config_file ) {

    say {*STDERR} q{Please supply a config file};
    exit 1;
}

## Test perl modules and functions
test_modules();

## Loads a YAML file into an arbitrary hash and returns it.
%active_parameter = load_yaml( { yaml_file => $config_file, } );

if ( exists $active_parameter{pedigree_file} ) {

    ## Loads a YAML file into an arbitrary hash and returns it.
    %pedigree = load_yaml( { yaml_file => $active_parameter{pedigree_file}, } );

    ### Sample level info

  PEDIGREE_HREF:
    foreach my $pedigree_sample_href ( @{ $pedigree{samples} } ) {

        ## Sample_id
        my $sample_id = $pedigree_sample_href->{sample_id};

        ## Phenotype
        push
          @{ $parameter{dynamic_parameter}{ $pedigree_sample_href->{phenotype} }
          }, $sample_id;

        ## Sex
        push @{ $parameter{dynamic_parameter}{ $pedigree_sample_href->{sex} } },
          $sample_id;
    }
}

if ( $infile =~ /.selected.vcf/sxm ) {

    if ( exists $active_parameter{vcfparser_select_file}
        && $active_parameter{vcfparser_select_file} )
    {

        ## Reads a file containg features to be annotated using range queries
        read_range_file(
            {
                vcfparser_data_href => \%vcfparser_data,
                range_coulumns_ref  => \@{
                    $active_parameter{vcfparser_select_feature_annotation_columns}
                },
                infile_path =>
                  catfile( $active_parameter{vcfparser_select_file} ),
                range_file_key => q{select_file},
            }
        );
    }
}
else {
    # Range file

    if ( exists $active_parameter{vcfparser_range_feature_file}
        && $active_parameter{vcfparser_range_feature_file} )
    {

        ## Reads a file containg features to be annotated using range queries
        read_range_file(
            {
                vcfparser_data_href => \%vcfparser_data,
                range_coulumns_ref  => \@{
                    $active_parameter{vcfparser_range_feature_annotation_columns}
                },
                infile_path =>
                  catfile( $active_parameter{vcfparser_range_feature_file} ),
                range_file_key => q{range_file},
            }
        );
    }
}

## Reads infile in vcf format and parses annotations
read_infile_vcf(
    {
        parameter_href        => \%parameter,
        active_parameter_href => \%active_parameter,
        vcfparser_data_href   => \%vcfparser_data,
        infile_vcf            => $infile,
    }
);

# Reached the end safely
Test::More::done_testing();

######################
####SubRoutines#######
######################

sub build_usage {

##build_usage

##Function : Build the USAGE instructions
##Returns  : ""
##Arguments: $program_name
##         : $program_name => Name of the script

    my ($arg_href) = @_;

    ## Default(s)
    my $program_name;

    my $tmpl = {
        program_name => {
            default     => basename($PROGRAM_NAME),
            strict_type => 1,
            store       => \$program_name,
        },
    };

    check( $tmpl, $arg_href, 1 ) or croak q{Could not parse arguments!};

    return <<"END_USAGE";
 $program_name infile.vcf [VCF] config_file [YAML] [options]
    -h/--help Display this help message
    -v/--version Display version
END_USAGE
}

sub test_modules {

## test_modules

## Function : Test perl modules and functions
## Returns  :
## Arguments:
##         :

    say {*STDOUT} $NEWLINE . q{Testing perl modules and selected functions},
      $NEWLINE;

    # Find directory of script
    use FindBin qw{ $Bin };

    ok( defined $Bin, q{FindBin: Locate directory of script} );

    ## Strip the last part of directory
    use File::Basename qw{ dirname };

    ok( dirname($Bin),
        q{File::Basename qw{ dirname }: Strip the last part of directory} );

    use File::Spec::Functions qw{ catdir };

    ok( catdir( dirname($Bin), q{t} ),
        q{File::Spec::Functions qw{ catdir }: Concatenate directories} );

    use YAML;

    my $yaml_file =
      catdir( dirname($Bin), qw{ definitions define_parameters.yaml } );
    ok( -f $yaml_file, q{YAML: File=} . $yaml_file . q{in MIP directory} );

    ## Create an object
    my $yaml = YAML::LoadFile($yaml_file);

    ## Check that we got something
    ok( defined $yaml, q{YAML: Load File} );
    ok( Dump($yaml),   q{YAML: Dump file} );

    use Log::Log4perl;
    ## Creates log
    my $log_file = catdir( dirname($Bin), qw{ templates mip_config.yaml } );
    ok( -f $log_file,
        q{Log::Log4perl: File=} . $log_file . q{in MIP directory} );

    ## Creates log object
    my $log = initiate_logger(
        {
            categories_ref => [qw{ TRACE ScreenApp }],
            file_path      => $log_file,
            log_name       => q{Test},
        }
    );

    ok( $log->info(1),  q{Log::Log4perl: info} );
    ok( $log->warn(1),  q{Log::Log4perl: warn} );
    ok( $log->error(1), q{Log::Log4perl: error} );
    ok( $log->fatal(1), q{Log::Log4perl: fatal} );

    use Getopt::Long;
    push @ARGV, qw{ -verbose 2 };
    my $verbose = 1;
    ok(
        GetOptions( q{verbose:n} => \$verbose ),
        q{Getopt::Long: Get options call}
    );
    ok( $verbose == 2, q{Getopt::Long: Get options modified} );

    return;
}

sub read_infile_vcf {

## read_infile_vcf

## Function : Reads infile in vcf format and adds and parses annotations
## Returns  :
## Arguments: $parameter_href, $active_parameter_href, $vcfparser_data_href, $infile_vcf
##          : $parameter_href        => The parameter hash {REF}
##          : $active_parameter_href => The active parameters for this analysis hash {REF}
##          : $vcfparser_data_href   => The keys from vcfParser i.e. range file and select file
##          : $infile_vcf            => Infile

    my ($arg_href) = @_;

    ## Flatten argument(s)
    my $parameter_href;
    my $active_parameter_href;
    my $vcfparser_data_href;
    my $infile_vcf;

    my $tmpl = {
        parameter_href => {
            required    => 1,
            defined     => 1,
            default     => {},
            strict_type => 1,
            store       => \$parameter_href
        },
        active_parameter_href => {
            required    => 1,
            defined     => 1,
            default     => {},
            strict_type => 1,
            store       => \$active_parameter_href
        },
        vcfparser_data_href => {
            required    => 1,
            defined     => 1,
            default     => {},
            strict_type => 1,
            store       => \$vcfparser_data_href
        },
        infile_vcf => {
            required    => 1,
            defined     => 1,
            strict_type => 1,
            store       => \$infile_vcf
        },
    };

    check( $tmpl, $arg_href, 1 ) or croak q{Could not parse arguments!};

    ## Constants
    Readonly my $MAX_LINE_TO_READ => 100_00;

    ## Retrieve logger object now that log_file has been set
    my $log = Log::Log4perl->get_logger(q{Test});

    my $is_csq_found;
    my @vep_format_fields;
    my %vep_format_field;

    # Catch vcf header #CHROM line
    my @vcf_format_columns;
    my %meta_data;
    my %vcf_header;
    my %vcf_info_key;
    my %vcf_info_csq_key;

    $log->info( q{Testing vcf header in file: } . $infile_vcf, $NEWLINE x 2 );

    # Create anonymous filehandle
    my $FILEHANDLE = IO::Handle->new();

    ## Read file
    open $FILEHANDLE, q{<},
      $infile_vcf
      or $log->logdie( q{Cannot open} . $SPACE . $infile_vcf . q{:} . $OS_ERROR,
        $NEWLINE );
  LINE:
    while (<$FILEHANDLE>) {

        chomp;

        ## Quit reading
        last LINE if ( $INPUT_LINE_NUMBER > $MAX_LINE_TO_READ );

        # Avoid blank lines
        next LINE if (m/ ^\s+$ /sxm);

        # If meta data
        if (/ ^\#\#\S+= /sxm) {

            my $line = $_;
            parse_meta_data( \%meta_data, $line );

            if (/ INFO\=\<ID\=([^,]+) /sxm) {

                $vcf_header{INFO}{$1} = $1;
            }

            $is_csq_found = check_if_vep_csq_in_line(
                {
                    vep_format_field_href => \%vep_format_field,
                    header_line           => $line,
                }
            );

            if ($is_csq_found) {

                ok(
                    $active_parameter_href->{pvarianteffectpredictor},
                    q{VEP: CSQ in header and VEP should have been executed}
                );
            }
            next LINE;
        }
        if (/ ^\#CHROM /xsm) {

            # Split vcf format line
            @vcf_format_columns = split $TAB;

            ### Check Header now that we read all

            ## Test Vt
            _test_vt_in_vcf_header(
                {
                    vcf_header_href   => \%vcf_header,
                    vt_mode           => $active_parameter_href->{pvt},
                    vt_decompose_mode => $active_parameter_href->{vt_decompose},
                    vt_normalize_mode => $active_parameter_href->{vt_normalize},
                    vt_genmod_filter =>
                      $active_parameter_href->{vt_genmod_filter},
                    vt_genmod_filter_1000g =>
                      $active_parameter_href->{vt_genmod_filter_1000g},
                }
            );

            ## Test vcfparser
            _test_vcfparser_in_vcf_header(
                {
                    vcfparser_data_href => $vcfparser_data_href,
                    vcf_header_href     => \%vcf_header,
                    vcfparser_mode      => $active_parameter_href->{pvcfparser},
                }
            );

            ## Test snpeff
            _test_snpeff_in_vcf_header(
                {
                    snpsift_annotation_files_href =>
                      \%{ $active_parameter_href->{snpsift_annotation_files} },
                    snpsift_annotation_outinfo_key_href => \%{
                        $active_parameter_href->{snpsift_annotation_outinfo_key}
                    },
                    vcf_header_href => \%vcf_header,
                    snpsift_dbnsfp_annotations_ref =>
                      \@{ $active_parameter_href->{snpsift_dbnsfp_annotations}
                      },
                    snpeff_mode => $active_parameter_href->{psnpeff},
                }
            );

            ## Test Rankvariants
            _test_rankvariants_in_vcf_header(
                {
                    vcf_header_href => \%vcf_header,
                    sample_ids_ref =>
                      \@{ $active_parameter_href->{sample_ids} },
                    unaffected_samples_ref =>
                      \@{ $parameter_href->{dynamic_parameter}{unaffected} },
                    rankvariant_mode => $active_parameter_href->{prankvariant},
                    spidex_file      => $active_parameter_href->{spidex_file},
                    genmod_annotate_cadd_files_ref =>
                      \@{ $active_parameter_href->{genmod_annotate_cadd_files}
                      },
                }
            );

            next LINE;
        }

        ## VCF body lines
        my %vcf_record =
          parse_vcf_line( { vcf_format_columns_ref => \@vcf_format_columns, } );

        ## Count incedence of keys
        foreach my $info_key ( keys %{ $vcf_record{INFO_key_value} } ) {

            $vcf_info_key{$info_key}++;    #Increment
        }

        my %csq_transcript_effect = parse_vep_csq_info(
            {
                vcf_record_href       => \%vcf_record,
                vep_format_field_href => \%vep_format_field,
                vcf_info_csq_key_href => \%vcf_info_csq_key,
            }
        );

        ## Sum all CSQ vcf transcript effect keys
      TRANSCRIPT_ID:
        foreach my $transcript_id ( keys %csq_transcript_effect ) {

          CSQ_TRANSCRIPT_EFFECTS:
            while ( my ( $effect_key, $effect_value ) = each %vep_format_field )
            {

                if ( exists $csq_transcript_effect{$transcript_id}{$effect_key}
                    && $csq_transcript_effect{$transcript_id}{$effect_key} )
                {

                    $vcf_info_csq_key{$effect_key}++;    #Increment
                }
            }
        }
    }
    close $FILEHANDLE;

    ## Check keys found in INFO field
    $log->info(
        q{Testing vcf INFO fields and presence in header: } . $infile_vcf,
        $NEWLINE x 2 );

  INFO_KEY:
    foreach my $info_key ( keys %vcf_info_key ) {

        ok(
            exists $vcf_header{INFO}{$info_key},
            q{Found both header and line field key for: }
              . $info_key
              . q{ with key count: }
              . $vcf_info_key{$info_key}
        );
    }

  VEP_KEY:
    foreach my $vep_key ( keys %vep_format_field ) {

        my @todo_keys = qw{ PolyPhen APPRIS TSL Existing_variation
          LoF_flags MOTIF_NAME MOTIF_POS HIGH_INF_POS
          MOTIF_SCORE_CHANGE LoF_filter };

        if ( any { $_ eq $vep_key } @todo_keys ) {

            ## This will fail for Appris tcl etc which is only available in Grch38
          TODO: {
                local $TODO = q{Check VEP CSQ currently not produced};

                ok( $vcf_info_csq_key{$vep_key},
                    q{Found entry for CSQ field key for: } . $vep_key );
            }
        }
        else {

            ok( $vcf_info_csq_key{$vep_key},
                    q{Found entry for CSQ field key for: }
                  . $vep_key
                  . q{ with key count: }
                  . $vcf_info_csq_key{$vep_key} );
        }
    }
    return;
}

sub parse_vcf_line {

## parse_vcf_line

## Function : Add each element to a key in vcf_record hash
## Returns  :

## Arguments: $vcf_format_columns_ref
##          : $vcf_format_columns_ref => Array ref description {REF}

    my ($arg_href) = @_;

    ## Flatten argument(s)
    my $vcf_format_columns_ref;

    my $tmpl = {
        vcf_format_columns_ref => {
            required    => 1,
            defined     => 1,
            default     => [],
            strict_type => 1,
            store       => \$vcf_format_columns_ref
        },
    };

    check( $tmpl, $arg_href, 1 ) or croak q{Could not parse arguments!};

    ## VCF body lines
    my %vcf_record;

    # Loads vcf elements
    my @line_elements = split $TAB;

    ##Add line elements to vcf_record hash
  LINE:
    while ( my ( $element_index, $element ) = each @line_elements ) {

        ## Link vcf format headers to the line elements
        $vcf_record{ $vcf_format_columns_ref->[$element_index] } = $element;
    }

    # Split INFO field to key=value items
    my @info_elements = split $SEMICOLON, $vcf_record{INFO};

    ## Add INFO to vcf_record hash as separate key
  INFO:
    for my $element (@info_elements) {

        ## key index = 0 and value index = 1
        my @key_value_pairs = split /=/xsm, $element;

        $vcf_record{INFO_key_value}{ $key_value_pairs[0] } =
          $key_value_pairs[1];
    }
    return %vcf_record;
}

sub read_range_file {

## read_range_file

## Function : Reads a file containg features to be annotated using range queries e.g. EnsemblGeneID.
## Returns  : ""
## Arguments: $vcfparser_data_href, $range_coulumns_ref, $range_file_key, $infile_path
##          : $vcfparser_data_href            => Range file hash {REF}
##          : $range_coulumns_ref             => Range columns to include {REF}
##          : $range_file_key                 => Range file key used to seperate range file(s) i.e., select and range
##          : $infile_path                    => Infile path

    my ($arg_href) = @_;

    ## Flatten argument(s)
    my $vcfparser_data_href;
    my $range_coulumns_ref;
    my $range_file_key;
    my $infile_path;

    my $tmpl = {
        vcfparser_data_href => {
            required    => 1,
            defined     => 1,
            default     => {},
            strict_type => 1,
            store       => \$vcfparser_data_href
        },
        range_coulumns_ref => {
            required    => 1,
            defined     => 1,
            default     => [],
            strict_type => 1,
            store       => \$range_coulumns_ref
        },
        range_file_key => {
            required    => 1,
            defined     => 1,
            strict_type => 1,
            store       => \$range_file_key
        },
        infile_path => {
            required    => 1,
            defined     => 1,
            strict_type => 1,
            store       => \$infile_path
        },
    };

    check( $tmpl, $arg_href, 1 ) or croak q{Could not parse arguments!};

    ## Constants
    Readonly my $MAX_RANGE_COLUMNS => scalar @{$range_coulumns_ref} - 1;

    ## Retrieve logger object now that log_file has been set
    my $log = Log::Log4perl->get_logger(q{Test});

    ## Save headers from rangeFile
    my @headers;

    ## Create anonymous filehandle
    my $FILEHANDLE = IO::Handle->new();

    ## Read file
    open $FILEHANDLE, q{<},
      $infile_path
      or
      $log->logdie( q{Cannot open} . $SPACE . $infile_path . q{:} . $OS_ERROR,
        $NEWLINE );

  LINE:
    while (<$FILEHANDLE>) {

        chomp;

        next LINE if (m/ ^\s+$ /sxm);

        next LINE if (/^\#\#/sxm);

        if (/^\#/xsm) {

            @headers = split $TAB;

            for my $extract_columns_counter ( 0 .. $MAX_RANGE_COLUMNS ) {
                ## Defines what scalar to store

                my $header_key_ref =
                  \$headers[ $range_coulumns_ref->[$extract_columns_counter] ];

                ## Column position in supplied range input file
                $vcfparser_data_href->{ ${$header_key_ref} } =
                  $extract_columns_counter;
            }
            next LINE;
        }
    }
    close $FILEHANDLE;
    $log->info(
        q{Finished reading } . $range_file_key . q{ file: } . $infile_path,
        $NEWLINE );
    return;
}

sub parse_meta_data {

## parse_meta_data

## Function : Writes metadata to filehandle specified by order in meta_data_orders.
## Returns  :
## Arguments: $meta_data_href, $meta_data_string
##          : $meta_data_href   => Hash for meta_data {REF}
##          : $meta_data_string => The meta_data string from vcf header

    my ( $meta_data_href, $meta_data_string ) = @_;

    ## Catch fileformat as it has to be at the top of header
    if ( $meta_data_string =~ / ^\#\#fileformat /sxm ) {

        ## Save metadata string
        push
          @{ $meta_data_href->{fileformat}{fileformat} },
          $meta_data_string;
    }
    elsif ( $meta_data_string =~ / ^\#\#contig /sxm ) {
        ## Catch contigs to not sort them later

        ## Save metadata string
        push @{ $meta_data_href->{contig}{contig} }, $meta_data_string;
    }
    elsif ( $meta_data_string =~ / ^\#\#(\w+)=(\S+) /sxm ) {
        ## FILTER, FORMAT, INFO etc and more custom records

        ## Save metadata string
        push @{ $meta_data_href->{$1}{$2} }, $meta_data_string;
    }
    else {
        #All oddities

        ## Save metadata string
        push @{ $meta_data_href->{other}{other} }, $meta_data_string;
    }
    return;
}

sub check_if_vep_csq_in_line {

## check_if_vep_csq_in_line

## Function : Check if the header line contains VEPs CSQ field
## Returns  :

## Arguments: $vep_format_field_href, $header_line
##          : $vep_format_field_href  => Hash ref description {REF}
##          : $header_line     => Header line

    my ($arg_href) = @_;

    ## Flatten argument(s)
    my $vep_format_field_href;
    my $header_line;

    my $tmpl = {
        vep_format_field_href => {
            required    => 1,
            defined     => 1,
            default     => {},
            strict_type => 1,
            store       => \$vep_format_field_href
        },
        header_line => {
            required    => 1,
            defined     => 1,
            strict_type => 1,
            store       => \$header_line
        },
    };

    check( $tmpl, $arg_href, 1 ) or croak q{Could not parse arguments!};

    # Find VEP CSQ INFO field
    if ( $header_line =~ / INFO\=\<ID\=CSQ /sxm ) {

        # Locate Format within VEP INFO meta line
        if (/ Format:\s(\S+)"\> /sxm) {

            my $vep_format_string = $1;
            my @vep_format_fields = split $PIPE, $vep_format_string;

            while ( my ( $field_index, $field ) = each @vep_format_fields ) {

                # Save the order of VEP features key => index
                $vep_format_field_href->{$field} = $field_index;
            }
        }
        ## Found CSQ line
        return 1;
    }
    return;

}

sub _test_vt_in_vcf_header {

## _test_vt_in_vcf_header

## Function : Test if vt info keys are present in vcf header
## Returns  :

## Arguments: $vcf_header_href, $vt_mode, $vt_decompose_mode, $vt_normalize_mode, $vt_genmod_filter, $vt_genmod_filter_1000g
##          : $vcf_header_href        => Vcf header info
##          : $vt_mode                => Vt has been used or not
##          : $vt_decompose_mode      => Vt decompose has been used or not
##          : $vt_normalize_mode      => Vt normalize has been used or not
##          : $vt_genmod_filter       => Vt genmod filter has been used or not
##          : $vt_genmod_filter_1000g => Vt genmod filter 100G has been used or not

    my ($arg_href) = @_;

    ## Flatten argument(s)
    my $vcf_header_href;
    my $vt_mode;
    my $vt_decompose_mode;
    my $vt_normalize_mode;
    my $vt_genmod_filter;
    my $vt_genmod_filter_1000g;

    my $tmpl = {
        vcf_header_href => {
            required    => 1,
            defined     => 1,
            default     => {},
            strict_type => 1,
            store       => \$vcf_header_href,
        },
        vt_mode => {
            required    => 1,
            defined     => 1,
            allow       => qr/ ^\d+$ /sxm,
            strict_type => 1,
            store       => \$vt_mode,
        },
        vt_decompose_mode => {
            required    => 1,
            defined     => 1,
            allow       => qr/ ^\d+$ /sxm,
            strict_type => 1,
            store       => \$vt_decompose_mode,
        },
        vt_normalize_mode => {
            required    => 1,
            defined     => 1,
            allow       => qr/ ^\d+$ /sxm,
            strict_type => 1,
            store       => \$vt_normalize_mode,
        },
        vt_genmod_filter => {
            required    => 1,
            defined     => 1,
            allow       => qr/ ^\d+$ /sxm,
            strict_type => 1,
            store       => \$vt_genmod_filter,
        },
        vt_genmod_filter_1000g => {
            strict_type => 1,
            store       => \$vt_genmod_filter_1000g,
        },
    };

    check( $tmpl, $arg_href, 1 ) or croak q{Could not parse arguments!};

    ## VT has been used
    if ( $vt_mode > 0 ) {

        if ( $vt_decompose_mode > 0 ) {

            ok( exists $vcf_header_href->{INFO}{OLD_MULTIALLELIC},
                q{VTDecompose key: OLD_MULTIALLELIC} );
        }
        if ( $vt_normalize_mode > 0 ) {

            ok( exists $vcf_header_href->{INFO}{OLD_VARIANT},
                q{VTNormalize key: OLD_VARIANT} );
        }
        if ( $vt_genmod_filter > 0 ) {

            if ($vt_genmod_filter_1000g) {

                ok( defined $vcf_header_href->{INFO}{q{1000GAF}},
                    q{Genmod filter: 1000GAF key} );
            }
        }
    }
    return;
}

sub _test_vcfparser_in_vcf_header {

## _test_vcfparser_in_vcf_header

## Function :Test if vcfparser info keys are present in vcf header
## Returns  :

## Arguments: $vcfparser_data_href, $vcf_header_href, $vcfparser_mode
##          : $vcfparser_data_href => Vcfparser keys hash {REF}
##          : $vcf_header_href     => Vcf header info {REF}
##          : $vcfparser_mode      => Vcfparser_Mode description

    my ($arg_href) = @_;

    ## Flatten argument(s)
    my $vcfparser_data_href;
    my $vcf_header_href;
    my $vcfparser_mode;

    my $tmpl = {
        vcfparser_data_href => {
            required    => 1,
            defined     => 1,
            default     => {},
            strict_type => 1,
            store       => \$vcfparser_data_href,
        },
        vcf_header_href => {
            required    => 1,
            defined     => 1,
            default     => {},
            strict_type => 1,
            store       => \$vcf_header_href,
        },
        vcfparser_mode => {
            required    => 1,
            defined     => 1,
            allow       => qr/ ^\d+$ /sxm,
            strict_type => 1,
            store       => \$vcfparser_mode,
        },
    };

    check( $tmpl, $arg_href, 1 ) or croak q{Could not parse arguments!};

    if ( $vcfparser_mode > 0 ) {

      VCFPARSER_KEY:
        for my $vcfparser_key ( keys %{$vcfparser_data_href} ) {

            ok( defined $vcf_header_href->{INFO}{$vcfparser_key},
                q{Vcfparser key: } . $vcfparser_key );
        }

        ## Keys from vcfparser.pl that are dynamically created from parsing the data
        my @vcfparser_dynamic_keys = qw{ most_severe_consequence };

      DYNAMIC_KEY:
        foreach my $dynamic_key (@vcfparser_dynamic_keys) {

            ok(
                defined $vcf_header_href->{INFO}{$dynamic_key},
                q{Vcfparser dynamic keys: } . $dynamic_key
            );
        }
    }
    return;
}

sub _test_snpeff_in_vcf_header {

## _test_snpeff_in_vcf_header

## Function : Test if snpeff info keys are present in vcf header
## Returns  :

## Arguments: $snpsift_annotation_files_href, $snpsift_annotation_outinfo_key_href, $vcf_header_href, $snpsift_dbnsfp_annotations_ref, $snpeff_mode
##          : $snpsift_annotation_files_href       => Snp sift annotation files {REF}
##          : $snpsift_annotation_outinfo_key_href => Snp sift annotation keys {REF}
##          : $vcf_header_href                     => Vcf header info {REF}
##          : $snpsift_dbnsfp_annotations_ref      => SnpSift dbnsfp annotations {REF}
##          : $snpeff_mode                         => Snpeff_Mode description

    my ($arg_href) = @_;

    ## Flatten argument(s)
    my $snpsift_annotation_files_href;
    my $snpsift_annotation_outinfo_key_href;
    my $vcf_header_href;
    my $snpsift_dbnsfp_annotations_ref;

    ## Default(s)
    my $snpeff_mode;

    my $tmpl = {
        snpsift_annotation_files_href => {
            required    => 1,
            defined     => 1,
            default     => {},
            strict_type => 1,
            store       => \$snpsift_annotation_files_href,
        },
        snpsift_annotation_outinfo_key_href => {
            required    => 1,
            defined     => 1,
            default     => {},
            strict_type => 1,
            store       => \$snpsift_annotation_outinfo_key_href,
        },
        vcf_header_href => {
            required    => 1,
            defined     => 1,
            default     => {},
            strict_type => 1,
            store       => \$vcf_header_href,
        },
        snpsift_dbnsfp_annotations_ref => {
            required    => 1,
            defined     => 1,
            default     => [],
            strict_type => 1,
            store       => \$snpsift_dbnsfp_annotations_ref
        },
        snpeff_mode => {
            required    => 1,
            defined     => 1,
            allow       => qr/ ^\d+$ /sxm,
            strict_type => 1,
            store       => \$snpeff_mode
        },
    };

    check( $tmpl, $arg_href, 1 ) or croak q{Could not parse arguments!};

    ## Snpeff
    if ( $snpeff_mode > 0 ) {

        my @reformated_keys;

      ANNOTATION_FILE:
        for my $annotation_file ( keys %{$snpsift_annotation_files_href} ) {

            ## Alias
            my $annotation_file_info_key_string =
              $snpsift_annotation_files_href->{$annotation_file};
            if (
                exists $snpsift_annotation_outinfo_key_href->{$annotation_file}
              )
            {

                ## Alias
                my $annotation_outinfo_key_string =
                  $snpsift_annotation_outinfo_key_href->{$annotation_file};

                @reformated_keys = split $COMMA, $annotation_outinfo_key_string;

                my @original_vcf_keys = split $COMMA,
                  $annotation_file_info_key_string;

                ## Modify list elements in place to produce -names flag from SnpEff
              ELEMENT:
                foreach my $elements (@reformated_keys) {

                    $elements .= shift @original_vcf_keys;
                }
            }
            else {

                @reformated_keys = split $COMMA,
                  $annotation_file_info_key_string;
            }
          SNPSIFT_KEY:
            foreach my $snpsift_key (@reformated_keys) {

                ok(
                    defined $vcf_header_href->{INFO}{$snpsift_key},
                    q{Snpsift annotation key: } . $snpsift_key
                );
            }
        }
      DBNSFP_KEY:
        for my $dbnsfp_key ( @{$snpsift_dbnsfp_annotations_ref} ) {

            ## Special case due to the fact that snpEff v4.2 transforms + to _ for some reason
            $dbnsfp_key =~ s/[+]/_/gsxm;
            $dbnsfp_key = q{dbNSFP_} . $dbnsfp_key;
            ok(
                defined $vcf_header_href->{INFO}{$dbnsfp_key},
                q{Snpsift dbNSFP_key: } . $dbnsfp_key
            );
        }
    }
    return;
}

sub _test_rankvariants_in_vcf_header {

## _test_rankvariants_in_vcf_header

## Function : Test if rankvariants info keys are present in vcf header
## Returns  :

## Arguments: $vcf_header_href, $sample_ids_ref, $unaffected_samples_ref, $genmod_annotate_cadd_files_ref, $rankvariant_mode, $spidex_file
##          : $vcf_header_href                => Vcf header info {REF}
##          : $sample_ids_ref                 => Array ref description {REF}
##          : $unaffected_samples_ref         => Number of unaffected individuals in analysis
##          : $genmod_annotate_cadd_files_ref => Cadd files annotate via genmod
##          : $rankvariant_mode               => Rankvariant_Mode description
##          : $spidex_file                    => Spidex file

    my ($arg_href) = @_;

    ## Flatten argument(s)
    my $vcf_header_href;
    my $sample_ids_ref;
    my $unaffected_samples_ref;
    my $genmod_annotate_cadd_files_ref;
    my $rankvariant_mode;
    my $spidex_file;

    my $tmpl = {
        vcf_header_href => {
            required    => 1,
            defined     => 1,
            default     => {},
            strict_type => 1,
            store       => \$vcf_header_href
        },
        sample_ids_ref => {
            required    => 1,
            defined     => 1,
            default     => [],
            strict_type => 1,
            store       => \$sample_ids_ref
        },
        unaffected_samples_ref => {
            required    => 1,
            defined     => 1,
            default     => [],
            strict_type => 1,
            store       => \$unaffected_samples_ref,
        },
        genmod_annotate_cadd_files_ref => {
            default     => [],
            strict_type => 1,
            store       => \$genmod_annotate_cadd_files_ref,
        },
        rankvariant_mode => {
            required    => 1,
            defined     => 1,
            allow       => qr/ ^\d+$ /sxm,
            strict_type => 1,
            store       => \$rankvariant_mode,
        },
        spidex_file => {
            strict_type => 1,
            store       => \$spidex_file,
        },
    };

    check( $tmpl, $arg_href, 1 ) or croak q{Could not parse arguments!};

    if ( $rankvariant_mode > 0 ) {

        ## Keys from genmod
        my @genmod_keys;

        ## Only unaffected - do nothing
        if (   @{$unaffected_samples_ref}
            && @{$unaffected_samples_ref} eq @{$sample_ids_ref} )
        {
        }
        else {

            @genmod_keys = qw{ Compounds RankScore ModelScore
              GeneticModels };
        }

      GENMOD_KEY:
        foreach my $genmod_key (@genmod_keys) {

            ok( defined $vcf_header_href->{INFO}{$genmod_key},
                q{Genmod: } . $genmod_key );
        }

        ## Spidex key from genmodAnnotate
        if ($spidex_file) {

            ok( defined $vcf_header_href->{INFO}{SPIDEX},
                q{Genmod annotate: SPIDEX key} );
        }
        ## CADD key from genmodAnnotate
        if ( @{$genmod_annotate_cadd_files_ref} ) {

            ok( defined $vcf_header_href->{INFO}{CADD},
                q{Genmod annotate: CADD key} );
        }
    }
    return;
}

sub parse_vep_csq_info {

## parse_vep_csq_info

## Function : Parse the VEP CSQ field
## Returns  :

## Arguments: $vcf_record_href, $vep_format_field_href, $vcf_info_csq_key_href
##          : $vcf_record_href             => Hash ref description {REF}
##          : $vep_format_field_href       => VEP format field column {REF}
##          : $vcf_info_csq_key_href       => Vcf info csq key hash {REF}

    my ($arg_href) = @_;

    ## Flatten argument(s)
    my $vcf_record_href;
    my $vep_format_field_href;
    my $vcf_info_csq_key_href;

    my $tmpl = {
        vcf_record_href => {
            required    => 1,
            defined     => 1,
            default     => {},
            strict_type => 1,
            store       => \$vcf_record_href,
        },
        vep_format_field_href => {
            required    => 1,
            defined     => 1,
            default     => {},
            strict_type => 1,
            store       => \$vep_format_field_href,
        },
        vcf_info_csq_key_href => {
            required    => 1,
            defined     => 1,
            default     => {},
            strict_type => 1,
            store       => \$vcf_info_csq_key_href,
        },
    };

    check( $tmpl, $arg_href, 1 ) or croak q{Could not parse arguments!};

    if ( exists $vcf_record_href->{INFO_key_value}{CSQ} ) {

        my %csq_transcript_effect;

        ## VEP map
        my %vep_format_field_index = reverse %{$vep_format_field_href};

        ## Split into transcripts
        my @transcripts = split $COMMA, $vcf_record_href->{INFO_key_value}{CSQ};

      CSQ_TRANSCRIPT:
        while ( my ( $transcript_index, $transcript ) = each @transcripts ) {

            my @transcript_effects = split $PIPE, $transcript;

          TRANSCRIP_EFFECT:
            while ( my ( $effect_index, $effect ) = each @transcript_effects ) {

                if ( exists $vep_format_field_index{$effect_index} ) {

                    ## Alias
                    my $vep_format_key_ref =
                      \$vep_format_field_index{$effect_index};
                    $csq_transcript_effect{$transcript_index}
                      { ${$vep_format_key_ref} } = $effect;
                }
            }
        }
        return %csq_transcript_effect;
    }
}
