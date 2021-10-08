---
layout: post
category: [Java,JUC,StampedLock]
tags:
  - Java
  - JUC
  - StampedLock
---


## 简介

*约等于翻译官方注释*

一个有三种模式,来控制读/写访问的锁. `StampedLock`的状态由一个版本和模式来组成.

锁的申请方法返回一个stamp,释放锁的时候需要这个参数,如果传入的stamp和锁的状态不匹配,则释放失败.

三个模式分别是:

* 写
`writeLock`将以独占模式加锁,返回一个stamp可以用来调用`unlockWrite`以解锁.提供了超时版本和不超时的版本.如果锁被以写模式持有,没有读锁可以被获取,所有的乐观读锁的申请将会失败.
* 读
`readLock`提供非独占式的加锁,返回一个stamp可以用来调用`unlockRead`以解锁. 也提供了超时和不超时的版本.
* 乐观读
`tryOptimisticRead`返回一个非零的stamp,如果锁没有被写模式持有. 如果锁已经被写模式获取,`validate`返回true.
这个模式可以被认为是一个极其软性的读锁,可以在任何时候被一个写锁打断.
乐观读模式在很短的只读代码段中使用,经常能够减少争抢以提升吞吐量.
然后它是天生脆弱的. 乐观读部分应该值用来读取属性,然后只在局部变量中持有锁.
乐观读的属性读取可能会不一致,所以只在你足够熟悉数据结构可以检查一致性的时候使用它.

这个类还支持三种模式之间的转换. 比如: `tryConvertToWriteLock`尝试去升级模式,当以下任意一个条件符合时,返回一个可用的写stamp.
1. 已经在写模式.
2. 在读模式,但是没有其他读取者
3. 在乐观读模式且锁可用.

这些形式设计来减少代码膨胀.

StampedLocks设计,是实现一些内部的线程安全组件的工具. 他的使用依赖于对数据结构,对象,方法的熟悉.
这个锁是不可重入的,因此锁住的部分应该不要调用不知道的方法,可能会导致重复的申请锁.(如果你把stamp传递给其他方法,那你可以使用或者升级锁).
读模式的锁使用依赖于使用的代码片段是无副作用的.
未经验证的乐观读模式不要调用不熟悉的方法,可能会导致不一致.

stamps表述能力有限,且没有加密. stamp的值可能会在一系列操作后被回收. 一个stamp不要持有太长时间,因为可能会验证失败.

`StampedLock`是可序列化的,但是会反序列化成最初的未加锁状态,因此不能用来做远程加锁.

像`Semaphore`,但是和大多数锁的实现不一样,`StampedLock`没有持有者的概念,一个线程申请的锁可能会被其他线程释放掉.

`StampedLock`锁的调度策略不一致,更加喜欢读锁而不是写锁.所有的`try`方法都是尽力而不是一定会遵从调度策略.
获取锁的`try`相关方法返回0,不表达更多信息,随后的申请锁可能会成功.

因为支持多种模式的协调使用,这个类不直接实现`Lock`或者`ReadWriteLock`接口.
然而,一个`StampedLock`可以当做一个读锁,写锁,或者读写锁.


简单的使用案例:
一个类维护简单的二维点.

```java
  class Point {
    private double x, y;
    private final StampedLock sl = new StampedLock();
 
    // an exclusively locked method
    void move(double deltaX, double deltaY) {
      long stamp = sl.writeLock();
      try {
        x += deltaX;
        y += deltaY;
      } finally {
        sl.unlockWrite(stamp);
      }
    }
 
    // a read-only method
    // upgrade from optimistic read to read lock
    double distanceFromOrigin() {
      long stamp = sl.tryOptimisticRead();
      try {
        retryHoldingLock: for (;; stamp = sl.readLock()) {
          if (stamp == 0L)
            continue retryHoldingLock;
          // possibly racy reads
          double currentX = x;
          double currentY = y;
          if (!sl.validate(stamp))
            continue retryHoldingLock;
          return Math.hypot(currentX, currentY);
        }
      } finally {
        if (StampedLock.isReadLockStamp(stamp))
          sl.unlockRead(stamp);
      }
    }
 
    // upgrade from optimistic read to write lock
    void moveIfAtOrigin(double newX, double newY) {
      long stamp = sl.tryOptimisticRead();
      try {
        retryHoldingLock: for (;; stamp = sl.writeLock()) {
          if (stamp == 0L)
            continue retryHoldingLock;
          // possibly racy reads
          double currentX = x;
          double currentY = y;
          if (!sl.validate(stamp))
            continue retryHoldingLock;
          if (currentX != 0.0 || currentY != 0.0)
            break;
          stamp = sl.tryConvertToWriteLock(stamp);
          if (stamp == 0L)
            continue retryHoldingLock;
          // exclusive access
          x = newX;
          y = newY;
          return;
        }
      } finally {
        if (StampedLock.isWriteLockStamp(stamp))
          sl.unlockWrite(stamp);
      }
    }
 
    // Upgrade read lock to write lock
    void moveIfAtOrigin(double newX, double newY) {
      long stamp = sl.readLock();
      try {
        while (x == 0.0 && y == 0.0) {
          long ws = sl.tryConvertToWriteLock(stamp);
          if (ws != 0L) {
            stamp = ws;
            x = newX;
            y = newY;
            break;
          }
          else {
            sl.unlockRead(stamp);
            stamp = sl.writeLock();
          }
        }
      } finally {
        sl.unlock(stamp);
      }
    }
  }
```

这个类管理了一个二维的点.提供了以下几个方法:

* move
独占式加锁,加个写锁,然后把当前点移到给定位置.
* distanceFromOrigin
只读方法,从乐观读升级到读锁.首先申请一个乐观读锁,如果乐观读锁不合法,将申请读锁.之后计算当前点到原点的距离.
* moveIfAtOrigin
从乐观读锁升级到写锁,首先申请乐观读, 如果合法且当前点再原地,就升级到写锁,将当前点移动到给定位置.
如果不合法,就升级写锁,移动点.
* moveIfAtOrigin2
从读锁升级到写锁,先申请个读锁,如果当前点在原地,就申请个写锁,将当前点移动到给定位置. 如果升级失败,就直接申请个写锁,移动点.

有一说一,没太懂会在什么场景使用这个类.

## 源码学习

### 主要的属性

```java
// 一堆常量
// 读线程的个数占有低7位
private static final int LG_READERS = 7;
// 读线程个数每次增加的单位
private static final long RUNIT = 1L;
// 写线程个数所在的位置
private static final long WBIT  = 1L << LG_READERS;  // 128 = 1000 0000
// 读线程个数所在的位置
private static final long RBITS = WBIT - 1L;  // 127 = 111 1111
// 最大读线程个数
private static final long RFULL = RBITS - 1L;  // 126 = 111 1110
// 读线程个数和写线程个数的掩码
private static final long ABITS = RBITS | WBIT;  // 255 = 1111 1111
// 读线程个数的反数，高25位全部为1
private static final long SBITS = ~RBITS;  // -128 = 1111 1111 1111 1111 1111 1111 1111 1111 1111 1111 1111 1111 1111 1111 1000 0000

// state的初始值
private static final long ORIGIN = WBIT << 1;  // 256 = 1 0000 0000
// 队列的头节点
private transient volatile WNode whead;
// 队列的尾节点
private transient volatile WNode wtail;
// 存储着当前的版本号，类似于AQS的状态变量state
private transient volatile long state;
```

一堆常量和状态,队列.
这个类没有使用AQS实现,而是自己维护了相似的结构,一个state变量和内部的队列.

而且根据常量可以看出来,内部状态使用bit来维护相关的信息.


### 构造方法

```java
    public StampedLock() {
        state = ORIGIN;
    }
```

将状态设置为初始的,未加锁状态. state=256.

### 写模式

#### writeLock 获取写锁

```java
    @ReservedStackAccess
    public long writeLock() {
        long next;
        return ((next = tryWriteLock()) != 0L) ? next : acquireWrite(false, 0L);
    }
```

首先调用`trWriteLock`,如果获取成功,则返回stamp.否则调用`acquireWrite`.

##### trWriteLock 尝试拿一下写锁

```java
   // 共用的方法
    @ReservedStackAccess
    public long tryWriteLock() {
        long s;
        return (((s = state) & ABITS) == 0L) ? tryWriteLock(s) : 0L;
    }
    
    // 内部真实实现
    private long tryWriteLock(long s) {
        // assert (s & ABITS) == 0L;
        long next;
        if (casState(s, next = s | WBIT)) {
            VarHandle.storeStoreFence();
            return next;
        }
        return 0L;
    }

```
`tryWriteLock()`方法中,首先判断`((s = state) & ABITS) == 0L)`. 如果不等于0意味着什么呢?
不等于0,意味着当前状态值小于255,也就是低7位有1.意味着当前锁已经被持有,直接返回0. 
否则的话调用`tryWriteLock(s)`.

`tryWriteLock(s)`方法中,首先使用CAS将state值的第7位置为1. 因为`WBIT=1<<7`.
如果成功, 返回加锁后的state值.
如果失败,返回0. 

##### acquireWrite 阻塞/自旋获取写锁

写锁申请时,首先尝试加锁,如果成功了,就返回加锁后的状态,如果没有成功,就会调用这个方法了.

```java
    private long acquireWrite(boolean interruptible, long deadline) {
        WNode node = null, p;
        // 自旋
        for (int spins = -1;;) { // spin while enqueuing
            long m, s, ns;
            // 没有写锁/读锁,尝试加写锁,成功就返回
            if ((m = (s = state) & ABITS) == 0L) {
                if ((ns = tryWriteLock(s)) != 0L)
                    return ns;
            }
            else if (spins < 0)
                spins = (m == WBIT && wtail == whead) ? SPINS : 0;
            else if (spins > 0) {
                --spins;
                Thread.onSpinWait();
            }
            else if ((p = wtail) == null) { // initialize queue
                WNode hd = new WNode(WMODE, null);
                if (WHEAD.weakCompareAndSet(this, null, hd))
                    wtail = hd;
            }
            else if (node == null)
                node = new WNode(WMODE, p);
            else if (node.prev != p)
                node.prev = p;
            else if (WTAIL.weakCompareAndSet(this, p, node)) {
                p.next = node;
                break;
            }
        }

        boolean wasInterrupted = false;
        for (int spins = -1;;) {
            WNode h, np, pp; int ps;
            if ((h = whead) == p) {
                if (spins < 0)
                    spins = HEAD_SPINS;
                else if (spins < MAX_HEAD_SPINS)
                    spins <<= 1;
                for (int k = spins; k > 0; --k) { // spin at head
                    long s, ns;
                    if (((s = state) & ABITS) == 0L) {
                        if ((ns = tryWriteLock(s)) != 0L) {
                            whead = node;
                            node.prev = null;
                            if (wasInterrupted)
                                Thread.currentThread().interrupt();
                            return ns;
                        }
                    }
                    else
                        Thread.onSpinWait();
                }
            }
            else if (h != null) { // help release stale waiters
                WNode c; Thread w;
                while ((c = h.cowait) != null) {
                    if (WCOWAIT.weakCompareAndSet(h, c, c.cowait) &&
                        (w = c.thread) != null)
                        LockSupport.unpark(w);
                }
            }
            if (whead == h) {
                if ((np = node.prev) != p) {
                    if (np != null)
                        (p = np).next = node;   // stale
                }
                else if ((ps = p.status) == 0)
                    WSTATUS.compareAndSet(p, 0, WAITING);
                else if (ps == CANCELLED) {
                    if ((pp = p.prev) != null) {
                        node.prev = pp;
                        pp.next = node;
                    }
                }
                else {
                    long time; // 0 argument to park means no timeout
                    if (deadline == 0L)
                        time = 0L;
                    else if ((time = deadline - System.nanoTime()) <= 0L)
                        return cancelWaiter(node, node, false);
                    Thread wt = Thread.currentThread();
                    node.thread = wt;
                    if (p.status < 0 && (p != h || (state & ABITS) != 0L) &&
                        whead == h && node.prev == p) {
                        if (time == 0L)
                            LockSupport.park(this);
                        else
                            LockSupport.parkNanos(this, time);
                    }
                    node.thread = null;
                    if (Thread.interrupted()) {
                        if (interruptible)
                            return cancelWaiter(node, node, true);
                        wasInterrupted = true;
                    }
                }
            }
        }
    }
```

这是个支持中断及超时的一个申请获取写锁的方法,虽然刚才的方法调用时,不支持中断,不超时.但是我们直接看下完整体的代码是怎么写的.

首先涉及到的是`WNode`内部类,他是一个类似于AQS中的队列节点的类,不展开了.

首先是入队的一次自旋:

1. 如果当前没有读锁/写锁,尝试加写锁,成功就返回.
2. 如果旋转次数小于0,就算一个旋转次数, (如果当前锁是写锁并且队列为空,代表快轮到自己了. 就根据cpu计算一个次数,否则旋转0次.
3. 如果旋转次数大于0,就稍等一会.选择次数减一.
4. 如果等待队列的尾巴为空, 说明没有初始化, 将当前线程搞成尾巴放入队列.
5. 如果还没有为当前线程创建节点,创建个节点.
6. 如果将当前节点连接在等待队列的尾巴成功,就退出这个循环.

第二个自旋的循环来了,目的是阻塞且等待唤醒:

1. 如果队列的头和尾相同,说明队列中只有当前节点的前置节点在等待,快轮到自己了.
   1. 初始化旋转次数, 旋转次数小于0,根据cpu计算一个旋转次数.否则将旋转次数扩大一倍.
   2. 开始自旋, 判断是否有读锁/写锁,没有就尝试加写锁,成功就返回.
2. 如果队列头和尾不同,且队头不为空.
   1. 循环将所有等待者唤醒.
3. 如果队头还是原来的队头,说明什么都还没变
   1. 如果尾节点有变化, 更新变化, 当前节点放在队尾
   2. 如果队尾的状态是0,改成等待中.
   3. 如果队尾的状态是取消了,往前挪一个.
   4. 如果超时了,取消等待
   5. 阻塞当前线程,等待唤醒.

好复杂啊....

简单总结一下:

1. 第一次自旋, 如果队列为空,就算一个自旋次数,开始尝试获取锁,否则直接入队开始第二段自旋.
2. 第二段自旋, 如果队列只有一个元素,说明快到自己了,算一个自旋次数开始自旋.也就是第三次自旋.
3. 否则的话, 就休眠等待唤醒.




#### unlockWrite 释放写锁

```java
    public void unlockWrite(long stamp) {
        if (state != stamp || (stamp & WBIT) == 0L)
            throw new IllegalMonitorStateException();
        unlockWriteInternal(stamp);
    }
```

检查stamp的合法性,必须和锁的状态一致,且是写锁,即第7位必须为1.

之后调用`unlockWriteInternal`.

```java
    // 内部的释放写锁
    private long unlockWriteInternal(long s) {
        long next; WNode h;
        STATE.setVolatile(this, next = unlockWriteState(s));
        if ((h = whead) != null && h.status != 0)
            release(h);
        return next;
    }
    
    // 计算释放后的状态
    private static long unlockWriteState(long s) {
        return ((s += WBIT) == 0L) ? ORIGIN : s;
    }
    
    // 真正的释放写锁
    private void release(WNode h) {
        if (h != null) {
            WNode q; Thread w;
            WSTATUS.compareAndSet(h, WAITING, 0);
            if ((q = h.next) == null || q.status == CANCELLED) {
                for (WNode t = wtail; t != null && t != h; t = t.prev)
                    if (t.status <= 0)
                        q = t;
            }
            if (q != null && (w = q.thread) != null)
                LockSupport.unpark(w);
        }
    }
```

这段逻辑里,涉及到3个方法,一个一个说.

##### unlockWriteInternal

计算释放后的状态. 如果头结点不为空且头结点的状态不为0, 就调用`release`. 
之后返回释放后的状态.

##### unlockWriteState

计算下解锁后的状态,返回即可.

注意解锁的操作是: 对原有的值`+WBIT`. 由于加锁就是第7位为1.再加1导致进位,相当于将第7位置为0了. 解锁成功.

##### release(WNode)

找到头结点的下一个, 唤醒它.

### 读模式

#### readLock() 读模式加锁

```java
    public long readLock() {
        long s, next;
        // bypass acquireRead on common uncontended case
        return (whead == wtail
                && ((s = state) & ABITS) < RFULL
                && casState(s, next = s + RUNIT))
            ? next
            : acquireRead(false, 0L);
    }
```

1. 队头等于队尾,等待队列为空.
2. 当前读锁的个数小于最大值126.
3. cas更新状态, 给已有的数字+1,代表多了一个读锁. 成功.

以上三个状态全部满足,返回更新后的状态,代表获取了一个读锁.

如果有一个不满足,走`acquireRead`.

##### acquireRead 阻塞式获取读锁

```java
    private long acquireRead(boolean interruptible, long deadline) {
        boolean wasInterrupted = false;
        WNode node = null, p;
        for (int spins = -1;;) {
            WNode h;
            if ((h = whead) == (p = wtail)) {
                for (long m, s, ns;;) {
                    if ((m = (s = state) & ABITS) < RFULL ?
                        casState(s, ns = s + RUNIT) :
                        (m < WBIT && (ns = tryIncReaderOverflow(s)) != 0L)) {
                        if (wasInterrupted)
                            Thread.currentThread().interrupt();
                        return ns;
                    }
                    else if (m >= WBIT) {
                        if (spins > 0) {
                            --spins;
                            Thread.onSpinWait();
                        }
                        else {
                            if (spins == 0) {
                                WNode nh = whead, np = wtail;
                                if ((nh == h && np == p) || (h = nh) != (p = np))
                                    break;
                            }
                            spins = SPINS;
                        }
                    }
                }
            }
            if (p == null) { // initialize queue
                WNode hd = new WNode(WMODE, null);
                if (WHEAD.weakCompareAndSet(this, null, hd))
                    wtail = hd;
            }
            else if (node == null)
                node = new WNode(RMODE, p);
            else if (h == p || p.mode != RMODE) {
                if (node.prev != p)
                    node.prev = p;
                else if (WTAIL.weakCompareAndSet(this, p, node)) {
                    p.next = node;
                    break;
                }
            }
            else if (!WCOWAIT.compareAndSet(p, node.cowait = p.cowait, node))
                node.cowait = null;
            else {
                for (;;) {
                    WNode pp, c; Thread w;
                    if ((h = whead) != null && (c = h.cowait) != null &&
                        WCOWAIT.compareAndSet(h, c, c.cowait) &&
                        (w = c.thread) != null) // help release
                        LockSupport.unpark(w);
                    if (Thread.interrupted()) {
                        if (interruptible)
                            return cancelWaiter(node, p, true);
                        wasInterrupted = true;
                    }
                    if (h == (pp = p.prev) || h == p || pp == null) {
                        long m, s, ns;
                        do {
                            if ((m = (s = state) & ABITS) < RFULL ?
                                casState(s, ns = s + RUNIT) :
                                (m < WBIT &&
                                 (ns = tryIncReaderOverflow(s)) != 0L)) {
                                if (wasInterrupted)
                                    Thread.currentThread().interrupt();
                                return ns;
                            }
                        } while (m < WBIT);
                    }
                    if (whead == h && p.prev == pp) {
                        long time;
                        if (pp == null || h == p || p.status > 0) {
                            node = null; // throw away
                            break;
                        }
                        if (deadline == 0L)
                            time = 0L;
                        else if ((time = deadline - System.nanoTime()) <= 0L) {
                            if (wasInterrupted)
                                Thread.currentThread().interrupt();
                            return cancelWaiter(node, p, false);
                        }
                        Thread wt = Thread.currentThread();
                        node.thread = wt;
                        if ((h != pp || (state & ABITS) == WBIT) &&
                            whead == h && p.prev == pp) {
                            if (time == 0L)
                                LockSupport.park(this);
                            else
                                LockSupport.parkNanos(this, time);
                        }
                        node.thread = null;
                    }
                }
            }
        }

        for (int spins = -1;;) {
            WNode h, np, pp; int ps;
            if ((h = whead) == p) {
                if (spins < 0)
                    spins = HEAD_SPINS;
                else if (spins < MAX_HEAD_SPINS)
                    spins <<= 1;
                for (int k = spins;;) { // spin at head
                    long m, s, ns;
                    if ((m = (s = state) & ABITS) < RFULL ?
                        casState(s, ns = s + RUNIT) :
                        (m < WBIT && (ns = tryIncReaderOverflow(s)) != 0L)) {
                        WNode c; Thread w;
                        whead = node;
                        node.prev = null;
                        while ((c = node.cowait) != null) {
                            if (WCOWAIT.compareAndSet(node, c, c.cowait) &&
                                (w = c.thread) != null)
                                LockSupport.unpark(w);
                        }
                        if (wasInterrupted)
                            Thread.currentThread().interrupt();
                        return ns;
                    }
                    else if (m >= WBIT && --k <= 0)
                        break;
                    else
                        Thread.onSpinWait();
                }
            }
            else if (h != null) {
                WNode c; Thread w;
                while ((c = h.cowait) != null) {
                    if (WCOWAIT.compareAndSet(h, c, c.cowait) &&
                        (w = c.thread) != null)
                        LockSupport.unpark(w);
                }
            }
            if (whead == h) {
                if ((np = node.prev) != p) {
                    if (np != null)
                        (p = np).next = node;   // stale
                }
                else if ((ps = p.status) == 0)
                    WSTATUS.compareAndSet(p, 0, WAITING);
                else if (ps == CANCELLED) {
                    if ((pp = p.prev) != null) {
                        node.prev = pp;
                        pp.next = node;
                    }
                }
                else {
                    long time;
                    if (deadline == 0L)
                        time = 0L;
                    else if ((time = deadline - System.nanoTime()) <= 0L)
                        return cancelWaiter(node, node, false);
                    Thread wt = Thread.currentThread();
                    node.thread = wt;
                    if (p.status < 0 &&
                        (p != h || (state & ABITS) == WBIT) &&
                        whead == h && node.prev == p) {
                            if (time == 0L)
                                LockSupport.park(this);
                            else
                                LockSupport.parkNanos(this, time);
                    }
                    node.thread = null;
                    if (Thread.interrupted()) {
                        if (interruptible)
                            return cancelWaiter(node, node, true);
                        wasInterrupted = true;
                    }
                }
            }
        }
    }

```

又是超级一大串代码.....不过有了之前的经验, 可能会轻松一点.

首先是第一次自旋:

1. 队头等于队尾, 说明等待队列为空,很快就可以到自己.
   1. 如果申请读锁成功, 则直接返回.
   2. 如果当前有写锁,就递减自旋次数,等待. 如果自旋次数为0了,看看是再自旋一会还是退出循环.
2. 如果队列没有初始化, 则初始化队列,将当前节点置为尾节点.
3. 如果当前节点没有初始化, 初始化当前节点.
4. 如果头点击发生了变化, 更新下相关信息.
5. 进入嵌套的第二次自旋:
   1. 如果头结点不为空且有等待节点,帮助唤醒等待节点.
   2. 如果头结点就是当前节点的前置节点,或者头结点是当前节点, 说明快要轮到自己了.
      1. 进入嵌套的第三次自旋,不断的尝试获取读锁,成功就返回.
   3. 如果头结点没有变化,当前节点的前置节点也没变, 就安心的阻塞等待一会,这里是支持超时机制的.

进入第二个大的循环体:

和第一段很像, 但是是单独给第一个读线程设计的.

1. 如果头结点等于为节点,说明快到自己了.初始化自选次数然后不断尝试获取锁.期间如果发现锁被别的写锁获取了,就退出循环.
2. 如果头结点不为空,帮助其唤醒他的等待者.
3. 如果头结点有变化, 更新相关的信息.
4. 如果尾节点状态为0, 改成waiting. 如果尾节点是取消状态, 跳过该节点.
5. 之后计算超时时间,让当前线程休眠等待唤醒.

##### tryIncReaderOverflow 尝试递增一个读锁

```java
    private long tryIncReaderOverflow(long s) {
        // assert (s & ABITS) >= RFULL;
        if ((s & ABITS) == RFULL) {
            if (casState(s, s | RBITS)) {
                ++readerOverflow;
                STATE.setVolatile(this, s);
                return s;
            }
        }
        else if ((LockSupport.nextSecondarySeed() & OVERFLOW_YIELD_RATE) == 0)
            Thread.yield();
        else
            Thread.onSpinWait();
        return 0L;
    }
```

如果读锁满了.更新状态,计数.

#### unlockRead 读锁解锁

```java
    public void unlockRead(long stamp) {
        long s, m; WNode h;
        while (((s = state) & SBITS) == (stamp & SBITS)
               && (stamp & RBITS) > 0L
               && ((m = s & RBITS) > 0L)) {
            if (m < RFULL) {
                if (casState(s, s - RUNIT)) {
                    if (m == RUNIT && (h = whead) != null && h.status != 0)
                        release(h);
                    return;
                }
            }
            else if (tryDecReaderOverflow(s) != 0L)
                return;
        }
        throw new IllegalMonitorStateException();
    }
```

首先对stamped进行检查,如果OK.进行递减,更新状态. 然后唤醒下一个节点.
如果超过最大可获取读锁数,尝试递减,成功返回.
其他情况抛出异常.

##### tryDecReaderOverFlow

```java

    private long tryDecReaderOverflow(long s) {
        // assert (s & ABITS) >= RFULL;
        if ((s & ABITS) == RFULL) {
            if (casState(s, s | RBITS)) {
                int r; long next;
                if ((r = readerOverflow) > 0) {
                    readerOverflow = r - 1;
                    next = s;
                }
                else
                    next = s - RUNIT;
                STATE.setVolatile(this, next);
                return next;
            }
        }
        else if ((LockSupport.nextSecondarySeed() & OVERFLOW_YIELD_RATE) == 0)
            Thread.yield();
        else
            Thread.onSpinWait();
        return 0L;
    }
```

尝试递减读锁,如果溢出的话,溢出数量减1. 如果没有溢出,返回状态值.


#### 乐观读模式

##### tryOptimisticRead 尝试获取乐观读锁

```java
    public long tryOptimisticRead() {
        long s;
        return (((s = state) & WBIT) == 0L) ? (s & SBITS) : 0L;
    }
```

返回一个stamp,稍后用来验证, 如果当前已经是写锁了,返回0.

##### validate 验证stamp的正确性

```java

    public boolean validate(long stamp) {
        VarHandle.acquireFence();
        return (stamp & SBITS) == (state & SBITS);
    }
```

约等于直接验证相等性.区别不大.

##### tryConvertToWriteLock

```java
    public long tryConvertToWriteLock(long stamp) {
        long a = stamp & ABITS, m, s, next;
        while (((s = state) & SBITS) == (stamp & SBITS)) {
            if ((m = s & ABITS) == 0L) {
                if (a != 0L)
                    break;
                if ((next = tryWriteLock(s)) != 0L)
                    return next;
            }
            else if (m == WBIT) {
                if (a != m)
                    break;
                return stamp;
            }
            else if (m == RUNIT && a != 0L) {
                if (casState(s, next = s - RUNIT + WBIT)) {
                    VarHandle.storeStoreFence();
                    return next;
                }
            }
            else
                break;
        }
        return 0L;
    }
```

尝试转换成一个写锁.

如果状态等于给定的stamp. 则原子性的进行以下操作:

如果stamp表示持有一个写锁. 直接返回.
如果持有读锁,且写锁是可用的,释放读锁然后申请写锁进行返回.
如果是一个乐观的读锁, 如果锁立即可用,就返回一个写锁.

这个方法永远返回0.

##### tryConvertToReadLock 尝试转换成一个读锁

```java
    public long tryConvertToReadLock(long stamp) {
        long a, s, next; WNode h;
        while (((s = state) & SBITS) == (stamp & SBITS)) {
            if ((a = stamp & ABITS) >= WBIT) {
                // write stamp
                if (s != stamp)
                    break;
                STATE.setVolatile(this, next = unlockWriteState(s) + RUNIT);
                if ((h = whead) != null && h.status != 0)
                    release(h);
                return next;
            }
            else if (a == 0L) {
                // optimistic read stamp
                if ((s & ABITS) < RFULL) {
                    if (casState(s, next = s + RUNIT))
                        return next;
                }
                else if ((next = tryIncReaderOverflow(s)) != 0L)
                    return next;
            }
            else {
                // already a read stamp
                if ((s & ABITS) == 0L)
                    break;
                return stamp;
            }
        }
        return 0L;
    }
```

如果锁状态和给定stamp相同,执行以下操作:

1. 如果stamp表示持有的是一个写锁, 释放写锁,申请一个读锁进行返回.
2. 如果持有的是一个读锁.直接返回.
3. 如果持有的是一个乐观读锁, 如果锁立即可用的情况下, 申请一个读锁返回.

这个方法永远返回0.

##### tryConvertToOptimisticRead 尝试转换成乐观读锁

```java
    public long tryConvertToOptimisticRead(long stamp) {
        long a, m, s, next; WNode h;
        VarHandle.acquireFence();
        while (((s = state) & SBITS) == (stamp & SBITS)) {
            if ((a = stamp & ABITS) >= WBIT) {
                // write stamp
                if (s != stamp)
                    break;
                return unlockWriteInternal(s);
            }
            else if (a == 0L)
                // already an optimistic read stamp
                return stamp;
            else if ((m = s & ABITS) == 0L) // invalid read stamp
                break;
            else if (m < RFULL) {
                if (casState(s, next = s - RUNIT)) {
                    if (m == RUNIT && (h = whead) != null && h.status != 0)
                        release(h);
                    return next & SBITS;
                }
            }
            else if ((next = tryDecReaderOverflow(s)) != 0L)
                return next & SBITS;
        }
        return 0L;
    }
```


如果锁状态和给定stamp相同,执行以下操作:

1. 如果stamp表示正在持有一个锁, 释放他, 返回一个乐观的stamp
2. 如果当前持有的就是乐观读锁,直接返回.

#### 其他方法

除此之外,还提供了一些用于判断当前锁状态,以及给定的stamp状态的方法. 比如:

方法 | 作用
--- | ---
isWriteLocked | 是否是写锁
isReadLocked | 是否是读锁
isWriteLockStamp | 是否是写锁的stamp
isReadLockStamp | 是否是读锁的stamp
isLockStamp | 是否是个锁的stamp
isOptimisticReadStamp | 是否是乐观读的stamp
isOptimisticReadStamp | 获取读锁的数量


## 总结

`StampedLock`是一个支持多种模式的,性能更好的读写锁.

他不是由AQS实现,而是自己实现的内部状态及等待队列的管理.

对内部状态的定义也是自己完成的. 内部的state值. 按位进行管理. 低位第7位代表写锁,低位的6位数字代表读锁以及读锁的个数.

由于第八位只有一个bit位来表示是否获取了写锁,因此是不可重入的.

代码中采用了大量的自旋操作,因此在竞争较小的时候性能会好一些,竞争太大的时候,会比较浪费cpu.

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


**更多学习笔记见个人博客或关注微信公众号 &lt;呼延十 &gt;------><a href="{{
site.baseurl }}/">呼延十</a>**
