---
layout: post
category: [Java面试,Java,多线程,java.util.concurrent]
tags:
  - Java面试
  - Java
  - 多线程
  - java.util.concurrent
---

## 前言

在之前的文章[Java中executors提供的的4种线程池](http://huyan.couplecoders.tech/java%E9%9D%A2%E8%AF%95/java/%E5%A4%9A%E7%BA%BF%E7%A8%8B/java.util.concurrent/2019/03/07/Java%E4%B8%ADExecutors%E6%8F%90%E4%BE%9B%E7%9A%84%E7%9A%844%E7%A7%8D%E7%BA%BF%E7%A8%8B%E6%B1%A0/)中,学习了一下Executors类中提供的四种线程池.

在该文中提到,这四种线程池只是四个静态工厂方法而已,本质上其实是调用的`ThreadPoolExecutor`类的构造方法,并且对其中的一些参数进行了了解.比如`corePoolSize`,`maximumPoolSize`等等.

但是对其中剩余的两个参数,`queen`阻塞队列,`handler`拒绝策略等没有了解的十分透彻.因此今天来补充一下.

本文主要对以上两个参数的作用以及实现方法,使用方法来学习一下,中间可能夹杂部分`ThreadPoolExecutor`的源码学习.

## 阻塞队列 

对阻塞队列完全不了解的同学可以查看一下这篇文章,[Java中对阻塞队列的实现](https://mp.weixin.qq.com/s/Epi-cBVFkeZWgvKvOMQZqw).

这里不会在对阻塞队列的原理做过多的探讨,主要聚焦于在线程池中阻塞队列的作用.

我前一阵面试的时候,对线程池这一块仅限于使用,一知半解(现在也是呢哈哈哈),在一次面试中问到了线程池中阻塞队列的作用,以及在什么情景下任务会被放入阻塞队列,而我一脸懵逼,今天也回答一下这个问题.

要想知道怎么放入,我们直接从`execute`方法来看,因为一般情况下我们都是通过这个方法来提交任务的,它的代码如下:

```java
    /**
     * Executes the given task sometime in the future.  The task
     * may execute in a new thread or in an existing pooled thread.
     *
     * If the task cannot be submitted for execution, either because this
     * executor has been shutdown or because its capacity has been reached,
     * the task is handled by the current {@code RejectedExecutionHandler}.
     *
     * @param command the task to execute
     * @throws RejectedExecutionException at discretion of
     *         {@code RejectedExecutionHandler}, if the task
     *         cannot be accepted for execution
     * @throws NullPointerException if {@code command} is null
     */
    public void execute(Runnable command) {
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
        if (workerCountOf(c) < corePoolSize) {
            if (addWorker(command, true))
                return;
            c = ctl.get();
        }
        if (isRunning(c) && workQueue.offer(command)) {
            int recheck = ctl.get();
            if (! isRunning(recheck) && remove(command))
                reject(command);
            else if (workerCountOf(recheck) == 0)
                addWorker(null, false);
        }
        else if (!addWorker(command, false))
            reject(command);
    }
```

我一般copy源代码都是删除注释的,因为实在太长了...但是这个的源代码我觉得十分的棒,简洁并且极其清晰.可以看一下.

方法上的注释:

>将在未来的某个时间执行给定的任务,任务可能会在一个新的线程或者一个旧的线程里执行.

> 如果任务不可以被执行,可能是因为线程池关闭了或者容量满了,任务将会被`RejectedExecutionHandler`处理.

看起来是不是没有什么用?其实在大的逻辑上说的很清晰了,接下来是代码中的这一段注释.

>分为三步:1.如果当前运行的线程数量小于核心池的数量,试着以给定的任务作为第一个任务去创建一个新的线程.这个添加worker的请求会原子性的检查线程的运行状态以及工作线程的数量,如果添加失败,会返回false.

>2.如果这个任务可以被成功的放入队列,我们将在添加一个线程前进行`double-check`双重检查,因为可能在此期间有一个线程挂掉了或者线程池挂掉了.所以我们再次检查状态,如果必要的话回滚对象,或者新建一个线程.

>3.如果我们不能讲任务放进队列,我们将新增一个线程,如果这也失败了,我们知道我们挂掉了或者说线程池的容量满了,然后我们拒绝这个任务.

这就是对上面那个问题的回答.也就是阻塞队列在线程池中的使用方法.

那么使用哪种阻塞队列呢?Java有很多的阻塞队列的实现的.

在`Executors`的四种静态工厂中,使用的阻塞队列实现有两种,`LinkedBlockingQueue`和`SynchronousQueue`.

**LinkedBlockingQueue**: 这个阻塞队列在前一篇文章中讲过了,主要强调一点,他可以是一个无界的阻塞队列,可以放下大量的任务.

**SynchronousQueue**: 这个阻塞队列内部没有容器,不会持有任务,而是将每一个生产者阻塞,知道等到与他配对的消费者.

从上面阻塞队列的使用方法中可以看出来,`maximumPoolSize`和`阻塞队列的长度`这两个值会互相影响,当阻塞队列很大时,相应的`maximumPoolSize`可以小一点,对CPU的压力也就会相应的小一点.而当阻塞队列很小的时候,会频繁的出现放入队列失败,然后尝试新建线程,这时会出现两种可能,线程数暴增或者大量的拒绝任务,都不是很好的选择,

因此在决定使用哪种阻塞队列的时候,需要对吞吐量和CPU的压力之间做一个权衡.

## 拒绝策略

当你的阻塞队列以及线程池容量全部爆掉之后,再次提交任务就会被拒绝,拒绝的策略由构造参数中的`handler`来提供.

这是`ThreadPoolExecutor`中默认使用的拒绝策略`AbortPolicy`:

```java
    /**
     * A handler for rejected tasks that throws a
     * {@code RejectedExecutionException}.
     */
    public static class AbortPolicy implements RejectedExecutionHandler {
        /**
         * Creates an {@code AbortPolicy}.
         */
        public AbortPolicy() { }

        /**
         * Always throws RejectedExecutionException.
         *
         * @param r the runnable task requested to be executed
         * @param e the executor attempting to execute this task
         * @throws RejectedExecutionException always
         */
        public void rejectedExecution(Runnable r, ThreadPoolExecutor e) {
            throw new RejectedExecutionException("Task " + r.toString() +
                                                 " rejected from " +
                                                 e.toString());
        }
    }
```

可以看到这个策略比较粗暴,直接抛出了异常.

JDK中还有一些其他的拒绝策略,如下:

* ThreadPoolExecutor#AbortPolicy：这个策略直接抛出 RejectedExecutionException 异常。

* ThreadPoolExecutor#CallerRunsPolicy：这个策略将会使用 Caller 线程来执行这个任务，这是一种 feedback 策略，可以降低任务提交的速度。

* ThreadPoolExecutor#DiscardPolicy：这个策略将会直接丢弃任务。

* ThreadPoolExecutor#DiscardOldestPolicy：这个策略将会把任务队列头部的任务丢弃，然后重新尝试执行，如果还是失败则继续实施策略。

那么我们能不能自己实现一种策略呢,当然可以,还很简单.

我们实现一种策略,当被拒绝时候,打印一句日志然后给我们发一个邮件好了(不值当鸭).

```java

        ThreadPoolExecutor ex = new ThreadPoolExecutor(10, 100, 100L, TimeUnit.SECONDS, new LinkedBlockingQueue<>(10), new MyRejectPolicy());


    	private static class MyRejectPolicy implements RejectedExecutionHandler {

        @Override
        public void rejectedExecution(Runnable r, ThreadPoolExecutor executor) {
            System.out.println("reject me,555");
            // send email ...
        }
    }

```

我们新建了一个线程池,核心池大小为10,最大大小为100,存活时间为100s,使用容量为10的`LinkedBlockingQueue`为工作队列,拒绝策略使用我们自己实现的一个策略,类定义如上所示.

只需要实现`RejectedExecutionHandler`接口并且实现他的唯一方法即可.

## 额外的小技巧

在看源代码的过程中,我发现了一个属性,`    private volatile boolean allowCoreThreadTimeOut;` 这个属性可以控制核心池中的线程会不会因为空闲时间过程而死亡,虽然听起来没什么用,因为我们可以通过减小核心池的大小来达到差不多的目的,但是总是有区别的,记录一下,说不定就遇到合适使用的场景了呢.

## 钩子Hook

在git中,hook十分有用,可以让我们进行很多事情,比如自动化部署,发邮件等等.那么在线程池中怎么能没有呢?

`ThreadPoolExecutor`提供了三个Hook来让我们执行一些定制化的东西,可以通过继承此类然后重写钩子来实现,三个Hook分别是:

```java
    protected void beforeExecute(Thread t, Runnable r) { }
    
    protected void afterExecute(Runnable r, Throwable t) { }

    protected void terminated() { }

```

他们分别在任务执行前,执行后,以及线程池终止的时候被调用.让我们来测试一下.

我们的类如下:

```java
    private static class  MyExecutor extends ThreadPoolExecutor{


        public MyExecutor(int corePoolSize, int maximumPoolSize, long keepAliveTime, TimeUnit unit, BlockingQueue<Runnable> workQueue, RejectedExecutionHandler handler) {
            super(corePoolSize, maximumPoolSize, keepAliveTime, unit, workQueue, handler);
        }

        @Override
        protected void beforeExecute(Thread t, Runnable r) {
            System.out.println("before");
        }

        @Override
        protected void afterExecute(Runnable r, Throwable t) {
            System.out.println("after");
        }

        @Override
        protected void terminated() {
            System.out.println("executor terminate");

        }
    }
```
测试代码:

```java
    public static void main(String[] args) {
        ThreadPoolExecutor ex = new MyExecutor(10, 100, 100L, TimeUnit.SECONDS, new LinkedBlockingQueue<>(10), new MyRejectPolicy());
        ex.execute(()->{
            for (int i = 0; i < 10; ++i) {
                System.out.println("i:" + i);
            }
        });

        ex.execute(()->{
            for (int i = 0; i < 10; ++i) {
                System.out.println("j:" + i);
            }
        });

        ex.shutdown();
    }
```

打印输出如下:

```java
before
i:0
i:1
i:2
i:3
i:4
i:5
before
i:6
i:7
i:8
i:9
j:0
j:1
j:2
j:3
j:4
j:5
j:6
j:7
after
j:8
j:9
after
executor terminate
```

可以看到我们对钩子的实现,完全的被执行了,所以我们可以用它做很多东西,比如记录日志,比如发推送消息,比如更加高级一点在执行之前设置`ThreadLocal`等等.具体操作就看我们的想象力了!

但是请注意一点,钩子中的内容如果执行错误,会影响任务本身的执行结果,要尽力保证钩子的正确性,不要顾此失彼.

完.


## 参考文章

https://mp.weixin.qq.com/s/Epi-cBVFkeZWgvKvOMQZqw


<br>
<br>
<br>
<br>
<h4>ChangeLog</h4>
2019-05-05   完成
<br>
<br>


**以上皆为个人所思所得，如有错误欢迎评论区指正。**

**欢迎转载，烦请署名并保留原文链接。**

**联系邮箱：huyanshi2580@gmail.com**

**更多学习笔记见个人博客------><a href="{{ site.baseurl }}/">呼延十</a>**
