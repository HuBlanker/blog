---
layout: post
category: [Java,延迟队列,DelayQueue]
tags:
  - Java
  - 延迟队列
  - DelayQueue
---




## 前言

## DelayQueue 延迟队列


### 官方注释翻译

用于延迟元素的一个无界的阻塞队列实现. 延迟元素只有在他的延迟过期之后，才可以被获取.

队头的元素，是队列中过期最早的元素。如果没有元素过期，那么将没有队头元素，`poll`方法将会返回一个null.

过期操作只有元素的`getDelay`方法返回一个小于等于0的数值时才会起作用.

尽管没有过期的元素，不能通过`take`或者`poll`来获取, 其他方面和正常的元素是一样的.

比如，`size()`返回过期和未过期的元素的计数，同时，这个队列也是不接受空元素.

这个类和他的迭代器实现了`Collection`和`Iterator`接口的所有可选方法.

这个类也是Java集合框架的一部分噢。

### 源码

#### 定义

```java

public class DelayQueue<E extends Delayed> extends AbstractQueue<E>
implements BlockingQueue<E> {

```
首先是一个普通队列， 且还是阻塞队列. 拥有他们的所有属性，同时，还要求放入的元素，是实现了`Delayed`接口的. 该接口定义如下:

```java

public interface Delayed extends Comparable<Delayed> {

    /**
     * Returns the remaining delay associated with this object, in the
     * given time unit.
     *
     * @param unit the time unit
     * @return the remaining delay; zero or negative values indicate
     * that the delay has already elapsed
     */
    long getDelay(TimeUnit unit);
}
```

根据给定的时间单位，返回剩余的延迟时间.

#### 属性

```java

    // 锁
    private final transient ReentrantLock lock = new ReentrantLock();
    // 优先级队列
    private final PriorityQueue<E> q = new PriorityQueue<E>();

    // 正在等待队头元素的线程
    private Thread leader;

    // 有元素可用的等待条件
    private final Condition available = lock.newCondition();
```


使用优先级队列来保存元素，同时记录等待队首元素的线程. 

这个优先级队列，是`java.util`包里的，暂不做详细解释，相信大家都懂哈.

提供了等待条件`available`来负责阻塞线程与唤醒.

#### 构造方法

```java
    public DelayQueue() {}

    public DelayQueue(Collection<? extends E> c) {
        this.addAll(c);
    }

```

提供两个构造方法，分别构造一个空的延迟队列和一个加载给定集合的阻塞队列.

#### 入队系列

```java

    public boolean add(E e) {
        return offer(e);
    }

    public boolean offer(E e) {
        final ReentrantLock lock = this.lock;
        lock.lock();
        try {
            // 插入元素
            q.offer(e);
            // 队头元素是刚才插入的元素，说明有可用元素，唤醒等待线程们
            if (q.peek() == e) {
                leader = null;
                available.signal();
            }
            return true;
        } finally {
            lock.unlock();
        }
    }

    public void put(E e) {
        offer(e);
    }

    public boolean offer(E e, long timeout, TimeUnit unit) {
        return offer(e);
    }
```

4个入队系列的方法，本质上都是调用了`offer`. 直接调用内部`优先级队列`的offer，无脑写入即可.

可以看到，该方法永远返回ture. 因为这个延迟队列也是无界的，因此不需要阻塞，不会插入失败.

插入只有两种可能:

1. 成功
2. 内存爆了，程序死掉.

#### 出队系列

##### poll 没有元素返回Null

```java

    public E poll() {
        final ReentrantLock lock = this.lock;
        lock.lock();
        try {
            // 获取第一个元素
            E first = q.peek();
            // 第一个元素为空，或者第一个元素的延迟时间没有到期，返回null.
            // 否则返回该元素
            return (first == null || first.getDelay(NANOSECONDS) > 0)
                ? null
                : q.poll();
        } finally {
            lock.unlock();
        }
    }
```

首先查看第一个元素，如果不为空且已经过期了，那就弹出进行返回. 否则就返回null.


##### take 阻塞等待

```java

    public E take() throws InterruptedException {
        final ReentrantLock lock = this.lock;
        lock.lockInterruptibly();
        try {
            // 自旋
            for (;;) {
                //  查看第一个元素
                E first = q.peek();
                // 第一个元素为空，直接等待
                if (first == null)
                    available.await();
                else {
                    // 第一个元素已经超时，可用了，就进行弹出
                    long delay = first.getDelay(NANOSECONDS);
                    if (delay <= 0L)
                        return q.poll();
                    // 等待
                    first = null; // don't retain ref while waiting
                    if (leader != null)
                        available.await();
                    else {
                        // 如果当前是第一个等待队首元素的线程,记录一下当前线程，且只阻塞剩余的时间，就苏醒来检查一下是否可用了
                        Thread thisThread = Thread.currentThread();
                        leader = thisThread;
                        try {
                            available.awaitNanos(delay);
                        } finally {
                            if (leader == thisThread)
                                leader = null;
                        }
                    }
                }
            }
        } finally {
            // 拿到元素后，协助唤醒一下等待线程
            if (leader == null && q.peek() != null)
                available.signal();
            lock.unlock();
        }
    }
```

这个阻塞版本的获取元素复杂一点.

1. 如果第一个元素为空， 就让当前线程阻塞等待.
2. 不为空，且已经过期，直接弹出，进行返回，此时获取元素成功.
3. 不为空，且没有过期，如果当前线程，是第一个等待队首元素的线程, 就阻塞第一个元素剩余的延迟时间, 到期后苏醒来检查队首元素的状态.
4. 不是第一个等待的线程，直接阻塞，等待第一个线程来唤醒.
5. 获取元素成功后，如果还有可用元素，协助唤醒一下其余的等待线程.

##### poll(time,unit) 超时阻塞版本

和上面的`take`代码很像，只是在每一个线程的阻塞时都加上了时间限制，就不重复讲了.

#### 查看系列


##### size 查看元素数量

这个简单的方法为啥要写呢，因为要注意: **返回的size,是所有过期的，未过期的总数**.

```java

    public int size() {
        final ReentrantLock lock = this.lock;
        lock.lock();
        try {
            return q.size();
        } finally {
            lock.unlock();
        }
    }
```

直接调用了内部的优先级队列的`size()`方法，没有判断是否过期.

##### peek() 查看队首元素，不弹出

由于在延迟队列中，总是需要看一下，队首元素，如果已经过期，就弹出，没过期，就不处理. 因此也简单看一下`peek()`方法.

```java

    public E peek() {
        final ReentrantLock lock = this.lock;
        lock.lock();
        try {
            return q.peek();
        } finally {
            lock.unlock();
        }
    }
```

没啥，加锁，然后调用优先级队列的`peek`完事了。

#### 总结

延迟队列，本质上是一个带有优先级的阻塞队列，且根据延迟限制队首元素的出队.

* 优先级队列的实验，使用了`java.util.PriorityQueue`,本质上实现应该也是一个堆实现的.
* 阻塞队列的实现，使用`Condition`条件. 由于是无界队列，入队操作不会阻塞. 出队行为在条件上等待，当有符合条件的元素时，唤醒所有等待线程.
* 延迟属性的实现，在出队时，对队首元素进行额外的过期判断，如果过期，就弹出，没有过期，就返回null.
* 线程安全方面，由于`java.util.PriorityQueue`不是线程安全的，因此使用额外的一个`ReentrantLock`来限制对数据的读写访问.

<br>


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