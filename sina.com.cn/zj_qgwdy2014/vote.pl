#!/usr/bin/perl

use strict;
use warnings;
use FindBin qw/$Bin/;
use LWP::UserAgent;
use JSON;
use Data::Dumper;
use utf8;
use List::Util 'shuffle';
use Parallel::ForkManager;

$| = 1;

my @vote_ids;
if (open(my $fh, '<', "$Bin/vote_ids.txt")) {
    while (my $l = <$fh>) {
        $l =~ s/\D+//g;
        push @vote_ids, $l if $l;
    }
    close($fh);
}

my $file = "$Bin/proxies.txt";
open(my $fh, '<', $file) or die "Can't open $file: $!";
my @proxies = <$fh>;
close($fh);
@proxies = map { s/^\s+|\s+$//g; $_ } @proxies;
@proxies = shuffle @proxies;

my $pm = Parallel::ForkManager->new(20);
foreach my $proxy (@proxies) {
    $pm->start() and next; # do the fork

    my $ua = LWP::UserAgent->new(
        agent => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.9; rv:30.0) Gecko/20100101 Firefox/30.0',
        cookie_jar => {}
    );
    $ua->proxy(['http', 'https'], 'http://' . $proxy);

    foreach my $vote_id (@vote_ids) {
        # http://act.city.sina.com.cn/interface/activity/json_add_vote.php?id=XXX&format=json&callback=jsonp1404959424188
        my $callback_num = time() * 1000 + int(rand(1000));
        my $url = "http://act.city.sina.com.cn/interface/activity/json_add_vote.php?id=$vote_id&format=json&callback=jsonp$callback_num";
        my $res = $ua->get($url,
            Accept => '*/*',
            'Accept-Language' => 'en-US,en;q=0.5',
            'Accept-Encoding' => 'gzip, deflate',
            'Referer' => 'http://zj.sina.com.cn/zt/news/qgwdy2014/',
        );
        if ($res->decoded_content =~ m{"error":"0"}) {
            print "VOTE FOR $vote_id with $proxy: OK\n";
        } else {
            print "VOTE FOR $vote_id with $proxy: FAIL (" . $res->decoded_content . ")\n";
        }

        sleep 10 + int(rand(60)); # more human
    }

    $pm->finish();
}

$pm->wait_all_children;

1;