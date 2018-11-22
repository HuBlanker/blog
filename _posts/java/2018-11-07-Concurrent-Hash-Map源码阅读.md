---
layout: post
category: [源码阅读,java]
tags:
  - Java
  - 源码阅读
---

<font  color="red">PS.本文基于JDK1.8</font>

## 前言

大家都知道HashMap是线程不安全的,想要在并发的环境中使用,用什么呢?HashTable?采用syncgronized加锁,导致效率及其底下.在java5之后jdk提供了另一个类,ConcurrentHashMap,极大的提升了并发下的性能.

这次将阅读ConcurrentHashMap的源码并记录关键知识.

## 实现原理

#### 数据结构

与HashMap的数据结构同步,在JDK1.7中使用数组+链表,在JDK1.8之后使用数组+链表+红黑树.

#### 并发

在1.7版本,使用<font color="red">锁分离</font>技术,即ConcurrentHashMap由Segment组成,每个Segment包含一些Node存储键值对.
而每个Segment都有一把锁.并发性能依赖于Segment的粒度,当你将整个HashMap放入同一个Segment,ConcurrentHashMap会退化成HashMap.

1.8版本中,摒弃了锁分离的概念,虽然保留了Segment,但是只是为了兼容老的版本.

**1.8中使用CAS算法+锁来保证并发性能及线程安全**

#### CAS 算法

通俗的讲(我的理解)就是:在每一次操作的时候参数中带有预期值(旧值),当且仅当内存中的值与预期值相同的时候,才写入新值.


## 源码逐步解析

注意,本文只解读JDK1.8版本的ConcurrentHashMap,在源码中与以前版本有关的东西略过.

### 常量

```java
//最大容量
private static final int MAXIMUM_CAPACITY = 1 << 30;

//默认容量，且必须为2的次幂
private static final int DEFAULT_CAPACITY = 16;

//负载因子，决定何时扩容
private static final float LOAD_FACTOR = 0.75f;

//链表转红黑树的阀值，>8
static final int TREEIFY_THRESHOLD = 8;

//红黑树转链表的阀值，<6
static final int UNTREEIFY_THRESHOLD = 6;

//树的最小容量
static final int MIN_TREEIFY_CAPACITY = 64;

//正在扩容的标示位
static final int MOVED     = -1; // hash for forwarding nodes
//树的根节点标识
static final int TREEBIN   = -2; // hash for roots of trees
```

常量的定义较为简单,这里只列出了一些常用的常量,还有一些在具体使用时再贴.

代码中已加入注释,一看就懂.

### 属性

```java

//node的数组，
transient volatile Node<K,V>[] table;

//node的数组，扩容时候使用
private transient volatile Node<K,V>[] nextTable;

//计数值，也是用CAS修改
private transient volatile long baseCount;

/**
 * Table initialization and resizing control.  When negative, the
 * table is being initialized or resized: -1 for initialization,
 * else -(1 + the number of active resizing threads).  Otherwise,
 * when table is null, holds the initial table size to use upon
 * creation, or 0 for default. After initialization, holds the
 * next element count value upon which to resize the table.
 */
 //这是一个标识位，当为-1的时候代表正在初始化，当为-N的时候代表有N - 1个线程正在扩容，
 //当为正数的时候代表下一次扩容后的大小
private transient volatile int sizeCtl;
```

这里面有一个重要的属性sizeCtl,保留了源码的注释及添加了我的理解.

### 数据节点Node类

```java
static class Node<K,V> implements Map.Entry<K,V> {
     final int hash;
     final K key;
     volatile V val;
     volatile Node<K,V> next;
}
```

对于Node类的构造方法以及getter/setter进行了省略.只保留了属性.

可以看到共有四个属性

1. final修饰的hash值,初始化后不能再次改变.
2. final修饰的key,初始化后不能再次改变.
3. <font color="red">volatile 修饰的值</font>
4. <font color="red">volatile 修饰的下一节点指针</font>

hash和key都被final修饰,不会存在线程安全问题,而value及next被volatile修饰,保证了线程间的数据可见性.


### 三个重要的原子方法

```java
//获取数组i位置的node
@SuppressWarnings("unchecked")
static final <K,V> Node<K,V> tabAt(Node<K,V>[] tab, int i) {
    return (Node<K,V>)U.getObjectVolatile(tab, ((long)i << ASHIFT) + ABASE);
}

//cas实现插入
static final <K,V> boolean casTabAt(Node<K,V>[] tab, int i,
                                    Node<K,V> c, Node<K,V> v) {
    return U.compareAndSwapObject(tab, ((long)i << ASHIFT) + ABASE, c, v);
}

//直接插入，此方法仅在上锁的区域被调用
static final <K,V> void setTabAt(Node<K,V>[] tab, int i, Node<K,V> v) {
    U.putObjectVolatile(tab, ((long)i << ASHIFT) + ABASE, v);
}
```

## 构造方法

构造方法十分简单,这里不再贴代码,只是需要注意:

在创建对象的时候没有进行Node数组的初始化,初始化操作在put时进行.

## get()方法

```java
public V get(Object key) {
    Node<K,V>[] tab; Node<K,V> e, p; int n, eh; K ek;
    //获取hash值
    int h = spread(key.hashCode());
    //通过tabat获取hash桶
    if ((tab = table) != null && (n = tab.length) > 0 &&
        (e = tabAt(tab, (n - 1) & h)) != null) {
        //如果该hash桶的第一个节点就是查找结果,则返回
        if ((eh = e.hash) == h) {
            if ((ek = e.key) == key || (ek != null && key.equals(ek)))
                return e.val;
        }
        //第一个节点是树的根节点,按照树的方式进行遍历查找
        else if (eh < 0)
            return (p = e.find(h, key)) != null ? p.val : null;
        //第一个节点是链表的根节点,按照链表的方式遍历查找
        while ((e = e.next) != null) {
            if (e.hash == h &&
                ((ek = e.key) == key || (ek != null && key.equals(ek))))
                return e.val;
        }
    }
    return null;
}
```

可以看到,在get()方法的过程中,是没有进行加锁操作的,那么是如何保证线程安全的呢?

1. 首先通过tabat获取hash桶的根节点
2. 遍历的时候根据node的volatile属性next.
3. 返回时读取node的volatile属性val.

所有的操作属性都是volatile,由该关键字保证内存的可见性,进一步保证读取时的线程安全.

## put()方法

```java
public V put(K key, V value) {
    return putVal(key, value, false);
}

/** Implementation for put and putIfAbsent */
final V putVal(K key, V value, boolean onlyIfAbsent) {
    if (key == null || value == null) throw new NullPointerException();
    //获取hash值
    int hash = spread(key.hashCode());
    int binCount = 0;
    //遍历数组
    for (Node<K,V>[] tab = table;;) {
        Node<K,V> f; int n, i, fh;
        //如果当前数组还未初始化,则进行初始化操作
        if (tab == null || (n = tab.length) == 0)
            tab = initTable();
        //如果已经初始化且要插入的位置为null,则直接使用cas方式进行插入,没有加锁
        else if ((f = tabAt(tab, i = (n - 1) & hash)) == null) {
            if (casTabAt(tab, i, null,
                         new Node<K,V>(hash, key, value, null)))
                break;                   // no lock when adding to empty bin
        }
        //如果当前节点为扩容标识节点,则帮助扩容
        else if ((fh = f.hash) == MOVED)
            tab = helpTransfer(tab, f);
        else {
            //对该hash桶进行加锁
            V oldVal = null;
            synchronized (f) {
                if (tabAt(tab, i) == f) {
                    //链表情况的插入
                    if (fh >= 0) {
                        binCount = 1;
                        for (Node<K,V> e = f;; ++binCount) {
                            K ek;
                            if (e.hash == hash &&
                                ((ek = e.key) == key ||
                                 (ek != null && key.equals(ek)))) {
                                oldVal = e.val;
                                if (!onlyIfAbsent)
                                    e.val = value;
                                break;
                            }
                            Node<K,V> pred = e;
                            if ((e = e.next) == null) {
                                pred.next = new Node<K,V>(hash, key,
                                                          value, null);
                                break;
                            }
                        }
                    }
                    //红黑树的插入
                    else if (f instanceof TreeBin) {
                        Node<K,V> p;
                        binCount = 2;
                        if ((p = ((TreeBin<K,V>)f).putTreeVal(hash, key,
                                                       value)) != null) {
                            oldVal = p.val;
                            if (!onlyIfAbsent)
                                p.val = value;
                        }
                    }
                }
            }
            //检查长度是否超过阀值,如果超过则由链表转成红黑树
            if (binCount != 0) {
                if (binCount >= TREEIFY_THRESHOLD)
                    treeifyBin(tab, i);
                if (oldVal != null)
                    return oldVal;
                break;
            }
        }
    }
    //size属性加1,如果过长则扩容
    addCount(1L, binCount);
    return null;
}
```

put方法中的流程:

1. 获取hash值
2. 遍历数组
3. 如果未初始化则初始化
4. 如果要插入的位置为null,则使用cas插入,不加锁
5. 如果要插入的位置为扩容标识节点,则帮助其扩容
6. 对插入的hash桶加锁
7. 按照红黑树或者链表的方式进行插入
8. 检查插入后链表长度是否超过阀值,如果超过则转为红黑树
9. 添加计数,如果添加后的数量大于扩容阀值,则进行扩容.

## remove()方法

```java
public V remove(Object key) {
        return replaceNode(key, null, null);
    }

    /**

       参数value:当 value==null 时 ，删除节点 。否则 更新节点的值为value

       参数cv:一个期望值， 当 map[key].value 等于期望值cv  或者 cv==null的时候 ，删除节点，或者更新节点的值
    */
    final V replaceNode(Object key, V value, Object cv) {
        int hash = spread(key.hashCode());
        for (Node<K,V>[] tab = table;;) {
            Node<K,V> f; int n, i, fh;
            //table还没有初始化或者key对应的hash桶为空
            if (tab == null || (n = tab.length) == 0 ||
                (f = tabAt(tab, i = (n - 1) & hash)) == null)
                break;
            //正在扩容
            else if ((fh = f.hash) == MOVED)
                tab = helpTransfer(tab, f);
            else {
                V oldVal = null;
                boolean validated = false;
                synchronized (f) {
                    //cas获取tab[i],如果此时tab[i]!=f,说明其他线程修改了tab[i]。回到for循环开始处，重新执行
                    if (tabAt(tab, i) == f) {
                        //node链表
                        if (fh >= 0) {
                            validated = true;
                            for (Node<K,V> e = f, pred = null;;) {
                                K ek;
                                //找的key对应的node
                                if (e.hash == hash &&
                                    ((ek = e.key) == key ||
                                     (ek != null && key.equals(ek)))) {
                                    V ev = e.val;
                                    //cv参数代表期望值
                                    //cv==null:表示直接更新value/删除节点
                                    //cv不为空，则只有在key的oldValue等于期望值的时候，才更新value/删除节点

                                    //符合更新value或者删除节点的条件
                                    if (cv == null || cv == ev ||
                                        (ev != null && cv.equals(ev))) {
                                        oldVal = ev;
                                        //更新value
                                        if (value != null)
                                            e.val = value;
                                        //删除非头节点
                                        else if (pred != null)
                                            pred.next = e.next;
                                        //删除头节点
                                        else
                                            //因为已经获取了头结点锁，所以此时不需要使用casTabAt
                                            setTabAt(tab, i, e.next);
                                    }
                                    break;
                                }
                                //当前节点不是目标节点，继续遍历下一个节点
                                pred = e;
                                if ((e = e.next) == null)
                                    //到达链表尾部，依旧没有找到，跳出循环
                                    break;
                            }
                        }
                        //红黑树
                        else if (f instanceof TreeBin) {
                            validated = true;
                            TreeBin<K,V> t = (TreeBin<K,V>)f;
                            TreeNode<K,V> r, p;
                            if ((r = t.root) != null &&
                                (p = r.findTreeNode(hash, key, null)) != null) {
                                V pv = p.val;
                                if (cv == null || cv == pv ||
                                    (pv != null && cv.equals(pv))) {
                                    oldVal = pv;
                                    if (value != null)
                                        p.val = value;
                                    else if (t.removeTreeNode(p))
                                        setTabAt(tab, i, untreeify(t.first));
                                }
                            }
                        }
                    }
                }
                if (validated) {
                    if (oldVal != null) {
                        //如果删除了节点，更新size
                        if (value == null)
                            addCount(-1L, -1);
                        return oldVal;
                    }
                    break;
                }
            }
        }
        return null;
    }
```

remove方法中流程:

1. 获取hash值
2. 如果未初始化或者该hash值对应的hash桶为空,则直接返回
3. 如果正在扩容则帮助扩容
4. 对该hash桶加锁
5. 遍历该hash桶处的链表或者红黑树,更新或者删除节点.


## 后话

本文记录了ConcurrentHashMap的基本原理及几个常用方法的实现,但由于才疏学浅以及ConcurrentHashMap的复杂性,文中可能会有些许疏漏,如有错误欢迎随时指出.

对于ConcurrentHashMap,建议还是先学会使用,在有一定的并发基础后再学习源码,至少要了解volatile及synchronized关键字的实现机制以及JMM(java内存模型)的一些基础知识.否则学习起来十分费劲(我看了好久,,),并且囫囵吞枣,学习之后收获也不一定很大.




# 参考链接
https://www.jianshu.com/p/cf5e024d9432
https://blog.csdn.net/u010723709/article/details/48007881
https://www.jianshu.com/p/5bc70d9e5410



<br>
完。

<br>
<br>
<br>
<br>
<h4>ChangeLog</h4>
2018-11-18 完成
<br>
<br>

**以上皆为个人所思所得，如有错误欢迎评论区指正。**

**欢迎转载，烦请署名并保留原文链接。**

**联系邮箱：huyanshi2580@gmail.com**

**更多学习笔记见个人博客------><a href="{{ site.baseurl }}/">呼延十</a>**
