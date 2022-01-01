---
layout: post
category: [Java,TransferQueue]
tags:
  - Java
  - TransferQueue
---



本文源码基于: <font color='red'>JDK13</font>


## TransferQueue 接口

### 官方注释翻译

一个支持让生产者阻塞等待消费者获取元素的阻塞队列. 可能用在消息传递系统中， 生产者有时候需要等待消费者调用`take`或者`poll`来获取元素,另外一些时候，入队元素可以不用等待消费者获取.

非阻塞的和超时阻塞的版本也是提供了的，使用`tryTransfer`.

一个`TransferQueue`也可以查询当前的消费者数量，这与`peek`是一个相反的操作.

像其他的阻塞队列一样，`TransferQueue`也可以是有界的。这种情况下，一个尝试传输的操作可能会首先阻塞等待可用的空间，然后阻塞等待对应的消费者. 注意，在一个容量为0的传输队列中，`put`和`transfer`
操作实际上都是同步的.

### 接口方法

* tryTransfer 尝试传输
* transfer 传输
* tryTransfer 尝试传输
* hasWaitingConsumer 是否有等待的消费者
* getWaitingConsumerCount 等待的消费者的数量


##  LinkedTransferQueue 链表实现的一个传输队列

### 官方注释翻译

一个无界的`TransferQueue`，基于链表实现. 这个队列严格按照`FIFO`的顺序排序元素.

队头元素是在队里时间最长的生产者,队尾元素是在队列里时间最短的生产者。

注意，和大多数集合类不一样的是， `size`方法并不是一个常量时间的方法. 由于队列的异步特定，确定当前元素的数量需要遍历一遍元素，如果在遍历期间有修改的动作，那么拿到的集合可能是不准确的.

批量操作，比如`add，remove，examine`等，不保证原子性，比如，一个`foreach`的便利操作，可能会值添加了部分元素.


这个类和他的迭代器，实现了`Collection`和`Iterator`的全部可选方法.


### 源码

#### 定义

```java

public class LinkedTransferQueue<E> extends AbstractQueue<E>
implements TransferQueue<E>, java.io.Serializable {

```

一个基本的队列，还是一个传输队列.


#### 内部节点 Node

传输队列，首先要看一下内部的抽象节点.


```java
    static final class Node {
        final boolean isData;   // false if this is a request node
        volatile Object item;   // initially non-null if isData; CASed to match
        volatile Node next;
        volatile Thread waiter; // null when not waiting for a match
```

保存了节点的属性(生产者/消费者), 节点的元素，下一个节点的指针，等待的线程.


#### LinkedTransferQueue 属性

```java

    transient volatile Node head;

    private transient volatile Node tail;

    private transient volatile int sweepVotes;
```

保存了链表的头结点和尾节点,链表的常见结构.

#### 构造方法

```java

    public LinkedTransferQueue() {
        head = tail = new Node();
    }

    public LinkedTransferQueue(Collection<? extends E> c) {
        Node h = null, t = null;
        for (E e : c) {
            Node newNode = new Node(Objects.requireNonNull(e));
            if (h == null)
                h = t = newNode;
            else
                t.appendRelaxed(t = newNode);
        }
        if (h == null)
            h = t = new Node();
        head = h;
        tail = t;
    }
```

提供了两个构造方法，分别创建一个空的传输队列，和将给定集合的所有元素添加到队列中.

#### 入队方法 生产者

```java

    public void put(E e) {
        xfer(e, true, ASYNC, 0);
    }

    public boolean offer(E e, long timeout, TimeUnit unit) {
        xfer(e, true, ASYNC, 0);
        return true;
    }

    public boolean offer(E e) {
        xfer(e, true, ASYNC, 0);
        return true;
    }

    public boolean add(E e) {
        xfer(e, true, ASYNC, 0);
        return true;
    }
```

#### 出队方法 消费者

```java

    public E take() throws InterruptedException {
        E e = xfer(null, false, SYNC, 0);
        if (e != null)
            return e;
        Thread.interrupted();
        throw new InterruptedException();
    }

    public E poll(long timeout, TimeUnit unit) throws InterruptedException {
        E e = xfer(null, false, TIMED, unit.toNanos(timeout));
        if (e != null || !Thread.interrupted())
            return e;
        throw new InterruptedException();
    }

    public E poll() {
        return xfer(null, false, NOW, 0);
    }
```

可以看到，基本上也都一致，调用的`xfer`方法，这就是核心了.

#### 尝试传输方法 


```java

    public boolean tryTransfer(E e) {
        return xfer(e, true, NOW, 0) == null;
    }

    public void transfer(E e) throws InterruptedException {
        if (xfer(e, true, SYNC, 0) != null) {
            Thread.interrupted(); // failure possible only due to interrupt
            throw new InterruptedException();
        }
    }

    public boolean tryTransfer(E e, long timeout, TimeUnit unit)
        throws InterruptedException {
        if (xfer(e, true, TIMED, unit.toNanos(timeout)) == null)
            return true;
        if (!Thread.interrupted())
            return false;
        throw new InterruptedException();
    }
    
```
            
也是全部调用了xfer方法，这个方法就是这个类的核心了.

#### Xfer

是核心，但是不想看了.

思路是: 维护量一个队列，队列中的元素有两种状态，生产者或者消费者.

每一个请求到来之后，从队列头部开始匹配，如果成功，就返回. 失败就匹配下一个，如果匹配到队列末尾还没有匹配成功，则将其添加到队列末尾，进行阻塞等待.

请求到来之后，如果队首的元素类型和当前的都不一致，那就不用匹配了，直接开始阻塞等待即可.

详细的代码放在这里，啥时候有耐心看懂再看.

```java

    private E xfer(E e, boolean haveData, int how, long nanos) {
        // 生产者元素为空，不接受
        if (haveData && (e == null))
            throw new NullPointerException();

        // 外层自旋
        restart: for (Node s = null, t = null, h = null;;) {
            
            // 从头结点开始匹配
            for (Node p = (t != (t = tail) && t.isData == haveData) ? t
                     : (h = head);; ) {
                final Node q; final Object item;
                // 如果头结点和属性和给定的不一致
                if (p.isData != haveData
                    && haveData == ((item = p.item) == null)) {
                    if (h == null) h = head;
                    // 尝试匹配
                    if (p.tryMatch(item, e)) {
                        if (h != p) skipDeadNodesNearHead(h, p);
                        // 返回匹配结果
                        return (E) item;
                    }
                }
                if ((q = p.next) == null) {
                    if (how == NOW) return e;
                    if (s == null) s = new Node(e);
                    if (!p.casNext(null, s)) continue;
                    if (p != t) casTail(t, s);
                    if (how == ASYNC) return e;
                    return awaitMatch(s, p, e, (how == TIMED), nanos);
                }
                if (p == (p = q)) continue restart;
            }
        }
    }
```

#### 总结


1. LinkedTransferQueue可以看作LinkedBlockingQueue、SynchronousQueue（公平模式）、ConcurrentLinkedQueue三者的集合体；
2. 不管是取元素还是放元素都会入队；
3. 先尝试跟头节点比较，如果二者模式不一样，就匹配它们，组成CP，然后返回对方的值；
4. 如果二者模式一样，就入队，并自旋或阻塞等待被唤醒；
5. LinkedTransferQueue全程都没有使用synchronized、重入锁等比较重的锁，基本是通过 自旋+CAS 实现；
6. 对于入队之后，先自旋一定次数后再调用LockSupport.park()或LockSupport.parkNanos阻塞；


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