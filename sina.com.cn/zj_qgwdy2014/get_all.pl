#!/usr/bin/perl

use strict;
use warnings;
use FindBin qw/$Bin/;
use LWP::UserAgent;
use JSON;
use Data::Dumper;
use utf8;

my $ua = LWP::UserAgent->new(
    agent => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.9; rv:30.0) Gecko/20100101 Firefox/30.0',
    cookie_jar => {}
);

my @vote_ids;
if (open(my $fh, '<', "$Bin/vote_ids.txt")) {
    while (my $l = <$fh>) {
        $l =~ s/\D+//g;
        push @vote_ids, $l if $l;
    }
    close($fh);
}

my %user;
foreach my $page (1 .. 4) {
    my $url = "http://act.city.sina.com.cn/interface/activity/json_get_user_works.php?callback=jsonp121404957729477&p=" . $page . "&pcount=16&act_id=5729&order=time";
    my $res = $ua->get($url,
        Accept => '*/*',
        'Accept-Language' => 'en-US,en;q=0.5',
        'Accept-Encoding' => 'gzip, deflate',
        'Referer' => 'http://zj.sina.com.cn/zt/news/qgwdy2014/',
    );
    die $res->status_line unless $res->is_success;

    my $c = $res->decoded_content;
    $c =~ s{^\s*jsonp121404957729477\(}{}; $c =~ s{\)$}{};

    my $data = decode_json($c);
    # print Dumper(\$data);
    foreach my $d (@{$data->{data}}) {
        print Dumper(\$d);

        $user{ $d->{id} } = $d->{vote_count};
    }

    sleep 5;
}

my $i = 1; my %pos;
foreach my $u (sort { $user{$b} <=> $user{$a} } keys %user) {
    print "$u -> $user{$u}\n";
    $pos{$u} = $i if grep { $u == $_ } @vote_ids;
    $i++;
}

print "\n\n";
foreach my $vote_id (@vote_ids) {
    print "$vote_id POS: $pos{$vote_id} on $user{$vote_id}\n";
}

1;