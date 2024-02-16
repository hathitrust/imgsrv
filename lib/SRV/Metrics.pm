package SRV::Metrics;

use strict;
use parent qw(Plack::Middleware);

use Net::Prometheus;
use Plack::Request;
use Time::HiRes qw(time);

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(@_);

  $self->{prometheus} = Net::Prometheus->new();
  $self->{metrics_app} = $self->{prometheus}->psgi_app();
  $self->setup_metrics;

  return $self;
}

sub setup_metrics {
  my $self = shift;
  my $prom = $self->{prometheus};
  my $metrics = {};

  warn("setting up metrics");

  $prom->register(Net::Prometheus::ProcessCollector->new());
  $metrics->{requests} = $prom->new_counter(
    name => "imgsrv_requests",
    help => "number of handled requests",
    labels => ['path_info','response_code']
  );

  $metrics->{request_time} = $prom->new_histogram(
    name => "imgsrv_request_seconds",
    help => "Summary request processing time",
    labels => ['path_info','response_code']
  );

  $self->{metrics} = $metrics;
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

sub call_app {
  # TODO: Any cleaner way to do this?
  my ($self, $env) = @_;

  return &{$self->{metrics_app}}($env);
}

sub finalize {
  my ($self, $env, $start, $res) = @_;

  my $req = Plack::Request->new($env);

  my $response_code = $res->[0];
  my $labels = {
    response_code => $response_code
  };

  $labels->{path_info} = $req->path_info unless $response_code == '404';
  print "LABELS: \n";
  use Data::Dumper;
  print Dumper($labels);

  $self->{metrics}{request_time}->observe($labels, time() - $start);
  $self->{metrics}{requests}->inc( $labels );
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
