package SRV::Volume::Remediated::Bundle;

use strict;
use warnings;

use parent qw( SRV::Volume::Base );

use Plack::Request;
use Plack::Response;
use Plack::Util;

use Plack::Util::Accessor
    @SRV::Volume::Base::accessors,
    qw(
        remediated_item_id
        is_extracted
        content_type
    );

use MdpItem::EMMA;
use File::Basename;

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    
    $self;
}

sub call {
    my ( $self, $env ) = @_;
    my $req = Plack::Request->new($env);

    $self->_fill_params($env);

    $self->_authorize($env);

    if ( $self->restricted ) {
        my $req = Plack::Request->new($env);
        my $res = $req->new_response(403);
        $res->content_type("text/html");
        $res->body(qq{<html><body>Restricted</body></html>});
        return $res->finalize;
    }

    return $self->_stream($env);
}

sub _stream {
    my ( $self, $env ) = @_;

    # return the file
    my $fh;
    my $req = Plack::Request->new($env);
    my $res = $req->new_response(200);

    my $err;
    eval {
        $self->_process_remediated($env);
    };
    $@ =~ /ASSERT_FAIL/ and $err = $@;
    if ( $err =~ m,Invalid document id provided, ) {
        $res->status(404);
        $res->content_type("text/html");
        $res->body(qq{<html><body>Not Found</body></html>});
        return $res->finalize;
    }

    $res->headers($self->_get_response_headers());

    if ( $self->is_extracted ) {
        $fh = new SRV::Utils::File $self->output_filename, ( $self->output_filename =~ m,$SRV::Globals::gMarkerPrefix, );
    } else {
        $fh = new IO::File $self->output_filename;
    }

    if ( $self->tracker ) {
        my $value = $req->cookies->{tracker} || '';
        $res->cookies->{tracker} = {
            value => $value . $self->tracker,
            path => '/',
            expires => time + 24 * 60 * 60,
        };
    }

    $res->body($fh);

    $self->_log($env);
    return $res->finalize;
}

sub _process_remediated {
    my $self = shift;
    my ( $env ) = @_;

    my $C = $$env{'psgix.context'};
    my $mdpItem = $C->get_object('MdpItem');
    my $gId = $mdpItem->GetId();

    my $remediated_item_id = $self->remediated_item_id;
    my $itemFileSystemLocation =
        Identifier::get_item_location($remediated_item_id);

    my $remediatedMdpItem;
    $remediatedMdpItem = MdpItem::EMMA->GetMdpItem($C, $remediated_item_id, $itemFileSystemLocation);

    my @fileIds = $remediatedMdpItem->GetRemediatedFileIds();

    if ( scalar @fileIds > 1 ) {
        # return the zip
        $self->content_type('application/zip');
        $self->output_filename($remediatedMdpItem->Get('zipfile'));
        $self->attachment_filename(basename($self->output_filename));
        $self->is_extracted(0);
    } else {
        my $fileid = $fileIds[0];
        $self->content_type($remediatedMdpItem->GetStoredFileMimeType($fileid));
        my ( $fileName, $filePath ) = $remediatedMdpItem->GetFilePathMaybeExtract($fileid);
        $self->attachment_filename($fileName);
        $self->output_filename($filePath);
        $self->is_extracted(1);
    }

}

sub _get_response_headers {
    my $self = shift;
    my $headers = [ "Content-Type", $self->_content_type ];
    my $filename = $self->attachment_filename;
    my $disposition = qq{attachment; filename=$filename};

    push @$headers, "Content-disposition", $disposition;
    if ( defined $self->output_filename && -f $self->output_filename ) {
        push @$headers, "Content-length", ( -s $self->output_filename );
    }
    return $headers;
}

sub _content_type {
    my $self = shift;
    return $self->content_type;
}

sub _action {
    my $self = shift;
    'remediated';
}

sub _fill_params {
    my ( $self, $env, $args ) = @_;

    my $C = $$env{'psgix.context'};
    my $mdpItem = $C->get_object('MdpItem');

    my $req = Plack::Request->new($env);

    my %params = $self->_possible_params();

    SRV::Utils::parse_env(\%params, [], $req, $args);

    foreach my $param ( keys %params ) {
        $self->$param($params{$param});
    }

    $self->id($mdpItem->GetId());
    $self->handle(SRV::Utils::get_itemhandle($mdpItem));
    $self->attachment(1);
}

sub _possible_params {
    my $self = shift;

    my %params = ();
    $params{remediated_item_id} = undef;
    $params{format} = undef;
    $params{tracker} = undef;

    return %params;
}

sub _authorize {
    my $self = shift;
    my $env = shift;

    $self->restricted(0) unless ( SRV::Utils::under_server() );

    unless ( defined $self->restricted ) {

        my $C = $$env{'psgix.context'};
        my $mdpItem = $C->get_object('MdpItem');
        my $ar = $C->get_object('Access::Rights');
        my $gId = $mdpItem->GetId();

        my $final_access_status = $ar->assert_final_access_status($C, $gId);
        my $download_access_status = $ar->get_remediated_items_access_status($C, $gId);

        my $restricted = ! ( ( $final_access_status eq 'allow' ) && ( $download_access_status eq 'allow' ) );
            
        $self->restricted($restricted);
    }
}


1;