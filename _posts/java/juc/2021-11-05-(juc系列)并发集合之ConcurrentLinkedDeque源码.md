---
layout: post
category: [Java,JUC, ConcurrentLinkedDeque]
tags:
  - Java
  - ConcurrentLinkedDeque
  - JUC
---

本文源码基于: <font color='red'>JDK13</font>


## ConcurrentLinkedDeque

### 官方注释翻译

一个无界的，并发的双端队列，使用链表实现. 多线程间的并发写入，移除，访问操作，可以保证安全.当有很多线程共享一个公共集合时，`ConcurrentLinkedDeque`
是一个不错的选择. 像其他的并发集合一样，这个类不接受null元素.

迭代器是弱一致的.


需要注意的是，和其他大多数集合不同，`size`方法不是常量时间的操作. 因为队列的异步特性，决定了计数当前的元素需要遍历所有元素，因此如果有别的线程正在更改，`size`方法可能返回不准确的数字.

批量操作不保证原子性，比如`addAll`等. 当`foreach`和`addAll`一起运行时，可能`foreach`只能观察到部分的元素.


这个类和他的迭代器实现了`Queue`和`Iterator`的所有可选方法.
 
### 源码

#### 定义

```java

public class ConcurrentLinkedDeque<E>
    extends AbstractCollection<E>
    implements Deque<E>, java.io.Serializable {
```

一个双端队列.


#### 内部链表节点

```java

    static final class Node<E> {
        volatile Node<E> prev;
        volatile E item;
        volatile Node<E> next;
    }
```

前后结点的指针，以及当前节点的元素.


#### 属性

```java

    private transient volatile Node<E> head;

    private transient volatile Node<E> tail;
```

保存了头尾节点


#### 构造方法

```java

    public ConcurrentLinkedDeque() {
        head = tail = new Node<E>();
    }

    public ConcurrentLinkedDeque(Collection<? extends E> c) {
        // Copy c into a private chain of Nodes
        Node<E> h = null, t = null;
        for (E e : c) {
            Node<E> newNode = newNode(Objects.requireNonNull(e));
            if (h == null)
                h = t = newNode;
            else {
                NEXT.set(t, newNode);
                PREV.set(newNode, t);
                t = newNode;
            }
        }
        initHeadTail(h, t);
    }
```

两个构造方法，一个构造空的队列,一个将给定集合初始化到队列中.


#### 入队方法

```java

    public void addFirst(E e) {
        linkFirst(e);
    }

    public void addLast(E e) {
        linkLast(e);
    }

    public boolean offerFirst(E e) {
        linkFirst(e);
        return true;
    }

    public boolean offerLast(E e) {
        linkLast(e);
        return true;
    }
```

支持队头和队尾的添加操作，具体调用的是`linkFirst`和`linkLast`.

* linkFirst

```java

    private void linkFirst(E e) {
        // 创建当前节点
        final Node<E> newNode = newNode(Objects.requireNonNull(e));

        restartFromHead:
        for (;;)
            for (Node<E> h = head, p = h, q;;) {
                // 如果节点的前置节点不为空，更新p节点
                if ((q = p.prev) != null &&
                    (q = (p = q).prev) != null)
                    // Check for head updates every other hop.
                    // If p == q, we are sure to follow head instead.
                    p = (h != (h = head)) ? h : q;
                // p节点出队了重新从头开始
                else if (p.next == p) // PREV_TERMINATOR
                    continue restartFromHead;
                else {
                    // p is first node
                    // 将当前节点设置为第一个.
                    NEXT.set(newNode, p); // CAS piggyback
                    // cas 更新相关属性, 原有头结点的前置属性，以及新的头结点等.
                    if (PREV.compareAndSet(p, null, newNode)) {
                        // Successful CAS is the linearization point
                        // for e to become an element of this deque,
                        // and for newNode to become "live".
                        if (p != h) // hop two nodes at a time; failure is OK
                            HEAD.weakCompareAndSet(this, h, newNode);
                        return;
                    }
                    // Lost CAS race to another thread; re-read prev
                }
            }
    }
```

将当前节点，设置为第一个节点，采用CAS+自旋实现，当发现已有头结点出队后，重新找头结点.


* linkLast

链接为节点，和头结点思路一致.

```java

    private void linkLast(E e) {
        final Node<E> newNode = newNode(Objects.requireNonNull(e));

        restartFromTail:
        for (;;)
            for (Node<E> t = tail, p = t, q;;) {
                if ((q = p.next) != null &&
                    (q = (p = q).next) != null)
                    // Check for tail updates every other hop.
                    // If p == q, we are sure to follow tail instead.
                    p = (t != (t = tail)) ? t : q;
                else if (p.prev == p) // NEXT_TERMINATOR
                    continue restartFromTail;
                else {
                    // p is last node
                    PREV.set(newNode, p); // CAS piggyback
                    if (NEXT.compareAndSet(p, null, newNode)) {
                        // Successful CAS is the linearization point
                        // for e to become an element of this deque,
                        // and for newNode to become "live".
                        if (p != t) // hop two nodes at a time; failure is OK
                            TAIL.weakCompareAndSet(this, t, newNode);
                        return;
                    }
                    // Lost CAS race to another thread; re-read next
                }
            }
    }
```

#### 出队操作

```java

    public E pollFirst() {
        restart: for (;;) {
            for (Node<E> first = first(), p = first;;) {
                // 队头节点, cas更改属性
                final E item;
                if ((item = p.item) != null) {
                    // recheck for linearizability
                    if (first.prev != null) continue restart;
                    if (ITEM.compareAndSet(p, item, null)) {
                        unlink(p);
                        return item;
                    }
                }
                // 已出队，重新开始
                if (p == (p = p.next)) continue restart;
                // p为空，队列为空，返回空
                if (p == null) {
                    if (first.prev != null) continue restart;
                    return null;
                }
            }
        }
    }

    public E pollLast() {
        restart: for (;;) {
            for (Node<E> last = last(), p = last;;) {
                final E item;
                if ((item = p.item) != null) {
                    // recheck for linearizability
                    if (last.next != null) continue restart;
                    if (ITEM.compareAndSet(p, item, null)) {
                        unlink(p);
                        return item;
                    }
                }
                if (p == (p = p.prev)) continue restart;
                if (p == null) {
                    if (last.next != null) continue restart;
                    return null;
                }
            }
        }
    }
```

与入队对应的，将队首或者队尾进行弹出. 思路一致.


#### 普通队列的操作

双端队列可以向普通队列一样，提供入队出队操作，此时他是一个`FIFO`的队列，也就是入队添加到队尾，出队从队头获取元素.


#### 总结

和`ConcurrentLinkedQueue`思路一致，使用CAS+自旋实现. 只是提供了双端队列相关的方法.

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