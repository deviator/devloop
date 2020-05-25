import std.stdio;
import std.string : toStringz;
import std.datetime : Duration, seconds;

import core.sys.posix.fcntl;
import core.sys.posix.unistd;
import core.stdc.errno;

import devloop;

void main(string[] args)
{
    devLoop = new EpollLoop;

    int openFD() { return open(args[1].toStringz, O_RDONLY | O_NONBLOCK | O_NOCTTY); }
    int fd = openFD();
    scope (exit) close(fd);

    void[1024] buffer = void;

    const evmask = Event.READ | Event.HUP;

    uint fnc(int f, uint ev)
    {
        if (ev & Event.HUP)
        {
            stderr.writefln("unwatch %d: ", f, devLoop.unwatch(f));
            close(f);
            fd = openFD();
            devLoop.watch(fd, evmask, &fnc);
            stderr.writefln("watch %d", fd);
        }
        const n = read(f, buffer.ptr, buffer.length);

        if (n < 0)
        {
            if (errno == EAGAIN) return evmask;
            else throw new Exception("fail read");
        }

        if (n) stderr.writefln!"read %d from %d: %s"(n, f, cast(char[])buffer[0..n]);

        return evmask;
    }

    devLoop.watch(fd, evmask, &fnc);

    devLoop.setTimer(Duration.zero, (t)
    {
        stderr.writefln("timer %d", t);
        return 1.seconds;
    });

    size_t n = 10;

    devLoop.setTimer(10.seconds, (t)
    {
        stderr.writefln("timer %d", t);
        return n-- > 0 ? 1.seconds : Duration.zero;
    });

    devLoop.run();
}