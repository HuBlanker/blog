---
layout: post
tags:
  - Java
  - JUC
  - ReentrantLock
---

本文源码基于: <font color='red'>JDK13</font>

## 前言

上一篇文章讲了AQS的基本原理，其中两个关键的操作: 获取/释放.

依赖于子类的实现，本文就借着学习ReentrantLock的同时，继续巩固一下AQS.

ReentrantLock支持公平锁以及非公平锁，实现源于内部不同的AQS子类同步器.

公平锁: 加锁时候按照线程申请顺序. 公平一点.
非公平锁: 不保证按照顺序. 性能好一点.



## Sync同步器

既然ReentrantLock是基于AQS实现的，那么肯定是继承了AQS来实现了一个同步器，首先就来看Sync的代码。

Sync继承自AQS,主要实现了两个方法:

### nonfairTryAcquire(int acquires)

为非公平锁开发的一个获取锁方法:

```java
        /**
         * Performs non-fair tryLock.  tryAcquire is implemented in
         * subclasses, but both need nonfair try for trylock method.
         */
        @ReservedStackAccess
        final boolean nonfairTryAcquire(int acquires) {
            final Thread current = Thread.currentThread();
            int c = getState();
            if (c == 0) {
                if (compareAndSetState(0, acquires)) {
                    setExclusiveOwnerThread(current);
                    return true;
                }
            }
            else if (current == getExclusiveOwnerThread()) {
                int nextc = c + acquires;
                if (nextc < 0) // overflow
                    throw new Error("Maximum lock count exceeded");
                setState(nextc);
                return true;
            }
            return false;
        }

```

首先拿到当前的state值. 

如果state值为0.说明锁当前空闲，那么通过cas进行更改state的值.同时将锁的占用线程改成当前线程.

如果state不等于0. 且当前线程是锁的占用线程，那就将state值加上此次申请的值. 之后设置state值. 这个步骤也就是ReentrantLock是可重入锁的关键，
当发现锁的占用线程，就是当前线程时，不是加锁失败，而是叠加的加锁. 当然释放时也需要释放对应多的次数.

不满足以上两个条件，加锁失败，返回false.

### tryRelease(int release)

解锁操作就不用区分公平还是非公平锁了.

```java
        @ReservedStackAccess
        protected final boolean tryRelease(int releases) {
            int c = getState() - releases;
            if (Thread.currentThread() != getExclusiveOwnerThread())
                throw new IllegalMonitorStateException();
            boolean free = false;
            if (c == 0) {
                free = true;
                setExclusiveOwnerThread(null);
            }
            setState(c);
            return free;
        }

```

.

如果当前线程不是持有锁的线程，抛出异常.

如果获取当年的state.减去此次要释放的后. 为0. 说明成功的释放锁了, 将锁的state置为0. 持有线程置为空。

如果不为0.设置新的状态，不修改持有线程，同时返回false.因为还没有完全释放锁.

## FairSync

公平锁，实现了公平锁的获取操作.

```java
        /**
         * Fair version of tryAcquire.  Don't grant access unless
         * recursive call or no waiters or is first.
         */
        @ReservedStackAccess
        protected final boolean tryAcquire(int acquires) {
            final Thread current = Thread.currentThread();
            int c = getState();
            if (c == 0) {
                if (!hasQueuedPredecessors() &&
                    compareAndSetState(0, acquires)) {
                    setExclusiveOwnerThread(current);
                    return true;
                }
            }
            else if (current == getExclusiveOwnerThread()) {
                int nextc = c + acquires;
                if (nextc < 0)
                    throw new Error("Maximum lock count exceeded");
                setState(nextc);
                return true;
            }
            return false;
        }

```

1. 获取当前state
2. 如果state=0,说明锁空闲, 如果等待队列中也没有节点，同时获取锁成功，就将当前线程设置为锁的持有节点. 返回true.
3. 如果锁不空闲，但是当前线程就是锁的持有线程，对state进行累加操作.
4. 如果以上都不符合，加锁失败. 返回false.

## NonFairSync

非公平锁，他的获取操作，调用Sync类中的`nonfairTryAcquire`.

## ReentrantLock构造器

```java
/**
 * Creates an instance of {@code ReentrantLock}.
 * This is equivalent to using {@code ReentrantLock(false)}.
 */
public ReentrantLock() {
        sync = new NonfairSync();
        }

/**
 * Creates an instance of {@code ReentrantLock} with the
 * given fairness policy.
 *
 * @param fair {@code true} if this lock should use a fair ordering policy
 */
public ReentrantLock(boolean fair) {
        sync = fair ? new FairSync() : new NonfairSync();
        }
```

两个构造器，默认是非公平锁，可以指定创建一个公平锁.

## lock 加锁

加锁操作，调用链如下:

![2021-09-29-22-01-53](http://img.couplecoders.tech/2021-09-29-22-01-53.png)

完全等同于AQS的`acquire`操作，只是在`tryAcquire`调用了ReentrantLock自己实现的方法.

## tryLock()

调用同步器`NonFairSync`的`nonfairTryAcquire`. 做一次获取的尝试，成功就返回true.否则返回false.

## tryLock(long timeout, TimeUnit unit)

带有自动超时的tryLock.

## unlock()

完全等同于AQS的`release`操作，只是在`tryRelease`调用了ReentrantLock自己实现的方法.


其他方法都是非核心方法，提供一些对于属性的读取，不再赘述.

## 总结

ReentrantLock基本上完全基于AQS的独占式加锁/解锁.

走的流程也是AQS的加锁/解锁流程，
只是在最核心的操作状态(State)上，依赖于ReentrantLock的实现而已.

ReentrantLock定义了State状态的具体值，+1/-1分别代表什么操作，
也因为对State可以执行累加操作，而获得了**可重入**特性.

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