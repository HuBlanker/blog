---
layout: post
category: [Java,JUC,Condition]
tags:
  - Java
  - JUC
  - Condition
---



本文源码基于: <font color='red'>JDK13</font>


## Condition

### 官方注释翻译

`Condition`将`Object`身上的方法`wait，notify，nitofyAll`等分解为不同的对象，通过将他们与任意的锁实现结合，实现了每个对象有多个等待集的效果. 锁代替了同步方法和语句，条件代替了对象对象监视器方法的使用.

`Conditions`(或者称为条件队列或者条件变量) 提供一个方法，让一个线程暂停`wait`，直到被其他线程通知，说某个等待条件可能为真. 因为共享状态的
访问在不同的线程中，因此必须保护它，与某种形式的锁相关联. 等待条件提供的关键属性是： 他原子性的释放关联的锁并挂起当前的线程，就像`Object.wait()`.

`Condition`本质上是绑定到锁上的，要获取给定锁的条件实例，请调用`locl.newCondition`方法.

比如，假设我们有一个支持`put`和`take`的有界缓冲区. 如果对一个空的缓冲区进行`take`操作，线程将会阻塞，知道有元素可用. 如果对一个满的缓冲去进行`put`操作，线程会阻塞直到缓冲区有空间，也就是阻塞队列的语义.

我们希望在单独的等待集中保持生产者和消费者的线程,这样我们可以在缓冲区有空间或者缓冲区不为空时，只唤醒一部分线程. 这可以使用两个`Condition`实例来实现.


```java
   class BoundedBuffer<E> {
     final Lock lock = new ReentrantLock();
     final Condition notFull  = lock.newCondition(); 
     final Condition notEmpty = lock.newCondition(); 
  
     final Object[] items = new Object[100];
     int putptr, takeptr, count;
  
     public void put(E x) throws InterruptedException {
       lock.lock();
       try {
         while (count == items.length)
           notFull.await();
         items[putptr] = x;
         if (++putptr == items.length) putptr = 0;
         ++count;
         notEmpty.signal();
       } finally {
         lock.unlock();
       }
     }
  
     public E take() throws InterruptedException {
       lock.lock();
       try {
         while (count == 0)
           notEmpty.await();
         E x = (E) items[takeptr];
         if (++takeptr == items.length) takeptr = 0;
         --count;
         notFull.signal();
         return x;
       } finally {
         lock.unlock();
       }
     }
   }
   
```

如果你看过`BlockingQueue`相关的代码， 就会发现上面的代码兼职太眼熟了我的天.

`Condition`的实现类可以提供与`Object`的监控方法不同的行为和语义，比如保证通知的顺序，或者在执行通知时不需要持有锁. 如果实现提供了这样专门
的语义，那必须记录下来.

注意: `Condition`对象只是普通的对象，他们可以用做同步语句中的目标，并且可以调用他们自己的等待和通知方法，获取`Condition`实例的监视器所，或者使用他的监视器方法，与获取与`Condition`关联的锁之间没有什么关系.
为了避免混淆，建议永远不要这么高.

除非特别说明，否则传递任何null都会导致NPE。

### 接口

* await 等待
* awaitUninterruptibly 不可中断的等待
* awaitNanos 等待指定毫秒
* await(time,unit) 等待指定时间 
* awaitUntil 等待知道deakline到来
* signal 通知一个等待线程
* signalAll 通知全部等待线程

### AQS中的ConditionObject

#### 定义 

```java

public class ConditionObject implements Condition, java.io.Serializable {
```

朴实无华，一个条件.

#### 属性
```java

        private transient Node firstWaiter;
        /** Last node of condition queue. */
        private transient Node lastWaiter;
```
等待的可能有多个线程，因此总是需要一个队列来保存等待者的，这里使用链表实现,保存了链表的首和尾.

Node节点保存了:

```java

    static final class Node {
        static final Node SHARED = new Node();
        static final Node EXCLUSIVE = null;

        static final int CANCELLED =  1;
        static final int SIGNAL    = -1;
        static final int CONDITION = -2;
        static final int PROPAGATE = -3;

        volatile int waitStatus;

        volatile Node prev;

        volatile Node next;

        volatile Thread thread;

        Node nextWaiter;
```

保存了等待的状态，以及前后节点，还有当前节点的线程.

#### 构造方法

```java

        public ConditionObject() { }

```
创建一个空的条件队列.


#### await 系列

既然实现了`Condition`接口，就按照接口的方法来看. 由于有多个关于时间控制的等待方法，为了避免冗余，我们只看一下`await(time,unit)`方法，比较有代表性.
```java

        public final boolean await(long time, TimeUnit unit)
                throws InterruptedException {
            // 计算纳秒时间
            long nanosTimeout = unit.toNanos(time);
            // 中断返回
            if (Thread.interrupted())
                throw new InterruptedException();
            // We don't check for nanosTimeout <= 0L here, to allow
            // await(0, unit) as a way to "yield the lock".
            // 计算结束时间
            final long deadline = System.nanoTime() + nanosTimeout;
            // 将当前节点添加到等待队列中
            Node node = addConditionWaiter();
            
            int savedState = fullyRelease(node);
            boolean timedout = false;
            int interruptMode = 0;
            // 状态ok就自旋
            while (!isOnSyncQueue(node)) {
                // 时间到了，结束
                if (nanosTimeout <= 0L) {
                    timedout = transferAfterCancelledWait(node);
                    break;
                }
                // 休眠给定时间
                if (nanosTimeout > SPIN_FOR_TIMEOUT_THRESHOLD)
                    LockSupport.parkNanos(this, nanosTimeout);
                // 是否中断
                if ((interruptMode = checkInterruptWhileWaiting(node)) != 0)
                    break;
                nanosTimeout = deadline - System.nanoTime();
            }
            // 状态OK？是否中断了
            if (acquireQueued(node, savedState) && interruptMode != THROW_IE)
                interruptMode = REINTERRUPT;
            // 如果当前节点还有后续节点，解除一些取消掉的节点
            if (node.nextWaiter != null)
                unlinkCancelledWaiters();
            if (interruptMode != 0)
                reportInterruptAfterWait(interruptMode);
            // 返回结果
            return !timedout;
        }

```

其实这种方法很难讲，代码写的很复杂，但是核心其实就一个`LockSupport.park()`,完事. 根据需要将当前线程休眠指定时间.


#### signal 唤醒系列


以signal为例，因为唤醒单个会了，唤醒全部大不了for循环～.

```java

        public final void signal() {
            if (!isHeldExclusively())
                throw new IllegalMonitorStateException();
            Node first = firstWaiter;
            if (first != null)
                doSignal(first);
        }

        private void doSignal(Node first) {
            do {
                if ( (firstWaiter = first.nextWaiter) == null)
                    lastWaiter = null;
                first.nextWaiter = null;
            } while (!transferForSignal(first) &&
                     (first = firstWaiter) != null);
        }


        final boolean transferForSignal(Node node) {
                if (!node.compareAndSetWaitStatus(Node.CONDITION, 0))
                return false;

                Node p = enq(node);
                int ws = p.waitStatus;
                if (ws > 0 || !p.compareAndSetWaitStatus(ws, Node.SIGNAL))
                LockSupport.unpark(node.thread);
                return true;
                }
```

从队头找到第一个等待线程，验证当前状态之后，进行唤醒.


### ReentrantLock 中的Condition

其实ReentrantLock是使用`AQS`实现的，为啥还要单独看呢？

因为在学习`BlockingQueue`时，对于两个条件分别控制生产者等待和消费者等待印象深刻，而`ArrayListBlockingQueue`是使用`ReentrantLock`实现的，因此单独看一下。

在`ReentrantLock`中，初始化一个`Condition`，使用:

```java

        final ConditionObject newCondition() {
            return new ConditionObject();
        }
```
朴实无华，直接使用了`AQS`的条件队列.


### 总结

`Condition`定义了一个接口，允许线程在它的实例上阻塞，互相唤醒.

我们已经有了`Object`提供了相关方法，为啥还需要`Condition`呢?

就是`ArrayListBlockingQueue`的情况了，`Object`对象，只允许所有的线程因为同样的原因阻塞.

而我们需要不同的线程群根据不同的条件阻塞，条件满足时，部分唤醒. 因此需要`Condition`。

同时，有了`Condition`，我们还可以自定义很多逻辑，比如线程的唤醒顺序，或者添加更多自定义的hook方法等等，更加灵活.

`AQS`中`Condition`为所有基于AQS实现的类，提供了默认的`ConditionObject`. 

他内部使用链表来保存等待线程，使用CAS来保证更新的原子性. 因为在`ArrayListBlockingQueue`中，使用两个条件队列才能那么丝滑.



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