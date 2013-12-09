#!/usr/bin/perl

use strict;
use warnings;
use FindBin qw/$Bin/;
use WWW::Mechanize;
use HTML::TreeBuilder;
use WWW::UserAgent::Random;
use Encode;
use List::MoreUtils 'uniq';
use List::Util 'shuffle';
use Parallel::ForkManager;
use lib 'dbc_api_v4_2_perl';
use DeathByCaptcha::SocketClient;

sub build_ua {
	my ($proxy) = @_;

	my $user_agent = rand_ua("browsers");
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

my $pm = Parallel::ForkManager->new(20);
foreach my $proxy (@proxies) {
	$pm->start() and next; # do the fork

	my $ua = build_ua($proxy);

	while (1) {
		my $url = 'http://toupiao.rarb.cn/list.php?group=31';
		print "# get $url\n";
		my $resp = $ua->get($url);
		unless ($resp->is_success) {
			print $resp->status_line . "\n";
			last;
		}

		my $TO_SHUA = 'FIXME'; # the one you want to go
		my $TO_SHUA_UID = '';

		my %data; my $i = 0;
		my $tree = HTML::TreeBuilder->new_from_content( decode_utf8($ua->content) );
		my @divs = $tree->look_down(_tag => 'div', class => 'listbox');
		foreach my $div (@divs) {
			my $uid = $div->look_down(_tag => 'input', name => 'uid')->attr('value');
			my $code = $div->look_down(_tag => 'font', style => qr'font-weight:700')->as_trimmed_text;
			my $num = $div->look_down(_tag => 'li', style => qr'margin-top:4px')->as_trimmed_text;
			$num =~ s/\D+//g;
			my $name = $div->look_down(_tag => 'img')->attr('title'); $name = encode_utf8($name);

			# print "$uid, $code, $name, $num\n";
			$data{$uid} = {
				uid => $uid,
				code => $code,
				name => $name,
				num => $num,
				i => $i++,
			};
			$TO_SHUA_UID = $uid if $TO_SHUA eq $code;
			print "# NOW GOT $num\n" if $TO_SHUA eq $code;
		}
		$tree = $tree->delete;

		die unless $TO_SHUA_UID ne 'FIXME'; # make sure it works

		## get lowest 23 ppl
		my @uids = sort { $data{$a}{num} <=> $data{$b}{num} } keys %data;
		@uids = splice(@uids, 0, 24);
		# print "LOWEST is " . $data{$uids[0]}{num} . "\n";
		# foreach my $uid (@uids) {
		# 	print "# $uid, $data{$uid}{num}\n";
		# }

		unshift @uids, $TO_SHUA_UID;
		@uids = uniq @uids;
		@uids = splice(@uids, 0, 24) if @uids > 24;
		@uids = sort { $data{$a}{i} <=> $data{$b}{i} } @uids;

		srand();
		my $image_file = "$Bin/" . rand() . '.jpg';
		$resp = $ua->get('http://toupiao.rarb.cn/includes/rand_func.php?rc=' . int(rand(100000)), ':content_file' => $image_file);
		unless ($resp->is_success) {
			print 'Failed to get image: ' . $resp->status_line . "\n";
			next;
		}
		my $client = DeathByCaptcha::SocketClient->new('fayland', $ENV{DeathByCaptcha_PASS});
		my $captcha = $client->decode($image_file, +DeathByCaptcha::Client::DEFAULT_TIMEOUT);
		if (defined $captcha) {
		    print "CAPTCHA " . $captcha->{"captcha"} . " solved: " . $captcha->{"text"} . "\n";
		    unlink($image_file);

		    $ua->back();
		    my $vid = '|' . join('|', @uids);
		    $resp = $ua->post('http://toupiao.rarb.cn/ajax.php',
		    	Content => [
		    		nt => 12996417340 + int(rand(20000)),
		    		user => '',
		    		vid => $vid,
		    		randcode => $captcha->{'text'},
		    		time => time() * 1000 + int(rand(1000)),
		    	]
		    );
		    print "RETURN: " . $resp->content . "\n";
		}

		# sleep 60;
		last;
	}

	$pm->finish();
}

$pm->wait_all_children;

1;