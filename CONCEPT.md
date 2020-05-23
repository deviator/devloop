Because idea born in russian telegram channel start working on concept on russian language.

# Базовые положения

## Что хочется получить

Некоторые базовые алгоритмы использования

### Возможность писать синхронный код в файберах, где операции io будут неблокирующими

Наример что-то вроде этого:
```d
void main()
{
    auto sp1 = new SerialPort(...);
    auto sp2 = new SerialPort(...);
    auto other = makeOtherIO;

    auto w1 = makeWorker(
    {
        void[4096] buffer = void;
        while (true)
        {
            const r = sp1.readUntil(buffer[], "\n"); // Fiber.yield внутри read
            const str = cast(char[])buffer[0..r];
            sp2.write(someProcess(str)); // Fiber.yield внутри write
        }
    });

    auto w2 = makeWorker(
    {
        void[4096] buffer = void;
        while (true)
        {
            const r = other.read(buffer[]); // Fiber.yield внутри read, выход по timeout, например
            doSomethingWithData(buffer[0..r]);
        }
    });

    eventLoop();
}
```

### Возможность писать код с использованием callback'ов (нужно?)

TODO: краткий пример

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

## Возможность интергации внешних библиотек в event loop

Пример [`mosquitto`](https://mosquitto.org/api) (работа с MQTT протоколом).
Функция `mosquitto_socket` возвращает файловый дескриптор сокета, а
`mosquitto_loop_read` и `mosquitto_loop_write` реализуют работу библиотеки при чтении и
записи в этот сокет. Так же есть функция `mosquitto_loop_misc`, которая должна вызываться
раз в секунду.

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