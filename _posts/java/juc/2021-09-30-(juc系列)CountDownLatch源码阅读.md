---
layout: post
category: [Java, JUC, CountDownLatch]
tags:
  - Java
  - CountDownLatch
  - JUC
---

## 前言

为了巩固AQS.　看一下CountDownLatch的源码.


## 简介

*大部分都是直接翻译的官方代码注释，嘻嘻*

一个同步器, 允许一个或者多个线程等待, 知道其他线程完成一系列操作.

初始化时提供一个数字. `await`方法将阻塞，直到别的线程通过调用`countDown`,达到给定的数字.

这个类是一个一次性，count数字不能被重新设置. 如果你需要一个可复用的版本，可以考虑使用`CyclicBarrier`.

`CountDownLatch` 可以用于以下目的:

1. 初始化为N. 所有线程调用`await`等待，直到门被一个线程调用`countDown`来打开．
2. 初始化为N, 一个线程等待，直到N个线程完成了一些动作，或者某个动作被完成了N次.

`CountDownLatch`的一个很有用的特性是:

所有调用`countDown`的线程不需要等待计数到达0. 他只是在`await`方法上阻塞所有想要通过的线程.

使用实例(**来自官方文档**):

两个类，使用两个`CountDownLatch`来完成以下功能.

1. 第一个`CountDownLatch`, 是一个开始信号，告诉所有工作线程，驱动已经就绪，可以开始工作了。
2. 第二个`CountDownLatch`, 是一个结束信号，允许驱动等待所有工作线程完成，之后进行其他工作.

```java
  class Driver { 
    
    void main() throws InterruptedException {
      CountDownLatch startSignal = new CountDownLatch(1);
      CountDownLatch doneSignal = new CountDownLatch(N);
 
      for (int i = 0; i < N; ++i) // create and start threads
        new Thread(new Worker(startSignal, doneSignal)).start();
 
      doSomethingElse();            // don't let run yet
      startSignal.countDown();      // let all threads proceed
      doSomethingElse();
      doneSignal.await();           // wait for all to finish
    }
  }
  
  class Worker implements Runnable {
      private final CountDownLatch startSignal;
      private final CountDownLatch doneSignal;

      Worker(CountDownLatch startSignal, CountDownLatch doneSignal) {
          this.startSignal = startSignal;
          this.doneSignal = doneSignal;
      }

      public void run() {
          try {
              startSignal.await();
              doWork();
              doneSignal.countDown();
          } catch (InterruptedException ex) {
          } // return;
      }

      void doWork() {

      }
  }
```

另外一个典型应用是，将一个任务分割成N部分，每一个部分封装成一个任务，交给线程池。
然后一个协调线程，调用`await｀等到所有的子部分完成. 再通过.

```java
class Driver2 { 
  void main() throws InterruptedException {
    CountDownLatch doneSignal = new CountDownLatch(N);
    Executor e = null; // some Executor

    for (int i = 0; i < N; ++i) // create and start threads
      e.execute(new WorkerRunnable(doneSignal, i));

    doneSignal.await();           // wait for all to finish
  }
}

class WorkerRunnable implements Runnable {
  private final CountDownLatch doneSignal;
  private final int i;
  WorkerRunnable(CountDownLatch doneSignal, int i) {
    this.doneSignal = doneSignal;
    this.i = i;
  }
  public void run() {
    try {
      doWork(i);
      doneSignal.countDown();
    } catch (InterruptedException ex) {} // return;
  }

  void doWork() {}
}

```

## 源码探究

最核心的实现，依然是继承自AQS的一个子类同步器`Sync`.

### Sync

```java
    /**
     * Synchronization control For CountDownLatch.
     * Uses AQS state to represent count.
     */
    private static final class Sync extends AbstractQueuedSynchronizer {
        private static final long serialVersionUID = 4982264981922014374L;

        Sync(int count) {
            setState(count);
        }

        int getCount() {
            return getState();
        }

        protected int tryAcquireShared(int acquires) {
            return (getState() == 0) ? 1 : -1;
        }

        protected boolean tryReleaseShared(int releases) {
            // Decrement count; signal when transition to zero
            for (;;) {
                int c = getState();
                if (c == 0)
                    return false;
                int nextc = c - 1;
                if (compareAndSetState(c, nextc))
                    return nextc == 0;
            }
        }
    }

```

首先，初始化时传递的`Count`值，复用AQS中的状态`State`.

实现了AQS的共享模式加锁及共享模式解锁.

#### tryAcquireShared(int acquires)

共享模式的加锁，锁空闲就返回1. 锁非空闲就返回-1.

#### tryReleaseShared(int releases)

共享模式的解锁.

```java
        protected boolean tryReleaseShared(int releases) {
            // Decrement count; signal when transition to zero
            for (;;) {
                int c = getState();
                if (c == 0)
                    return false;
                int nextc = c - 1;
                if (compareAndSetState(c, nextc))
                    return nextc == 0;
            }
        }

```

递减Count. 如果减1之后为0，就认为解锁成功. 通知.

如果减去1之后不为0. 返回false. 意味着解锁了，但是没有完全解锁成功.

### 构造方法

没啥说的，　将传入的Count值传入Sync.复用AQS的状态值来实现Count的控制.

### countDown()

调用Sync同步器的**释放共享锁**方法，进行一次解锁操作.

### await()

调用Sync同步器的**获取共享锁**方法，进行加锁操作.


## 总结

CountDownLatch是对AQS的共享模式的比较精巧的应用.

1. 首先初始化时传入Count值. 设置AQS的State值.
2. 由于自定义了共享锁的获取逻辑，当State值>0时，此锁不可再被获取.
3. countDown操作，即释放一次锁操作. 每次释放State值减1.
4. await操作，即加锁操作. 阻塞式加锁，在初始化之后，加锁会一直阻塞，直到调用N次的countDown之后，将锁完全释放. 此时获取锁成功，继续下一步，也就是`await`方法成功返回，成功通过`CountDownLatch`了.


**为什么CountDownLatch是一次性的?**

CountDownLatch中的同步器实现，并不是传统意义上的可以不断加锁或解锁。

只有在初始化时进行了设置State的操作，之后只可以进行读取/递减.

他的加锁操作，不会设置State的值，只是判断State是否大于1.

当解锁完成，State为0. 此时没有渠道去进行更新State的值.

如果重复的调用加锁，会不断的拿到"加锁成功". 但是State数值并不会改变.

因此此时的"加锁成功",其实意味着"门已经打开，可以无限进入". 每一次的"加锁操作", 约等于判断"门是否开着"的操作.

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