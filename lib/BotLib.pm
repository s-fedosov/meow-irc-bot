package BotLib;

use 5.030; ## no critic (ProhibitImplicitImport)
use strict;
use warnings;
use utf8;
use open            qw (:std :utf8);
use English         qw ( -no_match_vars );

use JSON::XS           ();
use Log::Any        qw ($log);

use BotLib::Conf    qw (LoadConf);
use BotLib::Command qw (Help Notify Todo Sha1b64Str Md5b64Str B64Str Md5Str Sha1Str Sha224Str Sha256Str Sha384Str
                        Sha512Str Crc32Str MurmurhashStr UrlencodeStr IrandNum);
use BotLib::Util    qw (runcmd);

use version; our $VERSION = qw (1.0);
use Exporter qw (import);
our @EXPORT_OK = qw (Command SigHandler SigIntHandler SigTermHandler SigQuitHandler);

local $OUTPUT_AUTOFLUSH = 1;

my $c = LoadConf ();

# Хэндлер, завершающий работу сервиса
# undef SigHandler($signal)
sub SigHandler {
	my $signal = shift;

	if (defined $MAIN::IRC) {                                          ## no critic (Modules::RequireExplicitInclusion)
		$log->info ('[INFO] Disconnect from server');

		if (defined $signal) {
			if ($signal eq 'exit') {
				$MAIN::IRC->send_raw ('QUIT :Quit by user request');   ## no critic (Modules::RequireExplicitInclusion)
			} else {
				$MAIN::IRC->send_raw ("QUIT :Quit by signal $signal"); ## no critic (Modules::RequireExplicitInclusion)
			}
		} else {
			$MAIN::IRC->send_raw ('QUIT :Quit with no reason');        ## no critic (Modules::RequireExplicitInclusion)
		}
	}

	if (defined ($c->{pidfile}) && -e $c->{pidfile}) {
		$log->info ("[INFO] Unlink $c->{pidfile}");
		unlink $c->{pidfile};
	}

	if (defined $signal) {
		if ($signal eq 'exit') {
			$log->info ('[INFO] Exit by user command');
		} else {
			$log->info ("[INFO] Exit by signal $signal");
		}

		exit 0;
	}

	# We should never see this in logs
	$log->info ('[INFO] Stay running because SigHandler called without signal name or reason');

	return;
}

# Хэндлер SigINT
# undef SigIntHandler()
sub SigIntHandler  { SigHandler ('INT');  return; }

# Хэндлер SigTERM
# undef SigTermHandler()
sub SigTermHandler { SigHandler ('TERM'); return; }

# Хэндлер SigQUIT
# undef SigQUITHandler()
sub SigQuitHandler { SigHandler ('QUIT'); return; }

# Парсер команд
# string Command($bot, $chatid, $chattername, $text)
sub Command {
	my $bot         = shift;
	my $chatid      = shift;
	my $chattername = shift;
	my $text        = shift;

	my $reply;
	my $csign = $c->{csign};

	return undef if (length ($text) <= length ($csign));

	$log->debug("Got message from $chattername in $chatid: $text");

	my $cmd = substr $text, length $csign;

	if ($cmd eq 'help' || $cmd eq 'помощь') {
		$reply = Help ();
	} elsif ($cmd eq 'version'  ||  $cmd eq 'ver') {
		$reply = 'Версия нуль.чего-то_там.чего-то_там';
	} elsif ($text eq '=(' || $text eq ':(' || $text eq '):') {
		$reply = ':)';
	} elsif ($text eq '=)' || $text eq ':)' || $text eq '(:') {
		$reply = ':D';
	} elsif ($cmd eq 'ping') {
		$reply = 'pong';
	} elsif ($cmd eq 'cal') {
		my @cmd = qw (cal -Nh3);
		my $res = runcmd (@cmd);

		if ($res->{success}) {
			$reply = $res->{text};
		} else {
			$reply = $res->{err_msg};
		}
	} elsif ($cmd eq 'quit' || $cmd eq 'exit') {
		SigHandler ('exit');
	} elsif ($cmd =~ /^(notify|remind)\s+me\s+after\s+(\d+)\s*(s|seconds|m|minutes|h|hours)\s+(.*)$/) {
		my $amount = $2;
		my $units = $3;
		my $message = $4;
		$reply = Notify ($chatid, $amount, $units, $message);
	} elsif ($cmd =~ /n\s+(\d+)(s|m|h)\s+(.*)$/) {
		my $amount = $1;
		my $units = $2;
		my $message = $3;
		$reply = Notify ($chatid, $amount, $units, $message);
	} elsif ($cmd =~ /^(todo\s*|todo\s+.+)$/) {
		$reply = Todo($cmd);
	} elsif ($cmd =~ /^b64\s(.*)/) {
		$reply = B64Str ($1);
	} elsif ($cmd =~ /^md5\s(.*)/) {
		$reply = Md5Str ($1);
	} elsif ($cmd =~ /^sha1\s(.*)/) {
		$reply = Sha1Str ($1);
	} elsif ($cmd =~ /^sha224\s(.*)/) {
		$reply = Sha224Str ($1);
	} elsif ($cmd =~ /^sha256\s(.*)/) {
		$reply = Sha256Str ($1);
	} elsif ($cmd =~ /^sha384\s(.*)/) {
		$reply = Sha384Str ($1);
	} elsif ($cmd =~ /^sha512\s(.*)/) {
		$reply = Sha512Str ($1);
	} elsif ($cmd =~ /^crc32\s(.*)/) {
		$reply = Crc32Str ($1);
	} elsif ($cmd =~ /^murmurhash\s(.*)/) {
		$reply = MurmurhashStr ($1);
	} elsif ($cmd =~ /^urlencode\s(.*)/) {
		$reply = UrlencodeStr ($1);
	} elsif ($cmd =~ /^rand\s+(.*)\s*/) {
		$reply = IrandNum ($1);
	} elsif ($cmd eq 'unixtime') {
		$reply = time();
	}

	return $reply;
}

1;

# vim: set ft=perl noet ai ts=4 sw=4 sts=4:
