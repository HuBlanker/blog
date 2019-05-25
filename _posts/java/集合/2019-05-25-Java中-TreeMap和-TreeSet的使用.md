---
layout: post
category: [Java,数据结构,Java集合]
tags:
  - Java
  - 数据结构
  - Java集合
---

## 目录

- [目录](#目录)
- [前言](#前言)
- [红黑树](#红黑树)
- [TreeMap](#treemap)
- [TreeSet](#treeset)
- [参考文章](#参考文章)


## 前言

首先要注意的是,本文章不涉及到红黑树的具体实现,也就是说不会逐行分析`TreeMap`和`TreeSet`的源码实现,因为红黑树看了也会忘的...

所以本文只是记录红黑树的一些基础介绍,以及`TreeMap`和`TreeSet`两个类的公共API.

-------

## 红黑树

>红黑树，一种二叉查找树，但在每个结点上增加一个存储位表示结点的颜色，可以是Red或Black。
通过对任何一条从根到叶子的路径上各个结点着色方式的限制，红黑树确保没有一条路径会比其他路径长出俩倍，因而是接近平衡的。

红黑树首先是一颗二叉查找树,满足二叉查找树的一下特点:

1. 若任意节点的左子树不空，则左子树上所有节点的值均小于它的根节点的值；
2. 若任意节点的右子树不空，则右子树上所有节点的值均大于它的根节点的值；
3. 任意节点的左、右子树也分别为二叉查找树；
4. 没有键值相等的节点。


红黑树在二叉查找树的基础上又有以下性质:

1. 每个结点要么是红的要么是黑的。  
2. 根结点是黑的。  
3. 每个叶结点（叶结点即指树尾端NIL指针或NULL结点）都是黑的。  
4. 如果一个结点是红的，那么它的两个儿子都是黑的。  
5. 对于任意结点而言，其到叶结点树尾端NIL指针的每条路径都包含相同数目的黑结点。 

通过这5个性质,可以保证红黑树的高度永远是`logn`,所以红黑树的查找、插入、删除的时间复杂度最坏为O(log n).

红黑树有什么作用呢?那就是快,查找,插入,删除的时间复杂度最坏为O(logn).

红黑树的具体实现可以google一下,有很多开源的实现.中心思想就是各种旋转~.

## TreeMap

TreeMap是一个有序的key-value集合,基于红黑树（Red-Black tree）实现。该映射根据其键的自然顺序进行排序，或者根据创建映射时提供的 Comparator 进行排序，具体取决于使用的构造方法。

具体的使用方法见下方API极其注释(常用的没有注释).

```
// 返回(大于等输入key)的最小的key/entry,不存在返回null
Entry<K, V>                ceilingEntry(K key)
K                          ceilingKey(K key)
void                       clear()
Object                     clone()
// 返回comparator
Comparator<? super K>      comparator()
boolean                    containsKey(Object key)
// 降序返回key/map
NavigableSet<K>            descendingKeySet()
NavigableMap<K, V>         descendingMap()
Set<Entry<K, V>>           entrySet()
// 返回第一个key/entry
Entry<K, V>                firstEntry()
K                          firstKey()
// 返回(小于等于输入key)的最大的key/entry,不存在返回null
Entry<K, V>                floorEntry(K key)
K                          floorKey(K key)
V                          get(Object key)
// 返回优先级高于指定k的部分map,inclusive为是否包含当前key
NavigableMap<K, V>         headMap(K to, boolean inclusive)
SortedMap<K, V>            headMap(K toExclusive)
// 返回大于给定key的第一个节点
Entry<K, V>                higherEntry(K key)
K                          higherKey(K key)
boolean                    isEmpty()
Set<K>                     keySet()
// 最后一个key/entry
Entry<K, V>                lastEntry()
K                          lastKey()
// 返回小于给定key的第一个节点
Entry<K, V>                lowerEntry(K key)
K                          lowerKey(K key)
// 返回NavigableSet,可以导航..有low/high等方法
NavigableSet<K>            navigableKeySet()
// 弹出第一个key/entry
Entry<K, V>                pollFirstEntry()
Entry<K, V>                pollLastEntry()
V                          put(K key, V value)
V                          remove(Object key)
int                        size()
SortedMap<K, V>            subMap(K fromInclusive, K toExclusive)
NavigableMap<K, V>         subMap(K from, boolean fromInclusive, K to, boolean toInclusive)
// 返回尾部map,小于给定k,inclusive为控制是否包含
NavigableMap<K, V>         tailMap(K from, boolean inclusive)
SortedMap<K, V>            tailMap(K fromInclusive)
```



## TreeSet

TreeSet是基于TreeMap实现的。TreeSet中的元素支持2种排序方式：自然排序 或者 根据创建TreeSet 时提供的 Comparator 进行排序。这取决于使用的构造方法。

因为他是基于TreeMap实现的,所以其实也是基于红黑树,其基本操作（add、remove 和 contains等）都是O(logn)的时间复杂度.

API如下:

```
boolean                   add(E object)
boolean                   addAll(Collection<? extends E> collection)
void                      clear()
Object                    clone()
boolean                   contains(Object object)
// 返回第一个/最后一个元素
E                         first()
E                         last()
boolean                   isEmpty()
// 弹出第一个或者最后一个元素
E                         pollFirst()
E                         pollLast()
// 返回大于/小于给定元素的元素
E                         higher(E e)
E                         lower(E e)
// 返回小于/大于给定元素的最大/最小的一个
E                         floor(E e)
E                         ceiling(E e)
boolean                   remove(Object object)
int                       size()
Comparator<? super E>     comparator()
Iterator<E>               iterator()
// 降序遍历
Iterator<E>               descendingIterator()
// 返回大于/小于给定元素的所有元素集合,endInclusive为是否包含的控制量
SortedSet<E>              headSet(E end)
NavigableSet<E>           headSet(E end, boolean endInclusive)
SortedSet<E>              tailSet(E start)
NavigableSet<E>           tailSet(E start, boolean startInclusive)
// 降序的set
NavigableSet<E>           descendingSet()
// 子集合
SortedSet<E>              subSet(E start, E end)
NavigableSet<E>           subSet(E start, boolean startInclusive, E end, boolean endInclusive)
```

## 参考文章

https://zh.wikipedia.org/wiki/%E7%BA%A2%E9%BB%91%E6%A0%91



<br>
完。
<br>
<br>
<br>
<br>
<h4>ChangeLog</h4>
2019-05-25 完成
<br>
<br>
**以上皆为个人所思所得，如有错误欢迎评论区指正。**


**欢迎转载，烦请署名并保留原文链接。**


**联系邮箱：huyanshi2580@gmail.com**


**更多学习笔记见个人博客------><a href="{{ site.baseurl }}/">呼延十</a>**