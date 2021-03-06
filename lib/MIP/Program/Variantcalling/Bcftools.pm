package MIP::Program::Variantcalling::Bcftools;

use Carp;
use charnames qw{ :full :short };
use English qw{ -no_match_vars };
use File::Basename qw{ dirname };
use File::Spec::Functions qw{ catdir catfile };
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
use MIP::Program::Base::Bcftools qw{ bcftools_base };
use MIP::Unix::Standard_streams qw{ unix_standard_streams };
use MIP::Unix::Write_to_file qw{ unix_write_to_file };

BEGIN {
    require Exporter;
    use base qw{ Exporter };

    # Set the version for version checking
    our $VERSION = 1.06;

    # Functions and variables which can be optionally exported
    our @EXPORT_OK =
      qw{ bcftools_annotate bcftools_call bcftools_concat bcftools_filter bcftools_index bcftools_merge bcftools_mpileup bcftools_norm bcftools_reheader bcftools_rename_vcf_samples bcftools_roh bcftools_stats bcftools_view bcftools_view_and_index_vcf};

}

## Constants
Readonly my $COMMA        => q{,};
Readonly my $DOUBLE_QUOTE => q{"};
Readonly my $PIPE         => q{|};
Readonly my $NEWLINE      => qq{\n};
Readonly my $SPACE        => q{ };

sub bcftools_annotate {

## Function : Perl wrapper for writing bcftools annotate recipe to $FILEHANDLE or return commands array. Based on bcftools 1.6.
## Returns  : @commands
## Arguments: $FILEHANDLE             => Filehandle to write to
##          : $headerfile_path        => File with lines which should be appended to the VCF header
##          : $infile_path            => Infile path to read from
##          : $outfile_path           => Outfile path to write to
##          : $output_type            => 'b' compressed BCF; 'u' uncompressed BCF; 'z' compressed VCF; 'v' uncompressed VCF [v]
##          : $regions_ref            => Regions to process {REF}
##          : $remove_ids_ref         => List of annotations to remove
##          : $samples_file_path      => File of samples to annotate
##          : $samples_ref            => Samples to include or exclude if prefixed with "^"
##          : $set_id                 => Set ID column
##          : $stderrfile_path        => Stderr file path to write to {OPTIONAL}
##          : $stderrfile_path_append => Append stderr info to file path
##          : $stdoutfile_path        => Stdoutfile path

    my ($arg_href) = @_;

    ## Flatten argument(s)
    my $FILEHANDLE;
    my $infile_path;
    my $headerfile_path;
    my $outfile_path;
    my $regions_ref;
    my $remove_ids_ref;
    my $samples_file_path;
    my $samples_ref;
    my $set_id;
    my $stderrfile_path;
    my $stderrfile_path_append;
    my $stdoutfile_path;

    ## Default(s)
    my $output_type;

    my $tmpl = {
        FILEHANDLE      => { store       => \$FILEHANDLE, },
        headerfile_path => { strict_type => 1, store => \$headerfile_path, },
        infile_path     => { strict_type => 1, store => \$infile_path, },
        outfile_path    => { strict_type => 1, store => \$outfile_path, },
        output_type => {
            default     => q{v},
            allow       => [qw{ b u z v}],
            strict_type => 1,
            store       => \$output_type,
        },
        regions_ref =>
          { default => [], strict_type => 1, store => \$regions_ref, },
        remove_ids_ref => {
            defined     => 1,
            default     => [],
            strict_type => 1,
            store       => \$remove_ids_ref,
        },
        samples_file_path =>
          { strict_type => 1, store => \$samples_file_path, },
        samples_ref => {
            default     => [],
            strict_type => 1,
            store       => \$samples_ref,
        },
        set_id          => { strict_type => 1, store => \$set_id, },
        stderrfile_path => { strict_type => 1, store => \$stderrfile_path, },
        stderrfile_path_append =>
          { strict_type => 1, store => \$stderrfile_path_append, },
        stdoutfile_path => { strict_type => 1, store => \$stdoutfile_path },
    };

    check( $tmpl, $arg_href, 1 ) or croak q{Could not parse arguments!};

    # Stores commands depending on input parameters
    my @commands = qw{ bcftools annotate };

    ## Bcftools base args
    @commands = bcftools_base(
        {
            commands_ref      => \@commands,
            outfile_path      => $outfile_path,
            output_type       => $output_type,
            regions_ref       => $regions_ref,
            samples_file_path => $samples_file_path,
            samples_ref       => $samples_ref,
        }
    );

    ## Options
    if ( @{$remove_ids_ref} ) {

        push @commands, q{--remove} . $SPACE . join $COMMA, @{$remove_ids_ref};
    }

    if ($set_id) {

        push @commands, q{--set-id} . $SPACE . $set_id;
    }

    if ($headerfile_path) {

        push @commands, q{--header-lines} . $SPACE . $headerfile_path;
    }

    ## Infile
    if ($infile_path) {

        push @commands, $infile_path;
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

sub bcftools_call {

## Function : Perl wrapper for writing bcftools call recipe to $FILEHANDLE or return commands array. Based on bcftools 1.6.
## Returns  : @commands
## Arguments: $constrain              => One of: alleles, trio
##          : $FILEHANDLE             => Filehandle to write to
##          : $form_fields_ref        => Output format fields {REF}
##          : $infile_path            => Infile path to read from
##          : $multiallelic_caller    => Alternative model for multiallelic and rare-variant calling
##          : $outfile_path           => Outfile path to write to
##          : $output_type            => 'b' compressed BCF; 'u' uncompressed BCF; 'z' compressed VCF; 'v' uncompressed VCF [v]
##          : $regions_ref            => Regions to process {REF}
##          : $samples_file_path      => PED file or a file with an optional column with sex
##          : $samples_ref            => Samples to include or exclude if prefixed with "^"
##          : $stderrfile_path        => Stderr file path to write to {OPTIONAL}
##          : $stderrfile_path_append => Append stderr info to file path
##          : $stdoutfile_path        => Stdoutfile path
##          : $variants_only          => Output variant sites only

    my ($arg_href) = @_;

    ## Flatten argument(s)
    my $constrain;
    my $FILEHANDLE;
    my $form_fields_ref;
    my $infile_path;
    my $outfile_path;
    my $regions_ref;
    my $samples_file_path;
    my $samples_ref;
    my $stderrfile_path;
    my $stderrfile_path_append;
    my $stdoutfile_path;

    ## Default(s)
    my $multiallelic_caller;
    my $output_type;
    my $variants_only;

    my $tmpl = {
        constrain => {
            allow       => [ undef, qw{ alleles trio } ],
            strict_type => 1,
            store       => \$constrain,
        },
        FILEHANDLE      => { store => \$FILEHANDLE, },
        form_fields_ref => {
            required    => 1,
            defined     => 1,
            default     => [],
            strict_type => 1,
            store       => \$form_fields_ref,
        },
        infile_path         => { strict_type => 1, store => \$infile_path, },
        multiallelic_caller => {
            default     => 1,
            allow       => [ undef, 0, 1 ],
            strict_type => 1,
            store       => \$multiallelic_caller,
        },
        outfile_path => { strict_type => 1, store => \$outfile_path, },
        output_type  => {
            default     => q{v},
            allow       => [qw{ b u z v }],
            strict_type => 1,
            store       => \$output_type,
        },
        regions_ref =>
          { default => [], strict_type => 1, store => \$regions_ref, },
        samples_file_path =>
          { strict_type => 1, store => \$samples_file_path, },
        samples_ref => {
            default     => [],
            strict_type => 1,
            store       => \$samples_ref,
        },
        stderrfile_path => { strict_type => 1, store => \$stderrfile_path, },
        stderrfile_path_append =>
          { strict_type => 1, store => \$stderrfile_path_append, },
        stdoutfile_path => { strict_type => 1, store => \$stdoutfile_path },
        variants_only   => {
            default     => 1,
            allow       => [ undef, 0, 1 ],
            strict_type => 1,
            store       => \$variants_only,
        },
    };

    check( $tmpl, $arg_href, 1 ) or croak q{Could not parse arguments!};

    # Stores commands depending on input parameters
    my @commands = qw{ bcftools call };

    ## Bcftools base args
    @commands = bcftools_base(
        {
            commands_ref      => \@commands,
            outfile_path      => $outfile_path,
            output_type       => $output_type,
            regions_ref       => $regions_ref,
            samples_file_path => $samples_file_path,
            samples_ref       => $samples_ref,
        }
    );

    ## Options
    if ($multiallelic_caller) {

        push @commands, q{--multiallelic-caller};
    }

    if ( @{$form_fields_ref} ) {

        push @commands, q{--format-fields} . $SPACE . join $COMMA,
          @{$form_fields_ref};
    }

    if ($variants_only) {

        push @commands, q{--variants-only};
    }

    if ($constrain) {

        push @commands, q{--constrain} . $SPACE . $constrain;
    }

    ## Infile
    if ($infile_path) {

        push @commands, $infile_path;
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

sub bcftools_concat {

## Function : Perl wrapper for writing bcftools concat recipe to $FILEHANDLE or return commands array. Based on bcftools 1.6.
## Returns  : @commands
## Arguments: $allow_overlaps         => First coordinate of the next file can precede last record of the current file
##          : $FILEHANDLE             => Filehandle to write to
##          : $infile_paths_ref       => Infile path to read from
##          : $outfile_path           => Outfile path to write to
##          : $output_type            => 'b' compressed BCF; 'u' uncompressed BCF; 'z' compressed VCF; 'v' uncompressed VCF [v]
##          : $regions_ref            => Regions to process {REF}
##          : $rm_dups                => Output duplicate records present in multiple files only once: <snps|indels|both|all|none>
##          : $samples_file_path      => File of samples to annotate
##          : $samples_ref            => Samples to include or exclude if prefixed with "^"
##          : $stderrfile_path        => Stderr file path to write to
##          : $stderrfile_path_append => Append stderr info to file path
##          : $stdoutfile_path        => Stdoutfile file path to write to

    my ($arg_href) = @_;

    ## Flatten argument(s)
    my $FILEHANDLE;
    my $infile_paths_ref;
    my $outfile_path;
    my $regions_ref;
    my $samples_file_path;
    my $samples_ref;
    my $stderrfile_path;
    my $stderrfile_path_append;
    my $stdoutfile_path;

    ## Default(s)
    my $allow_overlaps;
    my $output_type;
    my $rm_dups;

    my $tmpl = {
        allow_overlaps => {
            default     => 0,
            allow       => [ 0, 1 ],
            strict_type => 1,
            store       => \$allow_overlaps,
        },
        FILEHANDLE => { store => \$FILEHANDLE, },
        infile_paths_ref =>
          { default => [], strict_type => 1, store => \$infile_paths_ref, },
        outfile_path => { strict_type => 1, store => \$outfile_path, },
        output_type  => {
            default     => q{v},
            allow       => [qw{ b u z v }],
            strict_type => 1,
            store       => \$output_type,
        },
        regions_ref =>
          { default => [], strict_type => 1, store => \$regions_ref, },
        rm_dups => {
            default     => q{all},
            allow       => [qw{ snps indels both all none }],
            strict_type => 1,
            store       => \$rm_dups,
        },
        samples_file_path =>
          { strict_type => 1, store => \$samples_file_path, },
        samples_ref => {
            default     => [],
            strict_type => 1,
            store       => \$samples_ref,
        },
        stderrfile_path => { strict_type => 1, store => \$stderrfile_path, },
        stderrfile_path_append =>
          { strict_type => 1, store => \$stderrfile_path_append, },
        stdoutfile_path => { strict_type => 1, store => \$stdoutfile_path, },
    };

    check( $tmpl, $arg_href, 1 ) or croak q{Could not parse arguments!};

    # Stores commands depending on input parameters
    my @commands = qw{ bcftools concat };

    ## Bcftools base args
    @commands = bcftools_base(
        {
            commands_ref      => \@commands,
            outfile_path      => $outfile_path,
            output_type       => $output_type,
            regions_ref       => $regions_ref,
            samples_file_path => $samples_file_path,
            samples_ref       => $samples_ref,
        }
    );

    ## Options
    if ($allow_overlaps) {

        push @commands, q{--allow-overlaps};
    }

    if ($rm_dups) {

        push @commands, q{--rm-dups} . $SPACE . $rm_dups;
    }

    ## Infile
    if ( @{$infile_paths_ref} ) {

        push @commands, join $SPACE, @{$infile_paths_ref};
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

sub bcftools_filter {

## Function : Perl wrapper for writing bcftools filter recipe to $FILEHANDLE or return commands array. Based on bcftools 1.6.
## Returns  : @commands
## Arguments: $FILEHANDLE             => Filehandle to write to
##          : $exclude                => Exclude sites for which the expression is true
##          : $include                => Include only sites for which the expression is true
##          : $indel_gap              => Filter clusters of indels separated by <int> or fewer base pairs allowing only one to pass
##          : $infile_path            => Infile paths
##          : $outfile_path           => Outfile path to write to
##          : $output_type            => 'b' compressed BCF; 'u' uncompressed BCF; 'z' compressed VCF; 'v' uncompressed VCF [v]
##          : $regions_ref            => Regions to process {REF}
##          : $samples_file_path      => File of samples to annotate
##          : $samples_ref            => Samples to include or exclude if prefixed with "^"
##          : $soft_filter            => Annotate FILTER column with <string> or unique filter name
##          : $snp_gap                => Filter SNPs within <int> base pairs of an indel
##          : $stdoutfile_path        => Stdoutfile path
##          : $stderrfile_path        => Stderrfile path
##          : $stderrfile_path_append => Append stderr info to file path

    my ($arg_href) = @_;

    ## Flatten argument(s)
    my $FILEHANDLE;
    my $exclude;
    my $include;
    my $indel_gap;
    my $infile_path;
    my $soft_filter;
    my $snp_gap;
    my $outfile_path;
    my $regions_ref;
    my $samples_file_path;
    my $samples_ref;
    my $stdoutfile_path;
    my $stderrfile_path;
    my $stderrfile_path_append;

    ## Default(s)
    my $output_type;

    my $tmpl = {
        FILEHANDLE  => { store       => \$FILEHANDLE, },
        exclude     => { strict_type => 1, store => \$exclude, },
        infile_path => { strict_type => 1, store => \$infile_path, },
        include     => { strict_type => 1, store => \$include, },
        indel_gap => {
            allow       => qr/ ^\d+$ /sxm,
            strict_type => 1,
            store       => \$indel_gap,
        },
        outfile_path => { strict_type => 1, store => \$outfile_path, },
        output_type  => {
            default     => q{v},
            allow       => [qw{ b u z v}],
            strict_type => 1,
            store       => \$output_type,
        },
        regions_ref =>
          { default => [], strict_type => 1, store => \$regions_ref, },
        samples_file_path =>
          { strict_type => 1, store => \$samples_file_path, },
        samples_ref => {
            default     => [],
            strict_type => 1,
            store       => \$samples_ref,
        },
        soft_filter => { strict_type => 1, store => \$soft_filter, },
        snp_gap     => {
            allow       => qr/ ^\d+$ /sxm,
            strict_type => 1,
            store       => \$snp_gap,
        },
        stderrfile_path => { strict_type => 1, store => \$stderrfile_path, },
        stderrfile_path_append =>
          { strict_type => 1, store => \$stderrfile_path_append, },
        stdoutfile_path => { strict_type => 1, store => \$stdoutfile_path, },
    };

    check( $tmpl, $arg_href, 1 ) or croak q{Could not parse arguments!};

    # Stores commands depending on input parameters
    my @commands = qw{ bcftools filter };

    ## Bcftools base args
    @commands = bcftools_base(
        {
            commands_ref      => \@commands,
            outfile_path      => $outfile_path,
            output_type       => $output_type,
            regions_ref       => $regions_ref,
            samples_file_path => $samples_file_path,
            samples_ref       => $samples_ref,
        }
    );

    ## Options
    if ($exclude) {

        push @commands, q{--exclude} . $SPACE . $exclude;
    }
    if ($include) {

        push @commands, q{--include} . $SPACE . $include;
    }
    if ($soft_filter) {

        push @commands, q{--soft-filter} . $SPACE . $soft_filter;
    }

    if ($snp_gap) {

        push @commands, q{--SnpGap} . $SPACE . $snp_gap;
    }

    if ($indel_gap) {

        push @commands, q{--IndelGap} . $SPACE . $indel_gap;
    }

    ## Infile
    if ($infile_path) {

        push @commands, $infile_path;
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

sub bcftools_index {

## Function : Perl wrapper for writing bcftools index recipe to $FILEHANDLE or return commands array. Based on bcftools 1.6.
## Returns  : @commands
## Arguments: $FILEHANDLE             => Filehandle to write to
##          : $infile_path            => Infile path to read from
##          : $outfile_path           => Outfile path to write to
##          : $output_type            => 'csi' generate CSI-format index, 'tbi' generate TBI-format index
##          : $regions_ref            => Regions to process {REF}
##          : $samples_file_path      => File of samples to annotate
##          : $samples_ref            => Samples to include or exclude if prefixed with "^"
##          : $stderrfile_path        => Stderr file path to write to {OPTIONAL}
##          : $stderrfile_path_append => Append stderr info to file path
##          : $stdoutfile_path        => Stdoutfile path

    my ($arg_href) = @_;

    ## Flatten argument(s)
    my $FILEHANDLE;
    my $infile_path;
    my $outfile_path;
    my $regions_ref;
    my $samples_file_path;
    my $samples_ref;
    my $stderrfile_path;
    my $stderrfile_path_append;
    my $stdoutfile_path;

    ## Default(s)
    my $output_type;

    my $tmpl = {
        FILEHANDLE  => { store => \$FILEHANDLE, },
        infile_path => {
            required    => 1,
            defined     => 1,
            strict_type => 1,
            store       => \$infile_path,
        },
        outfile_path => { strict_type => 1, store => \$outfile_path, },
        output_type  => {
            default     => q{csi},
            allow       => [qw{ csi tbi }],
            strict_type => 1,
            store       => \$output_type,
        },
        regions_ref =>
          { default => [], strict_type => 1, store => \$regions_ref, },
        samples_file_path =>
          { strict_type => 1, store => \$samples_file_path, },
        samples_ref => {
            default     => [],
            strict_type => 1,
            store       => \$samples_ref,
        },
        stderrfile_path => { strict_type => 1, store => \$stderrfile_path, },
        stderrfile_path_append =>
          { strict_type => 1, store => \$stderrfile_path_append, },
        stdoutfile_path => { strict_type => 1, store => \$stdoutfile_path, },
    };

    check( $tmpl, $arg_href, 1 ) or croak q{Could not parse arguments!};

    # Stores commands depending on input parameters
    my @commands = qw{ bcftools index };

    ## Bcftools base args
    @commands = bcftools_base(
        {
            commands_ref      => \@commands,
            outfile_path      => $outfile_path,
            regions_ref       => $regions_ref,
            samples_file_path => $samples_file_path,
            samples_ref       => $samples_ref,
        }
    );

    ## Options
    # Special case: 'csi' or 'tbi'
    if ($output_type) {

        #Specify output type
        push @commands, q{--} . $output_type;
    }

    ## Infile
    if ($infile_path) {

        push @commands, $infile_path;
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

sub bcftools_merge {

## Function : Perl wrapper for writing bcftools merge recipe to $FILEHANDLE or return commands array. Based on bcftools 1.6.
## Returns  : @commands
## Arguments: $FILEHANDLE             => Filehandle to write to
##          : $infile_paths_ref       => Infile path to read from
##          : $outfile_path           => Outfile path to write to
##          : $output_type            => 'b' compressed BCF; 'u' uncompressed BCF; 'z' compressed VCF; 'v' uncompressed VCF [v]
##          : $regions_ref            => Regions to process {REF}
##          : $samples_file_path      => File of samples to annotate
##          : $samples_ref            => Samples to include or exclude if prefixed with "^"
##          : $stderrfile_path        => Stderr file path to write to
##          : $stderrfile_path_append => Append stderr info to file path
##          : $stdoutfile_path        => Stdoutfile file path to write to

    my ($arg_href) = @_;

    ## Flatten argument(s)
    my $FILEHANDLE;
    my $infile_paths_ref;
    my $outfile_path;
    my $regions_ref;
    my $samples_file_path;
    my $samples_ref;
    my $stderrfile_path;
    my $stderrfile_path_append;
    my $stdoutfile_path;

    ## Default(s)
    my $output_type;

    my $tmpl = {
        FILEHANDLE => { store => \$FILEHANDLE, },
        infile_paths_ref =>
          { default => [], strict_type => 1, store => \$infile_paths_ref, },
        outfile_path => { strict_type => 1, store => \$outfile_path, },
        output_type  => {
            default     => q{v},
            allow       => [qw{ b u z v}],
            strict_type => 1,
            store       => \$output_type,
        },
        regions_ref =>
          { default => [], strict_type => 1, store => \$regions_ref, },
        samples_file_path =>
          { strict_type => 1, store => \$samples_file_path, },
        samples_ref => {
            default     => [],
            strict_type => 1,
            store       => \$samples_ref,
        },
        stderrfile_path => { strict_type => 1, store => \$stderrfile_path, },
        stderrfile_path_append =>
          { strict_type => 1, store => \$stderrfile_path_append, },
        stdoutfile_path => { strict_type => 1, store => \$stdoutfile_path, },
    };

    check( $tmpl, $arg_href, 1 ) or croak q{Could not parse arguments!};

    # Stores commands depending on input parameters
    my @commands = qw{ bcftools merge };

    ## Bcftools base args
    @commands = bcftools_base(
        {
            commands_ref      => \@commands,
            outfile_path      => $outfile_path,
            output_type       => $output_type,
            regions_ref       => $regions_ref,
            samples_file_path => $samples_file_path,
            samples_ref       => $samples_ref,
        }
    );

    ## Options
    if ( @{$infile_paths_ref} ) {

        push @commands, join $SPACE, @{$infile_paths_ref};
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

sub bcftools_mpileup {

## Function : Perl wrapper for writing bcftools mpileup recipe to $FILEHANDLE. Based on bcftools 1.6 (using htslib 1.6).
## Returns  : @commands
##          : $adjust_mq                        => Adjust mapping quality
##          : $FILEHANDLE                       => Sbatch filehandle to write to
##          : $infile_paths_ref                 => Infile paths {REF}
##          : $outfile_path                     => Outfile path
##          : $output_tags_ref                  => Optional tags to output {REF}
##          : $output_type                      => 'b' compressed BCF; 'u' uncompressed BCF; 'z' compressed VCF; 'v' uncompressed VCF [v]
##          : $per_sample_increased_sensitivity => Apply -m and -F per-sample for increased sensitivity
##          : $referencefile_path               => Reference sequence file
##          : $regions_ref                      => Regions to process {REF}
##          : $samples_file_path                => File of samples to annotate
##          : $samples_ref                      => Samples to include or exclude if prefixed with "^"
##          : $stderrfile_path                  => Stderrfile path
##          : $stderrfile_path_append           => Stderrfile path append
##          : $stdoutfile_path                  => Stdoutfile file path to write to

    my ($arg_href) = @_;

    ## Flatten argument(s)
    my $FILEHANDLE;
    my $infile_paths_ref;
    my $outfile_path;
    my $output_tags_ref;
    my $referencefile_path;
    my $regions_ref;
    my $samples_file_path;
    my $samples_ref;
    my $stderrfile_path;
    my $stderrfile_path_append;
    my $stdoutfile_path;

    ## Default(s)
    my $adjust_mq;
    my $per_sample_increased_sensitivity;
    my $output_type;

    ## Constants
    Readonly my $ADJUST_MAPPING_QUALITY => 50;

    my $tmpl = {
        adjust_mq => {
            default     => $ADJUST_MAPPING_QUALITY,
            allow       => qr/ ^\d+$ /sxm,
            strict_type => 1,
            store       => \$adjust_mq,
        },
        FILEHANDLE       => { store => \$FILEHANDLE, },
        infile_paths_ref => {
            required    => 1,
            defined     => 1,
            default     => [],
            strict_type => 1,
            store       => \$infile_paths_ref,
        },
        outfile_path    => { strict_type => 1, store => \$outfile_path, },
        output_tags_ref => {
            required    => 1,
            defined     => 1,
            default     => [],
            strict_type => 1,
            store       => \$output_tags_ref,
        },
        output_type => {
            default     => q{b},
            allow       => [qw{ b u z v}],
            strict_type => 1,
            store       => \$output_type,
        },
        per_sample_increased_sensitivity => {
            default     => 0,
            allow       => [ undef, 0, 1 ],
            strict_type => 1,
            store       => \$per_sample_increased_sensitivity,
        },
        referencefile_path => {
            required    => 1,
            defined     => 1,
            strict_type => 1,
            store       => \$referencefile_path,
        },
        regions_ref =>
          { default => [], strict_type => 1, store => \$regions_ref, },
        samples_file_path =>
          { strict_type => 1, store => \$samples_file_path, },
        samples_ref => {
            default     => [],
            strict_type => 1,
            store       => \$samples_ref,
        },
        stderrfile_path => { strict_type => 1, store => \$stderrfile_path },
        stderrfile_path_append =>
          { strict_type => 1, store => \$stderrfile_path_append, },
        stdoutfile_path => { strict_type => 1, store => \$stdoutfile_path, },
    };

    check( $tmpl, $arg_href, 1 ) or croak q{Could not parse arguments!};

    ## Array @commands stores commands depending on input parameters
    my @commands = qw{ bcftools mpileup };

    ## Bcftools base args
    @commands = bcftools_base(
        {
            commands_ref      => \@commands,
            regions_ref       => $regions_ref,
            outfile_path      => $outfile_path,
            output_type       => $output_type,
            samples_file_path => $samples_file_path,
            samples_ref       => $samples_ref,
        }
    );

    ## Options
    push @commands, q{--adjust-MQ} . $SPACE . $adjust_mq;

    if ($per_sample_increased_sensitivity) {

        push @commands, q{--per-sample-mF};
    }

    if ( @{$output_tags_ref} ) {

        push @commands, q{--annotate} . $SPACE . join $COMMA,
          @{$output_tags_ref};
    }

    # Reference sequence file
    push @commands, q{--fasta-ref} . $SPACE . $referencefile_path;

    ## Infile
    push @commands, join $SPACE, @{$infile_paths_ref};

    # Redirect stderr output to program specific stderr file
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

sub bcftools_norm {

## Function : Perl wrapper for writing bcftools norm recipe to $FILEHANDLE or return commands array. Based on bcftools 1.6.
## Returns  : @commands
## Arguments: $FILEHANDLE             => Filehandle to write to
##          : $infile_path            => Infile path to read from
##          : $multiallelic           => To split/join multiallelic calls or not
##          : $multiallelic_type      => Type of multiallelic to split/join {OPTIONAL}
##          : $outfile_path           => Outfile path to write to
##          : $output_type            => 'b' compressed BCF; 'u' uncompressed BCF; 'z' compressed VCF; 'v' uncompressed VCF [v]
##          : $reference_path         => Human genome reference path
##          : $regions_ref            => Regions to process {REF}
##          : $samples_file_path      => File of samples to annotate
##          : $samples_ref            => Samples to include or exclude if prefixed with "^"
##          : $stderrfile_path        => Stderr file path to write to {OPTIONAL}
##          : $stderrfile_path_append => Append stderr info to file path
##          : $stdoutfile_path        => Stdoutfile path

    my ($arg_href) = @_;

    ## Flatten argument(s)
    my $FILEHANDLE;
    my $infile_path;
    my $multiallelic;
    my $outfile_path;
    my $reference_path;
    my $regions_ref;
    my $samples_file_path;
    my $samples_ref;
    my $stderrfile_path;
    my $stderrfile_path_append;
    my $stdoutfile_path;

    ## Default(s)
    my $multiallelic_type;
    my $output_type;

    my $tmpl = {
        FILEHANDLE  => { store       => \$FILEHANDLE, },
        infile_path => { strict_type => 1, store => \$infile_path, },
        multiallelic => {
            allow       => [qw{ + - }],
            strict_type => 1,
            store       => \$multiallelic,
        },
        multiallelic_type => {
            default     => q{both},
            allow       => [qw{ snps indels both any }],
            strict_type => 1,
            store       => \$multiallelic_type,
        },
        outfile_path => {
            required    => 1,
            defined     => 1,
            strict_type => 1,
            store       => \$outfile_path,
        },
        output_type => {
            default     => q{v},
            allow       => [qw{ b u z v }],
            strict_type => 1,
            store       => \$output_type,
        },
        reference_path => {
            required    => 1,
            defined     => 1,
            strict_type => 1,
            store       => \$reference_path,
        },
        regions_ref =>
          { default => [], strict_type => 1, store => \$regions_ref, },
        samples_file_path =>
          { strict_type => 1, store => \$samples_file_path, },
        samples_ref => {
            default     => [],
            strict_type => 1,
            store       => \$samples_ref,
        },
        stderrfile_path => { strict_type => 1, store => \$stderrfile_path, },
        stderrfile_path_append =>
          { strict_type => 1, store => \$stderrfile_path_append, },
        stdoutfile_path => { strict_type => 1, store => \$stdoutfile_path },
    };

    check( $tmpl, $arg_href, 1 ) or croak q{Could not parse arguments!};

    # Stores commands depending on input parameters
    my @commands = qw{ bcftools norm };

    ## Bcftools base args
    @commands = bcftools_base(
        {
            commands_ref      => \@commands,
            regions_ref       => $regions_ref,
            outfile_path      => $outfile_path,
            output_type       => $output_type,
            samples_file_path => $samples_file_path,
            samples_ref       => $samples_ref,
        }
    );

    ## Options
    if ($multiallelic) {

        push @commands,
          q{--multiallelics} . $SPACE . $multiallelic . $multiallelic_type;
    }

    if ($reference_path) {

        push @commands, q{--fasta-ref} . $SPACE . $reference_path;
    }

    ## Infile
    if ($infile_path) {

        push @commands, $infile_path;
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

sub bcftools_reheader {

## Function : Perl wrapper for writing bcftools reheader recipe to already open $FILEHANDLE or return commands array. Based on bcftools 1.3.1.
## Returns  : @commands
## Arguments: $FILEHANDLE             => Filehandle to write to
##          : $infile_path            => Infile path
##          : $outfile_path           => Outfile path
##          : $output_type            => 'b' compressed BCF; 'u' uncompressed BCF; 'z' compressed VCF; 'v' uncompressed VCF [v]
##          : $regions_ref            => Regions to process {REF}
##          : $samples_file_path      => File of samples to annotate
##          : $samples_ref            => Samples to include or exclude if prefixed with "^"
##          : $stderrfile_path        => Stderrfile path
##          : $stderrfile_path_append => Append stderr info to file path
##          : $stdoutfile_path        => Stdoutfile path

    my ($arg_href) = @_;

    ## Flatten argument(s)
    my $FILEHANDLE;
    my $infile_path;
    my $outfile_path;
    my $regions_ref;
    my $samples_file_path;
    my $samples_ref;
    my $stderrfile_path;
    my $stderrfile_path_append;
    my $stdoutfile_path;

    ## Default(s)
    my $output_type;

    my $tmpl = {
        FILEHANDLE   => { store       => \$FILEHANDLE, },
        infile_path  => { strict_type => 1, store => \$infile_path, },
        outfile_path => { strict_type => 1, store => \$outfile_path, },
        output_type => {
            default     => q{v},
            allow       => [qw{ b u z v}],
            strict_type => 1,
            store       => \$output_type,
        },
        regions_ref =>
          { default => [], strict_type => 1, store => \$regions_ref, },
        samples_file_path =>
          { strict_type => 1, store => \$samples_file_path, },
        samples_ref => {
            default     => [],
            strict_type => 1,
            store       => \$samples_ref,
        },
        stderrfile_path => { strict_type => 1, store => \$stderrfile_path, },
        stderrfile_path_append =>
          { strict_type => 1, store => \$stderrfile_path_append, },
        stdoutfile_path => { strict_type => 1, store => \$stdoutfile_path, },
    };

    check( $tmpl, $arg_href, 1 ) or croak q{Could not parse arguments!};

    # Stores commands depending on input parameters
    my @commands = qw{ bcftools reheader };

    ## Bcftools base args
    @commands = bcftools_base(
        {
            commands_ref      => \@commands,
            regions_ref       => $regions_ref,
            output_type       => $output_type,
            outfile_path      => $outfile_path,
            samples_file_path => $samples_file_path,
            samples_ref       => $samples_ref,
        }
    );

    ## Options
    # Infile
    if ($infile_path) {

        push @commands, $infile_path;
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

sub bcftools_rename_vcf_samples {

## Function : Rename vcf samples. The samples array will replace the sample names in the same order as supplied.
## Returns  :
## Arguments: $FILEHANDLE     => Filehandle to write to
##          : $infile         => Vcf infile to rename samples for
##          : $outfile        => Output vcf with samples renamed
##          : $output_type    => Output type
##          : $sample_ids_ref => Samples to rename in the same order as in the vcf {REF}
##          : $temp_directory => Temporary directory

    my ($arg_href) = @_;

    ## Flatten argument(s)
    my $FILEHANDLE;
    my $infile;
    my $outfile;
    my $sample_ids_ref;
    my $temp_directory;

    ## Default(s)
    my $output_type;

    my $tmpl = {
        FILEHANDLE => { required => 1, defined => 1, store => \$FILEHANDLE, },
        infile =>
          { required => 1, defined => 1, strict_type => 1, store => \$infile, },
        outfile => {
            required    => 1,
            defined     => 1,
            strict_type => 1,
            store       => \$outfile,
        },
        output_type => {
            default     => q{v},
            allow       => [qw{ b u z v }],
            strict_type => 1,
            store       => \$output_type,
        },
        sample_ids_ref => {
            required    => 1,
            defined     => 1,
            default     => [],
            strict_type => 1,
            store       => \$sample_ids_ref,
        },
        temp_directory => {
            required    => 1,
            defined     => 1,
            strict_type => 1,
            store       => \$temp_directory,
        },
    };

    check( $tmpl, $arg_href, 1 ) or croak q{Could not parse arguments!};

    use MIP::Gnu::Coreutils qw{ gnu_printf };

    ## Create new sample names file
    say {$FILEHANDLE} q{## Create new sample(s) names file};

    ## Get parameters
    my $format_string = $DOUBLE_QUOTE;
  SAMPLE_ID:
    foreach my $sample_id ( @{$sample_ids_ref} ) {

        $format_string .= $sample_id . q{\n};
    }
    $format_string .= $DOUBLE_QUOTE;
    gnu_printf(
        {
            format_string   => $format_string,
            stdoutfile_path => catfile( $temp_directory, q{sample_name.txt} ),
            FILEHANDLE      => $FILEHANDLE,
        }
    );
    say {$FILEHANDLE} $NEWLINE;

    ## Rename samples in VCF
    say {$FILEHANDLE} q{## Rename sample(s) names in VCF file};
    bcftools_reheader(
        {
            infile_path       => $infile,
            samples_file_path => catfile( $temp_directory, q{sample_name.txt} ),
            FILEHANDLE        => $FILEHANDLE,
        }
    );
    ## Pipe
    print {$FILEHANDLE} $PIPE . $SPACE;

    bcftools_view(
        {
            outfile_path => $outfile,
            output_type  => q{v},
            FILEHANDLE   => $FILEHANDLE,
        }
    );
    say {$FILEHANDLE} $NEWLINE;
    return;
}

sub bcftools_roh {

## Function : Perl wrapper for writing bcftools roh recipe to $FILEHANDLE or return commands array. Based on bcftools 1.6.
## Returns  : @commands
## Arguments: $af_file_path           => Read allele frequencies from file (CHR\tPOS\tREF,ALT\tAF)
##          : $FILEHANDLE             => Filehandle to write to
##          : $infile_path            => Infile path to read from
##          : $outfile_path           => Outfile path to write to
##          : $output_type            => 'b' compressed BCF; 'u' uncompressed BCF; 'z' compressed VCF; 'v' uncompressed VCF [v]
##          : $regions_ref            => Regions to process {REF}
##          : $samples_file_path      => File of samples to annotate
##          : $samples_ref            => Samples to include or exclude if prefixed with "^"
##          : $skip_indels            => Skip indels as their genotypes are enriched for errors
##          : $stderrfile_path        => Stderr file path to write to
##          : $stderrfile_path_append => Append stderr info to file path
##          : $stdoutfile_path        => Stdoutfile file path to write to

    my ($arg_href) = @_;

    ## Flatten argument(s)
    my $af_file_path;
    my $FILEHANDLE;
    my $infile_path;
    my $outfile_path;
    my $regions_ref;
    my $samples_file_path;
    my $samples_ref;
    my $stderrfile_path;
    my $stderrfile_path_append;
    my $stdoutfile_path;

    ## Default(s)
    my $skip_indels;
    my $output_type;

    my $tmpl = {
        af_file_path => { strict_type => 1, store => \$af_file_path, },
        FILEHANDLE  => { store => \$FILEHANDLE, },
        infile_path => {
            required    => 1,
            defined     => 1,
            strict_type => 1,
            store       => \$infile_path,
        },
        outfile_path => { strict_type => 1, store => \$outfile_path, },
        output_type  => {
            default     => q{v},
            allow       => [qw{ b u z v}],
            strict_type => 1,
            store       => \$output_type,
        },
        regions_ref =>
          { default => [], strict_type => 1, store => \$regions_ref, },
        samples_file_path =>
          { strict_type => 1, store => \$samples_file_path, },
        samples_ref => {
            default     => [],
            strict_type => 1,
            store       => \$samples_ref,
        },
        samples_ref => {
            default     => [],
            strict_type => 1,
            store       => \$samples_ref,
        },
        skip_indels => {
            default     => 0,
            allow       => [ 0, 1 ],
            strict_type => 1,
            store       => \$skip_indels,
        },
        stderrfile_path => { strict_type => 1, store => \$stderrfile_path, },
        stderrfile_path_append =>
          { strict_type => 1, store => \$stderrfile_path_append, },
        stdoutfile_path => { strict_type => 1, store => \$stdoutfile_path, },
    };

    check( $tmpl, $arg_href, 1 ) or croak q{Could not parse arguments!};

    # Stores commands depending on input parameters
    my @commands = qw{ bcftools roh };

    ## Bcftools base args
    @commands = bcftools_base(
        {
            commands_ref      => \@commands,
            regions_ref       => $regions_ref,
            output_type       => $output_type,
            outfile_path      => $outfile_path,
            samples_file_path => $samples_file_path,
            samples_ref       => $samples_ref,
        }
    );

    ## Options
    if ($af_file_path) {

        push @commands, q{--AF-file} . $SPACE . $af_file_path;
    }

    if ($skip_indels) {

        push @commands, q{--skip-indels};
    }

    ## Infile
    if ($infile_path) {

        push @commands, $infile_path;
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

sub bcftools_stats {

## Function : Perl wrapper for writing bcftools stats recipe to already open $FILEHANDLE or return commands array. Based on bcftools 1.6.
## Returns  : @commands
## Arguments: $infile_path            => Infile path
##          : $outfile_path           => Outfile path
##          : $output_type            => 'b' compressed BCF; 'u' uncompressed BCF; 'z' compressed VCF; 'v' uncompressed VCF [v]
##          : $regions_ref            => Regions to process {REF}
##          : $samples_file_path      => File of samples to annotate
##          : $samples_ref            => Samples to include or exclude if prefixed with "^"
##          : $stderrfile_path        => Stderrfile path
##          : $stderrfile_path_append => Append stderr info to file path
##          : $stdoutfile_path        => Stdoutfile path
##          : $FILEHANDLE             => Filehandle to write to

    my ($arg_href) = @_;

    ## Flatten argument(s)
    my $infile_path;
    my $outfile_path;
    my $regions_ref;
    my $samples_file_path;
    my $samples_ref;
    my $stderrfile_path;
    my $stderrfile_path_append;
    my $stdoutfile_path;
    my $FILEHANDLE;

    ## Default(s)
    my $output_type;

    my $tmpl = {
        infile_path  => { strict_type => 1, store => \$infile_path, },
        outfile_path => { strict_type => 1, store => \$outfile_path, },
        output_type  => {
            default     => q{v},
            allow       => [qw{ b u z v}],
            strict_type => 1,
            store       => \$output_type,
        },
        regions_ref =>
          { default => [], strict_type => 1, store => \$regions_ref, },
        samples_file_path =>
          { strict_type => 1, store => \$samples_file_path, },
        samples_ref => {
            default     => [],
            strict_type => 1,
            store       => \$samples_ref,
        },
        stderrfile_path => { strict_type => 1, store => \$stderrfile_path, },
        stderrfile_path_append =>
          { strict_type => 1, store => \$stderrfile_path_append, },
        stdoutfile_path => { strict_type => 1, store => \$stdoutfile_path, },
        FILEHANDLE => { store => \$FILEHANDLE, },
    };

    check( $tmpl, $arg_href, 1 ) or croak q{Could not parse arguments!};

    # Stores commands depending on input parameters
    my @commands = qw{ bcftools stats };

    ## Bcftools base args
    @commands = bcftools_base(
        {
            commands_ref      => \@commands,
            regions_ref       => $regions_ref,
            output_type       => $output_type,
            outfile_path      => $outfile_path,
            samples_file_path => $samples_file_path,
            samples_ref       => $samples_ref,
        }
    );

    ## Infile
    if ($infile_path) {

        push @commands, $infile_path;
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

sub bcftools_view {

## Function : Perl wrapper for writing bcftools view recipe to $FILEHANDLE or return commands array. Based on bcftools 1.6.
## Returns  : @commands
## Arguments: $apply_filters_ref      => Require at least one of the listed FILTER strings
##          : $exclude_types_ref      => Exclude comma-separated list of variant types: snps,indels,mnps,other
##          : $exclude                => Exclude sites for which the expression is true
##          : $FILEHANDLE             => Filehandle to write to
##          : $include                => Include only sites for which the expression is true
##          : $infile_path            => Infile path to read from
##          : $outfile_path           => Outfile path to write to
##          : $output_type            => 'b' compressed BCF; 'u' uncompressed BCF; 'z' compressed VCF; 'v' uncompressed VCF [v]
##          : $regions_ref            => Regions to process {REF}
##          : $samples_file_path      => File of samples to annotate

##          : $samples_ref            => Samples to include or exclude if prefixed with "^"
##          : $stderrfile_path        => Stderr file path to write to
##          : $stderrfile_path_append => Append stderr info to file path
##          : $stdoutfile_path        => Stdoutfile file path to write to

    my ($arg_href) = @_;

    ## Flatten argument(s)
    my $apply_filters_ref;
    my $exclude_types_ref;
    my $exclude;
    my $FILEHANDLE;
    my $include;
    my $infile_path;
    my $outfile_path;
    my $regions_ref;
    my $samples_file_path;
    my $samples_ref;
    my $stderrfile_path;
    my $stderrfile_path_append;
    my $stdoutfile_path;

    ## Default(s)
    my $output_type;

    my $tmpl = {
        FILEHANDLE => { store => \$FILEHANDLE, },
        apply_filters_ref =>
          { default => [], strict_type => 1, store => \$apply_filters_ref, },
        exclude_types_ref =>
          { default => [], strict_type => 1, store => \$exclude_types_ref, },
        exclude      => { strict_type => 1, store => \$exclude, },
        include      => { strict_type => 1, store => \$include, },
        infile_path  => { strict_type => 1, store => \$infile_path, },
        outfile_path => { strict_type => 1, store => \$outfile_path, },
        output_type  => {
            default     => q{v},
            allow       => [qw{ b u z v}],
            strict_type => 1,
            store       => \$output_type,
        },
        regions_ref =>
          { default => [], strict_type => 1, store => \$regions_ref, },
        samples_file_path =>
          { strict_type => 1, store => \$samples_file_path, },
        samples_ref => {
            default     => [],
            strict_type => 1,
            store       => \$samples_ref,
        },
        stderrfile_path => { strict_type => 1, store => \$stderrfile_path, },
        stderrfile_path_append =>
          { strict_type => 1, store => \$stderrfile_path_append, },
        stdoutfile_path => { strict_type => 1, store => \$stdoutfile_path, },
    };

    check( $tmpl, $arg_href, 1 ) or croak q{Could not parse arguments!};

    # Stores commands depending on input parameters
    my @commands = qw{ bcftools view };

    ## Bcftools base args
    @commands = bcftools_base(
        {
            commands_ref      => \@commands,
            regions_ref       => $regions_ref,
            output_type       => $output_type,
            outfile_path      => $outfile_path,
            samples_file_path => $samples_file_path,
            samples_ref       => $samples_ref,
        }
    );

    ## Options
    if ( @{$apply_filters_ref} ) {

        push @commands, q{--apply-filters} . $SPACE . join $COMMA,
          @{$apply_filters_ref};
    }

    if ( @{$exclude_types_ref} ) {

        push @commands, q{--exclude-types} . $SPACE . join $COMMA,
          @{$exclude_types_ref};
    }

    if ($exclude) {

        push @commands, q{--exclude} . $SPACE . $exclude;
    }

    if ($include) {

        push @commands, q{--include} . $SPACE . $include;
    }

    ## Infile
    if ($infile_path) {

        push @commands, $infile_path;
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

sub bcftools_view_and_index_vcf {

## Function : View variant calling file and index.
## Returns  :
## Arguments: $FILEHANDLE          => SBATCH script FILEHANDLE to print to
##          : $index               => Generate index of reformated file
##          : $index_type          => Type of index
##          : $infile_path         => Path to infile to compress and index
##          : $outfile_path_prefix => Out file path no file_ending {Optional}
##          : $output_type         => 'b' compressed BCF; 'u' uncompressed BCF; 'z' compressed VCF; 'v' uncompressed VCF [v]

    my ($arg_href) = @_;

    ## Flatten argument(s)
    my $FILEHANDLE;
    my $infile_path;
    my $outfile_path_prefix;

    ## Default(s)
    my $index;
    my $index_type;
    my $output_type;

    my $tmpl = {
        FILEHANDLE  => { required => 1, defined => 1, store => \$FILEHANDLE, },
        infile_path => {
            required    => 1,
            defined     => 1,
            strict_type => 1,
            store       => \$infile_path,
        },
        index => {
            default     => 1,
            allow       => [ undef, 0, 1 ],
            strict_type => 1,
            store       => \$index,
        },
        index_type => {
            default     => q{csi},
            allow       => [ undef, qw{ csi tbi } ],
            strict_type => 1,
            store       => \$index_type,
        },
        outfile_path_prefix =>
          { strict_type => 1, store => \$outfile_path_prefix, },
        output_type => {
            default     => q{v},
            allow       => [qw{ b u z v }],
            strict_type => 1,
            store       => \$output_type,
        },
    };

    check( $tmpl, $arg_href, 1 ) or croak q{Could not parse arguments!};

    my $outfile_path;
    my %output_type_ending = (
        b => q{.bcf},
        u => q{.bcf},
        z => q{.vcf.gz},
        v => q{.vcf},
    );

    if ( defined $outfile_path_prefix ) {

        $outfile_path =
          $outfile_path_prefix . $output_type_ending{$output_type};
    }

    say {$FILEHANDLE} q{## Reformat variant calling file};

    bcftools_view(
        {
            infile_path  => $infile_path,
            outfile_path => $outfile_path,
            output_type  => $output_type,
            FILEHANDLE   => $FILEHANDLE,
        }
    );
    say {$FILEHANDLE} $NEWLINE;

    if ($index) {

        say {$FILEHANDLE} q{## Index};

        bcftools_index(
            {
                infile_path => $outfile_path,
                output_type => $index_type,
                FILEHANDLE  => $FILEHANDLE,
            }
        );
        say {$FILEHANDLE} $NEWLINE;
    }
    return;
}

1;
