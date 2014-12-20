#!/usr/bin/perl

use strict;
use warnings;
use FindBin qw/$Bin/;
use WWW::Mechanize;
use HTML::TreeBuilder;
use Encode;
use List::Util 'shuffle';
use HTTP::Request;
use URI::Escape;

$| = 1;

my @names = qw/林启功 陈文 张可 李来来 林易 陈国庆 鲁文文 夏雪 陈琴 李康 钱勇 宋雪 余瑞金 葛天 黄章 宋楚瑜 张天 叶天华 赵冠宇 赵可可 林锦楠 夏天 张宇 陈学冬 方冰冰 范伟 方文山 周国庆 王铮 戎凯旋 步铮 杨松 秦霜 慕容情 叶文 林铁 章丘 夏夏 文章 洛离/;

my $TO_SHUA_UID = $ENV{SHUAPIAO_OID} or die "ENV SHUAPIAO_OID is required.";

sub build_ua {
	my ($proxy) = @_;

	my $user_agent = 'Mozilla/5.0 (iPhone; CPU iPhone OS 8_0 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Mobile/12A365 MicroMessenger/5.4.1 NetType/WIFI';
	$user_agent = 'Mozilla/5.0 (Linux; U; Android 4.1.1; zh-cn; LA-Q1 Build/JRO03C) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30 MicroMessenger/4.5.1.261' if int(rand(100)) % 2;
	my $ua = WWW::Mechanize->new(
		agent => $user_agent,
		stack_depth => 1,
		autocheck => 0,
		cookie_jar => {}
	);

	$ua->proxy(['http', 'https'], 'http://' . $proxy);

	return $ua;
}

my $file = "$Bin/proxies.txt";
open(my $fh, '<', $file) or die "Can't open $file: $!";
my @proxies = <$fh>;
close($fh);
@proxies = map { s/^\s+|\s+$//g; $_ } @proxies;
@proxies = shuffle @proxies;

foreach my $proxy (@proxies) {
	my $ua = build_ua($proxy);

	my $url = 'http://115.236.32.180/tpxt/index.php/vote-vote?id=3';
	print "# [$proxy] get $url\n";
	my $resp = $ua->get($url);
	unless ($resp->is_success) {
		print $resp->status_line . "\n";
		last;
	}

	my $tree = HTML::TreeBuilder->new_from_content( decode_utf8($ua->content) );
	my @oids = $tree->look_down(_tag => 'input', name => 'oid[]');
	@oids = map { $_->attr('value') } @oids;
	$tree = $tree->delete;

	die $resp->decoded_content unless @oids;

	srand();
	@oids = shuffle @oids;
	@oids = splice(@oids, 0, 17 + int(rand(5)));
	unless (grep { $_ eq $TO_SHUA_UID } @oids) {
		pop @oids;
		push @oids, $TO_SHUA_UID;
	}

	my $name = encode('gbk', decode_utf8($names[int(rand(scalar(@names)))]));
	my $number = sprintf('%08d', int(rand(99999)));
	my $i = int(rand(10));
	my $phone = '13' . $i . $number;

	my $req = HTTP::Request->new(POST => 'http://115.236.32.180/tpxt/index.php/vote-vote');
	my $content = 'vid=3&multi=34&min=17&';
	$content .= 'oid%5B%5D=' . $_ . '&' foreach (@oids);
	$content .= "username=" . uri_escape($name) . "&phone=$phone&id=3";
	$req->content($content);
	$req->header('Content-Length' => length $content);
	$req->header('Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8');
	$req->header('Content-Type' => 'application/x-www-form-urlencoded');

	$resp = $ua->request($req);

	if ($resp->decoded_content =~ m{<a id="forward" href="http://115.236.32.180/tou}) {
		print "[OK]\n";
	} else {
		# print Dumper(\$resp); use Data::Dumper;
		print $resp->decoded_content;
	}

	sleep 10;
}

1;