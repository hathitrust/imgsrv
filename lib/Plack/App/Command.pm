package Plack::App::Command;

use strict; 
use warnings; 

our $VERSION = '0.1';

use Getopt::Long;
use Term::ANSIColor;
use IO::Handle;
use IO::File;
autoflush STDOUT 1;

use URI;

use Plack;
use Plack::TempBuffer; 
use Plack::Util;

my $colors = 1; 
my $output = IO::Handle->new_from_fd(fileno(STDOUT), "w");
my $error = IO::Handle->new_from_fd(fileno(STDERR), "w");
my $headers = 0;
my $do_eat_output = 0;

my $output_filename;

use constant {
    STATUS  => 0,
    HEADERS => 1,
    BODY    => 2
};

$ENV{PSGI_COMMAND} = 1;

my $default_env = {
	HTTP_ACCEPT => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
	HTTP_USER_AGENT => "Plack $Plack::VERSION, CLI $VERSION",
	HTTP_CACHE_CONTROL => 'max-age=0',
	HTTP_ACCEPT_LANGUAGE => 'en-US,en;q=0.8',
	HTTP_ACCEPT_ENCODING => 'gzip,deflate,sdch',
	HTTP_ACCEPT_CHARSET => 'ISO-8859-1,utf-8;q=0.7,*;q=0.3',

    # Client
    REQUEST_METHOD => 'GET',
    SCRIPT_NAME    => '',
    REMOTE_ADDR    => '0.0.0.0',
    REMOTE_USER    => ($ENV{REMOTE_USER} || $ENV{USER} || ''),

    # Server
    SERVER_PROTOCOL => 'HTTP/1.0',
    SERVER_PORT     => 0,
    SERVER_NAME     => 'localhost',

    # PSGI
    'psgi.version'      => [1,1],
    'psgi.errors'       => $error,
    'psgi.multithread'  => Plack::Util::FALSE,
    'psgi.multiprocess' => Plack::Util::TRUE,
    'psgi.run_once'     => Plack::Util::TRUE,
    'psgi.streaming'    => Plack::Util::TRUE, # FALSE?
    'psgi.nonblocking'  => Plack::Util::FALSE,

    %ENV
};

my $env;

sub run {
 	my($self, $path_info, $config, $app) = @_;

	if ( ref $app ne "CODE" ) {
		$app = Plack::Util::load_psgi($app);
	} 

    $env = { %$default_env };
	
	my $options = {};
	my $environment = "deployment";

    GetOptions($options,
        "E=s",
        "o=s",
        "v",
        "n",
        "h",
        "output_filename=s",
        @$config
    );

	if ( exists $options->{E} ) {
		$environment = $options->{E};
        delete $$options{E};
	}

	if ( $options->{v} ) {
		print $env->{HTTP_USER_AGENT}, "\n";
		exit(0);
	}

	if ( $options->{n} ) {
		$colors = 0;
        delete $$options{n};
	}

	if ( $options->{h} ) {
		$headers = 1; 
	}

	my $method = "GET";

	my $request_uri = [""];
    push @$request_uri, $path_info if ( $path_info );
    if ( $$options{action} ) {
        push @$request_uri, $$options{action};
        delete $$options{action};
    }
    if ( $ENV{PSGI_ACTION} ) {
        push @$request_uri, $ENV{PSGI_ACTION};
    }

    foreach my $key ( sort keys %ENV ) {
        next unless ( $key =~ m,X-ENV, );
        $$env{$key} = $ENV{$key};
    }

    ## id really needs to be escaped (e.g. uc2.ark:/13960/t95719k1f)
    ## since v2 is legacy compatible with v1, keep the id parameter
    # if ( $$options{id} ) {
    #     push @$request_uri, $$options{id};
    #     delete $$options{id};
    # }
    $request_uri = join('/', @$request_uri);

	if ( exists $options->{X} ) {
		$method = $options->{X};
        delete $$options{X};
	}

    if ( exists $$options{output_filename} ) {
        # app is writing to this
        $output_filename = $$options{output_filename};
        $output = new IO::File "$output_filename.download", "w" or die "FAIL: $output_filename: $!";
        $colors = 0;
        delete $$options{output_filename};
    }

    # now adjust the parameters
    my @query = ();
    foreach my $param ( keys %$options ) {
        my $values = $$options{$param};
        unless ( ref($values) ) { $values = [ $values ]; }
        foreach my $value ( @$values ) {
            ## escape + to %2B. ARK!
            $value =~ s,\+,%2B,g;
            $value =~ s,;,%3B,g;
            push @query, qq{$param=$value};
        }
    }
    if ( scalar @query ) {
        $request_uri .= '?' . join('&', @query);
    }

    my $url = "http://localhost" . $request_uri;

	if ( $method eq "POST" ) {
		my $data = "";
		while ( <STDIN> ) { chomp; $data .= $_; }

		my $len = length $data; 
		my $buf = new Plack::TempBuffer($len);
		$buf->print($data);

		$env->{CONTENT_LENGTH} = $len;
		$env->{CONTENT_TYPE} = "application/x-www-form-urlencoded"; 
		$env->{'psgi.input'} = $buf->rewind;
	} elsif ( $method eq "GET"  ) {
		$method = "GET";
	} else {
		print STDERR "Only GET and POST methods are supported.\n";
	}

	$env->{environment} = $environment;
 
	my $uri = URI->new($url);

    $env->{REQUEST_METHOD} = $method;
    $env->{REQUEST_URI} = $request_uri;
    $env->{SCRIPT_NAME} = $uri->path; 
    $env->{SCRIPT_NAME} = '' if $env->{SCRIPT_NAME} eq '/';
    $env->{QUERY_STRING} = $uri->query;
    $ENV{HTTP_HOST} = $env->{HTTP_HOST} = $uri->host;
    $env->{PATH_INFO} = $uri->path;
    $env->{'psgi.url_scheme'} = $uri->scheme;

	my $res = Plack::Util::run_app($app, $env);

	if (ref $res eq 'ARRAY') {
		$self->_handle_response($res);
	} elsif (ref $res eq 'CODE') {

        # use B::Deparse ();
        # my $de = B::Deparse->new;
        # print STDERR $de->coderef2text($res) . "\n";


		$res->(sub {
	    		$self->_handle_response($_[0]);
		});
	} else {
		die "Bad response $res";
	}

    $output->close;
    $error->close;

    # rename the filename
    if ( $output_filename && -f "$output_filename.download" ) {
        rename("$output_filename.download", $output_filename) || warn $!;
        return $output_filename;
    }
}

sub _handle_response {
   	my ($self, $res) = @_;

	if ( $headers ) {
		print "\n"; 

		print color "magenta bold" if $colors; 
		print "Request\n"; 
		print "  $env->{REQUEST_METHOD} $env->{REQUEST_URI} $env->{SERVER_PROTOCOL}\n";
		print "\n";
		print color "reset" if $colors;

		print color ( $res->[STATUS] == 200 ? "green bold" : "red" ) if $colors; 
		print "Response\n";
		print "  Status ", $res->[STATUS], " \n";
		print color "reset" if $colors;

		print color "cyan bold" if $colors;
		my %h = ( @{$res->[HEADERS]} );

		print "  $_: $h{$_} \n" foreach keys %h;
		print color "reset" if $colors;

		$output->print(color "reset") if $colors;
		print "\n";
	}

    my $emitter = $res->[STATUS] == 200 ? $output : $error;
    # print STDERR "COMMAND RETURNED : " . $res->[STATUS] . "\n";

	if ( defined $res->[BODY] ) {
        my $cb = sub { $emitter->print(@_); $emitter->flush(); };
        if ( ref $res->[BODY] eq 'ARRAY' ) {
            Plack::Util::foreach($res->[BODY], $cb);
        } else {
            local $/ = \65536 unless ref $/;
            while (defined(my $line = $res->[BODY]->getline)) {
                $cb->($line) if length $line;
            }
            $res->[BODY]->close;
        }
	} else {
        return Plack::Util::inline_object
            write => sub { $emitter->print(@_) },
            close => sub { };
    }
}

1;
__END__

=head1 NAME 

Plack::App::CLI - Command Line Interface to PSGI

=head1 SYNOPIS 


	use Plack::App::CLI; 
	Plack::App::CLI->run(FILENAME || CODEREF);

Run handler using run method accpeting a code reference of the application or .psgi file.

=head1 DESCRIPTION 

Plack::App::CLI is a handler for using psgi application using console. Simply pass options and path including query strings. Also POST is supported. 

=head1 USAGE 

	echo "username=john&password=secret" | ./script.pl -p /form 

Script accepts options and path to process. 
Example above pretty much equals to 

	POST /form HTTP/1.0

	username=john&password=secret	

=head1 FUNCTIONS 

=over 4

=item run 

	Runs the application 

=back 

=head1 OPTIONS 

=over 4 

=item -v 

	prints version

=item -E environment 

	Plack app environment, default deployment

=item -n 

	suppress colored output 

=item -X POST|GET  

	use POST OR GET method (default)  

=item -o file

	print body into file 

=item -H header 

	add header 

=back

=head1 SEE ALSO 

L<PSGI>

L<Plack>

=head1 AUTHOR 

Dalibor Horinek E<lt>dal@horinek.netE<gt>

=head1 LICENSE

Copyright (c) 2012, Dalibor Horinek E<lt>dal@horinek.netE<gt> 

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. See L<perlartistic> for details.

