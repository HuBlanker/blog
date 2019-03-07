---
layout: post
category: [Java面试,Java,多线程]
tags:
  - Java面试
  - Java
  - 多线程
---

## 前言

了解一下线程池的源码实现.

## ThreadPoolExecutor

jdk中关于线程池一个比较核心的类是`ThreadPoolExecutor`,先来看一下他的实现.

### 构造方法

```java
public ThreadPoolExecutor(int corePoolSize,
                          int maximumPoolSize,
                          long keepAliveTime,
                          TimeUnit unit,
                          BlockingQueue<Runnable> workQueue) {
    this(corePoolSize, maximumPoolSize, keepAliveTime, unit, workQueue,
         Executors.defaultThreadFactory(), defaultHandler);
}

public ThreadPoolExecutor(int corePoolSize,
                          int maximumPoolSize,
                          long keepAliveTime,
                          TimeUnit unit,
                          BlockingQueue<Runnable> workQueue,
                          ThreadFactory threadFactory) {
    this(corePoolSize, maximumPoolSize, keepAliveTime, unit, workQueue,
         threadFactory, defaultHandler);
}


public ThreadPoolExecutor(int corePoolSize,
                          int maximumPoolSize,
                          long keepAliveTime,
                          TimeUnit unit,
                          BlockingQueue<Runnable> workQueue,
                          RejectedExecutionHandler handler) {
    this(corePoolSize, maximumPoolSize, keepAliveTime, unit, workQueue,
         Executors.defaultThreadFactory(), handler);
}

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
    this.acc = System.getSecurityManager() == null ?
            null :
            AccessController.getContext();
    this.corePoolSize = corePoolSize;
    this.maximumPoolSize = maximumPoolSize;
    this.workQueue = workQueue;
    this.keepAliveTime = unit.toNanos(keepAliveTime);
    this.threadFactory = threadFactory;
    this.handler = handler;
}
```

可以看到ThreadPoolExecutor提供了4中构造方法,分别传入了不同的参数,而前三个构造函数都是调用的第四个构造函数,对其参数进行了赋值.

### 参数

那么我们了解一下这些参数的作用:

1. corePoolSize:核心池的大小.即正常情况下,保持活跃的线程的数量.

2. maximumPoolSize:线程最大数量.

3. keepAliveTime:线程未使用保持活跃的时间.一般情况下,只有在当前线程数大于corePoolSize才会生效.

4. workQueue:一个阻塞队列,用来存放待执行的任务.

5. threadFactory: 线程工厂,负责创建线程.

6. handler:  拒绝处理任务时的策略.

## 四种线程池

Java通过Executors提供四种线程池，分别为：

1. newCachedThreadPool创建一个可缓存线程池，如果线程池长度超过处理需要，可灵活回收空闲线程，若无可回收，则新建线程。
2. newFixedThreadPool 创建一个定长线程池，可控制线程最大并发数，超出的线程会在队列中等待。
3. newScheduledThreadPool 创建一个定长线程池，支持定时及周期性任务执行。
4. newSingleThreadExecutor 创建一个单线程化的线程池，它只会用唯一的工作线程来执行任务，保证所有任务按照指定顺序(FIFO, LIFO, 优先级)执行。

我们来一一看一下:

### newCachedThreadPool

```java
public static ExecutorService newCachedThreadPool() {
    return new ThreadPoolExecutor(0, Integer.MAX_VALUE,
                                  60L, TimeUnit.SECONDS,
                                  new SynchronousQueue<Runnable>());
}
```
 通过指定参数,返回ThreadPoolExecutor来实现.
 参数为:
 ```
 核心线程池大小=0
 最大线程池大小为Integer.MAX_VALUE
 线程过期时间为60s
 使用SynchronousQueue作为工作队列.
 ```
所以线程池为0-max个线程,并且会60s过期,实现了可以缓存的线程池.

### newFixedThreadPool

```java
public static ExecutorService newFixedThreadPool(int nThreads) {
    return new ThreadPoolExecutor(nThreads, nThreads,
                                  0L, TimeUnit.MILLISECONDS,
                                  new LinkedBlockingQueue<Runnable>());
}
```

```
核心线程池大小=传入参数
最大线程池大小为传入参数
线程过期时间为0ms
LinkedBlockingQueue作为工作队列.
```

通过最小与最大线程数量来控制实现定长线程池.

### newScheduledThreadPool

```java
public ScheduledThreadPoolExecutor(int corePoolSize) {
    super(corePoolSize, Integer.MAX_VALUE, 0, NANOSECONDS,
          new DelayedWorkQueue());
}
```

```
核心线程池大小=传入参数
最大线程池大小为Integer.MAX_VALUE
线程过期时间为0ms
DelayedWorkQueue作为工作队列.
```
主要是通过DelayedWorkQueue来实现的定时线程.

### newSingleThreadExecutor

```java
public static ExecutorService newSingleThreadExecutor() {
    return new FinalizableDelegatedExecutorService
        (new ThreadPoolExecutor(1, 1,
                                0L, TimeUnit.MILLISECONDS,
                                new LinkedBlockingQueue<Runnable>()));
}
```
```
核心线程池大小=1
最大线程池大小为1
线程过期时间为0ms
LinkedBlockingQueue作为工作队列.
```

综上,java提供的4种线程池,只是预想了一些使用场景,使用参数定义的而已,我们在使用的过程中,完全可以根据业务需要,自己去定义一些其他类型的线程池来使用(如果需要的话).

其中多种阻塞队列的实现方式显然比4中线程池更难一些.

完.


<br>
<br>
<br>
<br>
<h4>ChangeLog</h4>
2019-01-28   
<br>
<br>


**以上皆为个人所思所得，如有错误欢迎评论区指正。**

**欢迎转载，烦请署名并保留原文链接。**

**联系邮箱：huyanshi2580@gmail.com**

**更多学习笔记见个人博客------><a href="{{ site.baseurl }}/">呼延十</a>**
