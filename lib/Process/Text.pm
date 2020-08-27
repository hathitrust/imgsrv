package Process::Text;
use feature qw(say);

use strict;
use warnings;
use IPC::Run;
use MIME::Types;
use File::Basename qw(dirname basename fileparse);
use File::stat;
use File::Slurp;

use Data::Dumper;

use XML::LibXML;
use XML::LibXSLT;

use HTML::Entities;

use Scalar::Util;

use Utils;

use Plack::Util::Accessor qw(
    transforms
    format
    serialize
    restricted
    readingOrder
    blank
    missing
    watermark
    dom
    fragment
    logfile );

use Try::Tiny;

use Process::Globals;

use Time::HiRes qw(time);

use utf8;

my $MIME_TO_EXT = {
    'text/plain' => 'txt',
    'text/html' => 'html',
    'text/xhtml'  => 'xhtml',
    'text/xml'  => 'xml',
};

my $EXT_TO_MIME = { map { $$MIME_TO_EXT{$_} => $_ } keys %$MIME_TO_EXT };

sub _b {
    my ( $msg, $t0 ) = @_;
    say STDERR $msg, " : ", ( time - $t0 );
}

sub new {
    my $class = shift;
    my $options = shift || {};
    $$options{source} = $$options{source} || {};
    $$options{output} = $$options{output} || {};
    $$options{steps} = [];
    my $self = bless $options, $class;

    # defaults
    $self->serialize($$options{serialize} || 1);
    $self->transforms($$options{transforms} || []);
    $self;
}

sub source {
    my $self = shift;
    my $hash = $$self{source};
    if ( scalar @_ ) {
        my $args = { @_ };
        $self->_merge($hash, $args);
        $self->_get_file_info($hash);
    }
    $hash;
}

sub output {
    my $self = shift;
    my $hash = $$self{output};
    if ( scalar @_ ) {
        my $args = { @_ };
        $self->_merge($hash, $args);
        $self->_get_file_info($hash, 0);
    }
    $hash;
}

sub process {
    my $self = shift;

    # does the source exist?
    $self->_process_source();

    # $self->_process_output();

    $self->_process_transforms();

    # run all steps
    $self->_run();

    # return output hash
    $self->output;

}

sub add_transform {
    my $self = shift;
    my ( $transform, $params ) = @_;
    unless ( ref($self->transforms) ) {
        $self->transforms([]);
        $$self{params} = $$self{xparams} = {};
    }
    $$self{params}{$transform} = $params if ( ref($params) && $transform =~ m,\.xsl, );
    push @{ $self->transforms }, $transform;
}

# STEPS
sub _add_step {
    my $self = shift;
    my $step = shift;
    push @{ $$self{steps} }, $step;
}

sub _process_transforms {
    my $self = shift;
    foreach my $transform ( @{ $$Process::Globals::transforms{$self->format} }, @{ $self->transforms } ) {
        if ( ! ref($transform) && $transform =~ m,\.xsl, ) {
            # stylesheet
            my $style_doc = XML::LibXML->load_xml(location => $transform);
            my $stylesheet = $self->xslt->parse_stylesheet($style_doc);
            $$self{xparams}{$stylesheet} = $$self{params}{$transform} if ( ref($$self{params} ));

            # for now setting dir=auto
            # if ( $self->readingOrder eq 'right-to-left' ) {
            #     $$self{xparams}{$stylesheet} = {} unless ( ref( $$self{xparams}{$stylesheet} ));
            #     $$self{xparams}{$stylesheet}{dir} = q{'rtl'};
            # }
            $self->_add_step($stylesheet);
        } else {
            # reference to a callable
            $self->_add_step($transform);
        }
    }
}

sub _run {
    my $self = shift;
    my $t0 = time();

    # OK, here we go
    my $contents = $self->dom;
    foreach my $step ( @{ $$self{steps} } ) {
        if ( Scalar::Util::blessed($step) && $step->can('transform') ) {
            # can we add some parameters
            my $params = ref ($$self{xparams}{$step}) ? $$self{xparams}{$step} : {};
            my $tmp = $step->transform($contents, %$params);
            $contents = $tmp;
        } elsif ( ref($step) eq 'CODE' ) {
            # operate on the dom?
            $step->($contents);
        }
    }
    $self->dom($contents);

    # if ( $self->source->{mimetype} =~ 'text/plain' && ! scalar @{ $$self{steps} } ) {
    #     # just return the <div>
    #     $contents = ($contents->findnodes(qq{//body/div}))[0];
    # }

    unless ( $self->serialize ) {
        return;
    }

    $self->finish;

}

sub to_xml {
    my $self = shift;
    my $contents = $$self{dom};
    if ( $self->fragment ) {
        $contents = ($contents->findnodes(qq{//body/div}))[0];
    }
    if ( ref($contents) ) {
        $contents = $contents->toString();
    } else {
        # there's nothing here, so...
        $contents = q{<div></div>};
    }
    # chuck the doctype
    $contents =~ s,^<\?xml version="1.0" encoding="UTF-8"\?>\n,,sm;
    $contents =~ s,^<!DOCTYPE[^>]+>\n,,s;
    if ( utf8::valid($contents) && ! utf8::is_utf8($contents) ) {
        # I ... don't understand any of this
        utf8::upgrade($contents);
    }
    $self->output->{contents} = $contents;
}

sub finish {
    my $self = shift;
    $self->to_xml;
    write_file($self->output->{filename}, $self->output->{contents}) if ( $self->output->{filename} );
}

# EXTRACTION

sub _process_source {
    my $self = shift;
    my $mimetype = $self->source->{mimetype};
    my $filename = $self->source->{filename};

    if ( $self->blank ) {
        # generate blank page
        $self->_load_blank();
    } elsif ( $self->restricted ) {
        # generate restricted message
        $self->_load_restricted();
    } elsif ( $self->missing ) {
        $self->_load_missing();
    } elsif ( $mimetype eq 'text/plain' ) {
        $self->_load_text_plain();
    } elsif ( $mimetype eq 'text/html' ) {
        $self->_load_text_html();
    } elsif ( $mimetype eq 'application/xml' ) {
        $self->_load_text_xml();
    }
}

sub _process_output {
    my $self = shift;
    my $mimetype = $self->output->{mimetype};
}

sub _load_text_plain {
    my $self = shift;
    my $lines = Utils::read_file($self->source->{filename});
    $self->_parse_text_plain($lines);
}

sub _load_missing {
    my $self = shift;
    my $text = "PAGE NOT AVAILABLE";
    $self->_parse_text_plain(\$text, 'missing_page');
}

sub _load_blank {
    my $self = shift;
    my $text = "";
    $self->_parse_text_plain(\$text, 'blank_page');
}

sub _load_restricted {
    my $self = shift;
    my $text = "RESTRICTED";
    $self->_parse_text_plain(\$text, 'restricted_page');
}

sub _parse_text_plain {
    my $self = shift;
    my ( $lines, $class ) = @_;
    my @tmp = ();
    $class = $class || '';
    eval {
        Utils::remove_invalid_xml_chars($lines);
    };
    if ( my $err = $@ ) {
        $lines = \q{PAGE NOT AVAILABLE}; $class = 'missing_page';
        SRV::Utils::log_string('error', [['error',$err],['filename',$self->source->{filename}]]);
    }
    foreach my $line ( split(/\n/, $$lines) ) {
        # $line =~ s,<,&lt;,g;
        $line = encode_entities($line);
        push @tmp, q{<span>} . $line . q{</span>};
    }
    my $html = qq{<div class="ocr_page $class">} . join("\n<br />\n", @tmp) . q{</div>};
    $self->dom($self->_parse_html_string($html));
    $self->format('text/plain');
}

sub _load_text_html {
    my $self = shift;
    my $tmp = [ File::Slurp::read_file($self->source->{filename}, binmode => ':utf8') ];
    unless ( scalar @$tmp ) {
        # file had no lines
        $tmp = [ '<html><body></body></html>' ];
    }
    if ( $$tmp[0] =~ m,DOCTYPE, ) {
        # obliterate
        shift @$tmp;
    }
    $tmp = join('', @$tmp);
    $tmp =~ s,&([^;\s]+);,__AMP__${1}__SEMI__,gsm;
    $tmp =~ s,&,&amp;,gsm;
    $tmp =~ s,__AMP__,&,gsm;
    $tmp =~ s,__SEMI__,;,gsm;
    $tmp =~ s,<>,&lt;&gt;,gsm;
    $tmp =~ s,<([^<>]*?)<,&lt;$1<,gsm;

    $self->dom($self->_parse_html_string($tmp));
    my $format = $self->dom->findvalue(q{//meta[@name='ocr-system']/@content});
    if ( $format =~ m,ABBY,i || $format =~ m,Tesseract,i ) {
        $self->format("text/abby+html");
    } else {
        $self->format("text/html");
    }
}

sub _load_text_xml {
    my $self = shift;

    my $t0 = time;

    open my $fh, '<', $self->source->{filename}; binmode $fh;
    my $line = <$fh>;
    $line = <$fh> if ( $line =~ m,<\?xml version, );
    seek $fh, 0, 0;
    $self->dom(XML::LibXML->load_xml(IO => $fh, load_ext_dtd => 0));

    unless ( $self->format ) {
        $self->format('application/xml');
        # print STDERR "LOAD XML: $line\n";
        if ( $line =~ m,DOCTYPE, ) {
            # JATS will likely be handled by ArticleHandler to include version
            if ( $line =~ m,article PUBLIC '-//NLM//DTD Journal Publishing DTD, ) {
                $self->format('application/jats+xml');
            } elsif ( $line =~ m,DjVuXML, ) {
                $self->format('application/djvu+xml');
            }
        } else {
            foreach my $tuple ( ["alto", "alto"], [ "DjVuXML", "djvu"] ) {
                # my $xpc = XML::LibXML::XPathContext->new($self->dom->documentElement);
                # if ( my $xmlns_uri = $self->dom->documentElement->getAttribute('xmlns') ) {
                #     $xpc->registerNs("", $xmlns_uri);
                # }
                # # my $check = $self->dom->findnodes($$tuple[0]);
                # my $check = $xpc->findnodes($$tuple[0]);
                # print STDERR "XML CHECK: $$tuple[0] : " . $self->dom->documentElement->nodeName . "\n";

                if ( $self->dom->documentElement->nodeName eq $$tuple[0] ) {
                    $self->format('application/' . $$tuple[1] . "+xml"); last;
                }

                # if ( scalar @$check ) { $self->format('application/' . $$tuple[1] . "+xml"); last; };
            }

            # if ( $self->format() eq 'application/alto+xml' ) {
            #     # check that this has the namespace
            #     my $node =  $self->dom->documentElement;
            #     unless ( $node->getAttribute('xmlns') || $node->getAttribute('xmlns:alto') ) {
            #         print STDERR "AHOY SHOULD BE SETTING SOMETHING\n";
            #         $node->setAttribute('xmlns', 'http://www.loc.gov/standards/alto/ns-v2#');
            #     }
            # }
        }
    }

}


# UTILITY

sub _merge {
    my $self = shift;
    my $hash = shift;
    my $new = shift;
    foreach my $key ( keys %$new ) {
        $$hash{$key} = $$new{$key};
    }
}

sub _get_file_info {
    my $self = shift;
    my $hash = shift;
    my $do_get_metadata = scalar @_ ? shift : 1;
    return unless ( $$hash{filename} );
    my $mime_data = MIME::Types->new->mimeTypeOf($$hash{filename});
    my @suffixes = map(".$_", @{$$mime_data{MT_extensions}});
    my ( $basename, $pathname, $suffix) = fileparse($$hash{filename}, @suffixes );
    $$hash{basename} = $basename;
    $$hash{pathname} = $pathname;
    $$hash{suffix} = $suffix;
    $$hash{mimetype} = $$mime_data{MT_type} unless ( $$hash{mimetype} );
}

sub _parse_html_string {
    my $self = shift;
    my ( $html ) = @_;
    $self->dom(XML::LibXML->load_html(string => $html, recover => 1));
}

sub xslt {
    my $self = shift;
    unless ( ref($$self{_xslt}) ) {
        $$self{_xslt} = XML::LibXSLT->new();
    }
    return $$self{_xslt};
}

1;
