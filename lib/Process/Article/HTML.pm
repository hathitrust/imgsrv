package Process::Article::HTML;

use strict;

use Plack::Util::Accessor qw(
    file
    mdpItem
    output_filename
    mode
    processor
);

use Process::Globals;
use Process::Text;

use File::Basename qw(basename);

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;

    my $self;
    if (@_ == 1 && ref $_[0] eq 'HASH') {
        $self = bless {%{$_[0]}}, $class;
    } else {
        $self = bless {@_}, $class;
    }

    $self->_initialize();

    $self;
}

sub _initialize {
    my $self = shift;
    unless ( $self->mode ) {
        $self->mode('standalone');
    }
}

sub process {
    my $self = shift;
    my $env = shift;

    my $C = $$env{'psgix.context'};
    my $mdpItem = $C->get_object('MdpItem');
    my $gId = $mdpItem->GetId();

    my $source_filename = $mdpItem->GetFilePathMaybeExtract($self->file);

    my $output_filename = $self->output_filename;

    my $content_type = $mdpItem->GetMarkupLanguage() || qq{application/xml};

    # my $watermark_filename;
    # if ( $self->watermark ) {
    #     $watermark_filename = SRV::Utils::get_watermark_filename($mdpItem);
    # }

    $self->processor(new Process::Text);

    $self->processor->source( filename => $source_filename);
    $self->processor->output( filename => $output_filename );
    $self->processor->format($content_type);
    $self->processor->serialize(0);
    my $output = $self->processor->process();

    # post process the output
    my $method = qq{_process_} . $self->mode;
    $self->$method($mdpItem);

    $self->processor->finish;

    return $output;
}

sub _process_standalone {
    my ( $self, $mdpItem) = @_;

    my $dom = $self->processor->dom;

    # modify the <img> elements
    foreach my $node ( $dom->findnodes("//img") ) {
        my ( $href, $params ) = split(/\?/, $node->getAttribute("src"));
        my $fileid = $mdpItem->GetFileIdByXlinkHref($href);
        $href = qq{/cgi/imgsrv/image/} . $mdpItem->GetId() . q{/} . $fileid;
        if ( $params ) {
            $params =~ s,&,;,g;
            $href .= q{?} . $params;
        }

        $node->setAttribute('src', $href);
    }

    my $map = $$Process::Globals::js_css_map{$self->processor->format};
    my $root = $$map{'__ROOT__'};
    # and the link to the css
    foreach my $node ( $dom->findnodes("//link[\@rel='stylesheet']") ) {
        my $href = $node->getAttribute('href');
        if ( exists $$map{$href} ) {
            $href = qq{$root$$map{$href}};
            $node->setAttribute('href', $href);
        }
    }
}

sub _process_embedded {
    my ( $self, $mdpItem ) = @_;

    my $dom = $self->processor->dom;

    # take the standalone modifications
    $self->_process_standalone($mdpItem);

    # and then add the iframe support to the body
    my $parent = ($dom->findnodes("//body"))[0];

    # my $node;
    # $node = $dom->createElement("script");
    # $node->setAttribute("type", "text/javascript");
    # $node->setAttribute("src", $Process::Globals::jquery_url);
    # $parent->appendChild($node);

    # $node = $dom->createElement("script");
    # $node->setAttribute("type", "text/javascript");
    # $node->setAttribute("src", $Process::Globals::postmessage_url);
    # $parent->appendChild($node);

    # foreach my $script_url ( @{ $Process::Globals::iframe_script_urls } ) {
    #     $node = $dom->createElement("script");
    #     $node->setAttribute("type", "text/javascript");
    #     $node->setAttribute("src", $script_url);
    #     $parent->appendChild($node);
    # }

    $parent = ($dom->findnodes("//html"))[0];
    $parent->setAttribute("class", "embedded");
}

sub _process_static {
    my ( $self, $mdpItem ) = @_;

    my $dom = $self->processor->dom;

    # nothing happens; flat references be flat and 
    # the images can be exported as-is ... except we do rewrite the files

    my $map = $$Process::Globals::js_css_map{$self->processor->format};
    my $root = $$map{'__ROOT__'};
    # and the link to the css
    foreach my $node ( $dom->findnodes("//link[\@rel='stylesheet']") ) {
        my $href = $node->getAttribute('href');
        if ( exists $$map{$href} ) {
            $href = basename(qq{$root$$map{$href}});
            $node->setAttribute('href', $href);
        }
    }

    my $parent = ($dom->findnodes("//html"))[0];
    $parent->setAttribute("class", "static");

}

1;