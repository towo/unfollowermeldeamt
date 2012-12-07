unfollower-mailer
=================

When executed, mails you a summary of your unfollowers since you last ran this program (on the same machine).

Prerequisites
=============

* Perl
* Perl modules:
  * Config::Simple
  * Net::Twitter
  * Mail::Sendmail
  * Encode
  * Try::Tiny

Configuration
=============

Configuration file format is pretty straightforward, `key=value` in `[sections]`.
At first run, a default configuration will be created.

You will need to create a Twitter application on [the Twitter developer page](http://dev.twitter.com). It only needs read-only permissions.

Usage
=====

- Execute for the first time after configured.
- Wait for a while.
- Execute for a second time, ideally after someone unfollowed you. You will get a mail.

Ideally, you'll just dump this in a cronjob and it'll take care of itself.

Licence
=======

MIT licence