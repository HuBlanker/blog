---
layout: post
tags:
  - Java
  - CyclicBarrier
  - JUC
---

## 前言

本文源码基于: <font color='red'>JDK13</font>

为了巩固AQS.　看一下CyclicBarrier的源码.


## 简介

*大部分都是直接翻译的官方代码注释，嘻嘻*

一个允许一系列线程互相等待，到达一个公共屏障点的同步辅助器.

CyclicBarrier在一个固定大小的线程集合，必须互相等待时很有用.

之所以叫做循环(Cyclic), 是因为CyclicBarrier在线程全部释放后可以重复利用.

CyclicBarrier支持一个可选的`Runnable`命令，　它将在每个屏障点运行一次(所有线程到达后，运行一次)。　在最后一个线程到达之后，但是在任何一个线程被释放之前.

这个操作对于在任何一个线程继续之前更新共享状态很有用.

使用实例:

示例展示了一个分解任务的设计.

将一份任务分解为N份，交给N个线程去做.

当N个线程全部完成工作后，触发Merge操作.收取结果.

```java
  class Solver {
    final int N;
    final float[][] data;
    final CyclicBarrier barrier;
 
    class Worker implements Runnable {
      int myRow;
      Worker(int row) { myRow = row; }
      public void run() {
        while (!done()) {
          processRow(myRow);
 
          try {
            barrier.await();
          } catch (InterruptedException ex) {
            return;
          } catch (BrokenBarrierException ex) {
            return;
          }
        }
      }
    }
 
     public Solver(float[][] matrix) {
      data = matrix;
      N = matrix.length;
      Runnable barrierAction = () -> mergeRows();
      barrier = new CyclicBarrier(N, barrierAction);
 
      List<Thread> threads = new ArrayList<>(N);
      for (int i = 0; i < N; i++) {
        Thread thread = new Thread(new Worker(i));
        threads.add(thread);
        thread.start();
      }
 
      // wait until done
      for (Thread thread : threads)
        thread.join();
    }
  }
```

CyclicBarrier采用all-or-none的异常策略. 如果一个线程异常退出了. 所有其他在屏障点等待的线程也会异常退出.

## 源码探究


### 构造方法

```java
    /**
     * Creates a new {@code CyclicBarrier} that will trip when the
     * given number of parties (threads) are waiting upon it, and which
     * will execute the given barrier action when the barrier is tripped,
     * performed by the last thread entering the barrier.
     *
     * @param parties the number of threads that must invoke {@link #await}
     *        before the barrier is tripped
     * @param barrierAction the command to execute when the barrier is
     *        tripped, or {@code null} if there is no action
     * @throws IllegalArgumentException if {@code parties} is less than 1
     */
    public CyclicBarrier(int parties, Runnable barrierAction) {
        if (parties <= 0) throw new IllegalArgumentException();
        this.parties = parties;
        this.count = parties;
        this.barrierCommand = barrierAction;
    }

    /**
     * Creates a new {@code CyclicBarrier} that will trip when the
     * given number of parties (threads) are waiting upon it, and
     * does not perform a predefined action when the barrier is tripped.
     *
     * @param parties the number of threads that must invoke {@link #await}
     *        before the barrier is tripped
     * @throws IllegalArgumentException if {@code parties} is less than 1
     */
    public CyclicBarrier(int parties) {
        this(parties, null);
    }
```

两个构造方法，一个指定数量, 一个可以指定数量+屏障点行为的.

基本上只有赋值操作，不多说.

### 核心方法　await()

```java
    public int await() throws InterruptedException, BrokenBarrierException {
        try {
            return dowait(false, 0L);
        } catch (TimeoutException toe) {
            throw new Error(toe); // cannot happen
        }
    }
```

可以看到直接调用了dowait. 这也是整个类的核心代码.

```java
    /**
     * Main barrier code, covering the various policies.
     */
    private int dowait(boolean timed, long nanos)
        throws InterruptedException, BrokenBarrierException,
               TimeoutException {
        // 加锁
        final ReentrantLock lock = this.lock;
        lock.lock();
        try {
            final Generation g = generation;

            // 
            if (g.broken)
                throw new BrokenBarrierException();

            if (Thread.interrupted()) {
                breakBarrier();
                throw new InterruptedException();
            }

            int index = --count;
            if (index == 0) {  // tripped
                Runnable command = barrierCommand;
                if (command != null) {
                    try {
                        command.run();
                    } catch (Throwable ex) {
                        breakBarrier();
                        throw ex;
                    }
                }
                nextGeneration();
                return 0;
            }

            // loop until tripped, broken, interrupted, or timed out
            for (;;) {
                try {
                    if (!timed)
                        trip.await();
                    else if (nanos > 0L)
                        nanos = trip.awaitNanos(nanos);
                } catch (InterruptedException ie) {
                    if (g == generation && ! g.broken) {
                        breakBarrier();
                        throw ie;
                    } else {
                        // We're about to finish waiting even if we had not
                        // been interrupted, so this interrupt is deemed to
                        // "belong" to subsequent execution.
                        Thread.currentThread().interrupt();
                    }
                }

                if (g.broken)
                    throw new BrokenBarrierException();

                if (g != generation)
                    return index;

                if (timed && nanos <= 0L) {
                    breakBarrier();
                    throw new TimeoutException();
                }
            }
        } finally {
            lock.unlock();
        }
    }

```

１．首先获取内部唯一的ReentrantLock. 进行加锁操作.
2. 判断当前`CyclicBarrier`是否已经残破，如果是的话抛出异常.
3. 判断当前线程是否被中断了，如果是中断的话，根据之前说的，有一个线程中断，整个屏障中所有等待线程异常退出.
4. 等待线程递减，如果递减完为0.说明是最后一个线程，那么如果屏障行为不为空，就执行该`Runnalbe`. 并重置整个屏障(这就是可复用了). 并通知所有等待的线程.
5. 如果递减后不为0. 开始休眠等待唤醒. 在等待过程中，如果发生异常或者线程被中断，则将当前屏障标记为破碎，同时唤醒其他等待的线程，异常退出.
6. 解锁.



### reset()

```java
    /**
     * Resets the barrier to its initial state.  If any parties are
     * currently waiting at the barrier, they will return with a
     * {@link BrokenBarrierException}. Note that resets <em>after</em>
     * a breakage has occurred for other reasons can be complicated to
     * carry out; threads need to re-synchronize in some other way,
     * and choose one to perform the reset.  It may be preferable to
     * instead create a new barrier for subsequent use.
     */
    public void reset() {
        final ReentrantLock lock = this.lock;
        lock.lock();
        try {
            breakBarrier();   // break the current generation
            nextGeneration(); // start a new generation
        } finally {
            lock.unlock();
        }
    }

```

重置这个屏障，首先加锁，然后将当前屏障的所有等待线程唤醒，重置屏障完成. 解锁.

## 总结

CountDownLatch是一个一次性，用于一个线程等待多个线程，或者多个线程等待一个线程的同步器。

CyclicBarrier是一个可复用的，多个线程互相等待的同步器.

实现原理也不一致.

CountDownLatch基于AQS实现，自定义了同步器，之后对外提供API.

CyclicBarrier内部使用ReentrantLock来实现同步. 对内部的count等属性的操作，也依赖于ReentrantLock的同步功能.

完.

## 参考文章


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