module devloop.core.be.epoll;

version (Posix):

import std.array : Appender;
import std.experimental.logger;
import std.datetime : Duration, Clock;
import std.container.rbtree;
import std.exception : enforce;

import core.sys.linux.epoll;
import devloop.core.base;
import devloop.core.be.errproc;

pragma(inline) private uint base2epollEvent()(uint evs)
{
    return (evs & Event.ERROR ? EPOLLERR : 0) |
           (evs & Event.READ  ? EPOLLIN  : 0) |
           (evs & Event.WRITE ? EPOLLOUT : 0) |
           (evs & Event.PRIOR ? EPOLLPRI : 0) |
           (evs & Event.HUP   ? EPOLLHUP : 0) ;
}

pragma(inline) private uint epoll2baseEvent()(uint evs)
{
    return (evs & EPOLLERR ? Event.ERROR : 0) |
           (evs & EPOLLIN  ? Event.READ  : 0) |
           (evs & EPOLLOUT ? Event.WRITE : 0) |
           (evs & EPOLLPRI ? Event.PRIOR : 0) |
           (evs & EPOLLHUP ? Event.HUP   : 0) ;
}

class EpollLoop : EvLoop
{
protected:
    bool isRun;
    bool cleaned;

    int epfd;
    epoll_event[256] evbuf;

    struct CBData
    {
        uint mask;
        FDCallback cb;
    }

    long timers_ids=1;
    struct TMData
    {
        long time;
        long id;
        TimerCallback cb;
    }

    RedBlackTree!(TMData, "a.time < b.time", true) timers;

    CBData[int] cbDataList;

    Appender!(TMData[]) clearList;
    Appender!(TMData[]) insertList;

    int runTimers()
    {
        clearList.clear();
        insertList.clear();
        const ct = Clock.currStdTime;
        foreach (t; timers.lowerBound(TMData(ct)))
        {
            const nt = t.cb(t.id).total!"hnsecs";
            clearList.put(t);
            if (nt > 0)
            {
                const time = ct + nt;
                insertList.put(TMData(time, t.id, t.cb));
            }
        }
        timers.removeKey(clearList.data);
        timers.insert(insertList.data);

        if (timers.empty) return -1;

        auto ret = (timers.front().time - ct) / 10_000;

        return cast(int)ret;
    }

public:
    this()
    {
        epfd = check!epoll_create1(EPOLL_CLOEXEC);
        isRun = true;
        timers = new typeof(timers);
    }

override:
    void watch(FD fd, uint evmask, FDCallback cb)
    {
        version (checkNullCallback)
            enforce(cb !is null, "fd callback is null");

        epoll_event ev;
        ev.events = base2epollEvent(evmask) | EPOLLONESHOT | EPOLLET;
        ev.data.fd = fd;

        const CTL = fd !in cbDataList ? EPOLL_CTL_ADD : EPOLL_CTL_MOD;
        check!epoll_ctl(epfd, CTL, fd, &ev);

        cbDataList[fd] = CBData(evmask, cb);
    }

    bool unwatch(FD fd)
    {
        if (fd !in cbDataList) return false;

        check!epoll_ctl(epfd, EPOLL_CTL_DEL, fd, null);
        cbDataList.remove(fd);

        return true;
    }

    long setTimer(Duration d, TimerCallback cb)
    {
        version (checkNullCallback)
            enforce(cb !is null, "fd callback is null");

        const time = Clock.currStdTime + d.total!"hnsecs";
        const id = timers_ids++;
        timers.insert(TMData(time, id, cb));

        return id;
    }

    bool resetTimer(long id)
    {
        foreach (td; timers)
            if (td.id == id)
            {
                timers.removeKey(td);
                return true;
            }
        return false;
    }

    bool step()
    {
        const timeout = runTimers();

        int nfds = check!epoll_wait(epfd,
            evbuf.ptr, cast(int)evbuf.length, timeout);

        foreach (i; 0 .. nfds)
        {
            const e = evbuf[i];
            const fd = e.data.fd;
            auto cbd = fd in cbDataList;

            if (cbd is null)
            {
                errorf("have null callback data for fd %d", fd);
                continue;
            }

            const be = epoll2baseEvent(e.events);
            if ((*cbd).mask & be)
            {
                const nmask = (*cbd).cb(fd, be);
                if (nmask) watch(fd, nmask, (*cbd).cb);
            }
        }

        return isRun;
    }

    void exit() { isRun = false; }

    void run()
    {
        while (step()) {}
        cleanup();
    }

    void cleanup()
    {
        import core.sys.posix.unistd : close;

        if (cleaned) return;
        close(epfd);
        cleaned = true;
    }
}

version (none):

private EpollLoop epollloop;

static this()
{
    epollloop = new EpollLoop; 
}

class EpollWaker : Waker
{
    int fd = -1;
    epoll_event ev;
    Callback cb;
    Worker wrkr;

    this(Worker w)
    {
        wrkr = w;
        ev.events = EPOLLIN | EPOLLOUT | EPOLLET;
        cb = &call;
        ev.data.ptr = cast(void*)&cb;
    }

    override
    {
        void beforeCloseHandle(int h)
        {
            assert(h == fd, "wrong fd for WrapFD.beforeCloseHandle");
            check!epoll_ctl(epollloop.epfd, EPOLL_CTL_DEL, h, null);
        }

        void afterOpenHandle(int h)
        {
            assert(fd == -1, "WrapFD is inited");
            check!epoll_ctl(epollloop.epfd, EPOLL_CTL_ADD, h, &ev);
            fd = h;
        }

        void wakeOnRead(bool w, Duration t) { wakeOnIO(w, t); }
        void wakeOnWrite(bool w, Duration t) { wakeOnIO(w, t); }
    }

    void wakeOnIO(bool wake, Duration timeout)
    {
        if (wake) wrkr.setWaker(this);
        else wrkr.unsetWaker(this);
        wrkr.timer.set(timeout);
    }

    void call(uint evmask)
    {
        // shut down connection
        if (evmask & EPOLLRDHUP) { mlog("EPOLLRDHUP"); }
        // close other side of pipe
        if (evmask & EPOLLERR) { mlog("EPOLLERR"); }
        // internal error
        if (evmask & EPOLLHUP) { mlog("EPOLLHUP"); }
        // priority?
        if (evmask & EPOLLPRI) { mlog("EPOLLPRI"); }

        // EPOLLET can only be setted
        // EPOLLONESHOT can only be setted

        // can read
        if (evmask & EPOLLIN)
            if (wrkr.currentWaker is this)
                wrkr.exec();

        // can write
        if (evmask & EPOLLOUT)
            if (wrkr.currentWaker is this)
                wrkr.exec();
    }
}