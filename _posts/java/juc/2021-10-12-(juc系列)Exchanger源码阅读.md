---
layout: post
category: [Java,JUC]
tags:
  - Java
  - JUC
---

## 简介

一个用于让线程之间配对和交换元素的同步点.

每个线程拿出一个元素，匹配另外一个伙伴线程, 互相交换.

`Exchanger`可以看做是一个双向的`SynchronousQueue`.

这个类在遗传算法和流水线设计时很有用.

### 示例

这个类使用`Exchanger`来在线程之间交换缓冲区.

```java
class FillAndEmpty {
   Exchanger<DataBuffer> exchanger = new Exchanger<>();
   DataBuffer initialEmptyBuffer = ... a made-up type
   DataBuffer initialFullBuffer = ...

   class FillingLoop implements Runnable {
     public void run() {
       DataBuffer currentBuffer = initialEmptyBuffer;
       try {
         while (currentBuffer != null) {
           addToBuffer(currentBuffer);
           if (currentBuffer.isFull())
             currentBuffer = exchanger.exchange(currentBuffer);
         }
       } catch (InterruptedException ex) { ... handle ... }
     }
   }

   class EmptyingLoop implements Runnable {
     public void run() {
       DataBuffer currentBuffer = initialFullBuffer;
       try {
         while (currentBuffer != null) {
           takeFromBuffer(currentBuffer);
           if (currentBuffer.isEmpty())
             currentBuffer = exchanger.exchange(currentBuffer);
         }
       } catch (InterruptedException ex) { ... handle ...}
     }
   }

   void start() {
     new Thread(new FillingLoop()).start();
     new Thread(new EmptyingLoop()).start();
   }
 }
```

一个生产者和一个消费者通过`Exchanger`来交换缓冲区，以确保消费者可以不断拿到满的缓冲区，生产者不断拿到空的缓冲区.

## 源码阅读

### 构造方法

```java
    public Exchanger() {
        participant = new Participant();
    }
```

初始化一个`Participant`. 这个类是一个ThreadLocal的子类.负责为每个线程存储一个对应的`Node`.

```java
static final class Participant extends ThreadLocal<Node> {
    public Node initialValue() { return new Node(); }
}
```

Node节点的定义:

```java
@jdk.internal.vm.annotation.Contended static final class Node {
    int index;              // Arena index 在数组中的下标
    int bound;              // Last recorded value of Exchanger.bound // 上一个Exchanger.bound值
    int collides;           // Number of CAS failures at current bound CAS失败次数
    int hash;               // Pseudo-random for spins // 自旋随机次数
    Object item;            // This thread's current item // 线程对应的item
    volatile Object match;  // Item provided by releasing thread // 匹配上的值
    volatile Thread parked; // Set to this thread when parked, else null // 阻塞线程
}
```

可以看到，一个线程绑定一个节点，记录了他在数组中的下标，自身携带的item.以及最终匹配给他的item等等.

### exchange(V v)

这个方法还有另外一个带有超时时间的版本，就不多说那个了.

```java
    public V exchange(V x) throws InterruptedException {
        Object v;
        Node[] a;
        Object item = (x == null) ? NULL_ITEM : x; // translate null args
        if (((a = arena) != null ||
        (v = slotExchange(item, false, 0L)) == null) &&
        (Thread.interrupted() || // disambiguates null return
        (v = arenaExchange(item, false, 0L)) == null))
        throw new InterruptedException();
        return (v == NULL_ITEM) ? null : (V)v;
        }

```

这个交换方法的逻辑比较清晰.

1. 如果当前的竞技场(就是交换场所，数组版本的)为空，那就在`slot`交换，调用`slotExchange`.
2. 否则调用`arenaExchange`. 在数组中进行匹配，交换.

### slotExchange

如果目前只有一个等待交换的线程，也就是没有产生竞争，单个slot即可以完成交换操作.

```java
    private final Object slotExchange(Object item, boolean timed, long ns) {
        // 当前线程的节点
        Node p = participant.get();
        // 当前线程
        Thread t = Thread.currentThread();
        // 被中断了直接返回null
        if (t.isInterrupted()) // preserve interrupt status so caller can recheck
            return null;

        
        for (Node q;;) {
            // 已有slot在等待交换了
            if ((q = slot) != null) {
                // 置空SLOT, 拿到交换后的值，并唤醒对应的线程
                if (SLOT.compareAndSet(this, q, null)) {
                    Object v = q.item;
                    q.match = item;
                    Thread w = q.parked;
                    if (w != null)
                        LockSupport.unpark(w);
                    return v;
                }
                // create arena on contention, but continue until slot null
                // 有竞争了，创建一个数组
                if (NCPU > 1 && bound == 0 &&
                    BOUND.compareAndSet(this, 0, SEQ))
                    arena = new Node[(FULL + 2) << ASHIFT];
            }
            // slot为空，但是数组不为空，直接返回空
            else if (arena != null)
                return null; // caller must reroute to arenaExchange
            else {
                // 如果当前slot和数组都是空,将当前线程放进slot
                p.item = item;
                if (SLOT.compareAndSet(this, null, p))
                    break;
                p.item = null;
            }
        }

        // await release
        // 自旋等待匹配
        int h = p.hash;
        long end = timed ? System.nanoTime() + ns : 0L;
        int spins = (NCPU > 1) ? SPINS : 1;
        Object v;
        while ((v = p.match) == null) {
            if (spins > 0) {
                h ^= h << 1; h ^= h >>> 3; h ^= h << 10;
                if (h == 0)
                    h = SPINS | (int)t.getId();
                else if (h < 0 && (--spins & ((SPINS >>> 1) - 1)) == 0)
                    Thread.yield();
            }
            else if (slot != p)
                spins = SPINS;
            else if (!t.isInterrupted() && arena == null &&
                     (!timed || (ns = end - System.nanoTime()) > 0L)) {
                p.parked = t;
                if (slot == p) {
                    if (ns == 0L)
                        LockSupport.park(this);
                    else
                        LockSupport.parkNanos(this, ns);
                }
                p.parked = null;
            }
            else if (SLOT.compareAndSet(this, p, null)) {
                v = timed && ns <= 0L && !t.isInterrupted() ? TIMED_OUT : null;
                break;
            }
        }
        // 被唤醒，返回匹配到的值.
        MATCH.setRelease(p, null);
        p.item = null;
        p.hash = h;
        return v;
    }

```

当一个线程调用`exchange`,如果当前没有什么竞争，通过slot来进行交换时，可能面对两种可能:


1. 当前`Exchanger`内部为空的，直接将当前线程放在slot，阻塞等待匹配
2. 当前slot不为空，直接与slot交换元素，返回值.

### arenaExchange

通过数组进行交换，用于当前竞争很严重的时候.

```java
    private final Object arenaExchange(Object item, boolean timed, long ns) {
        Node[] a = arena;
        int alen = a.length;
        // 当前线程的节点
        Node p = participant.get();
        for (int i = p.index;;) {                      // access slot at i
            int b, m, c;
            int j = (i << ASHIFT) + ((1 << ASHIFT) - 1);
            if (j < 0 || j >= alen)
                j = alen - 1;
            // 从对应的下标取一个slot出来
            Node q = (Node)AA.getAcquire(a, j);
            if (q != null && AA.compareAndSet(a, j, q, null)) {
                // 对应的slot有值，尝试交换成功.返回交换后的值
                Object v = q.item;                     // release
                q.match = item;
                Thread w = q.parked;
                if (w != null)
                    LockSupport.unpark(w);
                return v;
            }
            // 对应的slot没有值，且下标符合要求，就将当前节点放在slot上, 自选等待匹配唤醒.
            else if (i <= (m = (b = bound) & MMASK) && q == null) {
                p.item = item;                         // offer
                if (AA.compareAndSet(a, j, null, p)) {
                    long end = (timed && m == 0) ? System.nanoTime() + ns : 0L;
                    Thread t = Thread.currentThread(); // wait
                    for (int h = p.hash, spins = SPINS;;) {
                        Object v = p.match;
                        if (v != null) {
                            MATCH.setRelease(p, null);
                            p.item = null;             // clear for next use
                            p.hash = h;
                            return v;
                        }
                        else if (spins > 0) {
                            h ^= h << 1; h ^= h >>> 3; h ^= h << 10; // xorshift
                            if (h == 0)                // initialize hash
                                h = SPINS | (int)t.getId();
                            else if (h < 0 &&          // approx 50% true
                                     (--spins & ((SPINS >>> 1) - 1)) == 0)
                                Thread.yield();        // two yields per wait
                        }
                        else if (AA.getAcquire(a, j) != p)
                            spins = SPINS;       // releaser hasn't set match yet
                        else if (!t.isInterrupted() && m == 0 &&
                                 (!timed ||
                                  (ns = end - System.nanoTime()) > 0L)) {
                            p.parked = t;              // minimize window
                            if (AA.getAcquire(a, j) == p) {
                                if (ns == 0L)
                                    LockSupport.park(this);
                                else
                                    LockSupport.parkNanos(this, ns);
                            }
                            p.parked = null;
                        }
                        else if (AA.getAcquire(a, j) == p &&
                                 AA.compareAndSet(a, j, p, null)) {
                            if (m != 0)                // try to shrink
                                BOUND.compareAndSet(this, b, b + SEQ - 1);
                            p.item = null;
                            p.hash = h;
                            i = p.index >>>= 1;        // descend
                            if (Thread.interrupted())
                                return null;
                            if (timed && m == 0 && ns <= 0L)
                                return TIMED_OUT;
                            break;                     // expired; restart
                        }
                    }
                }
                else
                    p.item = null;                     // clear offer
            }
            else {
                // 下标不符合要求，　计算新的下标
                if (p.bound != b) {                    // stale; reset
                    p.bound = b;
                    p.collides = 0;
                    i = (i != m || m == 0) ? m : m - 1;
                }
                else if ((c = p.collides) < m || m == FULL ||
                         !BOUND.compareAndSet(this, b, b + SEQ + 1)) {
                    p.collides = c + 1;
                    i = (i == 0) ? m : i - 1;          // cyclically traverse
                }
                else
                    i = m + 1;                         // grow
                p.index = i;
            }
        }
    }
```

根据计算的下标，从数组中取一个位置，

* 如果该位置有值，就将当前节点和该位置交换.
* 该位置没有值，且下标合理，就将当前节点放到该位置上
* 该位置没有值，下标不合理，就重新计算下标

## 总结

Exchanger的作用，原理都比较明了，就是代码细节比较难懂.

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