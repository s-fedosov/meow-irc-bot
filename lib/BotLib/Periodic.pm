package BotLib::Periodic;

use 5.030; ## no critic (ProhibitImplicitImport)
use strict;
use warnings;

use utf8;
use open                  qw (:std :utf8);
use English               qw ( -no_match_vars );

use JSON::XS              qw (decode_json);
use Log::Any              qw ($log);

use BotLib::Command       qw (PrintMsg);
use BotLib::Conf          qw (LoadConf);
use BotLib::Util          qw (runcmd cleanexpireddata rakedata deletedata);

use version; our $VERSION = qw (1.0);
use Exporter qw (import);
our @EXPORT_OK = qw (PollNotifications CleanExpiredEntries);

local $OUTPUT_AUTOFLUSH = 1;

my $c = LoadConf ();

# Регулярно выгребает нотификашки из базы, запускает нотификашки и пишет уведомления в канальчик с оповещениями
# undef PollNotifications()
sub PollNotifications {
	# Достаём все нотифаи в формате ссылки на хэш
	my $notification  = rakedata ('notifications');
	$log->debug ('[DEBUG] Raked notifications from ' . $c->{db}->{notifications} . ' db');

	my $deadline      = time ();
	my @notifications = sort (keys %{$notification});

	foreach my $timestamp (@notifications) {
		if ($timestamp <= $deadline) {
			$log->debug ("[Debug] Notification timestamp $timestamp <= $deadline, parsing");

			my $alarm = eval { decode_json ($notification->{$timestamp}); };
			deletedata ($c->{db}->{notifications}, $timestamp);

			next unless ($c->{notifications}->{enabled});

			# TODO: Показывать нотификации не только для mac os
			if (defined $alarm) {
				my @cmd = ('afplay', $c->{notifications}->{sound}, '--volume', '6');
				my $res = runcmd (@cmd);
				$#cmd = -1;

				if (defined $alarm->{text} && $alarm->{text} ne '') {
					if (defined $alarm->{title} && $alarm->{title} ne '') {
						my $applescript = sprintf 'display notification "%s" with title "%s"', $alarm->{text}, $alarm->{title};
						@cmd = ('osascript', '-e', "'$applescript'");
					} else {
						my $applescript = sprintf 'display notification "%s" with title "%s"', $alarm->{text}, $alarm->{text};
						@cmd = ('osascript', '-e', "'$applescript'");
					}

					PrintMsg($c->{channels}->{notify}, $alarm->{text});
				} else {
					my $applescript = 'display notification "Настало время придти времени." with title "Напоминание от meow-бота"';
					@cmd = ('osascript', '-e', "'$applescript'");

					PrintMsg($c->{channels}->{notify}, 'Настало время придти времени.');
				}

				$res = runcmd (@cmd);
			} else {
				$log->error (sprintf '[ERROR] Bad notification data in db %s: %s', $c->{db}->{notifications}, $EVAL_ERROR);
			}
		} else {
			$log->debug ("[Debug] Notification timestamp $timestamp > $deadline, skipping");
		}

		# Не выплёвываем все нотификации сразу, если их более одной штуки
		if ($#notifications > -1) {
			sleep 1;
		}
	}

	return;
}

# Вычищает протухшие записи из всех баз
# undef CleanExpiredEntries()
sub CleanExpiredEntries {
	foreach my $db (keys %{$c->{db}}) {
		cleanexpireddata ($db);
	}

	return;
}

1;
