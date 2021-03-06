package MIP::Recipes::Analysis::Cnvnator;

use Carp;
use charnames qw{ :full :short };
use English qw{ -no_match_vars };
use File::Spec::Functions qw{ catdir catfile };
use open qw{ :encoding(UTF-8) :std };
use Params::Check qw{ check allow last_error };
use strict;
use utf8;
use warnings;
use warnings qw{ FATAL utf8 };

## CPANM
use autodie qw{ :all };
use Readonly;

BEGIN {

    require Exporter;
    use base qw{ Exporter };

    # Set the version for version checking
    our $VERSION = 1.02;

    # Functions and variables which can be optionally exported
    our @EXPORT_OK = qw{ analysis_cnvnator };

}

## Constants
Readonly my $AMPERSAND  => q{&};
Readonly my $ASTERISK   => q{*};
Readonly my $DOT        => q{.};
Readonly my $EMPTY_STR  => q{};
Readonly my $NEWLINE    => qq{\n};
Readonly my $SEMICOLON  => q{;};
Readonly my $SPACE      => q{ };
Readonly my $UNDERSCORE => q{_};

sub analysis_cnvnator {

## Function : Call structural variants using cnvnator
## Returns  :
##          : $active_parameter_href   => Active parameters for this analysis hash {REF}
##          : $family_id               => Family id
##          : $file_info_href          => The file_info hash {REF}
##          : $infile_lane_prefix_href => Infile(s) without the ".ending" {REF}
##          : $insample_directory      => In sample directory
##          : $job_id_href             => Job id hash {REF}
##          : $outaligner_dir          => Outaligner_dir used in the analysis
##          : $outsample_directory     => Out sample directory
##          : $parameter_href          => Parameter hash {REF}
##          : $program_name            => Program name
##          : $reference_dir           => MIP reference directory
##          : $sample_info_href        => Info on samples and family hash {REF}
##          : $sample_id               => Sample id
##          : $temp_directory          => Temporary directory
##          : $xargs_file_counter      => The xargs file counter

    my ($arg_href) = @_;

    ## Default(s)
    my $family_id;
    my $outaligner_dir;
    my $reference_dir;
    my $temp_directory;
    my $xargs_file_counter;

    ## Flatten argument(s)
    my $active_parameter_href;
    my $FILEHANDLE;
    my $file_info_href;
    my $infile_lane_prefix_href;
    my $insample_directory;
    my $job_id_href;
    my $outsample_directory;
    my $parameter_href;
    my $program_name;
    my $sample_id;
    my $sample_info_href;

    my $tmpl = {
        active_parameter_href => {
            required    => 1,
            defined     => 1,
            default     => {},
            strict_type => 1,
            store       => \$active_parameter_href,
        },
        family_id => {
            default     => $arg_href->{active_parameter_href}{family_id},
            strict_type => 1,
            store       => \$family_id,
        },
        file_info_href => {
            required    => 1,
            defined     => 1,
            default     => {},
            strict_type => 1,
            store       => \$file_info_href,
        },
        infile_lane_prefix_href => {
            required    => 1,
            defined     => 1,
            default     => {},
            strict_type => 1,
            store       => \$infile_lane_prefix_href,
        },
        insample_directory => {
            required    => 1,
            defined     => 1,
            strict_type => 1,
            store       => \$insample_directory,
        },
        job_id_href => {
            required    => 1,
            defined     => 1,
            default     => {},
            strict_type => 1,
            store       => \$job_id_href,
        },
        outaligner_dir => {
            default     => $arg_href->{active_parameter_href}{outaligner_dir},
            strict_type => 1,
            store       => \$outaligner_dir,
        },
        outsample_directory => {
            required    => 1,
            defined     => 1,
            strict_type => 1,
            store       => \$outsample_directory,
        },
        parameter_href => {
            required    => 1,
            defined     => 1,
            default     => {},
            strict_type => 1,
            store       => \$parameter_href,
        },
        program_name => {
            required    => 1,
            defined     => 1,
            strict_type => 1,
            store       => \$program_name,
        },
        reference_dir => {
            default     => $arg_href->{active_parameter_href}{reference_dir},
            strict_type => 1,
            store       => \$reference_dir,
        },
        sample_id => {
            required    => 1,
            defined     => 1,
            default     => 1,
            strict_type => 1,
            store       => \$sample_id,
        },
        sample_info_href => {
            required    => 1,
            defined     => 1,
            default     => {},
            strict_type => 1,
            store       => \$sample_info_href,
        },
        temp_directory => {
            default     => $arg_href->{active_parameter_href}{temp_directory},
            strict_type => 1,
            store       => \$temp_directory,
        },
        xargs_file_counter => {
            default     => 0,
            allow       => qr/ ^\d+$ /sxm,
            strict_type => 1,
            store       => \$xargs_file_counter,
        },
    };

    check( $tmpl, $arg_href, 1 ) or croak q{Could not parse arguments!};

    use MIP::Get::File qw{ get_file_suffix };
    use MIP::IO::Files qw{ migrate_file xargs_migrate_contig_files};
    use MIP::Language::Java qw{ java_core };
    use MIP::Processmanagement::Slurm_processes
      qw{ slurm_submit_job_sample_id_dependency_add_to_sample };
    use MIP::Program::Alignment::Samtools
      qw{ samtools_create_chromosome_files };
    use MIP::Program::Variantcalling::Bcftools qw{ bcftools_annotate };
    use MIP::Program::Variantcalling::Cnvnator
      qw{ cnvnator_read_extraction cnvnator_histogram cnvnator_statistics cnvnator_partition cnvnator_calling cnvnator_convert_to_vcf };
    use MIP::Program::Variantcalling::Gatk qw{ gatk_catvariants };
    use MIP::QC::Record qw{ add_program_outfile_to_sample_info };
    use MIP::Recipes::Analysis::Xargs qw{ xargs_command };
    use MIP::Script::Setup_script qw{ setup_script };
    use MIP::Set::File qw{ set_file_suffix };

    ## Retrieve logger object
    my $log = Log::Log4perl->get_logger(q{MIP});

    ## Set MIP program name
    my $mip_program_name = q{p} . $program_name;
    my $mip_program_mode = $active_parameter_href->{$mip_program_name};

    ## Alias
    my $job_id_chain = $parameter_href->{$mip_program_name}{chain};
    my $core_number =
      $active_parameter_href->{module_core_number}{$mip_program_name};
    my $program_outdirectory_name =
      $parameter_href->{$mip_program_name}{outdir_name};
    my $xargs_file_path_prefix;
    my $time = $active_parameter_href->{module_time}{$mip_program_name};
    my $phenotype_info =
      $sample_info_href->{sample}{$sample_id}{phenotype};
    my $human_genome_reference_ref =
      $arg_href->{active_parameter_href}{human_genome_reference};

    ## Filehandles
    # Create anonymous filehandle
    $FILEHANDLE = IO::Handle->new();

    # Create a second anonymous filehandle
    my $XARGSFILEHANDLE = IO::Handle->new();

    ## Creates program directories (info & programData & programScript), program script filenames and writes sbatch header
    my ( $file_path, $program_info_path ) = setup_script(
        {
            active_parameter_href => $active_parameter_href,
            job_id_href           => $job_id_href,
            FILEHANDLE            => $FILEHANDLE,
            directory_id          => $sample_id,
            program_name          => $program_name,
            program_directory =>
              catfile( $outaligner_dir, $program_outdirectory_name ),
            core_number    => $core_number,
            process_time   => $time,
            temp_directory => $temp_directory
        }
    );

    #Used downstream
    $parameter_href->{$mip_program_name}{$sample_id}{indirectory} =
      $outsample_directory;

    ## Files
    my $infile = $file_info_href->{$sample_id}{merged_infile};
    my $infile_tag =
      $file_info_href->{$sample_id}{pgatk_baserecalibration}{file_tag};
    my $outfile_tag =
      $file_info_href->{$sample_id}{$mip_program_name}{file_tag};
    my $infile_prefix  = $infile . $infile_tag;
    my $outfile_prefix = $infile . $outfile_tag;

    ## Paths
    my $file_path_prefix    = catfile( $temp_directory, $infile_prefix );
    my $outfile_path_prefix = catfile( $temp_directory, $outfile_prefix );

    ### Assign suffix
    my $infile_suffix = get_file_suffix(
        {
            parameter_href => $parameter_href,
            suffix_key     => q{alignment_file_suffix},
            jobid_chain    => $parameter_href->{pgatk_baserecalibration}{chain},
        }
    );

    ## Set file suffix for next module within jobid chain
    my $outfile_suffix = set_file_suffix(
        {
            parameter_href => $parameter_href,
            suffix_key     => q{variant_file_suffix},
            job_id_chain   => $job_id_chain,
            file_suffix => $parameter_href->{$mip_program_name}{outfile_suffix},
        }
    );

    ##Special fix to accomodate outdated versions of .so libraries required by root
    if ( exists $active_parameter_href->{cnv_root_ld_lib} ) {

        say {$FILEHANDLE} q{LD_LIBRARY_PATH=}
          . $active_parameter_href->{cnv_root_ld_lib}
          . q{/:$LD_LIBRARY_PATH};
        say {$FILEHANDLE} q{export LD_LIBRARY_PATH}, $NEWLINE;
    }

    ## Add contigs to vcfheader
    _add_contigs_to_vcfheader(
        {
            human_genome_reference => $human_genome_reference_ref,
            temp_directory         => $temp_directory,
            FILEHANDLE             => $FILEHANDLE,
        }
    );

    ## Call to Samtools to create chromosome sequence files (.fa) used by Cnvnator
    say {$FILEHANDLE} q{## Create by cnvnator required 'chr.fa' files};
    samtools_create_chromosome_files(
        {
            regions_ref        => $file_info_href->{contigs},
            infile_path        => $human_genome_reference_ref,
            temp_directory     => $temp_directory,
            suffix             => $DOT . q{fa},
            max_process_number => $core_number,
            FILEHANDLE         => $FILEHANDLE,
        }
    );

    say {$FILEHANDLE} q{wait}, $NEWLINE;

    ## Copy file(s) to temporary directory
    say {$FILEHANDLE} q{## Copy file(s) to temporary directory};
    ($xargs_file_counter) = xargs_migrate_contig_files(
        {
            FILEHANDLE         => $FILEHANDLE,
            XARGSFILEHANDLE    => $XARGSFILEHANDLE,
            contigs_ref        => \@{ $file_info_href->{contigs_size_ordered} },
            file_path          => $file_path,
            program_info_path  => $program_info_path,
            core_number        => $core_number,
            xargs_file_counter => $xargs_file_counter,
            infile             => $infile_prefix,
            indirectory        => $insample_directory,
            file_ending        => substr( $infile_suffix, 0, 2 ) . $ASTERISK,
            temp_directory     => $temp_directory,
        }
    );

    ## cnvnator
    say {$FILEHANDLE} q{## cnvnator};

    ## Create file commands for xargs
    ( $xargs_file_counter, $xargs_file_path_prefix ) = xargs_command(
        {
            FILEHANDLE         => $FILEHANDLE,
            XARGSFILEHANDLE    => $XARGSFILEHANDLE,
            file_path          => $file_path,
            program_info_path  => $program_info_path,
            core_number        => $core_number,
            xargs_file_counter => $xargs_file_counter,
        }
    );

  CONTIG:
    foreach my $contig ( @{ $file_info_href->{contigs_size_ordered} } ) {

        my $stderrfile_path_prefix = $xargs_file_path_prefix . $DOT . $contig;

        ## Assemble parameter
        # Output ROOT file
        my $root_file =
          $file_path_prefix . $UNDERSCORE . $contig . $DOT . q{root};

        cnvnator_read_extraction(
            {
                infile_paths_ref => [
                    $file_path_prefix . $UNDERSCORE . $contig . $infile_suffix
                ],
                outfile_path    => $root_file,
                regions_ref     => [$contig],
                unique          => 1,
                stdoutfile_path => $xargs_file_path_prefix
                  . $DOT
                  . $contig
                  . $DOT
                  . q{stdout.txt},
                stderrfile_path => $stderrfile_path_prefix
                  . $DOT
                  . q{stderr.txt},
                FILEHANDLE => $XARGSFILEHANDLE,
            }
        );
        print {$XARGSFILEHANDLE} $SEMICOLON . $SPACE;

        cnvnator_histogram(
            {
                infile_path  => $root_file,
                regions_ref  => [$contig],
                cnv_bin_size => $active_parameter_href->{cnv_bin_size},
                referencedirectory_path => $temp_directory,
                FILEHANDLE              => $XARGSFILEHANDLE,
                stdoutfile_path         => $stderrfile_path_prefix
                  . $UNDERSCORE
                  . q{histogram.stdout.txt},
                stderrfile_path => $xargs_file_path_prefix
                  . $DOT
                  . $contig
                  . $UNDERSCORE
                  . q{histogram.stderr.txt},
            }
        );
        print {$XARGSFILEHANDLE} $SEMICOLON . $SPACE;

        cnvnator_statistics(
            {
                infile_path     => $root_file,
                regions_ref     => [$contig],
                cnv_bin_size    => $active_parameter_href->{cnv_bin_size},
                FILEHANDLE      => $XARGSFILEHANDLE,
                stdoutfile_path => $xargs_file_path_prefix
                  . $DOT
                  . $contig
                  . $UNDERSCORE
                  . q{statistics.stdout.txt},
                stderrfile_path => $xargs_file_path_prefix
                  . $DOT
                  . $contig
                  . $UNDERSCORE
                  . q{statistics.stderr.txt},
            }
        );
        print {$XARGSFILEHANDLE} $SEMICOLON . $SPACE;

        cnvnator_partition(
            {
                infile_path     => $root_file,
                regions_ref     => [$contig],
                cnv_bin_size    => $active_parameter_href->{cnv_bin_size},
                FILEHANDLE      => $XARGSFILEHANDLE,
                stdoutfile_path => $xargs_file_path_prefix
                  . $DOT
                  . $contig
                  . $UNDERSCORE
                  . q{partition.stdout.txt},
                stderrfile_path => $xargs_file_path_prefix
                  . $DOT
                  . $contig
                  . $UNDERSCORE
                  . q{partition.stderr.txt},
            }
        );
        print {$XARGSFILEHANDLE} $SEMICOLON . $SPACE;

        cnvnator_calling(
            {
                infile_path     => $root_file,
                stdoutfile_path => $outfile_path_prefix
                  . $UNDERSCORE
                  . $contig
                  . $DOT
                  . q{cnvnator},
                regions_ref     => [$contig],
                cnv_bin_size    => $active_parameter_href->{cnv_bin_size},
                FILEHANDLE      => $XARGSFILEHANDLE,
                stderrfile_path => $xargs_file_path_prefix
                  . $DOT
                  . $contig
                  . $UNDERSCORE
                  . q{calling.stderr.txt},
            }
        );
        print {$XARGSFILEHANDLE} $SEMICOLON . $SPACE;

        cnvnator_convert_to_vcf(
            {
                infile_path => $outfile_path_prefix
                  . $UNDERSCORE
                  . $contig
                  . $DOT
                  . q{cnvnator},
                stdoutfile_path => $outfile_path_prefix
                  . $UNDERSCORE
                  . $contig
                  . $outfile_suffix,
                stderrfile_path => $xargs_file_path_prefix
                  . $DOT
                  . $contig
                  . $UNDERSCORE
                  . q{convert_to_vcf.stderr.txt},
                referencedirectory_path => $temp_directory,
                FILEHANDLE              => $XARGSFILEHANDLE,
            }
        );
        print {$XARGSFILEHANDLE} $NEWLINE;
    }

    ## Write sbatch code to supplied filehandle to concatenate variants in vcf format. Each array element is combined with the infile prefix and postfix.
    $infile_prefix = $outfile_path_prefix . $UNDERSCORE;
    my $infile_postfix = $outfile_suffix;
    my $outfile =
      $outfile_path_prefix . $UNDERSCORE . q{concat} . $outfile_suffix;
    my $elements_ref = \@{ $file_info_href->{contigs} };

    if ( not defined $infile_postfix ) {

        #No postfix
        $infile_postfix = $EMPTY_STR;
    }

    if ( not defined $outfile ) {

        $outfile = $infile_prefix . $outfile_suffix;
    }

    say {$FILEHANDLE} q{## GATK CatVariants};

    ## Assemble infile paths
    my @infile_paths =
      map { $infile_prefix . $_ . $infile_postfix } @{$elements_ref};

    my $gatk_path =
        catfile( $active_parameter_href->{gatk_path}, q{GenomeAnalysisTK.jar} )
      . $SPACE
      . q{org.broadinstitute.gatk.tools.CatVariants};

    gatk_catvariants(
        {
            memory_allocation => q{Xmx4g},
            java_use_large_pages =>
              $active_parameter_href->{java_use_large_pages},
            temp_directory     => $active_parameter_href->{temp_directory},
            gatk_path          => $gatk_path,
            infile_paths_ref   => \@infile_paths,
            outfile_path       => $outfile,
            referencefile_path => $human_genome_reference_ref,
            logging_level      => $active_parameter_href->{gatk_logging_level},
            FILEHANDLE         => $FILEHANDLE,
        }
    );
    say {$FILEHANDLE} $NEWLINE;

    ## Fix GT FORMAT in header and Sample_id and GT and Genotype call
    _fix_gt_format_in_header(
        {
            sample_id           => $sample_id,
            outfile_path_prefix => $outfile_path_prefix,
            outfile_suffix      => $outfile_suffix,
            FILEHANDLE          => $FILEHANDLE,

        }
    );

    ## Add contigs to header
    bcftools_annotate(
        {
            infile_path => $outfile_path_prefix
              . $UNDERSCORE
              . q{concat_fix}
              . $outfile_suffix,
            outfile_path    => $outfile_path_prefix . $outfile_suffix,
            output_type     => q{v},
            headerfile_path => catfile( $temp_directory, q{contig_header.txt} ),
            FILEHANDLE      => $FILEHANDLE,
        }
    );
    say {$FILEHANDLE} $NEWLINE;

    ## Copies file from temporary directory.
    say {$FILEHANDLE} q{## Copy file from temporary directory};
    migrate_file(
        {
            infile_path  => $outfile_path_prefix . $outfile_suffix . $ASTERISK,
            outfile_path => $outsample_directory,
            FILEHANDLE   => $FILEHANDLE,
        }
    );
    say {$FILEHANDLE} q{wait}, $NEWLINE;

    close $FILEHANDLE;

    if ( $mip_program_mode == 1 ) {

        add_program_outfile_to_sample_info(
            {
                sample_info_href => $sample_info_href,
                program_name     => q{cnvnator},
                path             => catfile(
                    $outsample_directory, $outfile_prefix . $outfile_suffix
                ),
            }
        );

        slurm_submit_job_sample_id_dependency_add_to_sample(
            {
                job_id_href             => $job_id_href,
                infile_lane_prefix_href => $infile_lane_prefix_href,
                family_id               => $family_id,
                sample_id               => $sample_id,
                path                    => $job_id_chain,
                log                     => $log,
                sbatch_file_name        => $file_path
            }
        );
    }

    return;

}

sub _add_contigs_to_vcfheader {

## Function : Add contigs to VCF header
##          : $human_genome_reference => Human genome reference
##          : $temp_directory         => Temporary directory
##          : $FILEHANDLE             => Filehandle to write to

    my ($arg_href) = @_;

    ## Flatten argument(s)
    my $human_genome_reference;
    my $temp_directory;
    my $FILEHANDLE;

    my $tmpl = {
        human_genome_reference => {
            required => 1,
            defined  => 1,
            store    => \$human_genome_reference,
        },
        temp_directory => {
            required => 1,
            defined  => 1,
            store    => \$temp_directory,
        },
        FILEHANDLE => {
            required => 1,
            defined  => 1,
            store    => \$FILEHANDLE,
        },

    };

    check( $tmpl, $arg_href, 1 ) or croak q{Could not parse arguments!};

    my $regexp;

    ## Execute perl
    $regexp = q?perl -nae '?;

    ## Write contig ID from header
    $regexp .= q?{print "##contig=<ID=".$F[0].",length=".$F[1].">", "\n"}'?;

    print {$FILEHANDLE} $regexp . $SPACE;

    # Reference fai file
    print {$FILEHANDLE} $human_genome_reference . $DOT . q{fai} . $SPACE;

    say {$FILEHANDLE} q{>}
      . $SPACE
      . catfile( $temp_directory, q{contig_header.txt} ),
      $NEWLINE;

    return;
}

sub _fix_gt_format_in_header {

## Function : Fix GT format in header
##          : $sample_id           => Sample id
##          : $outfile_path_prefix => Outfile path prefix
##          : $outfile_suffix      => Outfile suffix
##          : $FILEHANDLE          => Filehandle to write to

    my ($arg_href) = @_;

    ## Flatten argument(s)
    my $sample_id;
    my $outfile_path_prefix;
    my $outfile_suffix;
    my $FILEHANDLE;

    my $tmpl = {
        sample_id => {
            required => 1,
            defined  => 1,
            store    => \$sample_id,
        },
        outfile_path_prefix => {
            required => 1,
            defined  => 1,
            store    => \$outfile_path_prefix,
        },
        outfile_suffix => {
            required => 1,
            defined  => 1,
            store    => \$outfile_suffix,
        },
        FILEHANDLE => {
            required => 1,
            defined  => 1,
            store    => \$FILEHANDLE,
        },

    };

    check( $tmpl, $arg_href, 1 ) or croak q{Could not parse arguments!};

    my $regexp;

    ## Execute perl
    $regexp = q?perl -nae '?;

    ## Fix standard header fields
    $regexp .=
q?chomp($_); if($_=~/^##/) {print $_, "\n"} elsif($_=~/^#CHROM/) {my @a = split("\t", $_); pop(@a);print join("\t", @a)."\t?;

    ## Add sample ID
    $regexp .= $sample_id . q?", "\n"} else {print $_, "\n"}'?;

    print {$FILEHANDLE} $regexp . $SPACE;
    print {$FILEHANDLE} $outfile_path_prefix
      . $UNDERSCORE
      . q{concat}
      . $outfile_suffix
      . $SPACE;
    say {$FILEHANDLE} q{>}
      . $SPACE
      . $outfile_path_prefix
      . $UNDERSCORE
      . q{concat_fix}
      . $outfile_suffix, $NEWLINE;

    return;

}

1;
