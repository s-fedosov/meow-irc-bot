# Meow-IRC-bot - Простой ассистивный IRC бот

## About

Бот основан Perl модуле [AnyEvent::IRC][1].

Конфиг должен находиться в **data/config.json**, пример конфига расположен в**data/sample_config.json**.

Бота можно запустить через команду **bin/aleesa-irc-bot**.

Этот бот можно считать экспериментальным из-за отсутсвия всестороннего тестирования. Он работает по принципу "works for
me".

## Installation

In order to run this application, you need to "bootstrap" it - download and
install all dependencies and libraries.

You'll need "Development Tools" or similar group of packages, perl, perl-devel,
perl-local-lib, perl-app-cpanm, sqlite-devel, zlib-devel, openssl-devel,
libdb4-devel (Berkeley DB devel), make.

After installing required dependencies it is possible to run:

```bash
bash bootstrap.sh
```

and all libraries should be downloaded, built, tested and installed.

[1]: https://metacpan.org/pod/AnyEvent::IRC
