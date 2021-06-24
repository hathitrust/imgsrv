package SRV::SearchUtils;

=head1 NAME

PT::SearchUtils

=head1 DESCRIPTION

This pachage contains the wrapper code to drive item-level search
coupled with dynamic Solr indexing.

=head1 SYNOPSIS

Coding example

=head1 METHODS

=over 8

=cut

use Time::HiRes;
use URI::Escape;


use Utils;
use Utils::Time;
use Utils::Logger;
use Debug::DUtils;
use MdpConfig;

use Db;
use Search::Query;
use Search::Constants;
use SLIP_Utils::Solr;
use Search::Result::SLIP_Raw;
use Search::Result::Page;

use Index_Module;

use Search::Query;

my $HOST = `hostname`; chomp($HOST); $HOST =~ s,\..*$,,;

{
    package SRV::Query;

    use strict;

    use Utils;
    use Debug::DUtils;

    use base qw(Search::Query);

    use SLIP_Utils::Common;

    # ---------------------------------------------------------------------
    sub AFTER_Query_initialize {
    }

    # ---------------------------------------------------------------------
    sub get_Solr_query_string {
        my $self = shift;
        my $C = shift;

        return $self->{'query_string'};
    }

    # ---------------------------------------------------------------------
    sub __format_time {
        my $t = shift;
        my $precision = shift;
        
        return sprintf("%.${precision}f", $t);
    }

    # ---------------------------------------------------------------------
    sub log_query {
        my $self = shift;
        my ($C, $stats_ref, $Solr_url) = @_;
    }
}

# # ---------------------------------------------------------------------

# =item __enable_indexing

# Errors on an id can disable indexing service.  Enable.

# =cut

# # ---------------------------------------------------------------------
# sub __enable_indexing {
#     my ($C, $run) = @_;

#     my $dbh = $C->get_object('Database')->get_DBH($C);
#     Db::update_host_enabled($C, $dbh, $run, $HOST, 1);
#     Db::update_shard_enabled($C, $dbh, $run, 1, 1);
# }

# ---------------------------------------------------------------------

=item __timer

Description

=cut

# ---------------------------------------------------------------------
sub __timer {
    my $start = shift;

    my $elapsed = Time::HiRes::time() - $start;
    return $elapsed;
}

# # ---------------------------------------------------------------------

# =item __index_item_ok

# Description

# =cut

# # ---------------------------------------------------------------------
# sub __index_item_ok {
#     my ($index_state, $data_status, $metadata_status) = @_;

#     my $ok = (
#               (! Search::Constants::indexing_failed($index_state))
#               &&
#               ($data_status == IX_NO_ERROR)
#               &&
#               ($metadata_status == IX_NO_ERROR)
#              );

#     return $ok;
# }

# # ---------------------------------------------------------------------

# =item __build_item_index_fail_msg

# Description

# =cut

# # ---------------------------------------------------------------------
# sub __build_item_index_fail_msg {
#     my ($C, $id, $index_state, $data_status, $metadata_status) = @_;

#     my $msg = qq{\nITEM-LEVEL INDEXING FAIL: id=$id index=$index_state data=$data_status meta=$metadata_status\n};
#     my $hostname = Utils::get_hostname();
#     ($hostname) = ($hostname =~ m,^(.*?)\..*$,);
#     my $when = Utils::Time::iso_Time();
#     $msg .= qq{ host=$hostname at=$when\n};
#     $msg = Carp::longmess($msg);
#     $msg .= qq{\nCGI: } . CGI::self_url();
#     $msg .= qq{\nEnvironment: } . Debug::DUtils::print_env();

#     return $msg;
# }

# # ---------------------------------------------------------------------

# =item maybe_Solr_index_item

# If item is not indexed or has been updated in the repository since
# indexed, index it.

# =cut

# # ---------------------------------------------------------------------
# sub maybe_Solr_index_item {
#     my ($C, $run, $id, $g_stats_ref) = @_;

#     use constant COMMIT_TIMEOUT => 60;

#     my $start_0 = Time::HiRes::time();

#     # Indexed ?
#     my $do_index = 0;

#     my $rs = new Search::Result::SLIP_Raw;
#     my $searcher = SLIP_Utils::Solr::create_shard_Searcher_by_alias($C, 1);
#     my $safe_id = Identifier::get_safe_Solr_id($id);
#     my $query = qq{q=vol_id:$safe_id&start=0&rows=1&fl=timestamp};

#     $rs = $searcher->get_Solr_raw_internal_query_result($C, $query, $rs);
#     $g_stats_ref->{update}{check} = __timer($start_0);

#     my $indexed = $rs->get_num_found();

#     my ($index_state, $data_status, $metadata_status, $stats_ref ) =
#       (IX_INDEXED, IX_NO_ERROR, IX_NO_ERROR, {});

#     if (! $indexed) {
#         __enable_indexing($C, $run);

#         ($index_state, $data_status, $metadata_status, $stats_ref) =
#           Solr_index_one_item($C, $run, $id);

#         SLIP_Utils::Common::merge_stats($C, $g_stats_ref, $stats_ref);

#         if (__index_item_ok($index_state, $data_status, $metadata_status)) {
#             my $indexer = SLIP_Utils::Solr::create_shard_Indexer_by_alias($C, 1);
#             my ($index_state, $commit_stats_ref) = $indexer->commit_updates($C);

#             SLIP_Utils::Common::merge_stats($C, $g_stats_ref, $commit_stats_ref);
#         }
#         else {
#             Utils::Logger::__Log_string($C,
#                                         __build_item_index_fail_msg($C, $id, $index_state, $data_status, $metadata_status),
#                                         'item_indexer_fail_logfile', '___RUN___',
#                                         SLIP_Utils::Common::get_run_number($C->get_object('MdpConfig')));
#         }
#     }

#     $g_stats_ref->{update}{total} = __timer($start_0);

#     return ($index_state, $data_status, $metadata_status, $g_stats_hashref);
# }

sub has_Solr_index_item {
    my ($C, $run, $id, $g_stats_ref) = @_;

    use constant COMMIT_TIMEOUT => 60;

    my $start_0 = Time::HiRes::time();

    # Indexed ?
    my $do_index = 0;

    my $rs = new Search::Result::SLIP_Raw;
    my $searcher = SLIP_Utils::Solr::create_shard_Searcher_by_alias($C, 1);
    my $safe_id = Identifier::get_safe_Solr_id($id);
    my $query = qq{q=vol_id:$safe_id&start=0&rows=1&fl=timestamp};

    $rs = $searcher->get_Solr_raw_internal_query_result($C, $query, $rs);
    $g_stats_ref->{update}{check} = __timer($start_0);

    my $indexed = $rs->get_num_found();
    my $Solr_error = ($rs->get_response_code() ne '200');

    return ($indexed, $Solr_error);
}

# # ---------------------------------------------------------------------

# =item Solr_index_one_item

# Description

# =cut

# # ---------------------------------------------------------------------
# sub Solr_index_one_item {
#     my ($C, $run, $id) = @_;

#     my $dbh = $C->get_object('Database')->get_DBH($C);

#     # The item-level index consists of only a single shard (for now)
#     my $shard = 1;

#     my ($index_state, $data_status, $metadata_status, $stats_ref) =
#       Index_Module::Service_ID($C, $dbh, $run, $shard, $$, $HOST, $id, 1);

#     return ($index_state, $data_status, $metadata_status, $stats_ref);
# }


# # ---------------------------------------------------------------------

# =item isMultiple

# Assumes Solr using unigrams for CJK
# Use isMultipleBigrams if using bigrams for CJK

# True if string will be split into more than one token

# Current cases below

#  This may change when if we change settings on CJKFiltering

# Assumes that we have a string with no spaces!  
# ###Consider using Analysis request handler which would always be correct

# 1   2 or more Han or Hiragana characters
# 2   Combination of any two of these: Han, Hiragana, Katakana Latin Number

# See testIsMultiple.pl in $SDRROOT/pt/scripts

# =cut

# # ---------------------------------------------------------------------
# sub isMultiple {
#     my $q = shift;

#     my $toReturn = 'false';
#     $q =~ s/\s//g;

#     eval {
#         if ($q =~ /\p{Han}|\p{Hiragana}/) {
#             # count Han/Hir
#             my $temp_q = $q;

#             my $Han_count = $temp_q =~ s/\p{Han}//g;
#             # print "q is $q han count is $Han_count\n";

#             $temp_q = $q;
#             my $Hir_count = $temp_q =~ s/\p{Hiragana}//g;
#             if ($Han_count  > 1 || $Hir_count > 1) {
#                 $toReturn = 'true';
#             }
#             else {
#                 # test for 2 different scripts of any of Han, Hiragana, Katakana, Latin
#                 # (do we need totest for numbers?)
#                 $temp_q = $q;
#                 my $Kat_count = $temp_q =~ s/\p{Katakana}//g;
#                 $temp_q = $q;
#                 my $Lat_count = $temp_q =~ s/\p{Latin}//g;
#                 # XXX what about numbers and punctuation that is not
#                 # stripped out could us \p{common} but that includes
#                 # punct that is stripped out for now just include
#                 # numbers
#                 $temp_q = $q;
#                 my $Num_count = $temp_q =~ s/\d//g;
#                 my $total_scripts = 0;

#                 foreach my $count ($Han_count, $Hir_count, $Kat_count, $Lat_count, $Num_count) {
#                     if ($count > 0) {
#                         $total_scripts++;
#                     }
#                 }

#                 if ($total_scripts > 1) {
#                     $toReturn = 'true';
#                 }
#             }
#         }
#     };
#     if ($@) {
#         print STDERR "bad char $@  $_\n";
#     }

#     return $toReturn;
# }

# # ---------------------------------------------------------------------


# =item isMultipleBigrams

# True if string will be split into more than one token
# Assumes Solr using bigrams for CJK

# Current cases below

#  This may change when if we change settings on CJKFiltering

# Assumes that we have a string with no spaces!  
# ###Consider using Analysis request handler which would always be correct

# 1   3 or more Han or Hiragana characters
# 2   Combination of any two of these: Han, Hiragana, Katakana Latin Number

# See testIsMultiple.pl in $SDRROOT/tburtonw.babel (should move to test and rewrite to
# actually use the sub from PT::PIFiller::Search instead of a copy)

# =cut

# # ---------------------------------------------------------------------
# sub isMultipleBigrams {
#     my $q = shift;

#     my $toReturn = 'false';
#     $q =~ s/\s//g;

#     eval {
#         if ($q =~ /\p{Han}|\p{Hiragana}/) {
#             # count Han/Hir
#             my $temp_q = $q;

#             my $Han_count = $temp_q =~ s/\p{Han}//g;
#             # print "q is $q han count is $Han_count\n";

#             $temp_q = $q;
#             my $Hir_count = $temp_q =~ s/\p{Hiragana}//g;
#             if ($Han_count  > 2 || $Hir_count > 2) {
#                 $toReturn = 'true';
#             }
#             else {
#                 # test for 2 of any of Han, Hiragana, Katakana, Latin
#                 # (do we need totest for numbers?)
#                 $temp_q = $q;
#                 my $Kat_count = $temp_q =~ s/\p{Katakana}//g;
#                 $temp_q = $q;
#                 my $Lat_count = $temp_q =~ s/\p{Latin}//g;
#                 # XXX what about numbers and punctuation that is not
#                 # stripped out could us \p{common} but that includes
#                 # punct that is stripped out for now just include
#                 # numbers
#                 $temp_q = $q;
#                 my $Num_count = $temp_q =~ s/\d//g;
#                 my $total_scripts = 0;

#                 foreach my $count ($Han_count, $Hir_count, $Kat_count, $Lat_count, $Num_count) {
#                     if ($count > 0) {
#                         $total_scripts++;
#                     }
#                 }

#                 if ($total_scripts > 1) {
#                     $toReturn = 'true';
#                 }
#             }
#         }
#     };
#     if ($@) {
#         print STDERR "bad char $@  $_\n";
#     }

#     return $toReturn;
# }

# # ---------------------------------------------------------------------

# =item Solr_search_item

# Description

# =cut

# # ---------------------------------------------------------------------
# sub Solr_search_item {
#     my ($C, $id, $g_stats_ref) = @_;

#     my $start_0 = Time::HiRes::time();

#     my $cgi = $C->get_object('CGI');
#     my $config = $C->get_object('MdpConfig');

#     my $q1 = $cgi->param('q1');

#     my $Q = new PT::Query($C, $q1);
#     my $processed_q1 = $Q->get_processed_user_query_string();

#     $C->set_object('Query', $Q);

#     my $q_str;
#     my $parsed_terms_arr_ref;
#     if ($Q->parse_was_valid_boolean_expression()) {
#         $parsed_terms_arr_ref = [$processed_q1];
#         $q_str = $processed_q1;
#     }
#     else {
#         $parsed_terms_arr_ref = __parse_search_terms($C, $processed_q1);
#         $q_str = join(' ', @$parsed_terms_arr_ref);
#     }

#     # Convert user query from xml escaped string to regular characters
#     # and then url encode it so we can send it to Solr in an http
#     # request
#     Utils::remap_cers_to_chars(\$q_str);
#     $q_str = uri_escape_utf8( $q_str );

#     # Solr paging is zero-relative
#     my $start = max($cgi->param('start') - 1, 0);
#     my $rows = $cgi->param('size');

#     my $rs = new Search::Result::Page;
#     $rs->set_auxillary_data('parsed_query_terms', $parsed_terms_arr_ref);

#     # If this is a CJK query containing Han characters and there is
#     # only one string, we need to check to see if the string would be
#     # tokenized into multiple terms
#     my $multi_term  = 'false';
#     if (scalar(@$parsed_terms_arr_ref) > 1) {
#         $multi_term = 'true';
#     }
#     elsif (scalar(@$parsed_terms_arr_ref) == 1) {
#         $multi_term = isMultiple($parsed_terms_arr_ref->[0]);
#     }
#     $rs->set_auxillary_data('is_multiple', $multi_term);

#     if (scalar(@$parsed_terms_arr_ref) > 0) {
#         my $searcher = SLIP_Utils::Solr::create_shard_Searcher_by_alias($C, 1);

#         my $safe_id = Identifier::get_safe_Solr_id($id);
#         my $fls = $config->get('default_Solr_search_fields');

#         # Default to the solrconfig.xml default unless specified on the URL
#         my $op = $cgi->param('ptsop') || 'AND';
#         my $solr_q_op_param = 'q.op=' . uc($op);

#         # highlighting sizes
#         my $snip = $config->get('solr_hl_snippets');
#         my $frag = $config->get('solr_hl_fragsize');

#         my $mdpItem = $C->get_object('MdpItem');
#         if ( $mdpItem->GetItemSubType() eq 'EPUB' ) {
#             $frag = 10000;
#         }

#         # Must wrap query string with outermost parens so that +-
#         # operators are handled as ocr:(-foo +bar) -ocr:foo +ocr:bar
#         my $query = qq{q=ocr:($q_str)&start=$start&rows=$rows&fl=$fls&hl.fragListBuilder=simple&fq=vol_id:$safe_id&hl.snippets=$snip&hl.fragsize=$frag&$solr_q_op_param};

#         if ( 1 && $mdpItem->GetItemSubType() eq 'EPUB' ) {
#             $query .= qq{&hl.tag.pre=[[&hl.tag.post=]]};
#         }

#         $rs = $searcher->get_Solr_raw_internal_query_result($C, $query, $rs);

#         $g_stats_ref->{query}{qtime} = $rs->get_query_time();
#         $g_stats_ref->{query}{num_found} = $rs->get_num_found();
#         $g_stats_ref->{query}{elapsed} = __timer($start_0);
#         $g_stats_ref->{cgi}{elapsed} = __timer($main::realSTART);

#         my $Solr_url = $searcher->get_engine_uri() . '?' . $query;
#         $Solr_url =~ s, ,+,g;

#         my $Q = new PT::Query($C);
#         $Q->log_query($C, $g_stats_ref, $Solr_url);
#     }

#     return $rs;
# }

# ---------------------------------------------------------------------

=item Solr_retrieve_OCR_page

Description

=cut

# ---------------------------------------------------------------------
sub Solr_retrieve_OCR_page {
    my ($C, $id, $seq) = @_;

    my $config = $C->get_object('MdpConfig');
    my $run_config = SLIP_Utils::Common::merge_run_config('imgsrv', $config);
    # Stomp $config in Context object
    $C->set_object('MdpConfig', $run_config);
    my $config = $run_config;

    # maybe_Solr_index_item($C, SLIP_Utils::Common::get_run_number($config), $id);
    my ( $indexed, $solr_error ) = has_Solr_index_item($C, SLIP_Utils::Common::get_run_number($config), $id);
    return \"" unless ( $indexed );

    my $cgi = $C->get_object('CGI');
    my $q1 = $cgi->param('q1');

    my $Q = new SRV::Query($C, $q1);
    my $processed_q1 = $Q->get_processed_user_query_string();

    $C->set_object('Query', $Q);

    my $q_str;
    if ($Q->parse_was_valid_boolean_expression()) {
        $q_str = $processed_q1;
    }
    else {
        my $parsed_terms_arr_ref = __parse_search_terms($C, $processed_q1);
        $q_str = join(' ', @$parsed_terms_arr_ref);
    }

    # decode so the imgsrv query matches pt/search
    utf8::decode($q_str);

    # Convert user query from xml escaped string to regular characters
    # and then url encode it so we can send it to Solr in an http
    # request
    Utils::remap_cers_to_chars(\$q_str);
    $q_str = uri_escape_utf8( $q_str );

    my $rs = new Search::Result::Page;
    my $searcher = SLIP_Utils::Solr::create_shard_Searcher_by_alias($C, 1);
    my $safe_id = Identifier::get_safe_Solr_id($id) . "_$seq";

    # get ocr field as we will get an empty snippet list if the q_str does not match
    my $fls = 'vol_id,id,ocr';
    my $start = 0;
    my $rows = 1;
    # The page to retrieve may not have the q1 match on it so OR it
    # with the id of the page we want.
    my $query = qq{q=ocr:$q_str+OR+id:$safe_id&start=$start&rows=$rows&fl=$fls&hl.fragListBuilder=single&hl.fragsize=10000&fq=id:$safe_id};

    $rs = $searcher->get_Solr_raw_internal_query_result($C, $query, $rs);

    my $Page_result = $rs->get_next_Page_result();
    my $snip_list = $Page_result->{snip_list};
    my $page_OCR_ref = $snip_list->[0];

    if (! $page_OCR_ref) {
        # Use the 'ocr' field w/o highlights
        $page_OCR_ref = $Page_result->{ocr};
    }

    return $page_OCR_ref;
}


# ---------------------------------------------------------------------

=item __get_id_timestamp

Description

=cut

# ---------------------------------------------------------------------
sub __get_id_timestamp {
    my ($C, $id) = @_;

    my $dbh = $C->get_object('Database')->get_DBH($C);
    my ($namespace, $barcode) = split(/\./, $id);

    my $rights_hashref = Db::Select_latest_rights_row($C, $dbh, $namespace, $barcode);

    return $rights_hashref->{time};
}


# ---------------------------------------------------------------------

=item __parse_search_terms

Description

=cut

# ---------------------------------------------------------------------
sub __trim_spaces {
    my $s = shift;
    $s =~ s,^\s*,,; $s =~ s,\s*$,,; return $s;
}

sub __parse_search_terms {
    my ($C, $q) = @_;

    my $parsed_terms_arr_ref = [];

    # yank out quoted terms
    my @quotedTerms = ( $q =~ m,\"(.*?)\",gis );
    $q =~ s,\"(.*?)\",,gis;
    # remove empty strings between quotes
    @quotedTerms = grep( !/^\s*$/, @quotedTerms );
    # remove leading and trailing spaces within quotes
    @quotedTerms = map { __trim_spaces($_) } @quotedTerms;

    # yank out single word terms w/o leading/trailing space
    $q = __trim_spaces($q);
    my @singleWords = split(/\s+/, $q);

    foreach my $sTerm (@singleWords) {
        push(@$parsed_terms_arr_ref, $sTerm);
    }

    foreach my $qTerm (@quotedTerms) {
        push(@$parsed_terms_arr_ref, qq{"$qTerm"});
    }

    if (DEBUG('query') || DEBUG('all')) {
        my $s = join(' ', @$parsed_terms_arr_ref);
        Utils::map_chars_to_cers(\$s, [q{"}, q{'}]) if Debug::DUtils::under_server();;
        DEBUG('query,all',
          sub {
              return qq{<h3>CGI after parsing into separate terms: $s</h3>};
          });
    };

    return $parsed_terms_arr_ref;
}

1;

__END__

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2011 ©, The Regents of The University of Michigan, All Rights Reserved

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject
to the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

=cut
