---
layout: post
tags:
  - Java
  - JUC
  - 线程池
---

## 前言

这是Java中常用的另外一个线程池，主要用于实现**任务的延迟执行及周期性执行**.

听起来与`Timer`很相似，但是比`Timer`更加健壮，灵活一些。

## 简介

官方注释翻译:

> 一个可以延迟执行命令，或者周期性执行命令的`ThreadPoolExecutor`.
> 如果需要多个工作线程，这个类就比Timer更加好用了,或者当你需要比Timer更加灵活，健壮的线程池时，也使用这个类.

>延迟任务在他们可用之后很快被执行，但是不完全保证实时. 任务被严格按照FIFO的顺序进行调度。

> 当一个提交的任务在执行前被取消了,执行就不会进行了. 默认情况下，一个取消了的任务在他的延迟时间到达之前，不会从工作队列中移除.
> 因为没有启用一些检查和监控，这会导致保留了过多的已取消任务。为了避免这种情况，使用`setRemoveOnCancelPolicy`方法来让任务在取消时立即从工作队列中移除.

> 不同的执行，可能会使用不同的工作线程. 

> 因为这个类继承了`ThreadPoolExecutor`. 一些继承的方法没有用.

> 和`ThreadPoolExecutor`一样，如果没有特殊情况，这个类也使用`Executors.defaultThreadFactory`来创建线程，也使用`ThreadPoolExecutor.AbortPolicy`作为默认的拒绝策略.

> 注意事项: 这个类重写了`execute`和`submit`方法，去生成内部的`ScheduledFuture`对象，以此来控制每个任务的延时和调度.
> 所有重写了这两个方法的子类，必须要调用父类的方法。

简单地说，这个类继承自`ThreadPoolExecutor`，父类有的他都有。
除此之外.添加了对任务的延迟执行及周期性执行。

来看看实现～.

## 源码

### ScheduledFutureTask 任务结构

为了实现延迟及周期性执行，实现了一个基于`FutureTask`的任务结构.

#### 定义
```java
    private class ScheduledFutureTask<V>
            extends FutureTask<V> implements RunnableScheduledFuture<V> {
```

这个任务类，继承自`FutureTask`，同时实现了`RunnableScheduleFuture`接口.

#### 属性
```java

        // 为了保证FIFO.设置的一个序列号
        private final long sequenceNumber;

        // 延迟执行的纳秒数字
        private volatile long time;

         // 周期性执行的任务，周期的纳秒数
        private final long period;

        // 实际执行的任务，也就是要被调度的任务
        RunnableScheduledFuture<V> outerTask = this;

         // 在延迟队列中的索引，方便用来快速的取消任务
        int heapIndex;
```

可以看到，除了`FutureTask`父类的属性外，额外保存了延迟时间和周期时间的参数，而由于周期性任务是要被不断的执行的，因为使用`outerTask`来保存实际的任务.

#### 构造方法
```java

        ScheduledFutureTask(Runnable r, V result, long triggerTime,
                            long sequenceNumber) {
            super(r, result);
            this.time = triggerTime;
            this.period = 0;
            this.sequenceNumber = sequenceNumber;
        }

        ScheduledFutureTask(Runnable r, V result, long triggerTime,
                            long period, long sequenceNumber) {
            super(r, result);
            this.time = triggerTime;
            this.period = period;
            this.sequenceNumber = sequenceNumber;
        }

        ScheduledFutureTask(Callable<V> callable, long triggerTime,
                            long sequenceNumber) {
            super(callable);
            this.time = triggerTime;
            this.period = 0;
            this.sequenceNumber = sequenceNumber;
        }
```

提供了三个构造方法，全是赋值型的方法重载，没啥说的.


#### compareTo 优先级

由于在线程池内部的优先级队列中，需要一个优先级. 这里通过重写`compareTo`方法，实现了优先级的定义.

```java

        public int compareTo(Delayed other) {
            if (other == this) // compare zero if same object
                return 0;
            if (other instanceof ScheduledFutureTask) {
                ScheduledFutureTask<?> x = (ScheduledFutureTask<?>)other;
                long diff = time - x.time;
                if (diff < 0)
                    return -1;
                else if (diff > 0)
                    return 1;
                else if (sequenceNumber < x.sequenceNumber)
                    return -1;
                else
                    return 1;
            }
            long diff = getDelay(NANOSECONDS) - other.getDelay(NANOSECONDS);
            return (diff < 0) ? -1 : (diff > 0) ? 1 : 0;
        }

```

优先级使用三个属性定义:

1. 下一次执行时间
2. 序列号
3. 任务提交时间

所以说优先级队列的队首，放的永远是下一个要被执行的任务.

也许和第二名的执行时间一样，但是序列号晚，或者提交时间晚.

#### run 核心执行方法

```java

        public void run() {
            // 当前不能执行，取消
            if (!canRunInCurrentRunState(this))
                cancel(false);
            // 不是周期性任务，执行一次
            else if (!isPeriodic())
                super.run();
            // 是周期性任务，执行一次,且将状态设置为最初的样子，也就是reset.
            else if (super.runAndReset()) {
                setNextRunTime();
                reExecutePeriodic(outerTask);
            }
        }

```

这里重写了`FutureTask`的`run`方法，为了支持周期性的一个属性设置.

有三个分支:

1. 当前任务不能执行，直接取消任务
2. 当前任务可以执行，不是周期性任务，调用`run`执行一次即可。
3. 当前任务可以执行，是周期性任务. 
    1. 执行一次run.且将当前Future的状态设置为最初的样子.
    2. 设置下一次运行的时间.
    3. 将下一次的任务放入工作队列.

其中涉及到另外两个方法:

* setNextRunTime

设置下一次的执行时间，对于周期性任务来说，下一次执行时间就是`当前时间+周期时间`。
```java

        private void setNextRunTime() {
            long p = period;
            if (p > 0)
                time += p;
            else
                time = triggerTime(-p);
        }

```

* reExecutePeriodic

将当前任务再次入队，等待调度执行.
```java

    void reExecutePeriodic(RunnableScheduledFuture<?> task) {
        if (canRunInCurrentRunState(task)) {
            super.getQueue().add(task);
            if (canRunInCurrentRunState(task) || !remove(task)) {
                ensurePrestart();
                return;
            }
        }
        task.cancel(false);
    }
```

如果当前状态没问题，就将任务放入工作队列，然后确保有工作线程是活着的.

否则就取消任务.

#### 取消 cancel
```java

        public boolean cancel(boolean mayInterruptIfRunning) {
            // The racy read of heapIndex below is benign:
            // if heapIndex < 0, then OOTA guarantees that we have surely
            // been removed; else we recheck under lock in remove()
            boolean cancelled = super.cancel(mayInterruptIfRunning);
            if (cancelled && removeOnCancel && heapIndex >= 0)
                remove(this);
            return cancelled;
        }
```

调用父类`cancel`取消掉当前任务，如果需要立即移除掉工作队列中的任务，就移除.

### ScheduleThreadPoolExecutor 构造方法

这个类没有什么属性，完全应用了父类的属性，因此构造方法也是对父类参数的一些赋值操作.

```java

    public ScheduledThreadPoolExecutor(int corePoolSize) {
        super(corePoolSize, Integer.MAX_VALUE,
              DEFAULT_KEEPALIVE_MILLIS, MILLISECONDS,
              new DelayedWorkQueue());
    }

    public ScheduledThreadPoolExecutor(int corePoolSize,
                                       ThreadFactory threadFactory) {
        super(corePoolSize, Integer.MAX_VALUE,
              DEFAULT_KEEPALIVE_MILLIS, MILLISECONDS,
              new DelayedWorkQueue(), threadFactory);
    }

    public ScheduledThreadPoolExecutor(int corePoolSize,
                                       RejectedExecutionHandler handler) {
        super(corePoolSize, Integer.MAX_VALUE,
              DEFAULT_KEEPALIVE_MILLIS, MILLISECONDS,
              new DelayedWorkQueue(), handler);
    }

    public ScheduledThreadPoolExecutor(int corePoolSize,
                                       ThreadFactory threadFactory,
                                       RejectedExecutionHandler handler) {
        super(corePoolSize, Integer.MAX_VALUE,
              DEFAULT_KEEPALIVE_MILLIS, MILLISECONDS,
              new DelayedWorkQueue(), threadFactory, handler);
    }
```

提供了4个构造方法，对于`线程工厂`和`拒绝策略`这两个值，与父类并没有什么不同。

值得注意的是，所有的工作队列，都使用了`DelayedWorkQueue`,这是一个特意实现的内部类.

### DelayedWorkQueue 源码

#### 定义

```java
static class DelayedWorkQueue extends AbstractQueue<Runnable>
        implements BlockingQueue<Runnable> {
```
作为一个`工作队列`，他实现了队列和阻塞队列的接口，这两个在本文不详细介绍，认为大家都有所了解.

作为一个队列，最重要的就是入队出队两个方法.

#### 入队 系列方法

提供了三个入队的方法:

```java

        public void put(Runnable e) {
            offer(e);
        }

        public boolean add(Runnable e) {
            return offer(e);
        }

        public boolean offer(Runnable e, long timeout, TimeUnit unit) {
            return offer(e);
        }

```

可以看到，三个方法调用的都是底层的`offer`实现. 

需要注意:

由于所有任务的入队，都是`ScheduledThreadPoolExecutor`类中自己进行的，因此认为是可信的.
所以工作队列是一个无界的队列，所有入队操作，不会超时，不会阻塞，绝对会成功.

```java

        public boolean offer(Runnable x) {
            if (x == null)
                throw new NullPointerException();
            RunnableScheduledFuture<?> e = (RunnableScheduledFuture<?>)x;
            final ReentrantLock lock = this.lock;
            // 加锁
            lock.lock();
            try {
                int i = size;
                // 需要扩容就扩容
                if (i >= queue.length)
                    grow();
                size = i + 1;
                if (i == 0) {
                    // 如果当前队列为空，放在第一位.
                    queue[0] = e;
                    // 给这个任务记录一下自己所在的index
                    setIndex(e, 0);
                } else {
                    // 上浮，根据compareTo给的优先级，将当前任务放在合适的位置上.
                    siftUp(i, e);
                }
                if (queue[0] == e) {
                    leader = null;
                    available.signal();
                }
            } finally {
                // 解锁
                lock.unlock();
            }
            return true;
        }
```

入队方法比较粗暴，主要分为两个分支:

1. 如果队列为空，就直接放在第一位.
2. 如果队列不为空，就要根据`CompareTo`的值，将任务放在合适的位置上，以符合优先级队列的特性.

#### 出队系列

出队系列复杂一点，分开讲.

##### peek 获取队首

```java

        public RunnableScheduledFuture<?> peek() {
            final ReentrantLock lock = this.lock;
            lock.lock();
            try {
                return queue[0];
            } finally {
                lock.unlock();
            }
        }

```

直接返回了队首的元素. 不判断是否到了执行时间，因为没有弹出，只是返回一下，让调用方自己看看.

##### poll 获取并弹出队首元素

```java

        public RunnableScheduledFuture<?> poll() {
            final ReentrantLock lock = this.lock;
            lock.lock();
            try {
                // 获取队首的元素，
                RunnableScheduledFuture<?> first = queue[0];
                // 如果队首的元素，没到执行时间，就返回null，拒绝弹出
                // 到了执行时间就调用finishPoll，进行实际的弹出.
                return (first == null || first.getDelay(NANOSECONDS) > 0)
                    ? null
                    : finishPoll(first);
            } finally {
                lock.unlock();
            }
        }

        // 实际的弹出方法
        private RunnableScheduledFuture<?> finishPoll(RunnableScheduledFuture<?> f) {   
            // size减1
            int s = --size;
            // 队尾的元素
            RunnableScheduledFuture<?> x = queue[s];
            // 队尾为空
            queue[s] = null;
            if (s != 0)
                // 将队尾的元素，从队头开始下沉，以继续保证优先级队列的规则
                siftDown(0, x);
            // 返回队头元素
            setIndex(f, -1);
            return f;
        }
```

poll方法是核心的弹出队首的方法.这里就要判断时间了。

1. 如果队首的元素，还没到执行的时间，就返回Null.拒绝弹出.
2. 队首的元素应该执行，就弹出队首元素，同时将队尾元素放在队首，进行下沉操作，以保证优先级队列的合理性.

##### take 阻塞等待弹出队首元素
```java

        public RunnableScheduledFuture<?> take() throws InterruptedException {
            final ReentrantLock lock = this.lock;
            // 获取一个可中断的锁
            lock.lockInterruptibly();
            try {
                // 自旋
                for (;;) {
                    // 队首
                    RunnableScheduledFuture<?> first = queue[0];
                    // 如果队首为空，直接休眠
                    if (first == null)
                        available.await();
                    else {
                        // 队首还有多久可以执行
                        long delay = first.getDelay(NANOSECONDS);
                        // 如果已经可以执行，就弹出
                        if (delay <= 0L)
                            return finishPoll(first);
                        // 
                        first = null; // don't retain ref while waiting
                        if (leader != null)
                            available.await();
                        else {
                            // 当前线程等待队首元素还差着的时间
                            Thread thisThread = Thread.currentThread();
                            leader = thisThread;
                            try {
                                available.awaitNanos(delay);
                            } finally {
                                if (leader == thisThread)
                                    leader = null;
                            }
                        }
                    }
                }
            } finally {
                // 解锁，并且唤醒等待的其他线程
                if (leader == null && queue[0] != null)
                    available.signal();
                lock.unlock();
            }
        }
```

带有超时时间的版本,以阻塞等待队首元素的成功弹出.

1. 如果队首为空，直接不限期的进行休眠等待.
2. 如果队首已经可以执行了，就弹出.
3. 队首不可以执行，就休眠等待队首剩余的时间.
4. 如果队首不为空，就唤醒其他的休眠等待的线程.

### ScheduledThreadPoolExecutor 核心调度方法 schedule

分为两类，一种是只延迟执行，没有周期执行。

#### 仅延迟执行一次


```java

    public ScheduledFuture<?> schedule(Runnable command,
                                       long delay,
                                       TimeUnit unit) {
        if (command == null || unit == null)
            throw new NullPointerException();
        // 创建一个任务，调用延迟执行
        RunnableScheduledFuture<Void> t = decorateTask(command,
            new ScheduledFutureTask<Void>(command, null,
                                          triggerTime(delay, unit),
                                          sequencer.getAndIncrement()));
        delayedExecute(t);
        return t;
    }
```

1. 创建了一个`ScheduleFutureTask`. 具体的参数有.
   * 执行的命令
   * 触发的时间
   * 序列号
2. 调用`delayedExecute`进行延迟执行.

```java

    private void delayedExecute(RunnableScheduledFuture<?> task) {
        // 如果线程池终止了，就拒绝任务
        if (isShutdown())
            reject(task);
        else {
            // 添加到队列中
            super.getQueue().add(task);
            // 如果状态有问题，就取消任务
            if (!canRunInCurrentRunState(task) && remove(task))
                task.cancel(false);
            else
                // 确保线程池有线程活着
                ensurePrestart();
        }
    }
```

约等于直接将任务放进工作队列中.

#### 延迟执行一次，之后周期执行

有两个版本，

* 延迟执行一次，之后以固定比例周期执行，等待时间越来越长
* 延迟执行一次，之后以固定的周期时间进行执行，每次等待时间一样

这里以第二个为例。

```java

    public ScheduledFuture<?> scheduleWithFixedDelay(Runnable command,
                                                     long initialDelay,
                                                     long delay,
                                                     TimeUnit unit) {
        if (command == null || unit == null)
            throw new NullPointerException();
        if (delay <= 0L)
            throw new IllegalArgumentException();
        ScheduledFutureTask<Void> sft =
            new ScheduledFutureTask<Void>(command,
                                          null,
                                          triggerTime(initialDelay, unit),
                                          -unit.toNanos(delay),
                                          sequencer.getAndIncrement());
        RunnableScheduledFuture<Void> t = decorateTask(command, sft);
        sft.outerTask = t;
        delayedExecute(t);
        return t;
    }
```

也是首先计算参数，之后延迟执行一次，与上面的不进行周期执行的区别就是，这个方法会算出一个周期时间，然后传递给任务.

### 源码总结

有没有发现JDK这些代码的一个特点，很多`基础设施，方法`特别复杂，支持多种情况，而顶层的API很多都只是简单的转发调用等等. 在我理解，这其实是一种良好设计的体现，充分应对了可能出现需求扩展.

比如在上方的调度方法中，作为最核心的方法，却只是简单计算参数，传递给底层的队列，基本就完成了。

## 总结


本文并不算特别细致，对很多细节没有深究，这里尝试从原理上总结下`ScheduledThreadPoolExecutor`。

首先，它是一个`ThreadPoolExecutor`。因此之前学习的，所有线程池的属性，他都有，什么线程工厂，拒绝策略，核心线程，最大线程，线程活跃时间等等特性，他都有。

他额外实现了延迟执行与周期性执行两个特点.依赖什么实现的呢?

### 独特的延迟优先级队列

众所周知，线程池内部有一个工作队列，这个类实现了自己`DelayWorkQueue`。

1. 确保队列中的顺序，是有优先级的，按照触发时间的顺序排列，这里需要`ScheduledFutureTask`配合实现，提供`compareTo`。
2. 延迟队列，实现了特殊的`poll`方法，在队首(最早触发的任务)还没有到达触发时间时， 无法从队列弹出任务去执行.

### 独特的任务结构封装

`FutureTask`有很多实现方法，对于调度来说，什么最重要. 这个类实现了自己的`ScheduledFutureTask`.

1. 提供自己的触发时间，以及`compareTo`方法，两个任务之间要能够计算优先级。
2. 可重复调用. `FutureTask`是一次性的，在`done`之后，内部的状态已经是完成，不能再次执行了.`ScheduledFutureTask`方法调用的是父类的`runAndReset`方法，可以执行完一次后，将状态重置，等待下一次的调用.


由以上两点，结合父类的`ThreadPoolExecutor`，实现了一个可以延迟执行及周期性执行的线程池.

接下来模拟一个任务的全生命周期。懒得画图，手写吧.

1. 新建一个线程池.
2. 调度一个任务，并让他初次延迟10分钟，之后每1分钟执行一次. (假设当前时间是0分钟)
3. 调度开始，计算任务参数. 任务的`time`是十分钟后，`period`是一分钟. 
4. 在调度方法中，执行了一次延迟计算。向工作队列中放入了当前的任务.
5. 时间来到第5分钟，线程池中的多个线程，尝试调用队列的`poll`方法获取任务，由于队列中只有一个任务，且没到时间，拿不到，继续等待.
6. 时间来到第10分钟，终于有个线程拿到了队首的任务，执行了一次，执行后将状态重置，计算下一次的时间，`10+1`，下一次执行时间在11分钟. 再次将这个任务放入工作队列中.
7. 时间来到第11分钟，又有一个线程拿到了队首的任务，重复上面的步骤.
8. 之后每一个分钟都会执行一次了.

...太简单了，我们再加一个任务.

9. 在第15分钟，向线程池调度一个任务，初次延时5分钟，之后每30s周期性执行一次.
10. 计算参数，任务2的初次触发时间是20分钟. 将任务2放入队列中， 由于他比任务1执行的晚，因此他一直在队列尾部，拿不到他.
11. 在15-19分钟，还是任务1优先级比较高，每次都拿到了任务1执行一次，再放入队列.
12. 在第20分钟，由两个线程(看你配置，也可能是一个线程两次获取),分别获取到了任务1，任务2.
13. 任务1还是老样子，执行一次，再放回去.
14. 任务2执行一次后，计算下一次的时间.`20+0.5=20.5`, 新的任务的触发时间是20分30秒. 放入队列中，此时，任务2优先级高于任务1，放到了队列的第一个.
15. 20分30秒，有线程拿到了任务2（他在队首),执行一次，计算下一次时间，放入队列....
16. 21分，有两个线程拿到了任务1，任务2，分别执行一次，计算下一次时间，之后放入队列
17. 21分30秒，有线程拿到了任务2......


之后，每个半分钟，也就是30秒，都会执行一次任务2.每个整分钟，都会任务1和任务2各自执行一次。

完美运行.

最后这块流程梳理，主要是为了方便自己理解，如果写的过于抽象，而屏幕前的你已经理解的比较透彻了，可以不用看～.

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