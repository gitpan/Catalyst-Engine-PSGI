#line 1
package Test::SharedFork;
use strict;
use warnings;
our $VERSION = '0.05';
use Test::Builder;
use Test::SharedFork::Scalar;
use Test::SharedFork::Array;
use Test::SharedFork::Store;
use Storable ();
use File::Temp ();
use Fcntl ':flock';

our $TEST;
my $tmpnam;
my $STORE;
our $MODE = 'DEFAULT';
BEGIN {
    $TEST ||= Test::Builder->new();

    $tmpnam ||= File::Temp::tmpnam();

    my $store = Test::SharedFork::Store->new($tmpnam);
    $store->lock_cb(sub {
        $store->initialize();
    }, LOCK_EX);
    undef $store;

    no strict 'refs';
    no warnings 'redefine';
    for my $name (qw/ok skip todo_skip current_test/) {
        my $cur = *{"Test::Builder::${name}"}{CODE};
        *{"Test::Builder::${name}"} = sub {
            my @args = @_;
            if ($STORE) {
                $STORE->lock_cb(sub {
                    $cur->(@args);
                });
            } else {
                $cur->(@args);
            }
        };
    };
}

my @CLEANUPME;
sub parent {
    my $store = _setup();
    $STORE = $store;
    push @CLEANUPME, $tmpnam;
    $MODE = 'PARENT';
}

sub child {
    # And musuka said: 'ラピュタは滅びぬ！何度でもよみがえるさ！'
    # (Quote from 'LAPUTA: Castle in he Sky')
    $TEST->no_ending(1);

    $MODE = 'CHILD';
    $STORE = _setup();
}

sub _setup {
    my $store = Test::SharedFork::Store->new($tmpnam);
    tie $TEST->{Curr_Test}, 'Test::SharedFork::Scalar', 0, $store;
    tie @{$TEST->{Test_Results}}, 'Test::SharedFork::Array', $store;

    return $store;
}

sub fork {
    my $self = shift;

    my $pid = fork();
    if ($pid == 0) {
        child();
        return $pid;
    } elsif ($pid > 0) {
        parent();
        return $pid;
    } else {
        return $pid; # error
    }
}

END {
    undef $STORE;
    if ($MODE eq 'PARENT') {
        unlink $_ for @CLEANUPME;
    }
}

1;
__END__

#line 161
