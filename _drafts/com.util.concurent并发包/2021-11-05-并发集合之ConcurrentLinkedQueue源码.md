---
layout: post
category: [Java,JUC, ConcurrentLinkedQueue]
tags:
  - Java
  - ConcurrentLinkedQueue
  - JUC
---




## 前言

## ConcurrentLinkedQueue

### 官方注释翻译

一个用链表实现的无界的线程安全的队列. 这个队列提供`FIFO`的元素顺序. 

当多个线程需要共享一个集合的访问时， `ConcurrentLinkedQueue`是一个合适的选择. 向其他的并发集合实现一样，这个类不接受null元素.

这个实现使用了高效的无锁算法. 来源于paper [Simple, Fast, and Practical Non-Blocking and Blocking
Concurrent Queue Algorithms](https://www.cs.rochester.edu/~scott/papers/1996_PODC_queues.pdf)

迭代器是弱同步的，返回元素是创建迭代器时的元素快照. 不会抛出`ConcurrentModificationException`. 可以和其他操作一起并发的进行. 迭代器创建时的元素，将会被精准的返回一次.

需要注意的是，和其他大多数集合不同，`size`方法不是常量时间的操作. 因为队列的异步特性，决定了计数当前的元素需要遍历所有元素，因此如果有别的线程正在更改，`size`方法可能返回不准确的数字.

批量操作不保证原子性，比如`addAll`等. 当`foreach`和`addAll`一起运行时，可能`foreach`只能观察到部分的元素.


这个类和他的迭代器实现了`Queue`和`Iterator`的所有可选方法.

### 源码


#### 定义
```java

public class ConcurrentLinkedQueue<E> extends AbstractQueue<E>
implements Queue<E>, java.io.Serializable {
```

这是一个队列.


#### 链表节点

```java

    static final class Node<E> {
        volatile E item;
        volatile Node<E> next;

        /**
         * Constructs a node holding item.  Uses relaxed write because
         * item can only be seen after piggy-backing publication via CAS.
         */
        Node(E item) {
            ITEM.set(this, item);
        }

        /** Constructs a dead dummy node. */
        Node() {}

        void appendRelaxed(Node<E> next) {
            // assert next != null;
            // assert this.next == null;
            NEXT.set(this, next);
        }

        boolean casItem(E cmp, E val) {
            // assert item == cmp || item == null;
            // assert cmp != null;
            // assert val == null;
            return ITEM.compareAndSet(this, cmp, val);
        }
    }
```

保存了当前节点的数据`Item`及指向下一个节点的指针`next`. 

提供了两个cas方法，分别用来更改数据以及指针.

#### 属性


```java

    transient volatile Node<E> head;

    private transient volatile Node<E> tail;
```

保存了链表的头尾节点.


#### 构造方法
```java

    public ConcurrentLinkedQueue() {
        head = tail = new Node<E>();
    }

    public ConcurrentLinkedQueue(Collection<? extends E> c) {
        Node<E> h = null, t = null;
        for (E e : c) {
            Node<E> newNode = new Node<E>(Objects.requireNonNull(e));
            if (h == null)
                h = t = newNode;
            else
                t.appendRelaxed(t = newNode);
        }
        if (h == null)
            h = t = new Node<E>();
        head = h;
        tail = t;
    }
```

提供了两个构造方法，支持创建空的队列和将给定的集合全部初始化进队列.


#### 入队方法 offer


```java

    public boolean add(E e) {
        return offer(e);
    }

    public boolean offer(E e) {
        // 创建新的节点
        final Node<E> newNode = new Node<E>(Objects.requireNonNull(e));

        for (Node<E> t = tail, p = t;;) {
            Node<E> q = p.next;
            // 尾节点的下一个为空. 直接cas更新,且成功了
            if (q == null) {
                // p is last node
                if (NEXT.compareAndSet(p, null, newNode)) {
                    // Successful CAS is the linearization point
                    // for e to become an element of this queue,
                    // and for newNode to become "live".
                    if (p != t) // hop two nodes at a time; failure is OK
                        TAIL.weakCompareAndSet(this, t, newNode);
                    return true;
                }
                // Lost CAS race to another thread; re-read next
            }
            // p节点被删除了，也就是出队了. 重新设置p节点的值
            else if (p == q)
                // We have fallen off list.  If tail is unchanged, it
                // will also be off-list, in which case we need to
                // jump to head, from which all live nodes are always
                // reachable.  Else the new tail is a better bet.
                p = (t != (t = tail)) ? t : head;
            else
                // Check for tail updates after two hops.
                // 如果别的地方更新了尾节点，看一下应该继续向后找还是.
                p = (p != t && t != (t = tail)) ? t : q;
        }
    }
```

`offer`方法进行实际的添加操作，将给定的节点，链接到已有队列的尾部. 过程中要充分考虑到与其他线程产生竞争的情况.



#### 出队方法 poll

```java

    public E poll() {
        restartFromHead: for (;;) {
            for (Node<E> h = head, p = h, q;; p = q) {
                // 从队头开始
                final E item;
                // 如果队头就OK，直接cas更新，并且返回结果
                if ((item = p.item) != null && p.casItem(item, null)) {
                    // Successful CAS is the linearization point
                    // for item to be removed from this queue.
                    if (p != h) // hop two nodes at a time
                        updateHead(h, ((q = p.next) != null) ? q : p);
                    return item;
                }
                // 头结点的下一个为空，队列为空了
                else if ((q = p.next) == null) {
                    updateHead(h, p);
                    return null;
                }
                // 当前节点出队了，重新从队头开始
                else if (p == q)
                    continue restartFromHead;
            }
        }
    }

```

从队头开始遍历，如果成功拿到头结点，且CAS更新成功，就返回. 否则继续找到下一个.

#### 查看队首 peek


```java

    public E peek() {
        restartFromHead: for (;;) {
            for (Node<E> h = head, p = h, q;; p = q) {
                final E item;
                // 队头元素OK. 返回队头元素
                if ((item = p.item) != null
                    || (q = p.next) == null) {
                    updateHead(h, p);
                    return item;
                }
                // 当前节点出队了，重新找队头
                else if (p == q)
                    continue restartFromHead;
            }
        }
    }
```

比较简单，不断尝试获取队头元素.


#### 查看数量 size

```java

    public int size() {
        restartFromHead: for (;;) {
            int count = 0;
            // 从队头开始计数
            for (Node<E> p = first(); p != null;) {
                if (p.item != null)
                    if (++count == Integer.MAX_VALUE)
                        break;  // @see Collection.size()
                // 当前元素出队了，从头开始计数
                if (p == (p = p.next))
                    continue restartFromHead;
            }
            
            return count;
        }
    }
```


每次都从队头开始计数， 如果中间与双开被别人更改的情况，就重新从队头开始计数.


#### 总结




一个非阻塞的，线程安全的队列，全程无锁，采用CAS+自旋实现. 

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