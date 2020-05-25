module devloop.core.base;

import std : enforce;
import std.datetime : Duration, Clock;

version (Posix) alias FD = int;
else static assert(0, "not implement yet");
//else version (Windows) alias FD = HANDLE;

///
enum Event
{
    ERROR = 1<<0, ///
    READ  = 1<<1, ///
    WRITE = 1<<2, ///
    PRIOR = 1<<3, ///
    HUP   = 1<<4, ///
}

///
alias FDCallback = uint delegate(FD fd, uint mask);
///
alias TimerCallback = Duration delegate(long);

///
interface EvLoop
{
    /++
        callback can return new watching event mask (0 unwatch fd)
     +/
    void watch(FD fd, uint evmask, FDCallback cb);
    /// returns true if fd was under wathing, otherwise false
    bool unwatch(FD fd);

    /++
        callback can return new timeout for repeat
     +/
    long setTimer(Duration d, TimerCallback cb);
    /// returns true if timer was setted, otherwise false
    bool resetTimer(long timer);

    /// returns true -- continue work, false -- exit from main loop
    bool step();
    /// set false for step return value
    void exit();
    /// { while(step()) {}; cleanup(); }
    void run();
    ///
    void cleanup();
}

// TODO: select event loop at runtime (check kernel version for enabling io_uring for example)
package EvLoop evl;

EvLoop devLoop()() @property
{
    pragma(inline);

    version (checkNullEvLoop)
        return enforce(evl, "try get null event loop");
    else
        return evl;
}

void devLoop()(EvLoop e) @property
{
    pragma(inline);
    evl = enforce(e, "try set null event loop");
}