package BotLib::Command;
# Парсит команды

use 5.030; ## no critic (ProhibitImplicitImport)
use strict;
use warnings;
use utf8;
use open         qw (:std :utf8);
use English      qw ( -no_match_vars );

use JSON::XS     qw (encode_json);
use Log::Any     qw ($log);

use BotLib::Conf qw (LoadConf);
use BotLib::Util qw (storedata rakedata deletedata timems utf2md5hex utf2sha1hex utf2sha224hex utf2sha256hex
	                 utf2sha384hex utf2sha512hex utf2crc32hex utf2murmurhash urlencode irandom);

use version; our $VERSION = qw (1.0);
use Exporter qw (import);
our @EXPORT_OK = qw (Help Notify DelayedNotify PrintMsg Todo Sha1b64Str Md5b64Str B64Str Md5Str Sha1Str Sha224Str
                     Sha256Str Sha384Str Sha512Str Crc32Str MurmurhashStr UrlencodeStr IrandNum);

local $OUTPUT_AUTOFLUSH = 1;

my $c = LoadConf();

# Возвращает список возможных команд
# $text Help()
sub Help {
	my $text = '';
	my $csign = $c->{csign};
	$text .= "${csign}help                       - это сообщение\n";
	$text .= "${csign}ping                       - попинговать бота\n";
	$text .= "${csign}ver                        - написать что-то про версию ПО\n";
	$text .= "${csign}cal                        - календарик\n";
	$text .= "${csign}exit                       - завершить работу бота\n";
	$text .= "${csign}quit                       - завершить работу бота\n";
	$text .= "${csign}notify me after N [s|m|h]  - одноразовая напоминалка через desktop notification\n";
	$text .= "${csign}n N[s|m|h] message         - одноразовая напоминалка через desktop notification\n";
	$text .= "${csign}todo                       - выводит списк запланированных дел\n";
	$text .= "${csign}todo -d N                  - удаляет из списка запланированных дел дело N\n";
	$text .= "${csign}todo ДЕЛО                  - добавляет в списк запланированных дел ДЕЛО\n";
	$text .= "${csign}sha1 STR                   - выводит sha1sum для STR\n";
	$text .= "${csign}sha224 STR                 - выводит sha224sum для STR\n";
	$text .= "${csign}sha256 STR                 - выводит sha256sum для STR\n";
	$text .= "${csign}sha384 STR                 - выводит sha384sum для STR\n";
	$text .= "${csign}sha512 STR                 - выводит sha512sum для STR\n";
	$text .= "${csign}crc32 STR                  - выводит crc32 для STR\n";
	$text .= "${csign}md5 STR                    - выводит md5sum для STR\n";
	$text .= "${csign}murmurhash STR             - выводит murmur hash для STR\n";
	$text .= "${csign}b64 STR                    - выводит base64 для STR\n";
	$text .= "${csign}urlencode STR              - кодирует STR по urlencode\n";
	$text .= "${csign}rand N                     - выдаёт рандомное целое число от 0 до указанного\n";
	$text .= "${csign}unixtime                   - выдаёт текущее время в формате unix timestamp (секунды с 1 янв 1970)\n";

	return $text;
}

# Одноразовая напоминалка. Сохраняет сообщение в базу notifications и отправляет его в delayed notifications.
# Возвращает либо строку-подтверждение, либо подсказку как пользоваться командой.
# $string Notify($chatid, $amount, $units, $message)
sub Notify {
	my $chatid  = shift;
	my $amount  = shift;
	my $units   = shift;
	my $message = shift;

	if (defined $units) {
		if ($units eq 'm' || $units eq 'minute' || $units eq 'minutes') {
			$amount = eval { $amount * 60 };

			unless (defined $units) {
				return sprintf ('Usage: %s NUM [s|seconds|m|minutes|h|hours]', $units);
			}
		} elsif ($units eq 'h' || $units eq 'hour' || $units eq 'hours') {
			$amount = eval { $amount * 60 * 60 };

			unless (defined $units) {
				return sprintf ('Usage: %s NUM [s|seconds|m|minutes|h|hours]', $units);
			}
		} elsif ($units eq 's' || $units eq 'second' || $units eq 'seconds') {
			$amount = eval { $amount + 0 };

			unless (defined $units) {
				return sprintf ('Usage: %s NUM [s|seconds|m|minutes|h|hours]', $units);
			}
		}
	} else {
		$amount = eval { $amount + 0 };

		unless (defined $units) {
			return sprintf ('Usage: %s NUM [s|seconds|m|minutes|h|hours]', $units);
		}
	}

	my $timestamp = time () + $amount;
	my $msg->{title} = 'Meow-bot notification';
	my $json;

	if (defined $message && $message ne '') {
		$msg->{text} = $message;
	} else {
		$msg->{text} = 'Напоминалка!';
	}

	$json = encode_json $msg;
	storedata ($c->{db}->{notifications}, $timestamp, $json, $c->{notifications}->{retention_days});
	DelayedNotify ($c->{channels}->{notify}, $msg->{text});

	return sprintf 'Notification will be sent after %d seconds', $amount;
}

# Пишет сообщение в чятик и складывает в БД, чтобы позже показать юзеру, когда он появится в чятике
# undef PrinfMsgForUser($userid, $chatid, $message)
sub DelayedNotify {
	my $channel = shift;
	my $message = shift;

	my $timestamp = timems ();
	my $data;
	$data->{message}         = $message;
	$data->{channel}         = $channel;
	$data->{timestamp}       = $timestamp;
	$data->{expiration_time} = $c->{delayed_notifications}->{retention_days} * 24 * 60 * 60 * 1000 + $timestamp;
	$data->{retention_days}  = $c->{delayed_notifications}->{retention_days} ;

	# Достанем список тех, кто есть в канальчике notify, им на джоине показывать сообщение не надо
	my @users = keys %{$MAIN::IRC->channel_list->{$c->{channels}->{notify}}}; ## no critic (Modules::RequireExplicitInclusion)
	$data->{users_shown} = \@users;

	# TODO: Pretty jsonl
	my $json = encode_json $data;
	storedata ($c->{db}->{delayed_notifications}, timems (), $json, $c->{delayed_notifications}->{retention_days});

	return;
}

# Пишет сообщение в чятик или юзеру
# undef PrintMsg($chatid, $text)
sub PrintMsg {
	my $channel = shift;
	my $message = shift;

	$MAIN::IRC->send_long_message ('utf8', 0, 'PRIVMSG', $channel, $message); ## no critic (Modules::RequireExplicitInclusion)
	$log->debug ("[DEBUG] message '$message' sent to $channel");

	return;
}

# Выгребает список todo-шек из базы
# $msg = _todoPrint()
sub _todoPrint {
	$log->debug ('[DEBUG] raking data from todo db');
	my $todo = rakedata ('todo');
	my $msg = '';

	foreach (sort keys (%{$todo})) {
		$msg .= sprintf "%d. %s\n", $_, $todo->{$_};
	}

	return $msg;
}

# Парсит запрос команды .todo
# $reply Todo($message)
sub Todo {
	my $message = shift;

	$log->debug ("$message");
	my $reply;

	if (($message eq 'todo') || ($message =~ /^todo\s+$/)) {
		$log->debug ('[DEBUG] got todo command without arguments');
		$reply = _todoPrint ();
	} elsif ($message =~ /^todo\s+\-d\s+(\d+)\s*$/) {
		$log->debug ('[DEBUG] got todo command with -d argument');
		deletedata('todo', $1);
		$reply = _todoPrint ();
	} else {
		if ($message =~ /^todo\s+(.*)/) {
			my $data = $1;
			$log->debug("[DEBUG] got todo command message: $message");
			my $todo = rakedata ('todo');
			my $num = int (keys %{$todo}) + 1;
			storedata ('todo', $num, $data, 'never');
			$reply = _todoPrint ();
		} else {
			$log->debug ("[DEBUG] got todo command with garbage");
		}
	}

	return $reply;
}

sub B64Str {
	my $str = shift;
	return utf2b64 ($str);
}

sub Md5Str {
	my $str = shift;
	return utf2md5hex ($str);
}

sub Sha1Str {
	my $str = shift;
	return utf2sha1hex($str);
}

sub Sha224Str {
	my $str = shift;
	return utf2sha224hex($str);
}

sub Sha256Str {
	my $str = shift;
	return utf2sha256hex($str);
}

sub Sha384Str {
	my $str = shift;
	return utf2sha384hex($str);
}

sub Sha512Str {
	my $str = shift;
	return utf2sha512hex($str);
}

sub Crc32Str {
	my $str = shift;
	return utf2crc32hex($str);
}

sub MurmurhashStr {
	my $str = shift;
	return utf2murmurhash($str);
}

sub UrlencodeStr {
	my $str = shift;
	return urlencode ($str);
}

sub IrandNum {
	my $num = shift;
	$num = eval {$num + 0};

	if (defined $num) {
		return irandom($num);
	} else {
		return;
	}
}

1;

# vim: set ft=perl noet ai ts=4 sw=4 sts=4:
