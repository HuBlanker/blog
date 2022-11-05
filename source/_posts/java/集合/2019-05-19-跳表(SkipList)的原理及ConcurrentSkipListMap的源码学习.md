---
layout: post
tags:
  - Java
  - 源码阅读
  - Java集合
  - 数据结构
---

## 目录

- [目录](#目录)
- [前言](#前言)
- [跳表](#跳表)
    - [概述](#概述)
    - [原理](#原理)
    - [应用](#应用)
- [ConcurrentSkilListMap的实现](#concurrentskillistmap的实现)
    - [内部数据结构](#内部数据结构)
    - [主要API的实现](#主要api的实现)
        - [put](#put)
        - [Get](#get)
        - [findPredecessor](#findpredecessor)
        - [remove](#remove)
- [总结](#总结)
- [参考文章](#参考文章)

## 前言

本文分为两个部分,第一个是对跳表(SKipList)这种数据结构的介绍,第二部分则是对Java中`ConcurrentSkilListMap`的源码解读.

## 跳表

关于跳表的概述,强力推荐这篇文章,[漫画算法:什么是跳表](http://blog.jobbole.com/111731/),我也是看了这个之后才豁然开朗,讲解的通俗又生动.

### 概述

跳跃列表是一种数据结构。它允许快速查询一个有序元素的数据链表。跳跃列表的平均查找和插入时间复杂度都是O(log n)，优于普通队列的O(n)。

想一下我们日常对列表的存储方式:
1. 数组
2. 链表

数组查询较快,支持随机访问以及二分法查找,但是插入和删除数据需要移动较多的值,效率较低.时间复杂度为O(n).

链表的插入较快,但是在插入之前需要先寻找合适的位置,这一步骤也是O(n)的复杂度,因此链表的插入和查询都是O(n)的复杂度.

那么有没有一种在插入和查询上都表现比较好的数据结构呢?

有,各种查找树平衡树等,今天这里学习一种新的实现方式:跳表.

### 原理

其实跳表的原理,对计算机行业的同学来说,一张图就可以明了.

![2019-05-19-17-03-55](http://img.couplecoders.tech/2019-05-19-17-03-55.png)

即原来的链表不变,额外维护一份索引(1级),记录某几个值的位置及值.

当数据量过大,比如有10w数据,那么维护的索引有一半的话也有5w,那么查找依然很慢,这个时候可以再加一层索引,数据量就只有2w5了.

一直这样添加索引,到最后会额外多维护一份数据,但是模拟了二分查找,因此在插入和查找上都是O(logn)的时间复杂度,空间复杂度为O(2n)也就是O(n).

当然跳表有非常多的变种,可以在上面的策略上进行各种调整,以使他的时间复杂度和空间复杂度接近自己的要求.

当删除或者添加的时候,会造成原来链表结构的变化,这时候上面的各层索引也需要相应的修改,那么如何决定一个节点是否应该被提升一层作为一个索引呢?在跳表中使用的是随机的方式,比在二叉搜索树中的方法要轻量级许多.

### 应用

1. redis中的sorted set数据结构,内部使用跳表实现
2. lucene

## ConcurrentSkilListMap的实现

ConcurrentSkipListMap 一个并发安全, 基于 skip list 实现有序存储的Map.

### 内部数据结构

ConcurrentSkilListMap内部封装了几个数据结构,我们看一下:

```java
    // 一个节点,保存了key,value,还有指向下一个节点的指针 
    static final class Node<K,V> {
        final K key;
        volatile Object value;
        volatile Node<K,V> next;
    }

    // 索引,包含一个上面的节点,还有右边的索引(同一级),下边的索引(下一级) 
    static class Index<K,V> {
        final Node<K,V> node;
        final Index<K,V> down;
        volatile Index<K,V> right;
    }

    // 每一层的头索引,带有当前的level. 
    static final class HeadIndex<K,V> extends Index<K,V> {
        final int level;
        HeadIndex(Node<K,V> node, Index<K,V> down, Index<K,V> right, int level) {
            super(node, down, right);
            this.level = level;
        }
    }
```

### 主要API的实现

直接看代码有点难以下手,我们根据他提供的一些公共的API来逐一看一下实现方式.

#### put

这个方法我们必须首先看一下,是我们在使用`HashMap`等结构的时候常用的put方法.

这里大概说一下流程,代码里加上了注释.

1. 找到当前数据应该存放的位置进行插入.
2. 准备各层的索引.
3. 插入索引.



```java
    public V put(K key, V value) {
        if (value == null)
            throw new NullPointerException();
        return doPut(key, value, false);
    }

    /**
     * Main insertion method.  Adds element if not present, or
     * replaces value if present and onlyIfAbsent is false.
     * @param key the key
     * @param value the value that must be associated with key
     * @param onlyIfAbsent if should not insert if already present
     * @return the old value, or null if newly inserted
     */
     /**
      * 插入的主方法,如果不存在则插入元素,如果存在且传入的`onlyIfAbsent`为false则替换掉值.
      */
    private V doPut(K key, V value, boolean onlyIfAbsent) {
        Node<K,V> z;             // added node
        if (key == null)
            throw new NullPointerException();
        Comparator<? super K> cmp = comparator;
        outer: for (;;) {
            // 找到前置节点,在base-level上的.
            for (Node<K,V> b = findPredecessor(key, cmp), n = b.next;;) {
                if (n != null) {
                    Object v; int c;
                    Node<K,V> f = n.next;
                    // 发生了多线程竞争,break.重新试一遍
                    if (n != b.next)               // inconsistent read
                        break;
                    if ((v = n.value) == null) {   // n is deleted
                        n.helpDelete(b, f);
                        break;
                    }
                    if (b.value == null || v == n) // b is deleted
                        break;
                    
                    // 如果key大于前置节点,继续
                    if ((c = cpr(cmp, key, n.key)) > 0) {
                        b = n;
                        n = f;
                        continue;
                    }
                    // 等于则赋值
                    if (c == 0) {
                        if (onlyIfAbsent || n.casValue(v, value)) {
                            @SuppressWarnings("unchecked") V vv = (V)v;
                            return vv;
                        }
                        // 竞争失败了,重新来
                        break; // restart if lost race to replace value
                    }
                    // else c < 0; fall through
                }
                // 如果该前置节点的后继节点为空,则直接进行插入,使用cas操作连接传入的节点.
                z = new Node<K,V>(key, value, n);
                if (!b.casNext(n, z))
                    break;         // restart if lost race to append to b
                break outer;
            }
        }

        // 获取level
        int rnd = ThreadLocalRandom.nextSecondarySeed();
        if ((rnd & 0x80000001) == 0) { // test highest and lowest bits
            int level = 1, max;
            while (((rnd >>>= 1) & 1) != 0)
                ++level;
            Index<K,V> idx = null;
            HeadIndex<K,V> h = head;
            // 添加z的索引数据
            if (level <= (max = h.level)) {
                for (int i = 1; i <= level; ++i)
                    idx = new Index<K,V>(z, idx, null);
            }
            else { // 添加新的一层索引
                level = max + 1; // hold in array and later pick the one to use
                @SuppressWarnings("unchecked")Index<K,V>[] idxs =
                    (Index<K,V>[])new Index<?,?>[level+1];
                for (int i = 1; i <= level; ++i)
                    idxs[i] = idx = new Index<K,V>(z, idx, null);
                for (;;) {
                    h = head;
                    int oldLevel = h.level;
                    if (level <= oldLevel) // lost race to add level
                        break;
                    HeadIndex<K,V> newh = h;
                    Node<K,V> oldbase = h.node;
                    for (int j = oldLevel+1; j <= level; ++j)
                        newh = new HeadIndex<K,V>(oldbase, newh, idxs[j], j);
                    if (casHead(h, newh)) {
                        h = newh;
                        idx = idxs[level = oldLevel];
                        break;
                    }
                }
            }
            // find insertion points and splice in
            splice: for (int insertionLevel = level;;) {
                int j = h.level;
                for (Index<K,V> q = h, r = q.right, t = idx;;) {
                    if (q == null || t == null)
                        break splice;
                    if (r != null) {
                        Node<K,V> n = r.node;
                        // compare before deletion check avoids needing recheck
                        int c = cpr(cmp, key, n.key);
                        if (n.value == null) {
                            if (!q.unlink(r))
                                break;
                            r = q.right;
                            continue;
                        }
                        if (c > 0) {
                            q = r;
                            r = r.right;
                            continue;
                        }
                    }

                    if (j == insertionLevel) {
                        if (!q.link(r, t))
                            break; // restart
                        if (t.node.value == null) {
                            findNode(key);
                            break splice;
                        }
                        if (--insertionLevel == 0)
                            break splice;
                    }

                    if (--j >= insertionLevel && j < level)
                        t = t.down;
                    q = q.down;
                    r = q.right;
                }
            }
        }
        return null;
    }
```


#### Get

get方法比较简单:

```java
    /**
     * Gets value for key. Almost the same as findNode, but returns
     * the found value (to avoid retries during re-reads)
     *
     * @param key the key
     * @return the value, or null if absent
     */
    private V doGet(Object key) {
        if (key == null)
            throw new NullPointerException();
        Comparator<? super K> cmp = comparator;
        outer: for (;;) {
            // 寻找前置节点
            for (Node<K,V> b = findPredecessor(key, cmp), n = b.next;;) {
                Object v; int c;
                // 如果为空则不存在,直接返回
                if (n == null)
                    break outer;
                Node<K,V> f = n.next;
                // 多线程竞争,重新试一下
                if (n != b.next)                // inconsistent read
                    break;
                if ((v = n.value) == null) {    // n is deleted
                    n.helpDelete(b, f);
                    break;
                }
                if (b.value == null || v == n)  // b is deleted
                    break;
                    // 如果相等,则返回值.
                if ((c = cpr(cmp, key, n.key)) == 0) {
                    @SuppressWarnings("unchecked") V vv = (V)v;
                    return vv;
                }
                if (c < 0)
                    break outer;
                b = n;
                n = f;
            }
        }
        return null;
    }
```

#### findPredecessor

可以看到在`get`和`put`方法中,寻找前置节点都比较重要.

寻找前置节点的思路比较明了,就是跳表的查找思路:

1. 从矩形索引的左上角开始向右查找
2. 如果右侧索引为空,或者右侧索引的值大于要查找的值,则向下一层.
3. 然后重复向右侧,向下进行查找,知道拿到前置节点.

代码如下:

```java
    /**
     * Returns a base-level node with key strictly less than given key,
     * or the base-level header if there is no such node.  Also
     * unlinks indexes to deleted nodes found along the way.  Callers
     * rely on this side-effect of clearing indices to deleted nodes.
     * @param key the key
     * @return a predecessor of key
     */
    private Node<K,V> findPredecessor(Object key, Comparator<? super K> cmp) {
        if (key == null)
            throw new NullPointerException(); // don't postpone errors
        for (;;) {
            // 拿到矩形索引的左上角的索引
            for (Index<K,V> q = head, r = q.right, d;;) {
                // 右侧索引不为空
                if (r != null) {
                    Node<K,V> n = r.node;
                    K k = n.key;
                    // 竞争
                    if (n.value == null) {
                        if (!q.unlink(r))
                            break;           // restart
                        r = q.right;         // reread r
                        continue;
                    }
                    // 如果小于传入的key,则向右查找.
                    if (cpr(cmp, key, k) > 0) {
                        q = r;
                        r = r.right;
                        continue;
                    }
                }
                // 到达最后一层了,数据层,返回拿到的节点.就是后继几点.
                if ((d = q.down) == null)
                    return q.node;
                // 这边是右侧的索引为空,则可以直接向下一层了.
                q = d;
                r = d.right;
            }
        }
    }
```

#### remove

思路比较简单:
1. 找到前置节点
2. 删除节点
3. 删除索引

```java
    /**
     * Main deletion method. Locates node, nulls value, appends a
     * deletion marker, unlinks predecessor, removes associated index
     * nodes, and possibly reduces head index level.
     *
     * Index nodes are cleared out simply by calling findPredecessor.
     * which unlinks indexes to deleted nodes found along path to key,
     * which will include the indexes to this node.  This is done
     * unconditionally. We can't check beforehand whether there are
     * index nodes because it might be the case that some or all
     * indexes hadn't been inserted yet for this node during initial
     * search for it, and we'd like to ensure lack of garbage
     * retention, so must call to be sure.
     *
     * @param key the key
     * @param value if non-null, the value that must be
     * associated with key
     * @return the node, or null if not found
     */
    final V doRemove(Object key, Object value) {
        if (key == null)
            throw new NullPointerException();
        Comparator<? super K> cmp = comparator;
        outer: for (;;) {
            // 寻找前置节点
            for (Node<K,V> b = findPredecessor(key, cmp), n = b.next;;) {
                Object v; int c;
                // 竞争
                if (n == null)
                    break outer;
                Node<K,V> f = n.next;
                if (n != b.next)                    // inconsistent read
                    break;
                if ((v = n.value) == null) {        // n is deleted
                    n.helpDelete(b, f);
                    break;
                }
                if (b.value == null || v == n)      // b is deleted
                    break;
                //  如果节点不存在,直接返回
                if ((c = cpr(cmp, key, n.key)) < 0)
                    break outer;
                if (c > 0) {
                    b = n;
                    n = f;
                    continue;
                }
                // 不删除了
                if (value != null && !value.equals(v))
                    break outer;
                // 进行删除操作
                if (!n.casValue(v, null))
                    break;
                // 删除索引
                if (!n.appendMarker(f) || !b.casNext(n, f))
                    findNode(key);                  // retry via findNode
                else {
                    findPredecessor(key, cmp);      // clean index
                    // 如果一层索引都空了,则删除这一层.
                    if (head.right == null)
                        tryReduceLevel();
                }
                @SuppressWarnings("unchecked") V vv = (V)v;
                return vv;
            }
        }
        return null;
    }
```

## 总结

跳表是一种可以在有序的列表上进行快速的查找的数据结构,他的查找删除插入的时间复杂度都O(logN).在跳表中,存储数据的就是底层的一个单链表,同时维护一份索引,索引是最多31条单链表,并且不同层的相同节点在纵向上也是一个链表,因此索引其实是一个矩形的结构,查找时,从矩形的左上角逐渐向右向下查找.

`ConcurrentSkipListMap`是Java中对于跳表的一个并发实现,且没有使用锁机制,采用了CAS算法以提供并发的能力.


## ConcurrentSkipListSet

跳表实现集合. 内部使用`ConcurrentSkipListMap`实现.


### 属性及构造方法

```java

    private final ConcurrentNavigableMap<E,Object> m;

    public ConcurrentSkipListSet() {
        m = new ConcurrentSkipListMap<E,Object>();
    }

    public ConcurrentSkipListSet(Comparator<? super E> comparator) {
        m = new ConcurrentSkipListMap<E,Object>(comparator);
    }

    public ConcurrentSkipListSet(Collection<? extends E> c) {
            m = new ConcurrentSkipListMap<E,Object>();
            addAll(c);
            }

    public ConcurrentSkipListSet(SortedSet<E> s) {
            m = new ConcurrentSkipListMap<E,Object>(s.comparator());
            addAll(s);
            }
```

内部持有一个map，构造方法是对map的初始化.

同时支持将给定的集合，初始化到set中.




###  add 方法

```java

    public boolean add(E e) {
        return m.putIfAbsent(e, Boolean.TRUE) == null;
    }
```

调用`map`的`不存在则添加方法`,以实现`Set`的唯一性语义.

### remove

```java

    public boolean remove(Object o) {
        return m.remove(o, Boolean.TRUE);
    }
```

直接调用remove即可.


其他方法全部由map进行代理.

### 总结

使用`map`来实现`Set`的又一个案例. map的keys就是所需要的set集合. values放一个无意义值即可.

## 参考文章

http://blog.jobbole.com/111731/
https://www.jianshu.com/p/edc2fd149255

<br>
完。

<br>
<br>
<br>
<br>
<h4>ChangeLog</h4>
2019-05-19 完成
<br>
<br>

**以上皆为个人所思所得，如有错误欢迎评论区指正。**

**欢迎转载，烦请署名并保留原文链接。**

**联系邮箱：huyanshi2580@gmail.com**

**更多学习笔记见个人博客------><a href="{{ site.baseurl }}/">呼延十</a>**
