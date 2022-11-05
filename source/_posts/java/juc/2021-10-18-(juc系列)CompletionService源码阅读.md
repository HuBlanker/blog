---
layout: post
tags:
  - Java
  - JUC
  - 线程池
---

## 前言

线程池的另外一种实现，根据任务完成的顺序处理任务，而不是提交的顺序.

经常用在一些轻量级的任务处理上，或者追求更高的程序性能.

举几个常见的例子:

1. 多个任务，耗时不等. 不依赖于提交顺序. 此时希望提交任务后，主线程能尽快的开始处理结果.
2. 提交多个任务，耗时不等，只需要获取一个结果，之后其余的任务结果都被忽略. 此时也需要尽快拿到第一个完成的任务的结果.

## 简介

这是该接口及其实现类的简单类图:

![2021-10-18-16-52-40](http://img.couplecoders.tech/2021-10-18-16-52-40.png)

首先简单翻一下接口的注释:

> `CompletionService`是用来在新的异步任务的生产及已完成任务的结果消费之间进行解耦的。
> 生产者提交任务，消费者获取已经完成的任务，然后根据任务完成的顺序处理他们的结果.
> `CompletionService`可以用来管理异步的I/O.程序的一部分提交读取任务，在另外一部分处理读取后的结果，可能处理的顺序和提交任务的顺序不一致.
> 通常，`CompletionService`依赖于一个分开的`Executor`去进行真正的执行操作，`CompletionService`只负责管理内部的完成队列。 `ExecutorCompletionService`就是这么实现的.

翻一下`ExecutorCompletionService`的注释:

> `ExecutorCompletionService`使用提供的`Executor`去执行任务，它管理任务的提交，放在队列中被take访问。当处理一组任务时，这个是更加的轻量级。


使用示例:

* 当有一组任务时，每个任务返回值都是`Result`,想要并发行的执行他们，并处理返回的结果.

```java
         void solve(Executor e,
                    Collection<Callable<Result>> solvers)
             throws InterruptedException, ExecutionException {
           CompletionService<Result> cs
               = new ExecutorCompletionService<>(e);
           solvers.forEach(cs::submit);
           for (int i = solvers.size(); i > 0; i--) {
             Result r = cs.take().get();
             if (r != null)
               use(r);
           }
         }
```


首先根据提供的Executor创建一个实例，之后进行提交任务。

根据任务数量，遍历调用take.然后进行执行.

* 当有一组任务，只想要第一个完成的任务的结果，其他都忽略.

```java
 void solve(Executor e,
            Collection<Callable<Result>> solvers)
     throws InterruptedException {
   CompletionService<Result> cs
       = new ExecutorCompletionService<>(e);
   int n = solvers.size();
   List<Future<Result>> futures = new ArrayList<>(n);
   Result result = null;
   try {
     solvers.forEach(solver -> futures.add(cs.submit(solver)));
     for (int i = n; i > 0; i--) {
       try {
         Result r = cs.take().get();
         if (r != null) {
           result = r;
           break;
         }
       } catch (ExecutionException ignore) {}
     }
   } finally {
     futures.forEach(future -> future.cancel(true));
   }

   if (result != null)
     use(result);
 }}</pre>
```

首先创建实例，之后将所有的任务进行提交.

调用一次take,拿到不为空的结果后，对其他所有任务进行取消.

## `ExecutorCompletionService`源码

### 变量

```java
// 真正执行任务的线程池
private final Executor executor;
// 内部使用，为了用一些方法
private final AbstractExecutorService aes;
// 存放已完成的任务的队列
private final BlockingQueue<Future<V>> completionQueue;
```

看到这个，其实已经基本明了了. 任务执行完成后，将任务放入到内部的阻塞队列中，那么获取时就是按照任务完成顺序了。

### 构造方法

```java
    public ExecutorCompletionService(Executor executor) {
        if (executor == null)
            throw new NullPointerException();
        this.executor = executor;
        this.aes = (executor instanceof AbstractExecutorService) ?
            (AbstractExecutorService) executor : null;
        this.completionQueue = new LinkedBlockingQueue<Future<V>>();
    }

    public ExecutorCompletionService(Executor executor,
                                     BlockingQueue<Future<V>> completionQueue) {
        if (executor == null || completionQueue == null)
            throw new NullPointerException();
        this.executor = executor;
        this.aes = (executor instanceof AbstractExecutorService) ?
            (AbstractExecutorService) executor : null;
        this.completionQueue = completionQueue;
    }
```

首先获取传入的线程池，然后提取他的父类. 创建一个阻塞队列备用即可.

### submit 提交任务

```java
    public Future<V> submit(Callable<V> task) {
        if (task == null) throw new NullPointerException();
        RunnableFuture<V> f = newTaskFor(task);
        executor.execute(new QueueingFuture<V>(f, completionQueue));
        return f;
    }

    /**
     * @throws RejectedExecutionException {@inheritDoc}
     * @throws NullPointerException       {@inheritDoc}
     */
    public Future<V> submit(Runnable task, V result) {
        if (task == null) throw new NullPointerException();
        RunnableFuture<V> f = newTaskFor(task, result);
        executor.execute(new QueueingFuture<V>(f, completionQueue));
        return f;
    }
```

将给定的`Callable`或者`Runnable`进行包装，然后执行即可. 包装类是`QueueingFuture`. 这个一会说.


### take 获取结果
```java
    public Future<V> take() throws InterruptedException {
        return completionQueue.take();
    }

    public Future<V> poll() {
        return completionQueue.poll();
    }

    public Future<V> poll(long timeout, TimeUnit unit)
            throws InterruptedException {
        return completionQueue.poll(timeout, unit);
    }
```

获取结果的take和poll方法，都是直接调用的阻塞队列进行获取. 只需要保证入队顺序是完成顺序即可.


### `QueueingFuture`

```java
    private static class QueueingFuture<V> extends FutureTask<Void> {
        QueueingFuture(RunnableFuture<V> task,
                       BlockingQueue<Future<V>> completionQueue) {
            super(task, null);
            this.task = task;
            this.completionQueue = completionQueue;
        }
        private final Future<V> task;
        private final BlockingQueue<Future<V>> completionQueue;
        protected void done() { completionQueue.add(task); }
    }
```

继承自`FutureTask`.内部持有线程池`ExecutorCompletionService`的阻塞队列. 重写了`done`这个hook方法.

在任务完成时，会调用这个hook. 将当前的任务放入阻塞队列.

因此阻塞队列中的顺序，就是任务完成的顺序. 按照顺序取出进行处理.

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