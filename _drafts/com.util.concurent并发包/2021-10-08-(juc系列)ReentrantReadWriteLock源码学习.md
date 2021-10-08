---
layout: post
category: [Java, JUC, Lock]
tags:
  - Java
  - JUC
  - Lock
---


本文源码基于: <font color='red'>JDK13</font>


## 简介

这个类是一个`ReadWriteLock`的实现类，实现了类似于`ReentrantLock`的语义.

这个类有以下特性:

### 获取顺序

这个类没有给读写者强加获取锁的顺序，但是他实现了一个可选的公平策略。

* 非公平模式(默认模式
当创建一个非公平的锁，获取读锁，写锁的顺序是没有指定的. 满足可重入性的约束.
  
一个非公平锁，可能会因为不断的争执，而无限期的推迟一个或者多个读锁/写锁的获取线程，但是通常来讲拥有更好的吞吐量.

* 公平模式

当创建一个公平所，线程竞争使用一个到达序的策略. 当前持有锁的线程释放锁，等待时间最长的单个写入线程就拿到写锁，　或者如果有一组读线程，
等待的时间比所有的写线程都长，那么这组读线程将拿到读锁.

如果当前锁正在被写锁持有，或者有一个等待的写线程，公平模式下的获取读锁的请求将会被阻塞. 直到等待时间最长的写线程拿到锁并释放.

当然，如果一个等待中的写线程放弃了，让一个或者多少读线程成为了队列中等待最久的，　这些读线程将拿到读锁.

如果一个写线程尝试获取锁，除非当前所有的读锁和写锁都是空闲的，　才能拿到锁，意味着当前不能有任何的等待线程.

### 可重入性

这个锁允许所有的读线程和写线程重复的申请对应的锁，就像`ReentrantLock`一样. 不是重入的读线程将被正在持有锁的写线程阻塞.

一个写线程可以获取读锁. 在很多应用中，可重入性很有用，当写线程持有写锁，在某些调用或者回调方法中执行读操作。如果一个读线程尝试去申请写锁，永远不会成功.

### 锁降级

支持从写锁降级到读锁，但是从读锁升级到写锁是不允许的.

### 支持Condition

写锁提供了一个`Condition`的实现，他的行为模式和写锁一样. 就像`ReentrantLock`中的Condition一样.读锁不支持`Condition`.

### 仪表盘

这个类支持查看锁被持有还是竞争中，这些方法用于监视系统状态，而不是用于同步控制.

这个锁的序列化和内置锁的行为方式相同，反序列化的锁处于解锁状态，无论序列化时状态如何.

### 简单的使用案例.

代码片段简单的展示了在更新cache之后如何进行锁的降级.

```java
class CachedData {
   Object data;
   boolean cacheValid;
   final ReentrantReadWriteLock rwl = new ReentrantReadWriteLock();

   void processCachedData() {
       // 读锁
     rwl.readLock().lock();
     
     if (!cacheValid) {
       // Must release read lock before acquiring write lock
         // 释放读锁
       rwl.readLock().unlock();
       // 申请写锁
       rwl.writeLock().lock();
       try {
         // Recheck state because another thread might have
         // acquired write lock and changed state before we did.
         if (!cacheValid) {
             // 新数据的赋值
           data = ...
           cacheValid = true;
         }
         // Downgrade by acquiring read lock before releasing write lock
           // 降级成读锁
         rwl.readLock().lock();
       } finally {
           // 释放写锁，还持有读锁
         rwl.writeLock().unlock(); // Unlock write, still hold read
       }
     }

     try {
       use(data);
     } finally {
       rwl.readLock().unlock();
     }
   }
 }
```

1. 首先获取读锁.
2. 释放读锁，同时申请写锁.
3. 完成写操作后，申请读锁.
4. 释放写锁，持有读锁
5. 完全使用完成后，释放读锁。

`ReentrantReadWriteLock`可以用在一些集合类中，用来提升并发性. 只有当集合预期很大，且被很多歌读线程访问，数量远多余写线程时是值得的.

下面是一个使用`TreeMap`的类，预期很大且会有并发的访问.

```java
class RWDictionary {
   private final Map<String, Data> m = new TreeMap<>();
   private final ReentrantReadWriteLock rwl = new ReentrantReadWriteLock();
   private final Lock r = rwl.readLock();
   private final Lock w = rwl.writeLock();

   public Data get(String key) {
     r.lock();
     try { return m.get(key); }
     finally { r.unlock(); }
   }
   public List<String> allKeys() {
     r.lock();
     try { return new ArrayList<>(m.keySet()); }
     finally { r.unlock(); }
   }
   public Data put(String key, Data value) {
     w.lock();
     try { return m.put(key, value); }
     finally { w.unlock(); }
   }
   public void clear() {
     w.lock();
     try { m.clear(); }
     finally { w.unlock(); }
   }
 }
```

这个类对TreeMap进行了封装，使用`TreeMap+ReentrantReadWriteLock`实现了一个线程安全的`TreeMap`.

这个类支持最大65535个重入的写入所和65535个读锁.超过这个限制，会返回Error.

## 源码阅读

这个类使用AQS框架实现，先来看一下AQS的子类`Sync`.

### Sync

#### 变量

首先是几个属性.
```java
/*
 * Read vs write count extraction constants and functions.
 * Lock state is logically divided into two unsigned shorts:
 * The lower one representing the exclusive (writer) lock hold count,
 * and the upper the shared (reader) hold count.
 */

// 共享锁的位数
static final int SHARED_SHIFT   = 16;
// 共享锁unit
static final int SHARED_UNIT    = (1 << SHARED_SHIFT);
// 最大数量
static final int MAX_COUNT      = (1 << SHARED_SHIFT) - 1;
// 独占锁的mask.
static final int EXCLUSIVE_MASK = (1 << SHARED_SHIFT) - 1;

/**
 * A counter for per-thread read hold counts.
 * Maintained as a ThreadLocal; cached in cachedHoldCounter.
 */
// 每个线程持有的读锁的数量
static final class HoldCounter {
    int count;          // initially 0
    // Use id, not reference, to avoid garbage retention
    final long tid = LockSupport.getThreadId(Thread.currentThread());
}

/**
 * ThreadLocal subclass. Easiest to explicitly define for sake
 * of deserialization mechanics.
 */
// 用ThreadLocal记录每个线程持有的读锁的数量
static final class ThreadLocalHoldCounter
        extends ThreadLocal<HoldCounter> {
    public HoldCounter initialValue() {
        return new HoldCounter();
    }
}

    /**
     * The number of reentrant read locks held by current thread.
     * Initialized only in constructor and readObject.
     * Removed whenever a thread's read hold count drops to 0.
     */
    // 当前线程的读锁持有数量
    private transient ThreadLocalHoldCounter readHolds;

    /**
     * The hold count of the last thread to successfully acquire
     * readLock. This saves ThreadLocal lookup in the common case
     * where the next thread to release is the last one to
     * acquire. This is non-volatile since it is just used
     * as a heuristic, and would be great for threads to cache.
     *
     * <p>Can outlive the Thread for which it is caching the read
     * hold count, but avoids garbage retention by not retaining a
     * reference to the Thread.
     *
     * <p>Accessed via a benign data race; relies on the memory
     * model's final field and out-of-thin-air guarantees.
     */
    // 上一个成功获取读锁的线程持有的数量
    private transient HoldCounter cachedHoldCounter;

    /**
     * firstReader is the first thread to have acquired the read lock.
     * firstReaderHoldCount is firstReader's hold count.
     *
     * <p>More precisely, firstReader is the unique thread that last
     * changed the shared count from 0 to 1, and has not released the
     * read lock since then; null if there is no such thread.
     *
     * <p>Cannot cause garbage retention unless the thread terminated
     * without relinquishing its read locks, since tryReleaseShared
     * sets it to null.
     *
     * <p>Accessed via a benign data race; relies on the memory
     * model's out-of-thin-air guarantees for references.
     *
     * <p>This allows tracking of read holds for uncontended read
     * locks to be very cheap.
     */
    // 第一个申请读锁的线程
    // 第一个申请读锁的线程，现在持有的读锁数量.
    private transient Thread firstReader;
    private transient int firstReaderHoldCount;
```

首先定义了一些常量，用来指示在State状态的定义中，读写锁的表示方法等. 以及内部的读锁计数的保存》

#### 构造方法

```java

Sync() {
        readHolds = new ThreadLocalHoldCounter();
        setState(getState()); // ensures visibility of readHolds
}
```

比较简单，初始化了一个当前线程的计数器，然后检查了一下初始状态.

#### tryRelease

这是AQS中释放独占锁的方法：

```java
        /*
         * Note that tryRelease and tryAcquire can be called by
         * Conditions. So it is possible that their arguments contain
         * both read and write holds that are all released during a
         * condition wait and re-established in tryAcquire.
         */
        @ReservedStackAccess
        protected final boolean tryRelease(int releases) {
            if (!isHeldExclusively())
                throw new IllegalMonitorStateException();
            int nextc = getState() - releases;
            boolean free = exclusiveCount(nextc) == 0;
            if (free)
                setExclusiveOwnerThread(null);
            setState(nextc);
            return free;
        }

```

首先判断是否独占锁，不是的话抛出异常.

1. 用当前State减去要释放的数量. 
2. 如果释放后，独占锁的数量为0. 则锁释放成功.将锁的当前线程设置为null.
3. 如果独占锁的数量仍不为0(可重入锁),则释放返回仍未释放.

#### tryAcquire

这是AQS中获取独占锁的方法:

```java
        @ReservedStackAccess
        protected final boolean tryAcquire(int acquires) {
            /*
             * Walkthrough:
             * 1. If read count nonzero or write count nonzero
             *    and owner is a different thread, fail.
             * 2. If count would saturate, fail. (This can only
             *    happen if count is already nonzero.)
             * 3. Otherwise, this thread is eligible for lock if
             *    it is either a reentrant acquire or
             *    queue policy allows it. If so, update state
             *    and set owner.
             */
            Thread current = Thread.currentThread();
            int c = getState();
            int w = exclusiveCount(c);
            if (c != 0) {
                // (Note: if c != 0 and w == 0 then shared count != 0)
                if (w == 0 || current != getExclusiveOwnerThread())
                    return false;
                if (w + exclusiveCount(acquires) > MAX_COUNT)
                    throw new Error("Maximum lock count exceeded");
                // Reentrant acquire
                setState(c + acquires);
                return true;
            }
            if (writerShouldBlock() ||
                !compareAndSetState(c, c + acquires))
                return false;
            setExclusiveOwnerThread(current);
            return true;
        }

```

1. 首先拿到当前的线程以及当前锁的State.
2. 如果锁的状态不为0, 意味着当前有锁被持有. 但是独占锁的数量为0. 意味着当前锁在被shared模式持有. 直接返回加锁失败.
3. 对锁的状态递增此次申请的数量. 如果超过最大数量，抛出异常. 未超过，设置状态. 加锁成功.
4. 如果锁的状态为0. 且当前写锁应该被阻塞，或者设置状态尝试获取锁失败，都返回加锁失败. 否则加锁成功，设置当前持有锁的线程.

#### tryReleaseShared 释放共享锁

```java
        @ReservedStackAccess
        protected final boolean tryReleaseShared(int unused) {
            Thread current = Thread.currentThread();
            // 当前线程是第一个读线程
            if (firstReader == current) {
                // assert firstReaderHoldCount > 0;
                if (firstReaderHoldCount == 1)
                    firstReader = null;
                else
                    firstReaderHoldCount--;
            } else {
                // 拿到缓存的holder.或者当前线程的holder.
                HoldCounter rh = cachedHoldCounter;
                if (rh == null ||
                    rh.tid != LockSupport.getThreadId(current))
                    rh = readHolds.get();
                int count = rh.count;
                if (count <= 1) {
                    readHolds.remove();
                    if (count <= 0)
                        throw unmatchedUnlockException();
                }
                --rh.count;
            }
            // 自选，进行状态的递减
            for (;;) {
                int c = getState();
                int nextc = c - SHARED_UNIT;
                if (compareAndSetState(c, nextc))
                    // Releasing the read lock has no effect on readers,
                    // but it may allow waiting writers to proceed if
                    // both read and write locks are now free.
                    return nextc == 0;
            }
        }

```

这是AQS中释放共享锁的操作:

1. 如果当前线程是第一个获取读锁的线程: 将当前类持有的`firstReader`和`firstReaderHoldCount`进行相应的赋值.递减/置为null.
2. 拿到上一个持有共享锁的读线程，如果当前线程不是上一个线程. 就拿到当前线程的holder.
3. 对拿到的线程持有数量的holder进行递减.
4. 对共享锁进行递减，注意: 共享锁使用的是State的高位部分, 因此每次减去的值是: `SHARED_UNIT`.
5. 设置状态成功，返回释放后的state是否为0.

#### tryAcquireShared 获取共享锁

```java
        @ReservedStackAccess
        protected final int tryAcquireShared(int unused) {
            /*
             * Walkthrough:
             * 1. If write lock held by another thread, fail.
             * 2. Otherwise, this thread is eligible for
             *    lock wrt state, so ask if it should block
             *    because of queue policy. If not, try
             *    to grant by CASing state and updating count.
             *    Note that step does not check for reentrant
             *    acquires, which is postponed to full version
             *    to avoid having to check hold count in
             *    the more typical non-reentrant case.
             * 3. If step 2 fails either because thread
             *    apparently not eligible or CAS fails or count
             *    saturated, chain to version with full retry loop.
             */
            Thread current = Thread.currentThread();
            // 当前状态
            int c = getState();
            // 独占锁被持有，并且独占的线程不是当前线程，直接获取失败失败
            if (exclusiveCount(c) != 0 &&
                getExclusiveOwnerThread() != current)
                return -1;
            // 当前持有的共享锁的数量
            int r = sharedCount(c);
            // 获取共享锁是否应该被阻塞&&共享锁数量小于最大值&&递增状态State成功.
            // 意味着加锁成功了.
            if (!readerShouldBlock() &&
                r < MAX_COUNT &&
                compareAndSetState(c, c + SHARED_UNIT)) {
                // r==0意味着当前没有共享锁，那么当前线程就是第一个读线程，进行赋值
                if (r == 0) {
                    firstReader = current;
                    firstReaderHoldCount = 1;
                    
                } else if (firstReader == current) {
                    // 当前线程已经是第一个读线程了，对相关参数进行递增
                    firstReaderHoldCount++;
                } else {
                    // 获取上一个读锁的获取者
                    HoldCounter rh = cachedHoldCounter;
                    if (rh == null ||
                        rh.tid != LockSupport.getThreadId(current))
                        // 如果线程不是上一个线程，或者上一个缓存的为空
                        // 将当前的线程缓存起来
                        cachedHoldCounter = rh = readHolds.get();
                    else if (rh.count == 0)
                        // 当前线程就是缓存的上一个线程，但是数量为0. 就设置为readHold
                        readHolds.set(rh);
                    // 获取的读锁数量+1.
                    rh.count++;
                }
                // 代表成功了.
                return 1;
            }
            return fullTryAcquireShared(current);
        }
```


获取共享锁:整体的流程如备注中所述，上面的方法处理了:

1. 当前获取不阻塞.
2. 共享锁数量未超过最大值
3. CAS能成功.

这三个条件均满足的情况，如果不满足，调用了`fullTryAcquireShared`来处理.

```java

        /**
         * Full version of acquire for reads, that handles CAS misses
         * and reentrant reads not dealt with in tryAcquireShared.
         */
        final int fullTryAcquireShared(Thread current) {
            /*
             * This code is in part redundant with that in
             * tryAcquireShared but is simpler overall by not
             * complicating tryAcquireShared with interactions between
             * retries and lazily reading hold counts.
             */
            HoldCounter rh = null;
            for (;;) {
                // 当前状态
                int c = getState();
                // 有独占锁，直接失败
                if (exclusiveCount(c) != 0) {
                    if (getExclusiveOwnerThread() != current)
                        return -1;
                    // else we hold the exclusive lock; blocking here
                    // would cause deadlock.
                } else if (readerShouldBlock()) {
                    // 当前应该被阻塞.
                    // Make sure we're not acquiring read lock reentrantly
                // 第一个读线程，不干啥
                    if (firstReader == current) {
                        // assert firstReaderHoldCount > 0;
                    } else {
                        // 读取缓存的线程持有锁数量.
                        if (rh == null) {
                            rh = cachedHoldCounter;
                            if (rh == null ||
                                rh.tid != LockSupport.getThreadId(current)) {
                                // 缓存的不是当前线程，取当前线程的.
                                rh = readHolds.get();
                                // 持有锁数量为0. 删掉
                                if (rh.count == 0)
                                    readHolds.remove();
                            }
                        }
                        // 没看懂，为啥缓存的或者当前的为0. 要返回-1
                        if (rh.count == 0)
                            return -1;
                    }
                }
                // 当前读锁数量到达最大了，抛出异常
                if (sharedCount(c) == MAX_COUNT)
                    throw new Error("Maximum lock count exceeded");
                // 如果设置+1个读锁成功
                if (compareAndSetState(c, c + SHARED_UNIT)) {
                    // 如果读锁为0.那么当前线程就是第一个读锁
                    if (sharedCount(c) == 0) {
                        firstReader = current;
                        firstReaderHoldCount = 1;
                        // 第一个读锁重入
                    } else if (firstReader == current) {
                        firstReaderHoldCount++;
                    } else {
                        // 缓存上一个获取读锁的线程
                        if (rh == null)
                            rh = cachedHoldCounter;
                        if (rh == null ||
                            rh.tid != LockSupport.getThreadId(current))
                            rh = readHolds.get();
                        else if (rh.count == 0)
                            readHolds.set(rh);
                        rh.count++;
                        cachedHoldCounter = rh; // cache for release
                    }
                    // 成功
                    return 1;
                }
                // 如果CAS设置状态失败，继续自旋
            }
        }

```

其实和`tryAcquireShared`很像，只是通过分离代码处理了额外的几种情况.

#### tryWriteLock 获取写锁

```java

        /**
         * Performs tryLock for write, enabling barging in both modes.
         * This is identical in effect to tryAcquire except for lack
         * of calls to writerShouldBlock.
         */
        @ReservedStackAccess
        final boolean tryWriteLock() {
            Thread current = Thread.currentThread();
            int c = getState();
            if (c != 0) {
                int w = exclusiveCount(c);
                if (w == 0 || current != getExclusiveOwnerThread())
                    return false;
                if (w == MAX_COUNT)
                    throw new Error("Maximum lock count exceeded");
            }
            if (!compareAndSetState(c, c + 1))
                return false;
            setExclusiveOwnerThread(current);
            return true;
        }

```

和`tryAcquire`效果一样，只是不考虑`writerShouldBlock`.

#### tryReadLock 

```java

        /**
         * Performs tryLock for read, enabling barging in both modes.
         * This is identical in effect to tryAcquireShared except for
         * lack of calls to readerShouldBlock.
         */
        @ReservedStackAccess
        final boolean tryReadLock() {
            Thread current = Thread.currentThread();
            for (;;) {
                int c = getState();
                if (exclusiveCount(c) != 0 &&
                    getExclusiveOwnerThread() != current)
                    return false;
                int r = sharedCount(c);
                if (r == MAX_COUNT)
                    throw new Error("Maximum lock count exceeded");
                if (compareAndSetState(c, c + SHARED_UNIT)) {
                    if (r == 0) {
                        firstReader = current;
                        firstReaderHoldCount = 1;
                    } else if (firstReader == current) {
                        firstReaderHoldCount++;
                    } else {
                        HoldCounter rh = cachedHoldCounter;
                        if (rh == null ||
                            rh.tid != LockSupport.getThreadId(current))
                            cachedHoldCounter = rh = readHolds.get();
                        else if (rh.count == 0)
                            readHolds.set(rh);
                        rh.count++;
                    }
                    return true;
                }
            }
        }
```

和`tryAcquireShared`效果一样，只是不考虑`readerShouldBlock`.

### NonfairSync 非公平状态下的Sync

```java

    /**
     * Nonfair version of Sync
     */
    static final class NonfairSync extends Sync {
        private static final long serialVersionUID = -8159625535654395037L;
        final boolean writerShouldBlock() {
            return false; // writers can always barge
        }
        final boolean readerShouldBlock() {
            /* As a heuristic to avoid indefinite writer starvation,
             * block if the thread that momentarily appears to be head
             * of queue, if one exists, is a waiting writer.  This is
             * only a probabilistic effect since a new reader will not
             * block if there is a waiting writer behind other enabled
             * readers that have not yet drained from the queue.
             */
            return apparentlyFirstQueuedIsExclusive();
        }
    }

```

主要是定义了父类中的两个抽象方法.

* writerShouldBlock. 写锁的请求，任何时候都可以申请.
* readerShouldBlock . 读锁的请求，能不能申请，要看情况咯.

```java

    /**
     * Returns {@code true} if the apparent first queued thread, if one
     * exists, is waiting in exclusive mode.  If this method returns
     * {@code true}, and the current thread is attempting to acquire in
     * shared mode (that is, this method is invoked from {@link
     * #tryAcquireShared}) then it is guaranteed that the current thread
     * is not the first queued thread.  Used only as a heuristic in
     * ReentrantReadWriteLock.
     */
    final boolean apparentlyFirstQueuedIsExclusive() {
        Node h, s;
        return (h = head) != null &&
            (s = h.next)  != null &&
            !s.isShared()         &&
            s.thread != null;
    }

```

这是为了避免因为非公平的竞争，而把写锁饿死的情况实现的一个方法:

如果当前等待队列中有两个节点，且第二个还是独占的写锁等待，当前的读锁请求就不允许提交了.

这是一个概率上的问题，如果等待队列里面已经有一个写锁排在读锁后面了，害怕把写锁饿死，就在这里不让别的读锁来竞争，知道前面的锁走完.


### FairSync 公平模式

```java

    /**
     * Fair version of Sync
     */
    static final class FairSync extends Sync {
        private static final long serialVersionUID = -2274990926593161451L;
        final boolean writerShouldBlock() {
            return hasQueuedPredecessors();
        }
        final boolean readerShouldBlock() {
            return hasQueuedPredecessors();
        }
    }

```

公平锁，对于读写锁是公平的，都是看队列中有没有已经在等待的节点了.(这部分是在AQS实现的)

```java
    public final boolean hasQueuedPredecessors() {
        Node h, s;
        if ((h = head) != null) {
            if ((s = h.next) == null || s.waitStatus > 0) {
                s = null; // traverse in case of concurrent cancellation
                for (Node p = tail; p != h && p != null; p = p.prev) {
                    if (p.waitStatus <= 0)
                        s = p;
                }
            }
            // 队列中第一个在等待的节点，不是当前节点，那么当前线程就不要提交了
            if (s != null && s.thread != Thread.currentThread())
                return true;
        }
        // 当前节点的请求可以提交.
        return false;
    }

```

### ReadLock

read是一个实现了`Lock`接口的子类. 持有一个`Sync`同步器.

#### lock

```java
        public void lock() {
            sync.acquireShared(1);
        }

```

读锁的加锁，调用了AQS的申请一个共享锁.

#### tryLock

```java
        public boolean tryLock() {
            return sync.tryReadLock();
        }

```

读锁的**尝试加锁**. 调用的是同步器的`tryReadLock`，也就是不考虑`readerShouldBlock`,而强行进行的一次加锁行为.

#### unlock

```java
        public void unlock() {
            sync.releaseShared(1);
        }

```

读锁的解锁，是调用AQS的释放一次共享锁.

### WriteLock

写锁的实现，也是实现`Lock`接口的一个实现类.

#### lock

```java
        public void lock() {
            sync.acquire(1);
        }

```

写锁的加锁，是调用AQS的获取一个独占锁实现.


#### tryLock

```java
        public boolean tryLock() {
            return sync.tryWriteLock();
        }

```

写锁的`tryLock`.调用`sync.tryWriteLock`.不考虑`writerShoulBlock`进行的一次强行尝试.

#### unlock

```java
        public void unlock() {
            sync.release(1);
        }

```

写锁的解锁，调用AQS的释放独占锁一次.

### 其他

其他还有一些对于类内部属性的查询方法，主要用于对当前锁状态的监控，这里就不展开了. 都是比较简单的属性查询.

## 总结




## 参考文章

问题:

为啥要额外记录第一个读线程呢

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