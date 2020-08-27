package Process::Article::PDF;

use parent qw( Process::Article::Base );

use Plack::Util::Accessor qw(
    output_fh
    engine
);

use Process::Globals;
use IO::File;
use File::Copy qw(copy);

sub _initialize {
    my $self = shift;
    $self->SUPER::_initialize(@_);
    unless ( $self->engine ) {
        $self->engine('wkhtmltopdf');
    }
}

sub process {
    my $self = shift;
    my $env = shift;

    # will need to so something different for status
    my $do_rename = 0;
    unless ( ref $self->output_filename ) {
        $self->output_fh(new IO::File $self->output_filename . ".download", "w");
        $do_rename = 1;
    } else {
        $self->output_fh($self->output_filename);
    }

    # # do we have an existing PDF?
    # if ( my $fileid = $self->_get_alternate() ) {
    #     print STDERR "HAVE ALTERNATIVE : $fileid : ", $self->output_filename, "\n";
    #     # extract it to output_filename...?
    #     my $alt_filename = $self->mdpItem->GetFilePathMaybeExtract($fileid);
    #     copy($alt_filename, $self->output_fh);
    # } else {
    # }

    my $packager = Process::Article::PDF::Packager->new(tmpdir => $self->working_path);
    $self->gather_files($env, $packager);
    $self->generate_pdf;
    $self->updater->finish();

    if ( $do_rename ) {
        rename($self->output_filename . ".download", $self->output_filename);
    }

    return {
        filename => $self->output_filename,
        mimetype => 'application/pdf',
    }
}

sub generate_pdf {
    my $self = shift;
    my $method = q{_run_engine_} . $self->engine;
    $self->$method();
}

sub _run_engine_wkhtmltopdf {
    my $self = shift;
    chdir($self->working_path);

    my $pdf_filename = $self->output_filename;
    my @cmd = ($Process::Globals::wkhtmltopdf, "-s", "Letter", "toc", @{ $self->html_filenames });
    my @args;
    # wkhtmltopdf invoked differently whether we're streaming or not
    if ( ref $self->output_filename ) {
        push @cmd, "-";
        my $sub = sub {
            $self->output_fh->print(@_);
        };
        push @args, \@cmd, ">", $sub;
    } else {
        push @cmd, $self->output_filename;
        push @args, \@cmd;
    }
    IPC::Run::run @args;
}

package Process::Article::PDF::Packager;

use File::Copy qw(copy);

use Plack::Util::Accessor qw(tmpdir);

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;

    my $self;
    if (@_ == 1 && ref $_[0] eq 'HASH') {
        $self = bless {%{$_[0]}}, $class;
    } else {
        $self = bless {@_}, $class;
    }

    $self;
}

sub copy_xhtml {
    my $self = shift;
    my ( $src_filename, $filename, %opts ) = @_;
    my $tmpdir = $self->tmpdir;
    return if ( $src_filename eq "$tmpdir/$filename" );
    copy($src_filename, "$tmpdir/$filename");
}

sub copy_stylesheet {
    my ($self, $src_filename, $filename) = @_;
    my $tmpdir = $self->tmpdir;
    copy($src_filename, "$tmpdir/$filename");
}

sub copy_image {
    my ($self, $src_filename, $filename, $type) = @_;
    my $tmpdir = $self->tmpdir;
    copy($src_filename, "$tmpdir/$filename");
}

sub copy_file {
    my ($self, $src_filename, $filename, $type) = @_;
    my $tmpdir = $self->tmpdir;
    print STDERR "COPYING : $src_filename > $tmpdir/$filename\n";
    copy($src_filename, "$tmpdir/$filename");
}

sub add_navpoint {
    # NOOP
}

1;