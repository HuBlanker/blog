---
layout: post
category: [Java面试,Java,多线程,java.util.concurrent]
tags:
  - Java面试
  - Java
  - 多线程
  - java.util.concurrent
---

本文源码基于: <font color='red'>JDK13</font>

## 前言

其实早在19年，就简单的写过`ThreadPoolExecutor`. 但是只涉及到了其中两个参数，理解也不深刻，今天重新看一下代码。


## 简介

这个类是Java中常用的线程池的一个类，相关的类图：

![2021-10-11-17-38-50](http://img.couplecoders.tech/2021-10-11-17-38-50.png)

继承自父类: `AbstractExecutorService`,实现了`Executor`和`ExecutorService`接口.

使用一些池化的线程来执行每一个提交的任务,一般使用`Executors`的工厂方法来进行相关的配置.

线程池解决两个不同的问题：由于减少了每个任务的调用开销，它们通常在执行大量异步任务时提供更好的性能，
并且它们提供了一种限制和管理资源的方法，包括在执行集合时消耗的线程任务。
每个 ThreadPoolExecutor 还维护一些基本的统计信息，例如已完成的任务数。

为了在更加广泛的上下文中可用，这个类提供了许多可以调整的参数和可以扩展的挂钩. 但是强烈建议程序员使用`Executors`的工厂方法来进行这个类的创建.

如果你要手动创建和配置的话，以下是一些使用指南:

* 核心线程数和最大线程数

线程池自动调整池子的大小，调整范围在`corePoolSize`和`maximumPoolSize`之间.
如果正在运行的线程少于核心线程数, 处理请求时将创建一个新的线程.即使当前有一些线程是空闲的.
如果当前运行的线程数少于最大线程数.只有当工作队列满了的时候，才会创建新的线程. 设置核心线程数等于最大线程数，就创建了一个固定大小的线程池.
设置一个无限大的最大线程数，就允许线程池拥有任意数量的线程. 
通常，核心线程数和最大线程数只在调用构造方法时设置，但是也可以被对应的set方法修改.

* 按需构建

默认情况下，　核心线程也是在有新的任务到来时才会初始化. 但是这一点可以被动态的重写，使用`prestartCoreThread`和`prestartAllCoreThreads`.
如果你创建线程时已经有一个不为空的队列，你可能想要预启动线程.

* 创建新线程 

使用`ThreadFactory`创建新线程. 默认使用`Executors.defaultThreadFactory`. 他创建的线程全在同一个`ThreadGroup`中. 有用相同的优先级，且不是守护线程.
使用其他的线程工厂，你可以修改线程的名字，线程组，优先级，是否是守护线程等等.
如果线程工厂在创建新线程时出错，调用`newThread`时返回null.执行器会继续，但是可能没有办法执行任务了.
线程应该有用"修改线程"的运行时权限. 如果工作线程或者其他线程没有取得这个权限，服务将退化.配置的更改可能不起效，一个终止的线程池可能还处在未完成状态中.

* 活跃时间

如果一个线程池有超过核心线程数的线程数量，超过核心线程数的线程将在空闲超过`keepAliveTime`时间后被终止. 
当线程池没有完全应用起来时，这提供了一个减少资源消耗的方法.如果之后线程池变得更加活跃，将新创建线程.
这个参数也可以动态的更改. 使用Long.Max_Value意味着空闲线程永远不会终止.
默认实现中，`保持活跃`策略只有在线程数大于核心线程时被应用. 但是`allowCoreThreadTimeOut`可以将这个策略也应用在核心线程上.

* 排队

线程池应用一个`BlockingQueue`来持有提交的任务，这个队列的使用和线程池的大小有关系：

* 如果运行的线程小于核心线程数，优先新建线程而不是入队等待.
* 如果运行线程数大于等于核心线程数，新来的任务优先入队等待而不是新创建线程.
* 如果一个任务不能入队，将会新创建一个线程。如果线程数已经到达最大线程数，这个任务将会被拒绝.

常见的排队策略有三个:

* 直接交接

工作队列的一个默认实现是`SynchronousQueue`,他将任务直接交给线程，而不是使用其他方式来保留任务。
这种实现下，如果当前没有一个线程是立刻可用的，那么入队一个任务将会失败. 因此会创建一个新的线程.
这个策略避免了处理一系列内部依赖的任务时造成的锁定. 直接交接通常要求吴杰的最大线程数，以避免拒绝新任务.
当任务的到达速度，大于处理速度时，线程池将会无限增长.

* 无界队列

使用一个无界队列(没有给定容量的LinkedBlockingQueue)将会使新任务在队列中等待，如果所有的核心线程都在忙碌时.
因此，不会有超过核心线程数的线程被创建. (最大线程数这个参数就没有作用了.)
当任务之间完全互相独立时，这可能是有用的，因为任务不会影响彼此的执行.
比如在web网页服务中.
这个风格的排队策略，在处理平滑的请求速度中的尖刺时很有用，但是当任务的到达速度大于处理速度时，工作队列将会无线增长.

* 有界队列

有界队列防止资源耗尽，但是会更加难以控制.
队列的大小和最大线程数可能会不断影响彼此. 使用大的等待队列和比较小的线程池意味着较小的cpu使用率，系统资源以及上下文切换的浪费，
但是吞吐量会较低. 如果任务频繁的阻塞，系统可能可以调度时间到更多线程，远超过你搜允许的。
使用较小的队列通常要求更大的线程池，会导致CPU繁忙但是可能会遇到不可调度开销，这也会降低吞吐量.

* 拒绝任务

如果当前线程池已经终止了，或者所有的可用线程和工作队列都满了，新提交的任务将会被拒绝.
在这些情况下，执行方法将会调用`RejectedExecutionHandler.rejectedExecution`. 提供了４种预定义的处理策略:

* AbortPolicy 默认实现，拒绝时直接抛出异常
* CallerRunsPolicy 拒绝时让调用方的线程执行这个任务，这是一个反馈型的控制策略，可以让提交任务的速度慢下来
* DiscardPolicy　不能执行的任务直接丢弃掉.
* DiscardOldestPolicy 拒绝时，丢弃掉最老的任务，也就是等待队列的第一个节点.

还可以实现其他的拒绝策略，也可以自己实现

* 挂钩方法

这个类提供了`beforeExecute`和`afterExecute`方法，　在每个任务被执行之前和之后进行调用.
这些方法用来操作执行环境. 比如, 初始化`ThreadLocal`的值, 搜集一些统计信息，或者添加统计信息. 

`terminated`方法可以被重写，以在线程池完全终止后，执行一些特殊的操作.

如果挂钩，回调，等待队列等抛出异常，内部的工作线程可能会失败，终止，或者被替换.

* 队列维护

`getQueue`允许访问工作队列，以用来监控或者进行调试.如果用于其他目的的话，很不好.
当大量排队任务被取消时，`remove`和`purge`两个方法可以用来协助回收存储.

* 回收

程序中不再引用并且没有剩余线程的线程池可以在不显示关闭的情况下，被垃圾回收收集。
您可以通过设置合适的存活时间，使用一个较少的核心线程数，或者允许`allowCoreThreadTimeOut`来允许所有未使用的线程死亡.

* 扩展示例

这个类的大部分扩展类都重写了一个或者多个hook. 比如下面这个子类添加了一个简单的暂停，继续功能:

```java
class PausableThreadPoolExecutor extends ThreadPoolExecutor {
    // 暂停
    private boolean isPaused;
    private ReentrantLock pauseLock = new ReentrantLock();
    private Condition unpaused = pauseLock.newCondition();

    public PausableThreadPoolExecutor(...) { super(...); }

    protected void beforeExecute(Thread t, Runnable r) {
        super.beforeExecute(t, r);
        pauseLock.lock();
        try {
            while (isPaused) unpaused.await();
        } catch (InterruptedException ie) {
            t.interrupt();
        } finally {
            pauseLock.unlock();
        }
    }

    public void pause() {
        pauseLock.lock();
        try {
            isPaused = true;
        } finally {
            pauseLock.unlock();
        }
    }

    public void resume() {
        pauseLock.lock();
        try {
            isPaused = false;
            unpaused.signalAll();
        } finally {
            pauseLock.unlock();
        }
    }
}
```

在执行每一个任务之前，检查当前线程池是否被暂停了，如果是，自旋，等待外部唤醒.


## 源码阅读

### 常量

```java
// 线程数的bit为.
private static final int COUNT_BITS = Integer.SIZE - 3;
// 线程树的掩码
private static final int COUNT_MASK = (1 << COUNT_BITS) - 1;

// runState is stored in the high-order bits
// 高位上存储了线程池的状态
private static final int RUNNING    = -1 << COUNT_BITS;
private static final int SHUTDOWN   =  0 << COUNT_BITS;
private static final int STOP       =  1 << COUNT_BITS;
private static final int TIDYING    =  2 << COUNT_BITS;
private static final int TERMINATED =  3 << COUNT_BITS;

// 默认的拒绝策略，是直接抛出异常
private static final RejectedExecutionHandler defaultHandler =
        new AbortPolicy();

```

由于内部使用一个int来存储当前活跃的线程数和线程池的状态，因为需要一些bit位以及状态的定义，都在常量里面了.

### 变量

```java

// 状态及当前线程数
private final AtomicInteger ctl = new AtomicInteger(ctlOf(RUNNING, 0));


// 工作队列
private final BlockingQueue<Runnable> workQueue;

// 内部锁
private final ReentrantLock mainLock = new ReentrantLock();

// 工作线程
private final HashSet<Worker> workers = new HashSet<>();

// 等待条件
private final Condition termination = mainLock.newCondition();

// 到达过的最大线程数, 是一个实际的数量
private int largestPoolSize;

// 已完成任务数量
private long completedTaskCount;

// 线程工厂，负责创建线程
private volatile ThreadFactory threadFactory;

 // 拒绝策略
private volatile RejectedExecutionHandler handler;

 // 线程空闲后保持活跃的时间
private volatile long keepAliveTime;

 // 是否允许核心线程超时死亡
private volatile boolean allowCoreThreadTimeOut;

 // 核心线程数
private volatile int corePoolSize;

 // 允许的最大线程数,是一个限制数量
private volatile int maximumPoolSize;
```

### 内部同步器　Worker 工作线程

```java
    private final class Worker
        extends AbstractQueuedSynchronizer
        implements Runnable
{
    /**
     * This class will never be serialized, but we provide a
     * serialVersionUID to suppress a javac warning.
     */
    private static final long serialVersionUID = 6138294804551838833L;

    // 线程
    final Thread thread;
    /** Initial task to run.  Possibly null. */
    // 这个线程的第一个任务
    Runnable firstTask;
    /** Per-thread task counter */
    // 完成的任务数量
    volatile long completedTasks;

    // TODO: switch to AbstractQueuedLongSynchronizer and move
    // completedTasks into the lock word.

    /**
     * Creates with given first task and thread from ThreadFactory.
     * @param firstTask the first task (null if none)
     */
    // 第一个需要时，用一个任务创建一个线程
    Worker(Runnable firstTask) {
        setState(-1); // inhibit interrupts until runWorker
        this.firstTask = firstTask;
        this.thread = getThreadFactory().newThread(this);
    }

    /** Delegates main run loop to outer runWorker. */
    public void run() {
        runWorker(this);
    }

    // Lock methods
    //
    // The value 0 represents the unlocked state.
    // The value 1 represents the locked state.

    // 独占锁
    protected boolean isHeldExclusively() {
        return getState() != 0;
    }

    // 申请锁
    protected boolean tryAcquire(int unused) {
        // 从0->1,设置持有锁的线程
        if (compareAndSetState(0, 1)) {
            setExclusiveOwnerThread(Thread.currentThread());
            return true;
        }
        return false;
    }

    // 释放锁
    protected boolean tryRelease(int unused) {
        // 设置为0
        setExclusiveOwnerThread(null);
        setState(0);
        return true;
    }

    // 加解锁
    public void lock()        { acquire(1); }
    public boolean tryLock()  { return tryAcquire(1); }
    public void unlock()      { release(1); }
    public boolean isLocked() { return isHeldExclusively(); }

    // 如果工作线程启动了，就中断它
    void interruptIfStarted() {
        Thread t;
        // State大于0 -> 启动了
        // thread !=null -> 正在运行且没有中断
        if (getState() >= 0 && (t = thread) != null && !t.isInterrupted()) {
            try {
                // 中断它
                t.interrupt();
            } catch (SecurityException ignore) {
            }
        }
    }

    // 其实是ThreadPoolExecutor的方法，但是只有在这里面用了，我就挪进来了
    final void runWorker(Worker w) {
        Thread wt = Thread.currentThread();
        // 第一个任务
        Runnable task = w.firstTask;
        w.firstTask = null;
        w.unlock(); // allow interrupts // 状态设置为0,代表这个工作线程启动了，可以响应中断了
        boolean completedAbruptly = true;
        try {
            // 有任务
            while (task != null || (task = getTask()) != null) {
                // 加锁
                w.lock();
                // If pool is stopping, ensure thread is interrupted;
                // if not, ensure thread is not interrupted.  This
                // requires a recheck in second case to deal with
                // shutdownNow race while clearing interrupt
                if ((runStateAtLeast(ctl.get(), STOP) ||
                        (Thread.interrupted() &&
                                runStateAtLeast(ctl.get(), STOP))) &&
                        !wt.isInterrupted())
                    wt.interrupt();
                try {
                    // 调用before挂钩
                    beforeExecute(wt, task);
                    try {
                        // 执行任务
                        task.run();
                        // 调用after挂钩
                        afterExecute(task, null);
                    } catch (Throwable ex) {
                        // 出错也得执行挂钩
                        afterExecute(task, ex);
                        throw ex;
                    }
                } finally {
                    // 任务为空
                    task = null;
                    // 完成任务+1
                    w.completedTasks++;
                    // 解锁
                    w.unlock();
                }
            }
            completedAbruptly = false;
        } finally {
            processWorkerExit(w, completedAbruptly);
        }
    }
}
```


### 构造方法

这个类提供了4个构造方法，不过本质上都是最后一个.

```java
    public ThreadPoolExecutor(int corePoolSize,
                              int maximumPoolSize,
                              long keepAliveTime,
                              TimeUnit unit,
                              BlockingQueue<Runnable> workQueue,
                              ThreadFactory threadFactory,
                              RejectedExecutionHandler handler) {
                              
        if (corePoolSize < 0 ||
            maximumPoolSize <= 0 ||
            maximumPoolSize < corePoolSize ||
            keepAliveTime < 0)
            throw new IllegalArgumentException();
        if (workQueue == null || threadFactory == null || handler == null)
            throw new NullPointerException();
        this.corePoolSize = corePoolSize;
        this.maximumPoolSize = maximumPoolSize;
        this.workQueue = workQueue;
        this.keepAliveTime = unit.toNanos(keepAliveTime);
        this.threadFactory = threadFactory;
        this.handler = handler;
    }

```

比较简单，首先做了一些参数的检查，之后进行赋值.

### 提交任务 execute

一个线程池，最重要，最常用的方法就是提交任务了，让我们从这里开始正式的看代码.

```java
    public void execute(Runnable command) {
        // 为空，抛出异常
        if (command == null)
            throw new NullPointerException();
        /*
         * Proceed in 3 steps:
         *
         * 1. If fewer than corePoolSize threads are running, try to
         * start a new thread with the given command as its first
         * task.  The call to addWorker atomically checks runState and
         * workerCount, and so prevents false alarms that would add
         * threads when it shouldn't, by returning false.
         *
         * 2. If a task can be successfully queued, then we still need
         * to double-check whether we should have added a thread
         * (because existing ones died since last checking) or that
         * the pool shut down since entry into this method. So we
         * recheck state and if necessary roll back the enqueuing if
         * stopped, or start a new thread if there are none.
         *
         * 3. If we cannot queue task, then we try to add a new
         * thread.  If it fails, we know we are shut down or saturated
         * and so reject the task.
         */
        int c = ctl.get();
        // 当前线程数，小于核心线程数，直接新增一个工作线程
        if (workerCountOf(c) < corePoolSize) {
            if (addWorker(command, true))
                return;
            c = ctl.get();
        }
        // 如果线程数大于核心线程数，且当前任务入队成功.
        if (isRunning(c) && workQueue.offer(command)) {
            int recheck = ctl.get();
            // 再次检查，如果当前线程池关闭了，移除任务，拒绝任务
            if (! isRunning(recheck) && remove(command))
                reject(command);
            // 如果再次检查时工作线程为0,就新增一个工作线程
            else if (workerCountOf(recheck) == 0)
                addWorker(null, false);
        }
        // 如果新增工作线程失败，说明工作线程数达到最大线程数了，且工作队列满了，拒绝任务
        else if (!addWorker(command, false))
            reject(command);
    }

```

将一个任务提交至线程池，主要有三个分支:

* 当前工作线程数小于核心线程数，**新增一个工作线程**
* 如果线程大于核心线程数，但是可以入队成功. 
* 如果新增线程失败，且工作队列满了，就**拒绝任务**.

这里涉及到最重要的一个方法，就是新增一个工作线程.

#### 新增工作线程 addWorker

新增工作线程时，需要提供两个参数:

新增的第一个任务, 以及是否是核心线程

```java
    private boolean addWorker(Runnable firstTask, boolean core) {
        retry:
        for (int c = ctl.get();;) {
            // Check if queue empty only if necessary.
            // 1. 线程池没有在运行
            // 2. 线程池已经终止, 第一个任务不为空, 队列为空三选一
            // 这两个条件都满足，直接返回失败
            if (runStateAtLeast(c, SHUTDOWN)
                && (runStateAtLeast(c, STOP)
                    || firstTask != null
                    || workQueue.isEmpty()))
                return false;

            for (;;) {
                // 这次申请的新工作线程，数量超过允许了，要么超过核心线程数，要么超过了最大线程数, 返回失败
                if (workerCountOf(c)
                    >= ((core ? corePoolSize : maximumPoolSize) & COUNT_MASK))
                    return false;
                // 增加工作线程计数成功，退出外层循环
                if (compareAndIncrementWorkerCount(c))
                    break retry;
                // 状态C
                c = ctl.get();  // Re-read ctl
                // 如果线程池没在运行，继续外层循环，要么失败退出，要么CAS递增数量成功
                if (runStateAtLeast(c, SHUTDOWN))
                    continue retry;
                // else CAS failed due to workerCount change; retry inner loop
            }
        }

        boolean workerStarted = false;
        boolean workerAdded = false;
        Worker w = null;
        try {
            // 新建工作线程
            w = new Worker(firstTask);
            final Thread t = w.thread;
            // 要能从工厂拿到一个ok 的线程
            if (t != null) {
                // 加锁
                final ReentrantLock mainLock = this.mainLock;
                mainLock.lock();
                try {
                    // Recheck while holding lock.
                    // Back out on ThreadFactory failure or if
                    // shut down before lock acquired.
                    int c = ctl.get();

                    // 再一次检查状态，害怕在获取锁之前被改了
                    if (isRunning(c) ||
                        (runStateLessThan(c, STOP) && firstTask == null)) {
                        if (t.getState() != Thread.State.NEW)
                            throw new IllegalThreadStateException();
                        // 添加这个工作线程
                        workers.add(w);
                        workerAdded = true;
                        int s = workers.size();
                        // 更新到达过的最大线程数
                        if (s > largestPoolSize)
                            largestPoolSize = s;
                    }
                } finally {
                    // 解锁
                    mainLock.unlock();
                }
                // 如果添加成功了，就运行它
                if (workerAdded) {
                    t.start();
                    workerStarted = true;
                }
            }
        } finally {
            // 失败了
            if (! workerStarted)
                addWorkerFailed(w);
        }
        // 返回是否: 新增一个工作线程，且让他运行了
        return workerStarted;
    }

    // 添加一个工作线程失败了
    private void addWorkerFailed(Worker w) {
        final ReentrantLock mainLock = this.mainLock;
        mainLock.lock();
        try {
            // 如果刚才创建了，就移除掉
            if (w != null)
            workers.remove(w);
            // 减去一个工作线程
            decrementWorkerCount();
            // 终止线程池 
            tryTerminate();
        } finally {
            mainLock.unlock();
        }
    }
    
    // 尝试终止线程池
    final void tryTerminate() {
        for (;;) {
            // 线程池还在跑，终止不了
            int c = ctl.get();
            if (isRunning(c) ||
                runStateAtLeast(c, TIDYING) ||
                (runStateLessThan(c, STOP) && ! workQueue.isEmpty()))
                return;
            
            // 工作线程大于0,把空闲的都给中断掉
            if (workerCountOf(c) != 0) { // Eligible to terminate
                interruptIdleWorkers(ONLY_ONE);
                return;
            }

            // 到这里已经线程池已经完蛋了
            final ReentrantLock mainLock = this.mainLock;
            mainLock.lock();
            try {
                // 设置状态为整理中
                if (ctl.compareAndSet(c, ctlOf(TIDYING, 0))) {
                    try {
                        // 终止后可以用来执行一个行为的hook. 可以被子类重写.
                        terminated();
                    } finally {
                        // 设置状态为成功终止
                        ctl.set(ctlOf(TERMINATED, 0));
                        termination.signalAll();
                    }
                    return;
                }
            } finally {
                mainLock.unlock();
            }
            // else retry on failed CAS
        }
    }

```

上面已经备注了一些关键注释，这里再总结下新增工作线程时做了什么:

1. 如果线程池状态不ok,返回失败.
2. 自旋判断数量是否超出核心线程数或者最大线程数的限制，没有的话尝试增加工作线程计数.直到成功
3. 新建一个工作线程(同时从线程工厂新创建一个线程),将工作线程添加到集合中，然后让工作线程运行第一个任务.
4. 如果期间失败了，就清理相关属性，尝试终止线程池.

### 任务出队

在提交任务时，如果核心线程数满了，此时会将任务放入工作队列，那么什么时候出队呢?

每一个工作线程启动后，首先会执行创建它时的第一个任务，执行完后，会调用`getTask()`来获取下一个任务.

```java
    // 为当前的工作线程，获取下一个任务
    private Runnable getTask() {
        boolean timedOut = false; // Did the last poll() time out?

        for (;;) {
            // 当前状态
            int c = ctl.get();

            // Check if queue empty only if necessary.
            // 状态不ok,返回null
            if (runStateAtLeast(c, SHUTDOWN)
                && (runStateAtLeast(c, STOP) || workQueue.isEmpty())) {
                decrementWorkerCount();
                return null;
            }

            // 工作线程数
            int wc = workerCountOf(c);

            // Are workers subject to culling?
            // 是否要过期死亡
            boolean timed = allowCoreThreadTimeOut || wc > corePoolSize;

            // 1. 数量超过最大线程数了 或者 已经空闲超过给定时间了
            // 2. 工作线程数大于1, 等待队列为空
            if ((wc > maximumPoolSize || (timed && timedOut))
                && (wc > 1 || workQueue.isEmpty())) {
                // CAS递减工作线程数成功, 返回null, 让调用的工作线程死去吧
                if (compareAndDecrementWorkerCount(c))
                    return null;
                continue;
            }

            try {
                // 从队列中获取第一个元素
                Runnable r = timed ?
                    workQueue.poll(keepAliveTime, TimeUnit.NANOSECONDS) :
                    workQueue.take();
                // 返回这个任务
                if (r != null)
                    return r;
                // 拿到的为空，说明超时了，调用方的线程可以去死了
                timedOut = true;
            } catch (InterruptedException retry) {
                timedOut = false;
            }
        }
    }
```

这个方法比较简单，核心思路就是从等待队列中获取第一个元素，给调用的工作线程执行.

只是在其中夹杂了一些是否需要超时死亡，是否已经超时的代码. 用是否返回一个任务，来控制调用方的工作线程是否应该死亡.

### 如何拒绝任务?

回顾下拒绝任务的几种情况:

1. 线程池终止了
2. 线程池的工作线程以及工作队列都满了.

拒绝时调用`reject(command)`.

```java
    final void reject(Runnable command) {
        handler.rejectedExecution(command, this);
    }
```

额，比较简单，就是直接调用`RejectedExecutionHandler.rejectedExecution`方法，因此当需要实现自己的拒绝策略时，记得实现一个这个接口的实现类即可.

### 等待终止

经常在我们提交完任务后，想要等线程池中的所有方法执行完毕，我们再进行下一步操作，这个当然是可以通过`CountDownLatch`和`CyclicBarrier`等同步器来实现的,但是线程池其实已经实现了类似的功能.

```java
    // 手动关闭线程池
    public void shutdown() {
        final ReentrantLock mainLock = this.mainLock;
        mainLock.lock();
        try {
            // 检查权限
            checkShutdownAccess();
            // 更改状态
            advanceRunState(SHUTDOWN);
            // 中断空闲的工作者
            interruptIdleWorkers();
            onShutdown(); // hook for ScheduledThreadPoolExecutor
        } finally {
            mainLock.unlock();
        }
        // 尝试关闭线程池
        tryTerminate();
    }

    public boolean awaitTermination(long timeout, TimeUnit unit)
        throws InterruptedException {
        long nanos = unit.toNanos(timeout);
        // 加锁
        final ReentrantLock mainLock = this.mainLock;
        mainLock.lock();
        try {
            while (runStateLessThan(ctl.get(), TERMINATED)) {
                if (nanos <= 0L)
                    return false;
                // 休眠
                nanos = termination.awaitNanos(nanos);
            }
            return true;
        } finally {
            mainLock.unlock();
        }
    }
```

分为两步.

1. 手动调用`shutdown`来关闭线程池,线程池会将所有能关闭的工作线程都关闭掉.之后尝试终止线程池
2. 阻塞调用`awaitTermination`来等待线程池关闭，继续下一个步骤.

### 预热线程

如果在创建线程池之前，已经有一个有大量值的工作队列，我们可能希望预创建一些线程.

* prestartAllCoreThreads 预创建所有线程
* prestartCoreThread 预创建核心线程

### 删除任务

如果我们已经提交了一个任务，后悔了，或者说我们想删除掉所有等待的任务怎么办呢?

```java
    // 移除给定任务
    public boolean remove(Runnable task) {
        boolean removed = workQueue.remove(task);
        tryTerminate(); // In case SHUTDOWN and now empty
        return removed;
    }
    
    // 遍历等待队列，移除掉所有在等待的任务
    public void purge() {
        final BlockingQueue<Runnable> q = workQueue;
        try {
            Iterator<Runnable> it = q.iterator();
            while (it.hasNext()) {
                Runnable r = it.next();
                if (r instanceof Future<?> && ((Future<?>)r).isCancelled())
                    it.remove();
            }
        } catch (ConcurrentModificationException fallThrough) {
            // Take slow path if we encounter interference during traversal.
            // Make copy for traversal and call remove for cancelled entries.
            // The slow path is more likely to be O(N*N).
            for (Object r : q.toArray())
                if (r instanceof Future<?> && ((Future<?>)r).isCancelled())
                    q.remove(r);
        }

        tryTerminate(); // In case SHUTDOWN and now empty
    }
```

### 监控方法

这个类提供了大量的get/set方法，来监控当前线程池内的各种状态，以及动态的修改一些参数.

* isShutdown 是否关闭
* isTerminating 是否正在终止
* isTerminated 是否已经终止
* setThreadFactory 设置线程工厂
* getThreadFactory 获取线程工厂
* setRejectedExecutionHandler 设置拒绝策略
* getRejectedExecutionHandler 获取拒绝策略
* setCorePoolSize 设置核心线程数
* getCorePoolSize 获取核心线程数
* allowsCoreThreadTimeOut 核心线程是否允许超时死亡
* setMaximumPoolSize 设置最大线程数
* getMaximumPoolSize 获取最大线程数
* setKeepAliveTime 设置活跃时间
* getKeepAliveTime  获取活跃时间
* getQueue 获取工作队列
* getPoolSize 获取当前线程池的大小
* getActiveCount 获取活跃工作线程数量
* getLargestPoolSize 获取到达过的最大线程池大小
* getTaskCount 获取任务数量
* getCompletedTaskCount 获取已经完成的任务数量

### 线程工厂

线程工厂实现了`ThreadFactory`接口. 在`Executors`中的默认实现为:

```java
    private static class DefaultThreadFactory implements ThreadFactory {
        // 数量
        private static final AtomicInteger poolNumber = new AtomicInteger(1);
        // 分组
        private final ThreadGroup group;
        // 数量
        private final AtomicInteger threadNumber = new AtomicInteger(1);
        // 名字前缀
        private final String namePrefix;

        // 工厂构造方法
        DefaultThreadFactory() {
            SecurityManager s = System.getSecurityManager();
            // 同一个线程组
            group = (s != null) ? s.getThreadGroup() :
                                  Thread.currentThread().getThreadGroup();
            // 固定的前缀
            namePrefix = "pool-" +
                          poolNumber.getAndIncrement() +
                         "-thread-";
        }

        public Thread newThread(Runnable r) {
            // 创建一个线程
            Thread t = new Thread(group, r,
                                  namePrefix + threadNumber.getAndIncrement(),
                                  0);
            // 不是守护线程
            if (t.isDaemon())
                t.setDaemon(false);
            // 优先级为统一的正常优先级
            if (t.getPriority() != Thread.NORM_PRIORITY)
                t.setPriority(Thread.NORM_PRIORITY);
            return t;
        }
    }
```

比较简单，采用统一的线程组，递增的线程池编号，递增的线程编号，统一的前缀，不是守护线程作为参数创建一个线程.


### 拒绝策略

`ThreadPoolExecutor`默认提供了4种拒绝策略.

* AbortPolicy 默认实现，拒绝时直接抛出异常
* CallerRunsPolicy 拒绝时让调用方的线程执行这个任务，这是一个反馈型的控制策略，可以让提交任务的速度慢下来
* DiscardPolicy　不能执行的任务直接丢弃掉.
* DiscardOldestPolicy 拒绝时，丢弃掉最老的任务，也就是等待队列的第一个节点.

实际上根据需要，可以自己实现一些策略，这里简单列举两个:

1. 让调用方等待

```java
public static class WaitPolicy implements RejectedExecutionHandler {
    public WaitPolicy() {
    }

    public void rejectedExecution(Runnable r, ThreadPoolExecutor executor) {
        try {
            // 调用阻塞方法put,向等待队列中添加任务
            executor.getQueue().put(r);
        } catch (InterruptedException var4) {
        }

    }
}
```

上面的示例，调用阻塞方法put，在线程池中有一个任务完成，等待队列中空出一个位置时，该方法得以继续向下运行.

如果每个任务运行时间足够长，这个策略会导致提交任务的线程长时间阻塞，比较浪费.

2. 添加日志等

```java
    private static class MyRejectPolicy implements RejectedExecutionHandler {

        @Override
        public void rejectedExecution(Runnable r, ThreadPoolExecutor executor) {
            System.out.println("reject me,555");
            // send email ...
        }
    }
```

当一些重要程序中，发生异常，导致异常拒绝，需要打印日志，并发送邮件等通知开发者.

3. 强行新建线程运行

```java
private static final class NewThreadRunsPolicy implements RejectedExecutionHandler {
    NewThreadRunsPolicy() {
        super();
    }

    public void rejectedExecution(Runnable r, ThreadPoolExecutor executor) {
        try {
            final Thread t = new Thread(r, "Temporary task executor");
            t.start();
        } catch (Throwable e) {
            throw new RejectedExecutionException(
                    "Failed to start a new thread", e);
        }
    }
}
```

有时，我们宁愿服务器累死，也不想拒绝任务，可以使用这个.

不管任何强行，强行创建一个不受线程池管理的线程，去运行这个任务.


### 线程池工厂

19年介绍过`Executors`提供的4个工厂方法，这里不重复了.

[Java中executors提供的的4种线程池](http://huyan.couplecoders.tech/java%E9%9D%A2%E8%AF%95/java/%E5%A4%9A%E7%BA%BF%E7%A8%8B/java.util.concurrent/2019/03/07/Java%E4%B8%ADExecutors%E6%8F%90%E4%BE%9B%E7%9A%84%E7%9A%844%E7%A7%8D%E7%BA%BF%E7%A8%8B%E6%B1%A0/)


完.

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