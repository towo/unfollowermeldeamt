#!/usr/bin/perl
# mails log of people who unfollowed the authenticated user

# Copyright 2012 Tobias Wolter

# MIT licence:
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

use Config::Simple;
use Net::Twitter;
use Mail::Sendmail;
use Encode;
use strict;

# config file
my $rcfile = "$ENV{HOME}/.unfollow-mailerrc";
# config container
my $config;

if (-r $rcfile) {
	$config = new Config::Simple;
	$config->read($rcfile);
	die "Need a source mail address!" unless $config->param('mail.source') =~ m/@/;
	die "Need a target mail address!" unless $config->param('mail.target') =~ m/@/;
} else {
	if (-e $rcfile) {
		die "$0: configuration file «$rcfile» not readable\n";
	} else {
		$config = new Config::Simple('syntax' => 'ini');
		foreach my $variable (qw{oauth.consumer_key oauth.consumer_secret oauth.access_token oauth.access_token_secret mail.target mail.source twitter.follower_ids twitter.last_check}) {
			$config->param($variable, '');
		}
		$config->write($rcfile);
		print "$0: Blank configuration file «$rcfile» created.\n";
		print "    Please edit the file to supply the necessary information.\n";
		print "    You will need to create your own Twitter application;\n";
		print "    this can be done at https://dev.twitter.com/\n";
		exit 0;
	}
}

# fluff

my $mailheader  = "Hello, this is your friendly Twitter monitoring script thingie!\n\nThe following users unfollowed you";
if ($config->param('twitter.last_check')) {
   $mailheader .= " since I was last run on " . $config->param('twitter.last_check');
}
   $mailheader .= ":\n\n";
my $mailfooter  = "Burn in rage as you curse their ancestors!\n\nHave a nice day!\n";

# FIXME: config sanity checks
my $twitter = Net::Twitter->new(
	consumer_key        => $config->param('oauth.consumer_key'),
	consumer_secret     => $config->param('oauth.consumer_secret'),
	access_token        => $config->param('oauth.access_token'),
	access_token_secret => $config->param('oauth.access_token_secret'),
	traits              => [qw/OAuth API::REST/],
);

# FIXME: exception handling
my %seen;
# loops for followers; taken mostly straight from Net::Twitter perldoc
for (my $cursor = -1, my $r; $cursor; $cursor = $r->{next_cursor}) {
	$r = $twitter->followers_ids({ cursor => $cursor });
	foreach (@{$r->{ids}}) {
		$seen{$_} = 1;
	}
}

my @unfollowing_ids;
foreach (@{$config->param('twitter.follower_ids')}) {
	if ($seen{$_} != 1) {
		push(@unfollowing_ids, "$_");
	}
}

my $number_unfollowers = scalar @unfollowing_ids;

# no unfollowers
if ($number_unfollowers == 0) {
	if (-t STDOUT) {
		print "No action required, no unfollowers.\n";
	}
	exit 0;
}

my %unfollowers; my @data;
for (my $i = 0; $i <= int($number_unfollowers/100); $i++) {
	my $start = $i*100;
	my $end = ($i+1)*100-1;
	if ($i == int($number_unfollowers/100)) {
		$end = $number_unfollowers;
	}
	my $package = join(',', @unfollowing_ids[$start .. $end]);
	my $reference = $twitter->lookup_users({user_id => $package});
	push(@data,@{$reference});
}

foreach (@data) {
	$unfollowers{$_->{screen_name}} = $_->{name};
}

my $subject  = "Twitter: ";
   $subject .= ($number_unfollowers == 1) ? "one person " : "$number_unfollowers people ";
   $subject .= "unfollowed you!";

my $identified_unfollowers = scalar(keys(%unfollowers));
my $message  = '';

if ($identified_unfollowers > 0) {
	map { $message .= "  * $unfollowers{$_} ($_)\n" } sort(keys(%unfollowers));
	my $unidentified_unfollowers = $number_unfollowers - $identified_unfollowers;
	if ($unidentified_unfollowers > 0) {
		$message .= "\n";
		$message .= "Additionally, there were $unidentified_unfollowers accounts which could not be identified.\n";
		$message .= "This usually means they were deleted.\n";
	}
	$message .= "\n";
} else {
	$message .= "Sadly, this list is empty because none of them could be identified,";
	$message .= " which means they were probably deleted.\n";
}

my %mail = (
	'To'           => $config->param('mail.target'),
	'From'         => $config->param('mail.source'),
	'Message'      => Encode::encode('utf8',"${mailheader}${message}${mailfooter}"),
	'Subject'      => $subject,
	'Content-Type' => 'text/plain; charset="utf-8"',
);

sendmail(%mail) or die $Mail::Sendmail::error;

my $seen_string = join(',', sort keys %seen);

# write seen users to configuration
$config->param('twitter.follower_ids', $seen_string);

# log last check time
$config->param('twitter.last_check', scalar localtime);
$config->save;
