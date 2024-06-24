package SRV::Metrics;

use strict;
use parent qw(Plack::Middleware);

use Metrics;
use Plack::Request;
use Time::HiRes qw(time);

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(@_);

  warn("Setting up metrics (in pid $$)");
  $self->{prom} = Metrics->new;
  $self->setup_metrics;

  return $self;
}

sub setup_metrics {
  my $self = shift;
  my $prom = $self->{prom};

  $prom->declare(
    "imgsrv_request_seconds",
    type => "histogram",
    help => "Summary request processing time",
  );

  $prom->declare(
    "imgsrv_prolog_seconds",
    type => "histogram",
    help => "Summary processing time in prolog"
  );

  $prom->declare(
    "mdpitem_get_mdpitem_seconds",
    type => "histogram",
    help => "Summary fetch mdpitem metadata time"
  );

  $prom->declare(
    "imgsrv_srv_image_seconds",
    type => "histogram",
    help => "Summary time spent in SRV::Image::run"
  );

  $prom->declare(
    "imgsrv_process_image_seconds",
    type => "histogram",
    help => "Summary time spent in Process::Image::run"
  );

  $prom->declare(
    "utils_extract_run_seconds",
    type => "histogram",
    help => "Help string for utils_extract_run_seconds"
  );

  $prom->declare(
    "utils_extract_extracted_size_bytes",
    type => "counter",
    help => "Help string for utils_extract_extracted_size_bytes"
  );
}

# Mostly cribbed from SRV::Prolog and the Plack::Middleware info
sub call {
  my ($self, $env) = @_;

  # expose for other parts of the app to set their own metrics
  $env->{'psgix.metrics'} = $self;

  my $start = time();

  my $res = $self->app->($env);

  # track metrics from result
  # track failures?

  $self->response_cb($res, sub { $self->finalize($env, $start, $_[0]) });

}

# These wrappers are likely unnecessary given that the mdp-lib Metrics object is a singleton. 
sub observe {
  my $self = shift;
  $self->{prom}->observe(@_);
}

sub add {
  my $self = shift;
  $self->{prom}->add(@_);
}

sub render {
  my $self = shift;

  # TODO: can we get metrics via getrusage() for all children?

  return [ 200, [ 'Content-Type' => 'text/plain' ], [ $self->{prom}->format ] ];
}

sub finalize {
  my ($self, $env, $start, $res) = @_;

  my $req = Plack::Request->new($env);

  my $response_code = $res->[0];
  my $labels = {
    response_code => $response_code
  };

  $labels->{path_info} = $req->path_info unless $response_code == '404';

  $self->observe("imgsrv_request_seconds", time() - $start, $labels);
}

# counter: cache hits
# counter: cache misses
# counter: bytes read from disk; label: location (cache vs. uncached)

# histogram: seconds per request
# labels: endpoint
# labels: stage

# process collector
# prefix: imgsrv

1;
