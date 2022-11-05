---
layout: post
tags:
  - Java
  - semaphore
  - JUC
---

本文源码基于: <font color='red'>JDK13</font>

## 前言

为了巩固AQS.　看一下Semaphore的源码.

## 简介

*大部分都是直接翻译的官方代码注释，嘻嘻*

一个计数的信号量.

概念上讲，信号量维护了一个许可证的集合. 每一个获取操作可能会阻塞，直到有许可证可用.

每一个释放操作，会添加一个许可证. 相当于隐式的释放一个阻塞的获取者.

信号量经常用于，　严格数量的线程访问资源. 比如下面是一个例子:

使用信号量来控制对一个对象池的访问.

(个人感觉，更像是使用信号量来实现一个对象池)

```java
  class Pool {
    private static final int MAX_AVAILABLE = 100;
    private final Semaphore available = new Semaphore(MAX_AVAILABLE, true);
 
    public Object getItem() throws InterruptedException {
      available.acquire();
      return getNextAvailableItem();
    }
 
    public void putItem(Object x) {
      if (markAsUnused(x))
        available.release();
    }
 
    // Not a particularly efficient data structure; just for demo
 
    protected Object[] items = ... whatever kinds of items being managed
    protected boolean[] used = new boolean[MAX_AVAILABLE];
 
    protected synchronized Object getNextAvailableItem() {
      for (int i = 0; i < MAX_AVAILABLE; ++i) {
        if (!used[i]) {
          used[i] = true;
          return items[i];
        }
      }
      return null; // not reached
    }
 
    protected synchronized boolean markAsUnused(Object item) {
      for (int i = 0; i < MAX_AVAILABLE; ++i) {
        if (item == items[i]) {
          if (used[i]) {
            used[i] = false;
            return true;
          } else
            return false;
        }
      }
      return false;
    }
  }

```

在获取每一个Item之前，必须先从信号量获取一个许可证，保证有一个对象是可用的。

当线程使用完该对象，将其返回给对象池时，　同时返回给信号量一个许可证. 允许其他线程申请该对象.

注意: 如果没有acquire的线程，那么将阻止一个对象返还给对象池.

信号量封装了对对象吃的访问同步控制，但是池子本身的同步需要自己实现.


如果将一个信号量初始化为只有1个. 因为只有一个可用的许可证，所以信号量使用起来就像一个独占式的锁.　就是经常说的`binary semaphore`.

因为他只有两种状态: 一个许可证可用，　没有许可证可用.

当使用`binary semaphore`时, 他有以下的特性: "锁"可以被除了锁的持有者之外的线程释放.(因为信号量没有拥有者的概念)

这在某些特殊的上下文中是有用的，　比如死锁的恢复.

构造方法可以接受一个`fairness`的参数，如果设置为false. 这个类不保证线程申请许可证的公平性. 一个线程申请许可证，可能比已经在等待的线程拿到的早.

当公平性设置为true. 线程获取许可证的顺序与他们调用acquire的顺序一致.

一般来讲，　信号量用来控制资源方法时，　应该被初始化为公平的。以保证没有线程饿死.

当使用信号量做其他类型的同步控制时，非公平顺序的吞吐量优势经常是比公平性更加重要的。

这个类还提供了一些方便的方法，比如一次性申请多个许可证的`acquire`和`release`方法.

这些方法比使用循环获取有更好的性能. 然而，他们不保证任何偏好顺序，比如，如果线程A调用了`acquire(3)`, 线程B调用了`acquire(2)`. 即将有两个许可证变得可用，没有保证说线程B会获取这两个许可证。除非线程B是首先进行申请的，且当前信号量是公平模式.

## 源码

### Sync同步器

首先当前是最核心的同步器的实现了.

```java
    /**
     * Synchronization implementation for semaphore.  Uses AQS state
     * to represent permits. Subclassed into fair and nonfair
     * versions.
     */
    abstract static class Sync extends AbstractQueuedSynchronizer {
        private static final long serialVersionUID = 1192457210091910933L;

        Sync(int permits) {
            setState(permits);
        }

        final int getPermits() {
            return getState();
        }

        // 非公平模式的获取
        final int nonfairTryAcquireShared(int acquires) {
            for (;;) {
                // 剩余
                int available = getState();
                // 减去此次获取的值
                int remaining = available - acquires;
                // 没有剩余了. 或者获取成功，返回剩余数量.
                // 这里的两个条件，一个是成功，一个是失败.
                if (remaining < 0 ||
                    compareAndSetState(available, remaining))
                    return remaining;
            }
        }

        // 释放
        protected final boolean tryReleaseShared(int releases) {
            for (;;) {
                // 当前
                int current = getState();
                // 释放后
                int next = current + releases;
                // 溢出了
                if (next < current) // overflow
                    throw new Error("Maximum permit count exceeded");
                // 释放操作，成功返回true. 否则重试
                if (compareAndSetState(current, next))
                    return true;
            }
        }

        final void reducePermits(int reductions) {
            for (;;) {
                int current = getState();
                int next = current - reductions;
                if (next > current) // underflow
                    throw new Error("Permit count underflow");
                if (compareAndSetState(current, next))
                    return;
            }
        }

        final int drainPermits() {
            for (;;) {
                int current = getState();
                if (current == 0 || compareAndSetState(current, 0))
                    return current;
            }
        }
    }

```

#### 构造方法

初始化时提供一个许可证的数量. 将其设置为AQS的State.

#### nonfaireTryAcquireShared(int acquire)

非公平模式的获取许可证.

首先获取当前剩余数量，减去此次申请的值后，
如果小于0.　获取失败，返回缺少的数量.
如果大于0. 尝试更改状态，成功即返回.

#### tryReleaseShared(int release)

首先获取当前剩余数量，加上此次释放的数量. 如果溢出，报错.
之后进行CAS的设置状态操作.

其他两个非公用API用到的时候再看.

## NonfaireSync 同步器

非公平模式的同步器. 

```java
    /**
 * NonFair version
 */
static final class NonfairSync extends Sync {
    private static final long serialVersionUID = -2694183684443567898L;

    NonfairSync(int permits) {
        super(permits);
    }

    protected int tryAcquireShared(int acquires) {
        return nonfairTryAcquireShared(acquires);
    }
}

```

只是将AQS的`tryAcquireShared`申请共享锁指向了在`Sync`中实现的非公平模式获取.

## FairSync 公平模式同步器

```java
    /**
     * Fair version
     */
    static final class FairSync extends Sync {
        private static final long serialVersionUID = 2014338818796000944L;

        FairSync(int permits) {
            super(permits);
        }

        protected int tryAcquireShared(int acquires) {
            for (;;) {
                if (hasQueuedPredecessors())
                    return -1;
                int available = getState();
                int remaining = available - acquires;
                if (remaining < 0 ||
                    compareAndSetState(available, remaining))
                    return remaining;
            }
        }
    }
```

公平模式的同步器，实现了公平模式的获取许可证.

1. 如果已经有队列中的节点，直接返回获取失败.
2. 其他和非公平模式一样，这样可以确保获取许可证的顺序和申请顺序是一致的.

### 构造方法

有点像`ReentrantLock`的构造方法，可以指定公平或者非公平模式. 此外传入一个许可证的数量.

### acquire系列.

* acquire() 获取许可证，调用AQS的`acquireSharedInterruptibly`.
* acquireUninterruptibly(). 忽略中断的获取许可证.
* tryAcquire(). 尝试获取一次许可证
* tryAcquire(long timeout, TimeUnit unit). 带有超时的尝试获取许可证
* acquire(int permits). 一次性获取多个许可证.
* ...上面方法的多个许可证版本



### release系列

* release() 释放一个许可证. 调用AQS的`releaseShared`.
* release(int permits). 一次性释放多个许可证.


## 总结

这是对AQS的又一个直接应用.

那么他是怎么定义State的呢?

初始化State为许可证的数量.

* 加锁，递减State. 只要State仍然大于0. 加锁即视为成功.
* 解锁, 递增State. 除了溢出肯定会成功.

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