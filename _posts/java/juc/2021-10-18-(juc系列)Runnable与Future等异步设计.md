---
layout: post
category: [Java,JUC]
tags:
  - Java
  - JUC
---

这是JUC包中，与Future异步等相关的类图.

![2021-10-18-18-03-24](http://img.couplecoders.tech/2021-10-18-18-03-24.png)

简单的介绍以及记录. 偏意识流.

首先看一下最基本的`Runnable`

## Runnable

`Runable`接口， 应该由那些想要被线程执行的类来实现.它定义了一个无参数，无返回值的`run()`方法，负责运行代码段.

通俗点理解，`Runnable`接口，定义了`可被运行`这个概念。定义一个类，实现Runnable,将运行逻辑写入`run`方法，那么这个类可以手动进行执行，也可以交给线程来调度.

## Future

`Future`代表异步计算的结果. 提供了检查计算

* 计算是否完成
* 等待完成
* 获取计算结果

等等方法.

使用**get()**方法可以获取计算的结果，如果计算还没有完成，就等待.

还提供了判断任务是完成还是取消掉了的方法. 一旦任务完成，就不可以再取消了. 如果你想执行一个可取消的，但是没有结果的计算任务，可以使用`Future<?>`.然后返回null.

提供了以下方法:

* cancel 取消任务
* isCancelled 判断任务是否取消
* isDone 是否完成
* get 获取结果
* get(time) 等待一定的时间来获取结果，超时抛出异常

在JDK中，Future的子接口和子类还是比较多的，一个一个看一下.

### ScheduleFuture

```java

public interface ScheduledFuture<V> extends Delayed, Future<V> {
}
```

实现了`Future`和`Delyed`. 在Future的基础上，提供了延迟的功能.

### RunnableFuture

```java
    public interface RunnableFuture<V> extends Runnable, Future<V> {
/**
* Sets this Future to the result of its computation
* unless it has been cancelled.
  */
        void run();
    }
```

同时实现了`Future`和`Runnable`. 这个接口的子类，可以被执行，且通过`Future`拿到结果.

### RunnableScheduledFuture

实现了上方的两个接口，这个接口的子类可以被执行，可以被调度，可以拿到结果.

```java
public interface RunnableScheduledFuture<V> extends RunnableFuture<V>, ScheduledFuture<V> {

    /**
     * Returns {@code true} if this task is periodic. A periodic task may
     * re-run according to some schedule. A non-periodic task can be
     * run only once.
     *
     * @return {@code true} if this task is periodic
     */
    boolean isPeriodic();
}
```

### FutureTask

这是`RunnableFuture`的一个实现类，那么就具有相关的特性

* 可被执行
* 可以拿到结果

具体看看实现.


#### 属性

```java

    // 核心状态
    private volatile int state;
    // 状态的一些常量
    private static final int NEW          = 0;
    private static final int COMPLETING   = 1;
    private static final int NORMAL       = 2;
    private static final int EXCEPTIONAL  = 3;
    private static final int CANCELLED    = 4;
    private static final int INTERRUPTING = 5;
    private static final int INTERRUPTED  = 6;

    // 底层的Callable
    private Callable<V> callable;
    // 返回值或者抛出的异常
    private Object outcome; // non-volatile, protected by state reads/writes
    // 线程
    private volatile Thread runner;
    // 等待线程
    private volatile WaitNode waiters;
```

#### 构造方法

```java

    public FutureTask(Callable<V> callable) {
        if (callable == null)
            throw new NullPointerException();
        this.callable = callable;
        this.state = NEW;       // ensure visibility of callable
    }

    public FutureTask(Runnable runnable, V result) {
        this.callable = Executors.callable(runnable, result);
        this.state = NEW;       // ensure visibility of callable
    }
```

两个构造方法，分别提供与对`Callable`和`Runnable`的包装.且将状态赋值为New.

#### Runnable 执行

```java
    public void run() {
        // 如果任务状态不对，或者设置当前线程为运行线程失败，就退出
        if (state != NEW ||
            !RUNNER.compareAndSet(this, null, Thread.currentThread()))
            return;
        try {
            Callable<V> c = callable;
            if (c != null && state == NEW) {
                V result;
                boolean ran;
                try {
                    // 执行任务
                    result = c.call();
                    ran = true;
                } catch (Throwable ex) {
                    result = null;
                    ran = false;
                    // 抛出异常
                    setException(ex);
                }
                if (ran)
                    // 设置返回结果
                    set(result);
            }
        } finally {
            // 清理状态
            // runner must be non-null until state is settled to
            // prevent concurrent calls to run()
            runner = null;
            // state must be re-read after nulling runner to prevent
            // leaked interrupts
            int s = state;
            if (s >= INTERRUPTING)
                handlePossibleCancellationInterrupt(s);
        }
    }
```

实现`Runnable`的`run`方法.

1. 检查状态
2. 运行内部持有的`Callable`.
3. 出错就抛出异常
4. 成功执行结束就设置返回值.
5. 清理状态.

当执行成功时，设置相关属性:

```java
    protected void set(V v) {
        // 设置状态为正在完成中
        if (STATE.compareAndSet(this, NEW, COMPLETING)) {
            // 返回值为结果
            outcome = v;
            // 设置状态
            STATE.setRelease(this, NORMAL); // final state
            // 调用完成
            finishCompletion();
        }
    }
    

    private void finishCompletion() {
        // assert state > COMPLETING;
        // 将所有等待者，全部唤醒
        for (WaitNode q; (q = waiters) != null;) {
            if (WAITERS.weakCompareAndSet(this, q, null)) {
                for (;;) {
                    Thread t = q.thread;
                    if (t != null) {
                        q.thread = null;
                        LockSupport.unpark(t);
                    }
                    WaitNode next = q.next;
                    if (next == null)
                        break;
                    q.next = null; // unlink to help gc
                    q = next;
                }
                break;
            }
        }

        // 调用完成后的hook方法，留给子类去实现一些特殊的逻辑.
        done();

        callable = null;        // to reduce footprint
    }

```

当任务成功执行完之后，首先将所有等待的线程全部唤醒. 之后调用一个hook方法. 也就是`done`.这是留给子类的一个方法，可以方便的通过重写来实现特殊逻辑.

#### Future相关 获取结果

##### get 结果

get方法有永不超时和带有超时时间的两个版本. 本质上都是调用`awaitDone`.
```java

    private int awaitDone(boolean timed, long nanos)
        throws InterruptedException {
        // The code below is very delicate, to achieve these goals:
        // - call nanoTime exactly once for each call to park
        // - if nanos <= 0L, return promptly without allocation or nanoTime
        // - if nanos == Long.MIN_VALUE, don't underflow
        // - if nanos == Long.MAX_VALUE, and nanoTime is non-monotonic
        //   and we suffer a spurious wakeup, we will do no worse than
        //   to park-spin for a while
        long startTime = 0L;    // Special value 0L means not yet parked
        WaitNode q = null;
        boolean queued = false;
        // 自旋进行等待
        for (;;) {
            // 完成了，返回状态
            int s = state;
            if (s > COMPLETING) {
                if (q != null)
                    q.thread = null;
                return s;
            }
            // 等一会
            else if (s == COMPLETING)
                // We may have already promised (via isDone) that we are done
                // so never return empty-handed or throw InterruptedException
                Thread.yield();
            // 线程中断了，取消所有等待者
            else if (Thread.interrupted()) {
                removeWaiter(q);
                throw new InterruptedException();
            }
            // 添加新的等待者
            else if (q == null) {
                if (timed && nanos <= 0L)
                    return s;
                q = new WaitNode();
            }
            else if (!queued)
                queued = WAITERS.weakCompareAndSet(this, q.next = waiters, q);
            else if (timed) {
                final long parkNanos;
                if (startTime == 0L) { // first time
                    startTime = System.nanoTime();
                    if (startTime == 0L)
                        startTime = 1L;
                    parkNanos = nanos;
                } else {
                    long elapsed = System.nanoTime() - startTime;
                    if (elapsed >= nanos) {
                        removeWaiter(q);
                        return state;
                    }
                    parkNanos = nanos - elapsed;
                }
                // 等待
                // nanoTime may be slow; recheck before parking
                if (state < COMPLETING)
                    LockSupport.parkNanos(this, parkNanos);
            }
            else
                LockSupport.park(this);
        }
    }
```

这是一个等待执行完成或者超时/中断的方法.

1. 如果状态显示已经执行完成，返回结果
2. 如果状态显示正在执行，当前线程让出线程执行时间》
3. 如果线程被中断了，移除等待者，抛出中断异常.
4. 如果当前节点没有初始化，就初始化一个Node.
5. 如果没有入队，就把当前线程放到等待链表中.
6. 如果有超时设置：
    1. 没超时，就等待一会.
    2. 超时了，移除等待者，返回状态
7. 如果没有超时设置，当前线程直接阻塞.

##### removeWaiters 移除等待线程

当一个任务有多个等待线程时，如果正常完成了，那么需要唤醒所有等待线程。

如果在等待过程中，当前线程超时了，那么就需要移除掉自身Node.不再等待.

```java
    private void removeWaiter(WaitNode node) {
        if (node != null) {
            node.thread = null;
            retry:
            for (;;) {          // restart on removeWaiter race
                for (WaitNode pred = null, q = waiters, s; q != null; q = s) {
                    s = q.next;
                    if (q.thread != null)
                        pred = q;
                    else if (pred != null) {
                        pred.next = s;
                        if (pred.thread == null) // check for race
                            continue retry;
                    }
                    else if (!WAITERS.compareAndSet(this, q, s))
                        continue retry;
                }
                break;
            }
        }
    }
```

##### 取消任务 cancel

```java

    public boolean cancel(boolean mayInterruptIfRunning) {
        // 任务必须还是新创建的状态，如果不是就取消失败
        if (!(state == NEW && STATE.compareAndSet
              (this, NEW, mayInterruptIfRunning ? INTERRUPTING : CANCELLED)))
            return false;
        try {    // in case call to interrupt throws exception
            // 中断线程
            if (mayInterruptIfRunning) {
                try {
                    Thread t = runner;
                    if (t != null)
                        t.interrupt();
                } finally { // final state
                    STATE.setRelease(this, INTERRUPTED);
                }
            }
        } finally {
            // 任务执行完成，虽然是取消导致的完成.
            finishCompletion();
        }
        return true;
    }
```

判断状态, 然后中断线程，设置任务已经完成.

##### 查看状态

```java

    // 取消了
    public boolean isCancelled() {
        return state >= CANCELLED;
    }

    // 状态不是new. 代表任务完成.
    public boolean isDone() {
        return state != NEW;
    }
```

#### ForkJoinTask

这是用于`ForkJoinPool`的一个任务实现，它以及它的三个子类

* RecuriveAction
* RecuriveTask
* CountedCompleter

已经在[ForkJoin框架](http://huyan.couplecoders.tech/java/2021/10/14/(juc%E7%B3%BB%E5%88%97)ForkJoin%E6%A1%86%E6%9E%B6%E6%BA%90%E7%A0%81%E5%AD%A6%E4%B9%A0/)文章中讲过了，这里不再赘述.


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