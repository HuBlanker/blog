---
layout: post
category: [Java]
tags:
  - Java
---



## 简介

JUC系列提供的又一个线程池，采用分治思想，及工作窃取策略，能获得更高的并发性能.


### 分治思想

通过将大任务，切割成小任务并发执行，由每一个任务等待所有子任务的返回. 大概可以理解为递归的思路.

比如要计算1~100的累加和.

那么任务: **sum(1,100)**.

![2021-10-15-19-57-47](http://img.couplecoders.tech/2021-10-15-19-57-47.png)

首先不断的切分，直到单个任务足够小，然后并发运行，之后再进行join收集操作.


### 工作窃取策略

工作窃取（work-stealing）算法是指某个线程从其他队列里窃取任务来执行。

每个线程有自己的工作队列，当自己的工作队列为空，随机从别的线程的工作队列尾部窃取一个任务进行执行.这样可以有效的提升并发度.

### 框架

Fork/Join框架，主要分为三个部分:

* ForkJoinPool 线程池，管理线程
* ForkJoinTask 任务基类，定义一个任务
* ForkJoinWorkerThread 线程，实现任务执行等


这三个模块的关系是: 

**ForkJoinPool调用池中的ForkJoinWorkerThread,来执行ForkJoinTask**.


下面就结合源码，逐一介绍这三个部分.

## 源码阅读

### ForkJoinPool

#### ForkJoinPool简介

这是官方注释的简单翻译版本.

用来运行`ForkJoinTask`的一个线程池. `ForkJoinPool`提供了提交`非fork/join`任务的客户端，以及管理和监控操作.

`ForkJoinPool`和其他线程池不同的是，它实现了`工作窃取`算法: 所有池中的线程都尝试去寻找并执行任务. 包括提交到线程池的任务或者被其他任务创建的任务.(如果一个任务都没有， 最终所有的线程阻塞).

这个算在大多数任务都会创建一些新的子任务,或者大量的小任务被提交时，有更好的效率.

尤其当`asyncMode`在构造函数中被设置为true时, `ForkJoinPool`也可以适配事件型的任务. 所有的工作线程初始化为守护线程.

静态的`commonPool()`是对大多数应用是可用且合适的. 公用的池用来执行那些没有被明确提交给特殊线程池的任务.
使用公用的线程池通常能够减少资源的使用.

需要分离的或者定制化的线程池的任务，`ForkJoinPool`用一个给定的并发等级来进行初始化. 默认情况下，这个数字等于可用的处理器的数量.
线程池尝试保持足够活跃的线程，通过动态的添加暂停或者唤醒内部的工作线程. 

然而，没有什么调整是保证的， 在面对阻塞式IO或者其他没有被管理的同步操作时.

嵌套的`ManagedBlocker`接口允许扩展一些同步器. 默认的策略可以使用构造器来覆盖. 具体的文档在`ThreadPoolExecutor`里面.

为了执行和生命周期的管理，这个类提供了状态检查方法, `getStealCount`等用来帮助开发,调试和监控fork/join的应用程序.
另外，`toString`返回线程池状态，以进行一些非正式的监控.

在其他的`ExecutorService`中，有三种主要的执行策略，总结在下面的表中.
他们主要设计用于没有进行fork/join操作的客户端使用. 

这些方法的主要形式接受 ForkJoinTask 的实例，但重载形式也允许混合执行普通的基于 Runnable 或 Callable 的活动。但是，已经在池中执行的任务通常应该使用表中列出的计算内形式，除非使用通常不加入的异步事件样式任务，在这种情况下，方法选择之间几乎没有区别

构造共用池的参数，可以被一下属性进行控制:

* parallelism 并发等级，一个不为负数的整数
* threadFactory 线程工厂，
* exceptionHandler 异常处理器
* maximumSpares 为了保持目标并发等级，最大允许的线程数量


注意,这个类限制最大的运行线程树为32767.尝试创建更多的线程将会抛出异常.

#### ForkJoinTask类的简介

使用`ForkJoinPool`执行的任务的一个基类. 一个`ForkJoinTask`是一个类似于线程的实体，但是比一个真正的线程更加轻量级.
在`ForkJoinPool`中,很多的任务和子任务，可能被少量的实际线程管理. 作为代价，有些使用受限制.

一个主要的`ForkJoinTask`在明确提交给`ForkJoinPool`时开始执行，或者当前任务没有参与到`ForkJoin`囧穿，则通过`fork,invoke`等相关的方法，在`ForkJoinPool.commonPool()`中执行.
一旦开始执行，它通常会依次执行其他子任务.就像类名一样，大多数程序使用`ForkJoinTask`只采用`Fork,join`方法，或者像`invokeAll`这种衍生品.
然而，这个类还提供了许多可以在高级用法中发挥作用的其他方法，以及允许支持新形式的 fork/join 处理的扩展机制。

`ForkJoinTask`是`Future`的轻量级形式. 他的高效来源于一组限制(仅部分静态强制执行).它主要应用在计算纯函数，或者对隔离对象进行操作的计算任务.

主要的协调机制是:

* fork 安排异步执行
* join 等待任务的计算结果

计算中应该尽量避免同步方法或者代码块, 同时尽量减少其他的阻塞同步，除了等待其他任务或者使用`Phasers`等可以与`fork/join`调度合作的同步器.
子任务也应该尽量避免阻塞IO. 并且理想情况下，应该访问完全独立于其他任务的变量.

通过不允许抛出`IOException`等已检查异常，这些限制被强制执行. 但是，计算仍然可能遇到未经检查的异常，这些异常会被抛出.

可以定义和使用会阻塞的`ForkJoinTask`.但是这样做要考虑以下三个因素:

1. 如果其他任务应该阻塞在外部的同步器或者io. 将无法完成. 事件类型的异步任务将永远不会joined，他们通常属于这一类.
2. 为了尽量减少资源消耗，任务应该尽量小. 理想情况下只执行阻塞操作.
3. 除非`ForkJoinPool.ManagedBlocker`被使用，或者已知可能阻塞的任务数量小于`ForkJoinPool.getParallelism`等级.池子不保证有足够的线程，以达到较好的性能表现.

等待完成并提取结果的主要方法是`join`, 但是有一些变体:
 `Future.get()`方法支持可中断，可超时的等待。
 `invoke`方法在语义上等效与`fork`方法
`join()`方法永远尝试在当前线程开始执行. 这些方法都是静默形式的，不会提取结果或者报告异常. 这些方法在有一系列的任务等待执行，并且你需要延迟处理结果时很有用.

`invokeAll`方法和最常见的并发调用一样: 派生一系列的任务然后等待全部.

在典型的使用场景中，`fork-join`对就像递归调用中，一个`call`和一个`return`一样. 像其他的递归调用一样，返回操作应该尽快被执行.

任务的执行状态，可能会通过几种级别来查询细节, 
* `isDone`返回true,如果任务完成的话(包括被取消)
* `isCompletedNormally`返回true,如果任务没有取消或者抛出异常，而是正常执行结束.
* `isCancelled`返回ture,如果任务被取消。包含任务抛出取消异常.
* `isCompletedAbnormally`返回true, 如果一个任务被取消或者抛出异常了.

`ForkJoinTask`类通常不直接被继承，而是


ForkJoinTask类通常不会直接子类化。子类化一个支持特殊的fork/join处理风格的抽象类，
* 通常情况下，对于大多数不返回结果的计算，我们使用RecursiveAction;
* 对于返回结果的计算，我们使用RecursiveTask;
* 对于完成的操作触发其他操作的计算，我们使用CountedCompleter。

通常，具体的ForkJoinTask子类声明包含其参数的字段，在构造函数中建立，然后定义一个计算方法，该方法以某种方式使用该基类提供的控制方法。

`join`方法和他的变体只适合在没有循环以来的情况下使用. 也就是说，并行计算可以使用有向无环图(DAG)来描述.
否则，循环依赖的任务之间互相等待，可能造成死锁. 然后，这个框架支持一些其他的方法和技术(Phasers,helpQuiesce,complete),
可以为那些不是dag的问题构造子类.

大多数的基础方法都是final,以防止覆盖本质上与底层轻量级任务调度框架相关联的实现.
创建新的fork/join风格的开发人员应该最低限度的实现protected方法. `exec,setRawResutl`,`getRawResult`等.
同时还引入一个可以在其子类中实现的抽象计算方法，可能依赖于该类提供的其他受保护的方法。


ForkJoinTasks应该执行相对较少的计算量。通常通过递归分解将大任务分解为更小的子任务。
一个非常粗略的经验法则是，一个任务应该执行超过100个和少于10000个基本计算步骤，并且应该避免无限循环。
如果任务太大，并行性就不能提高吞吐量。如果太小，那么内存和内部任务维护开销可能会压倒处理。

这个类为Runnable和Callable提供了适配的方法，
当混合执行ForkJoinTasks和其他类型的任务时，这些方法可能会很有用。当所有任务都是这种形式时，考虑使用asyncMode构造池。

ForkJoinTasks是可序列化的，这使得它们可以用于远程执行框架等扩展。
合理的做法是只在执行之前或之后序列化任务，而不是在执行期间。在执行过程中并不依赖于序列化。




### 工作队列 `WorkQueue`

#### 属性

```java
        volatile int source;       // source queue id, or sentinel 源队列ID
        int id;                    // pool index, mode, tag 池ID
        int base;                  // index of next slot for poll // 下一个拿的index
        int top;                   // index of next slot for push // 下一个放的index
        volatile int phase;        // versioned, negative: queued, 1: locked // 1是锁定. 负数是有队列
        int stackPred;             // pool stack (ctl) predecessor link // 
        int nsteals;               // number of steals // 偷取任务数量
        ForkJoinTask<?>[] array;   // the queued tasks; power of 2 size // 队列中的任务
        final ForkJoinPool pool;   // the containing pool (may be null) // 池子
        final ForkJoinWorkerThread owner; // owning thread or null if shared // 所属线程
```

#### push 入队任务

```java
        final void push(ForkJoinTask<?> task) {
            ForkJoinTask<?>[] a;
            int s = top, d = s - base, cap, m;
            ForkJoinPool p = pool;
            // 已有队列
            if ((a = array) != null && (cap = a.length) > 0) {
                // CAS更新任务
                QA.setRelease(a, (m = cap - 1) & s, task);
                // 下标+1
                top = s + 1;
                // 数组满了,扩容
                if (d == m)
                    growArray(false);
                else if (QA.getAcquire(a, m & (s - 1)) == null && p != null) {
                    VarHandle.fullFence();  // was empty
                    // sinall
                    p.signalWork(null);
                }
            }
        }
```

通过CAS向数组中添加任务，成功后如果需要扩容任务数组.

#### poll 出队

```java
        final ForkJoinTask<?> poll() {
            int b, k, cap; ForkJoinTask<?>[] a;
            // 队列中有值，
            while ((a = array) != null && (cap = a.length) > 0 &&
                   top - (b = base) > 0) {
                // 从数组中获取一个任务
                ForkJoinTask<?> t = (ForkJoinTask<?>)
                    QA.getAcquire(a, k = (cap - 1) & b);
                if (base == b++) {
                    if (t == null)
                        Thread.yield(); // await index advance
                    // 置为空
                    else if (QA.compareAndSet(a, k, t, null)) {
                        BASE.setOpaque(this, b);
                        // 返回任务
                        return t;
                    }
                }
            }
            return null;
        }
```

从工作队列中取一个任务返回.

```java
        // 获取第一个任务
        final ForkJoinTask<?> peek() {
        int cap; ForkJoinTask<?>[] a;
        return ((a = array) != null && (cap = a.length) > 0) ?
        a[(cap - 1) & ((id & FIFO) != 0 ? base : top - 1)] : null;
        }

```


### 构造方法


```java
    public ForkJoinPool() {
        this(Math.min(MAX_CAP, Runtime.getRuntime().availableProcessors()),
             defaultForkJoinWorkerThreadFactory, null, false,
             0, MAX_CAP, 1, null, DEFAULT_KEEPALIVE, TimeUnit.MILLISECONDS);
    }

    public ForkJoinPool(int parallelism) {
        this(parallelism, defaultForkJoinWorkerThreadFactory, null, false,
             0, MAX_CAP, 1, null, DEFAULT_KEEPALIVE, TimeUnit.MILLISECONDS);
    }

    public ForkJoinPool(int parallelism,
                        ForkJoinWorkerThreadFactory factory,
                        UncaughtExceptionHandler handler,
                        boolean asyncMode) {
        this(parallelism, factory, handler, asyncMode,
             0, MAX_CAP, 1, null, DEFAULT_KEEPALIVE, TimeUnit.MILLISECONDS);
    }

    public ForkJoinPool(int parallelism,
                        ForkJoinWorkerThreadFactory factory,
                        UncaughtExceptionHandler handler,
                        boolean asyncMode,
                        int corePoolSize,
                        int maximumPoolSize,
                        int minimumRunnable,
                        Predicate<? super ForkJoinPool> saturate,
                        long keepAliveTime,
                        TimeUnit unit) {
        // check, encode, pack parameters
        if (parallelism <= 0 || parallelism > MAX_CAP ||
            maximumPoolSize < parallelism || keepAliveTime <= 0L)
            throw new IllegalArgumentException();
        if (factory == null)
            throw new NullPointerException();
        long ms = Math.max(unit.toMillis(keepAliveTime), TIMEOUT_SLOP);

        int corep = Math.min(Math.max(corePoolSize, parallelism), MAX_CAP);
        long c = ((((long)(-corep)       << TC_SHIFT) & TC_MASK) |
                  (((long)(-parallelism) << RC_SHIFT) & RC_MASK));
        int m = parallelism | (asyncMode ? FIFO : 0);
        int maxSpares = Math.min(maximumPoolSize, MAX_CAP) - parallelism;
        int minAvail = Math.min(Math.max(minimumRunnable, 0), MAX_CAP);
        int b = ((minAvail - parallelism) & SMASK) | (maxSpares << SWIDTH);
        int n = (parallelism > 1) ? parallelism - 1 : 1; // at least 2 slots
        n |= n >>> 1; n |= n >>> 2; n |= n >>> 4; n |= n >>> 8; n |= n >>> 16;
        n = (n + 1) << 1; // power of two, including space for submission queues

        this.workerNamePrefix = "ForkJoinPool-" + nextPoolId() + "-worker-";
        this.workQueues = new WorkQueue[n];
        this.factory = factory;
        this.ueh = handler;
        this.saturate = saturate;
        this.keepAlive = ms;
        this.bounds = b;
        this.mode = m;
        this.ctl = c;
        checkPermission();
    }

```

提供了4个构造方法，都是调用的最后一个。

计算了一堆参数.

### 变量

```java

// 权限
static final RuntimePermission modifyThreadPermission;

// common pool
static final ForkJoinPool common;

// 并发度
static final int COMMON_PARALLELISM;

// 偷取数量
volatile long stealCount;            // collects worker nsteals
// 保持活跃的时间
final long keepAlive;                // milliseconds before dropping if idle
// 下一个工作线程的下标
int indexSeed;                       // next worker index
// 最小最大线程
final int bounds;                    // min, max threads packed as shorts
// 并发度
volatile int mode;                   // parallelism, runstate, queue mode
// 工作队列
WorkQueue[] workQueues;              // main registry
// 工作线程的前缀
final String workerNamePrefix;       // for worker thread string; sync lock
// 线程工厂
final ForkJoinWorkerThreadFactory factory;
// 异常处理器
final UncaughtExceptionHandler ueh;  // per-worker UEH
// 是否饱和的判断方法
final Predicate<? super ForkJoinPool> saturate;

// 核心的状态控制
@jdk.internal.vm.annotation.Contended("fjpctl") // segregate
volatile long ctl;                   // main pool control
```


### 提交Runnable. execute(Runnable task)

```java

    public void execute(Runnable task) {
        if (task == null)
            throw new NullPointerException();
        ForkJoinTask<?> job;
        if (task instanceof ForkJoinTask<?>) // avoid re-wrap
            job = (ForkJoinTask<?>) task;
        else
            job = new ForkJoinTask.RunnableExecuteAction(task);
        // 调用
        externalSubmit(job);
    }
```

**ForkJoinTask.RunnableExecuteAction**

是对`ForkJoinTask`进行简单实现，包装一个`Runnable`的简单内部类.

首先对提交的任务进行wrap.之后调用`externalSubmit`.

```java
    private <T> ForkJoinTask<T> externalSubmit(ForkJoinTask<T> task) {
        Thread t; ForkJoinWorkerThread w; WorkQueue q;
        if (task == null)
            throw new NullPointerException();
        // 当前线程就是一个`ForkJoin`类型的线程，直接调用该线程的队列进行push
        if (((t = Thread.currentThread()) instanceof ForkJoinWorkerThread) &&
            (w = (ForkJoinWorkerThread)t).pool == this &&
            (q = w.workQueue) != null)
            q.push(task);
        else
            // 提交
            externalPush(task);
        return task;
    }
    
    final void externalPush(ForkJoinTask<?> task) {
        int r;                                // initialize caller's probe
        // 随机一个探针
        if ((r = ThreadLocalRandom.getProbe()) == 0) {
            ThreadLocalRandom.localInit();
            r = ThreadLocalRandom.getProbe();
        }
        for (;;) {
            WorkQueue q;
            int md = mode, n;
            WorkQueue[] ws = workQueues;
            if ((md & SHUTDOWN) != 0 || ws == null || (n = ws.length) <= 0)
                throw new RejectedExecutionException();
        // 该位置为空. 新建一个工作队列，加锁入队.
        else if ((q = ws[(n - 1) & r & SQMASK]) == null) { // add queue
                int qid = (r | QUIET) & ~(FIFO | OWNED);
                Object lock = workerNamePrefix;
                ForkJoinTask<?>[] qa =
                    new ForkJoinTask<?>[INITIAL_QUEUE_CAPACITY];
                q = new WorkQueue(this, null);
                q.array = qa;
                q.id = qid;
                q.source = QUIET;
                if (lock != null) {     // unless disabled, lock pool to install
                    synchronized (lock) {
                        WorkQueue[] vs; int i, vn;
                        if ((vs = workQueues) != null && (vn = vs.length) > 0 &&
                            vs[i = qid & (vn - 1) & SQMASK] == null)
                            vs[i] = q;  // else another thread already installed
                    }
                }
            }
            // 如果工作队列的当前位置在忙，重新随机一个位置.
            else if (!q.tryLockPhase()) // move if busy
                r = ThreadLocalRandom.advanceProbe(r);
            else {
                // 不知道
                if (q.lockedPush(task))
                    signalWork(null);
                return;
            }
        }
    }
```

### 任务何时运行?
```java
    final void signalWork(WorkQueue q) {
        for (;;) {
            long c; int sp; WorkQueue[] ws; int i; WorkQueue v;
        // 有足够多的任务，退出
        if ((c = ctl) >= 0L)                      // enough workers
                break;
            // 没有空闲线程
            else if ((sp = (int)c) == 0) {            // no idle workers
                // 线程数很少，添加一个线程
                if ((c & ADD_WORKER) != 0L)           // too few workers
                    tryAddWorker(c);
                break;
            }
            else if ((ws = workQueues) == null)
                break;                                // unstarted/terminated
            else if (ws.length <= (i = sp & SMASK))
                break;                                // terminated
            else if ((v = ws[i]) == null)
                break;                                // terminating
            else {
                // 唤醒一个其他的线程
                int np = sp & ~UNSIGNALLED;
                int vp = v.phase;
                long nc = (v.stackPred & SP_MASK) | (UC_MASK & (c + RC_UNIT));
                Thread vt = v.owner;
                if (sp == vp && CTL.compareAndSet(this, c, nc)) {
                    v.phase = np;
                    if (vt != null && v.source < 0)
                        LockSupport.unpark(vt);
                    break;
                }
                else if (q != null && q.isEmpty())     // no need to retry
                    break;
            }
        }
    }
    
    
    // 尝试添加一个工作线程
    private void tryAddWorker(long c) {
        do {
            long nc = ((RC_MASK & (c + RC_UNIT)) |
                       (TC_MASK & (c + TC_UNIT)));
            if (ctl == c && CTL.compareAndSet(this, c, nc)) {
                // 创建线程
                createWorker();
                break;
            }
        } while (((c = ctl) & ADD_WORKER) != 0L && (int)c == 0);
    }
    
    // 创建工作线程
    private boolean createWorker() {
        ForkJoinWorkerThreadFactory fac = factory;
        Throwable ex = null;
        ForkJoinWorkerThread wt = null;
        try {
            // 创建一个线程并运行
            if (fac != null && (wt = fac.newThread(this)) != null) {
                // 默认的实现是下方的Thread.
                wt.start();
                return true;
            }
        } catch (Throwable rex) {
            ex = rex;
        }
        // 注销一个工作线程
        deregisterWorker(wt, ex);
        return false;
    }
    
    
    // 默认的线程工厂，会创建一个线程
    private static final class DefaultForkJoinWorkerThreadFactory
        implements ForkJoinWorkerThreadFactory {
        private static final AccessControlContext ACC = contextWithPermissions(
            new RuntimePermission("getClassLoader"),
            new RuntimePermission("setContextClassLoader"));

        public final ForkJoinWorkerThread newThread(ForkJoinPool pool) {
            return AccessController.doPrivileged(
                new PrivilegedAction<>() {
                    public ForkJoinWorkerThread run() {
                        return new ForkJoinWorkerThread(
                            pool, ClassLoader.getSystemClassLoader()); }},
                ACC);
        }
    }
    
    通过一系列的线程方法，最后调用`runWorker`.
    final void runWorker(WorkQueue w) {
        int r = (w.id ^ ThreadLocalRandom.nextSecondarySeed()) | FIFO; // rng
        w.array = new ForkJoinTask<?>[INITIAL_QUEUE_CAPACITY]; // initialize
        for (;;) {
            int phase;
            if (scan(w, r)) {                     // scan until apparently empty
                r ^= r << 13; r ^= r >>> 17; r ^= r << 5; // move (xorshift)
            }
            else if ((phase = w.phase) >= 0) {    // enqueue, then rescan
                long np = (w.phase = (phase + SS_SEQ) | UNSIGNALLED) & SP_MASK;
                long c, nc;
                do {
                    w.stackPred = (int)(c = ctl);
                    nc = ((c - RC_UNIT) & UC_MASK) | np;
                } while (!CTL.weakCompareAndSet(this, c, nc));
            }
            else {                                // already queued
                int pred = w.stackPred;
                Thread.interrupted();             // clear before park
                w.source = DORMANT;               // enable signal
                long c = ctl;
                int md = mode, rc = (md & SMASK) + (int)(c >> RC_SHIFT);
                if (md < 0)                       // terminating
                    break;
                else if (rc <= 0 && (md & SHUTDOWN) != 0 &&
                         tryTerminate(false, false))
                    break;                        // quiescent shutdown
                else if (w.phase < 0) {
                    if (rc <= 0 && pred != 0 && phase == (int)c) {
                        long nc = (UC_MASK & (c - TC_UNIT)) | (SP_MASK & pred);
                        long d = keepAlive + System.currentTimeMillis();
                        LockSupport.parkUntil(this, d);
                        if (ctl == c &&           // drop on timeout if all idle
                            d - System.currentTimeMillis() <= TIMEOUT_SLOP &&
                            CTL.compareAndSet(this, c, nc)) {
                            w.phase = QUIET;
                            break;
                        }
                    }
                    else {
                        LockSupport.park(this);
                        if (w.phase < 0)          // one spurious wakeup check
                            LockSupport.park(this);
                    }
                }
                w.source = 0;                     // disable signal
            }
        }
    }
```

太难了， 弃了。


#### 其他提交方法

* invoke
* execute
* execute
* submit
* submit
* submit
* submit
* invokeAll

全部是调用的内部的`externalSubmit`方法. 


### 监控方法

一堆获取内部信息及控制是否要终止线程池的方法.

* getFactory
* getUncaughtExceptionHandler
* getParallelism
* getCommonPoolParallelism
* getPoolSize
* getAsyncMode
* getRunningThreadCount
* getActiveThreadCount
* isQuiescent
* getStealCount
* getQueuedTaskCount
* getQueuedSubmissionCount
* hasQueuedSubmissions
* toString
* shutdown
* shutdownNow
* isTerminated
* isTerminating
* isShutdown


放弃治疗， 太难了，等能看懂了再来看一次.



<br>


完。
<br>
<br>
<br>


## 联系我
最后，欢迎关注我的个人公众号【 呼延十 】，会不定期更新很多后端工程师的学习笔记。
也欢迎直接公众号私信或者邮箱联系我，一定知无不言，言无不尽。
![](http://img.couplecoders.tech/%E6%89%AB%E7%A0%81_%E6%90%9C%E7%B4%A2%E8%81%94%E5%90%88%E4%BC%A0%E6%92%AD%E6%A0%B7%E5%BC%8F-%E6%A0%87%E5%87%86%E8%89%B2%E7%89%88.png)


<br>
<br>




**以上皆为个人所思所得，如有错误欢迎评论区指正。**


**欢迎转载，烦请署名并保留原文链接。**


**联系邮箱：huyanshi2580@gmail.com**


**更多学习笔记见个人博客或关注微信公众号 &lt;呼延十 &gt;------><a href="{{ site.baseurl }}/">呼延十</a>**