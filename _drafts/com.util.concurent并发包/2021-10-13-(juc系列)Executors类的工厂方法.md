---
layout: post
category: [Java,JUC,Executor]
tags:
  - Java
  - Executor
  - JUC
---


## 简介

提供一些工厂方法和工具类方法. 给`Executor`,`ExecutorService`,`ScheduledExecutorService`和`ThreadFacotry`使用.
`Callable`类在这里定义.

这个类提供以下几种方法:

1. 用一些常用的参数设置，创建一个新的`ExecutorService`返回. 约等于`ExecutorService`的几个工厂方法.
2. `ScheduledExecutorSerivce`的工厂方法，用一些常用的参数创建.
3. 创建并返回一些`ExecutorService`的包装类, 关闭掉了重新设置参数的功能。
4. 创建`ThreadFactory`的一些方法.
5. 创建并返回`Callable`的一些方法.

## 源码

### ExecutorService的工厂方法

* newFixedThreadPool 创建一个固定大小的`ThreadPoolExecutor`.
* newSingleThreadExecutor 创建一个单个线程的`FinalizableDelegatedExecutorService`.
* newCachedThreadPool newCachedThreadPool创建一个无界的`ThreadPoolExecutor`.没有核心线程，也没有最大线程数量的限制.
* newWorkStealingPool 创建一个`ForkJoinPool`.
* newSingleThreadScheduledExecutor 创建一个具有单个线程的，周期定时执行的线程池.`DelegatedScheduledExecutorService`
* newScheduledThreadPool 创建多个线程的线程池，可以周期性的执行任务.
* unconfigurableExecutorService 将给定的`ExecutorService`进行封装，不再允许修改相关的配置.
* unconfigurableScheduledExecutorService 将给定的周期性线程池进行封装，不再允许修改配置.
  


### ThreadFactory 线程工厂

* defaultThreadFactory 返回`DefaultThreadFactory`类的一个实例，是默认的线程工厂，简单的创建一个非守护线程.
  
* privilegedThreadFactory 返回`PrivilegedThreadFactory`的一个实例，使得创建的线程拥有高级的访问权限和相同的类加载器. 代码如下.

```java
    private static class PrivilegedThreadFactory extends DefaultThreadFactory {
    final AccessControlContext acc;
    final ClassLoader ccl;

    PrivilegedThreadFactory() {
        super();
        SecurityManager sm = System.getSecurityManager();
        if (sm != null) {
            // Calls to getContextClassLoader from this class
            // never trigger a security check, but we check
            // whether our callers have this permission anyways.
            sm.checkPermission(SecurityConstants.GET_CLASSLOADER_PERMISSION);

            // Fail fast
            sm.checkPermission(new RuntimePermission("setContextClassLoader"));
        }
        this.acc = AccessController.getContext();
        this.ccl = Thread.currentThread().getContextClassLoader();
    }

    public Thread newThread(final Runnable r) {
        return super.newThread(new Runnable() {
            public void run() {
                AccessController.doPrivileged(new PrivilegedAction<>() {
                    public Void run() {
                        Thread.currentThread().setContextClassLoader(ccl);
                        r.run();
                        return null;
                    }
                }, acc);
            }
        });
    }
}
```


### 封装Callable

* callable(Runnable task, T result) 将给定的任务封装成Callable.但是不需要返回结果.
* callable(Runnable task) 给定的任务封装成Callable. 结束就返回null.
  
以上两个方法,通过`RunnableAdapter`实现.

```java
    // 一个run任务的装饰器
    private static final class RunnableAdapter<T> implements Callable<T> {
    private final Runnable task;
    private final T result;
    RunnableAdapter(Runnable task, T result) {
        this.task = task;
        this.result = result;
    }
    // 调用call时返回给定的结果
    public T call() {
        task.run();
        return result;
    }
    public String toString() {
        return super.toString() + "[Wrapped task = " + task + "]";
    }
}

```
* callable(final PrivilegedAction<?> action) 封装Callable.调用时执行action.
* callable(final PrivilegedExceptionAction<?> action) 同上
* privilegedCallable 具有特权的callable. 

### 简单的ExecutorService实现

#### DelegatedExecutorService

一个ExecutorService的简单实现，同时对另外一个ExecutorService进行包装,使得传入的ExecutorService，
对外只能暴露`ExecutorService`接口的相关方法，所有的动态修改配置方法不可用. 可以起到强制不允许修改线程池参数的作用。

```java
    private static class DelegatedExecutorService
        implements ExecutorService {
    private final ExecutorService e;
    DelegatedExecutorService(ExecutorService executor) { e = executor; }
    public void execute(Runnable command) {
        try {
            e.execute(command);
        } finally { reachabilityFence(this); }
    }
    public void shutdown() { e.shutdown(); }
    public List<Runnable> shutdownNow() {
        try {
            return e.shutdownNow();
        } finally { reachabilityFence(this); }
    }
    public boolean isShutdown() {
        try {
            return e.isShutdown();
        } finally { reachabilityFence(this); }
    }
    public boolean isTerminated() {
        try {
            return e.isTerminated();
        } finally { reachabilityFence(this); }
    }
    public boolean awaitTermination(long timeout, TimeUnit unit)
            throws InterruptedException {
        try {
            return e.awaitTermination(timeout, unit);
        } finally { reachabilityFence(this); }
    }
    public Future<?> submit(Runnable task) {
        try {
            return e.submit(task);
        } finally { reachabilityFence(this); }
    }
    public <T> Future<T> submit(Callable<T> task) {
        try {
            return e.submit(task);
        } finally { reachabilityFence(this); }
    }
    public <T> Future<T> submit(Runnable task, T result) {
        try {
            return e.submit(task, result);
        } finally { reachabilityFence(this); }
    }
    public <T> List<Future<T>> invokeAll(Collection<? extends Callable<T>> tasks)
            throws InterruptedException {
        try {
            return e.invokeAll(tasks);
        } finally { reachabilityFence(this); }
    }
    public <T> List<Future<T>> invokeAll(Collection<? extends Callable<T>> tasks,
                                         long timeout, TimeUnit unit)
            throws InterruptedException {
        try {
            return e.invokeAll(tasks, timeout, unit);
        } finally { reachabilityFence(this); }
    }
    public <T> T invokeAny(Collection<? extends Callable<T>> tasks)
            throws InterruptedException, ExecutionException {
        try {
            return e.invokeAny(tasks);
        } finally { reachabilityFence(this); }
    }
    public <T> T invokeAny(Collection<? extends Callable<T>> tasks,
                           long timeout, TimeUnit unit)
            throws InterruptedException, ExecutionException, TimeoutException {
        try {
            return e.invokeAny(tasks, timeout, unit);
        } finally { reachabilityFence(this); }
    }
}

```


可以看到，所有实现自`ExecutorService`的方法，都只是简单的做了委托，交给传入的`ExecutorService`去执行。


### DelegatedScheduledExecutorService 周期性调度的线程池的委托者

```java

private static class DelegatedScheduledExecutorService
        extends DelegatedExecutorService
        implements ScheduledExecutorService {
    private final ScheduledExecutorService e;
    DelegatedScheduledExecutorService(ScheduledExecutorService executor) {
        super(executor);
        e = executor;
    }
    public ScheduledFuture<?> schedule(Runnable command, long delay, TimeUnit unit) {
        return e.schedule(command, delay, unit);
    }
    public <V> ScheduledFuture<V> schedule(Callable<V> callable, long delay, TimeUnit unit) {
        return e.schedule(callable, delay, unit);
    }
    public ScheduledFuture<?> scheduleAtFixedRate(Runnable command, long initialDelay, long period, TimeUnit unit) {
        return e.scheduleAtFixedRate(command, initialDelay, period, unit);
    }
    public ScheduledFuture<?> scheduleWithFixedDelay(Runnable command, long initialDelay, long delay, TimeUnit unit) {
        return e.scheduleWithFixedDelay(command, initialDelay, delay, unit);
    }
}
```

类似与`DelegatedExecutorService`,对所有`ScheduledExecutorService`定义的方法进行实现，只做简单的委托，转发请求而已.


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