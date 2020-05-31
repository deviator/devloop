Because idea born in russian telegram channel start working on concept on russian language.

# Базовые положения

## Что хочется получить

Некоторые базовые алгоритмы использования

- Возможность писать синхронный код в файберах, где операции io будут неблокирующими
- Возможность писать код с использованием callback'ов
- Простота интерфейса и использования
- Хорошая документация с примерами
- Дефолтные настройки объектов и библиотеки должны быть достаточны для простого и быстрого старта, при этом не теряя гибкости конфигурирования

## Ориентированность на linux

Как минимум на начальном этапе Windows и другие ОС не в приоритете,
но архитектура должна позволять реализовать backend под них
(возможно с урезанной функциональностью).

## Работа с различными файловыми дескрипторами

1. сетевые сокеты
2. unix-сокеты
3. ком-порты и терминалы (/dev/tty*)
4. каналы (pipe)
5. файлы
6. таймеры (timerfd)
7. сигналы (signalfd)
8. события (eventfd)
9. fanotify, inotify

## предложение для интерфейса

        void delegate(scope Duration = Duration.max)       run;  // run event loop for some time
        @safe void delegate()                              stop; // stop it (exit from loop)
        @safe void delegate(Timer)                         startTimer; // start timer
        @safe void delegate(Timer)                         stopTimer;  // stop timer
        void delegate(Signal)                              startSignal; // start signal handling
        void delegate(Signal)                              stopSignal;  // stop signal handling
        @safe void delegate(int, AppEvent, FileEventHandler)   startPoll; // start listening to events on file
        @safe void delegate(int, AppEvent)                 stopPoll;  // stop listening to some events on file
        @safe void delegate(int)                           detach;    // detach file from loop (release space)
        @safe void delegate()                              deinit;    // close pollfd, timerfd,..., free memory


## Возможность интергации внешних библиотек в event loop

Пример [`mosquitto`](https://mosquitto.org/api) (работа с MQTT протоколом).
Функция `mosquitto_socket` возвращает файловый дескриптор сокета, а
`mosquitto_loop_read` и `mosquitto_loop_write` реализуют работу библиотеки при чтении и
записи в этот сокет. Так же есть функция `mosquitto_loop_misc`, которая должна вызываться
раз в секунду.

## Поддержка POLLPRI

### GPIO

https://raspberrypi.stackexchange.com/questions/44416/polling-gpio-pin-from-c-always-getting-immediate-response

https://www.kernel.org/doc/Documentation/gpio/sysfs.txt

### Net (?)

# Существующие решения

* https://code.dlang.org/packages/async

    плюсы:

    * имеет реализации для epoll, iocp, kqueue

    минусы:

    * ориентирован на network
    * callback архитектура

* https://code.dlang.org/packages/libasync
  
    плюсы:

    * поддержка многопоточности
    * DNS-resolver 

    минусы:

    * поддержка файловых операций через thread-pool (т.е. блокирующая работа с файлами)
    * callback архитектура

* https://code.dlang.org/packages/collie
    
    минусы:

    * ориентирован на network
    * срисован с java фреймворка netty

* https://code.dlang.org/packages/libuv
  
    биндинг к libuv

    TODO: проработать

* https://code.dlang.org/packages/libevent
    
    биндинг к libevent

    TODO: проработать

* https://code.dlang.org/packages/libev

    биндинг к libev

    TODO: проработать

    минусы:

    * нет поддержки windows (вроде история давняя и принципиальная)

* https://code.dlang.org/packages/vibe-core

    плюсы:

    * поддержка различных ОС

    минусы:

    * ориентирован на network
    * много ненужного: парсинг командной строки, логирование и тд

# Полезные ссылки

## Разное

- Упоминание реализации таймеров высокого разрешения в `libevent`: https://stackoverflow.com/q/240058/7695184
- В Windows 10 добавлена поддержка AF_UNIX сокетов: https://devblogs.microsoft.com/commandline/af_unix-comes-to-windows/

## io_uring

- poll with io_uring https://developpaper.com/using-io_uring-instead-of-epoll-to-realize-high-speed-polling/
- Софт в котором заявлена поддержка `io_uring`: https://stackoverflow.com/a/57451551/7695184
- Заявка в GsoC на добавление `io_uring` в Java библиотеку Netty: https://github.com/netty/netty/wiki/Google-Summer-of-Code-Ideas-2020

## Async Disk IO

- Описание и примеры AIO в Linux для асинхронных операций с файлами: https://kkourt.io/blog/2017/10-14-linux-aio.html (скрытая возможность: поддерживает eventfd для уведомления о выполненных действиях), не поддерживает Buffered IO (работает только с `O_DIRECT`)
- Бенчмарк Lighttpd сервера при отдаче файлов разными способами: https://www.lighttpd.net/2007/2/11/buffered-io-performance/
- Заметка автора libtorrent об Asynchronous Disk IO: https://blog.libtorrent.org/2012/10/asynchronous-disk-io/
