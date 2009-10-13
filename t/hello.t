use strict;
use Test::More;
use Test::Requires qw( Plack::Loader LWP );
use lib "t/Hello/lib";
use Test::TCP;
use LWP::UserAgent;

use Hello;
Hello->setup_engine('PSGI');

my $app = sub { Hello->run(@_) };

test_tcp(
    client => sub {
        my $port = shift;
        my $ua = LWP::UserAgent->new;
        my $res = $ua->get("http://127.0.0.1:$port/welcome");
        like $res->content, qr/Welcome/;

        $res = $ua->get("http://127.0.0.1:$port/?name=foo");
        is $res->content_type, 'text/plain';
        like $res->content, qr/Hello foo/;

        $res = $ua->post("http://127.0.0.1:$port/", { name => "bar" });
        like $res->content, qr/Hello bar/;
    },
    server => sub {
        my $port = shift;
        Plack::Loader->auto(port => $port)->run($app);
    },
);

done_testing;
