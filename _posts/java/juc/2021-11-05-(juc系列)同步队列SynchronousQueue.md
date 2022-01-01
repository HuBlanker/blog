---
layout: post
category: [Java,JUC, SynchronousQueue]
tags:
  - Java
  - SynchronousQueue
  - JUC
---



本文源码基于: <font color='red'>JDK13</font>


## SynchronousQueue

### 官方注释翻译

一个阻塞队列的实现，他的插入操作必须等待对应的移除操作. 反之亦然.

一个同步队列没有内部的容量限制.

* 不能执行`peek()`操作，因此只有当你尝试去移除的时候，元素才存在.
* 在没有其他线程等待移除的时候,你不能使用任何方法来插入一个元素.
* 不能执行迭代操作,因为没有任何元素可以迭代.

队头元素是第一个尝试添加元素的写入线程;如果没有等待的写入线程,那么没有任何元素可以用来移除,`poll`方法将会返回null.

如果以一个`集合`的视角来看`SynchronousQueue`,那么它是一个空的集合. 这个队列也不接受null元素.

同步队列像是一个合并的渠道. 一个线程中运行的事物,必须同步等待另外一个线程中运行的事务来处理某些信息,比如事件,任务等等.

这个类支持可选的公平策略.默认情况下,是没有任何保证的. 如果构造函数中,指定了使用公平策略,那么会保证线程访问的顺序是FIFO.

这个类也是Java集合框架的一部分.

### 源码

#### 定义

```java
public class SynchronousQueue<E> extends AbstractQueue<E>
        implements BlockingQueue<E>, java.io.Serializable {
```

继承了`AbstractQueue`和`BlockingQueue`,因此是一个阻塞队列.

#### 属性

```java

// 负责传输的类
private transient volatile Transferer<E> transferer;
// 队列的锁
private ReentrantLock qlock;
// 生产者等待队列
private WaitQueue waitingProducers;
// 消费者的等待队列
private WaitQueue waitingConsumers;
```

一共4个属性，除了一个可重入锁之外， 其他都是内部实现类，依次看一下.

#### Transferer

```java

// 抽象类，定义了传输的行为，他的实现类在下面
abstract static class Transferer<E> {
    abstract E transfer(E e, boolean timed, long nanos);
}
```

##### TransferStack 栈

内部保存了栈的头节点: `head`

```java
volatile SNode head;
```

这个`SNode`也是内部类，比较简单.

```java
static final class SNode {
    volatile SNode next;        // next node in stack
    volatile SNode match;       // the node matched to this
    volatile Thread waiter;     // to control park/unpark
    Object item;                // data; or null for REQUESTs
    int mode;
}
```

保存了当前节点的值，以及下一个节点，还有与当前节点匹配的节点.

同时保存了等待的线程，用于阻塞和唤醒.

`TransferStack`栈对于传输的实现为:

```java
        @SuppressWarnings("unchecked")
        E transfer(E e, boolean timed, long nanos) {
            SNode s = null; // constructed/reused as needed
                // 当前请求的类型是生产者还是消费者
            int mode = (e == null) ? REQUEST : DATA;

            // 自旋
            for (;;) {
                SNode h = head;
                // 如果当前栈为空，或者栈首元素的类型和当前类型一些.
                if (h == null || h.mode == mode) {  // empty or same-mode
                    // 超时了
                    if (timed && nanos <= 0L) {     // can't wait
                        // 头结点已经超时了，弹出该头节点,让下一个节点成为头节点
                        if (h != null && h.isCancelled())
                            casHead(h, h.next);     // pop cancelled node
                        else
                            // 超时了但是头结点为空，或者头结点还没取消，就返回空
                            return null;
                    } else if (casHead(h, s = snode(s, e, h, mode))) {
                        // 更新头结点为当前节点
                        // 之后阻塞等待匹配操作
                        SNode m = awaitFulfill(s, timed, nanos);
                        // 如果返回的m 是头结点，说明取消了，返回null
                        if (m == s) {               // wait was cancelled
                            clean(s);
                            return null;
                        }
                        // 如果头结点不为空， 且下一个节点是s. 
                        if ((h = head) != null && h.next == s)
                            casHead(h, s.next);     // help s's fulfiller
                        // 返回匹配成功的item.
                        return (E) ((mode == REQUEST) ? m.item : s.item);
                    }
                } else if (!isFulfilling(h.mode)) { // try to fulfill 没有正在进行中的匹配.
                    // 查看头结点是否取消
                    if (h.isCancelled())            // already cancelled
                        casHead(h, h.next);         // pop and retry
                    // 将当前节点置为头结点
                    else if (casHead(h, s=snode(s, e, h, FULFILLING|mode))) {
                        // 等待匹配成功
                        for (;;) { // loop until matched or waiters disappear
                            SNode m = s.next;       // m is s's match
                            if (m == null) {        // all waiters are gone
                                casHead(s, null);   // pop fulfill node
                                s = null;           // use new node next time
                                break;              // restart main loop
                            }
                            SNode mn = m.next;
                            if (m.tryMatch(s)) {
                                casHead(s, mn);     // pop both s and m
                                return (E) ((mode == REQUEST) ? m.item : s.item);
                            } else                  // lost match
                                s.casNext(m, mn);   // help unlink
                        }
                    }
                } else {                            // help a fulfiller
                    // 正在匹配中
                    SNode m = h.next;               // m is h's match
                    if (m == null)                  // waiter is gone
                        casHead(h, null);           // pop fulfilling node
                    else {
                        SNode mn = m.next;
                        if (m.tryMatch(h))          // help match
                            casHead(h, mn);         // pop both h and m
                        else                        // lost match
                            h.casNext(m, mn);       // help unlink
                    }
                }
            }
        }
```

代码比较复杂，尝试写一下各种分支:

1. 栈为空，或者栈首元素和当前的类型一致，要么都是消费者要么都是生产者.
    1. 如果超时了:
        1. 栈首元素已经被取消，就更新栈首元素，重新自旋.
        2. 栈首元素没取消或者为空，直接返回null. 结束.
    2. 没有超时，将当前节点放到栈首成功. 等待匹配. 
        1. 匹配失败，超时了，返回null。
        2. 匹配成功，返回对应的元素.
2. 没有正在进行的匹配.
    1. 如果栈首元素取消了，弹出它，换成他的next继续循环.
    2. 将栈首元素更换为当前元素，且状态为正在匹配，成功.
        1. 自旋等待匹配，匹配成功进行返回，失败继续匹配.
    3. 更新失败，继续循环.
3. 正在进行匹配，协助更新栈首及next指针.


##### TransferQueue 队列

首先是队列中的节点，保存了指向向一个节点的指针，当前节点的元素，以及等待的线程.

```java
//队列中的节点
static final class QNode {
    volatile QNode next;          // next node in queue
    volatile Object item;         // CAS'ed to or from null
    volatile Thread waiter;       // to control park/unpark
    final boolean isData;
}
```

它的属性有:

```java
transient volatile QNode head;
transient volatile QNode tail;
transient volatile QNode cleanMe;
```

队头和队尾。

```java

        @SuppressWarnings("unchecked")
        E transfer(E e, boolean timed, long nanos) {
            QNode s = null; // constructed/reused as needed
            boolean isData = (e != null);

            for (;;) {
                QNode t = tail;
                QNode h = head;
                if (t == null || h == null)         // saw uninitialized value
                    continue;                       // spin

                if (h == t || t.isData == isData) { // empty or same-mode
                    QNode tn = t.next;
                    if (t != tail)                  // inconsistent read
                        continue;
                    if (tn != null) {               // lagging tail
                        advanceTail(t, tn);
                        continue;
                    }
                    if (timed && nanos <= 0L)       // can't wait
                        return null;
                    if (s == null)
                        s = new QNode(e, isData);
                    if (!t.casNext(null, s))        // failed to link in
                        continue;

                    advanceTail(t, s);              // swing tail and wait
                    Object x = awaitFulfill(s, e, timed, nanos);
                    if (x == s) {                   // wait was cancelled
                        clean(t, s);
                        return null;
                    }

                    if (!s.isOffList()) {           // not already unlinked
                        advanceHead(t, s);          // unlink if head
                        if (x != null)              // and forget fields
                            s.item = s;
                        s.waiter = null;
                    }
                    return (x != null) ? (E)x : e;

                } else {                            // complementary-mode
                    QNode m = h.next;               // node to fulfill
                    if (t != tail || m == null || h != head)
                        continue;                   // inconsistent read

                    Object x = m.item;
                    if (isData == (x != null) ||    // m already fulfilled
                        x == m ||                   // m cancelled
                        !m.casItem(x, e)) {         // lost CAS
                        advanceHead(h, m);          // dequeue and retry
                        continue;
                    }

                    advanceHead(h, m);              // successfully fulfilled
                    LockSupport.unpark(m.waiter);
                    return (x != null) ? (E)x : e;
                }
            }
        }

```

队列的匹配操作如上.


仍然是自旋:

1. 如果队列为空，自旋.
2. 如果队列为空，或者都是同一个类型的节点.
    1. 如果队尾发生变化，重新自旋.
    2. 如果队尾向后延长，重新自旋.
    3. 如果超时了，返回null。
    4. 如果当前节点为空，创建当前节点.
    5. 如果将当前节点设置为队尾失败，重新自旋.
    6. 等待匹配，如果匹配失败，返回null。
    7. 匹配成功返回对应的元素.
3. 如果队列不为空，且不是同一个类型的节点
    1. 匹配成功，头结点出队，唤醒等待线程.

这两个实现类有什么区别的？ 就是用来实现公平性的.

#### 构造方法

```java
public SynchronousQueue() {
        this(false);
}

public SynchronousQueue(boolean fair) {
        transferer = fair ? new TransferQueue<E>() : new TransferStack<E>();
}
```

如果是公平性的，则使用FIFO的队列，如果不是公平性的，就使用栈.

#### 入队方法

* put

```java

    public void put(E e) throws InterruptedException {
        if (e == null) throw new NullPointerException();
        if (transferer.transfer(e, false, 0) == null) {
            Thread.interrupted();
            throw new InterruptedException();
        }
    }
```

直接调用`transferer`的传输方法，成功则返回，否则就抛出异常.

其他类似.

#### 出队方法

```java

    public E take() throws InterruptedException {
        E e = transferer.transfer(null, false, 0);
        if (e != null)
            return e;
        Thread.interrupted();
        throw new InterruptedException();
    }
```
直接调用`transferer`的传输方法，成功则返回，否则就抛出异常.

其他类似.

#### WaitQueue 等待队列

```java

    @SuppressWarnings("serial")
    static class WaitQueue implements java.io.Serializable { }
    static class LifoWaitQueue extends WaitQueue {
        private static final long serialVersionUID = -3633113410248163686L;
    }
    static class FifoWaitQueue extends WaitQueue {
        private static final long serialVersionUID = -3623113410248163686L;
    }
    private WaitQueue waitingProducers;
    private WaitQueue waitingConsumers;
```

等待队列以及生产者消费者队列两个属性，只是在JDK1.5版本为了方便序列化而加入的没有意义的空类.


#### 总结

`SynchronousQueue`内部根据是否公平性，实现了一个队列一个栈，用来保存当前请求的生产者和消费者.

将生产者和消费者抽象成队列或者栈中的节点，每次请求来到之后，找另外一种类型的节点进行匹配，如果匹配成功，两个节点均出队，如果匹配失败就不断自旋尝试.

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