---
layout: post
tags:
  - Java
  - 源码阅读
  - Java集合
---

## 前言
天天都在用Java集合,也偶尔用到了`Collections`类中的一些方法,但是一直没有对这个工具类进行一个较为系统的学习,今天放假比较无聊,闲来看一看.并且记录一下API.

5500多行的代码,,这个工具类是真的大,希望可以发现一些好用且常用的工具方法.

大部分API会在API记录部分写一下,少部分需要额外补充说明的,在`某些特殊说明`中单独记录.

## API记录

编号 | 方法 | 作用 | 备注
---  | ---  | ---  | ---
1 | `public static <T extends Comparable<? super T>> void sort(List<T> list)` | 对传入的list进行排序 | 使用该元素自己的Comparable
2 | `public static <T> void sort(List<T> list, Comparator<? super T> c) ` | 使用指定的Comparable进行排序 |
3 | `public static <T>  int binarySearch(List<? extends Comparable<? super T>> list, T key)` | 在给定的list里面找key,使用二分查找算法.
4 | `public static <T> int binarySearch(List<? extends T> list, T key, Comparator<? super T> c)` | 上一个方法的指定Comparable版本.
5 | `public static void reverse(List<?> list)`  | 翻转list中元素的顺序 |
6 | `public static void shuffle(List<?> list, Random rnd)` | 随机打乱list中的元素顺序 
7 | `public static void swap(List<?> list, int i, int j)` | 交换list在两个下标上的元素 | 所以我们日常的swap其实不用自己写的
8 | `public static <T> void fill(List<? super T> list, T obj)` | 用给定的元素将list的全部元素替换掉.
9 | `public static <T> void copy(List<? super T> dest, List<? extends T> src)` | 拷贝列表 
10 | `public static <T extends Object & Comparable<? super T>> T min(Collection<? extends T> coll) ` | 返回集合中最小的元素 | 当然他也有指定Comparable的版本.不贴了.
11 | `public static <T extends Object & Comparable<? super T>> T max(Collection<? extends T> coll)` | 返回集合中最大的元素 | 当然也有咯.
12 | `public static void rotate(List<?> list, int distance)` | 回转当前列表 | 回转的定义:之前是1,2,3,以1回转之后就是3,1,2.以2回转就是,2,3,1.
13 | `public static <T> boolean replaceAll(List<T> list, T oldVal, T newVal)` | 批量用新值替换当前列表中的某一个值
14 | `public static int indexOfSubList(List<?> source, List<?> target)` | 返回target集合在source列表中的index,如果target不是source的子列表,返回-1;
15 | `public static int lastIndexOfSubList(List<?> source, List<?> target)` | 返回最后出现的index,比如1,2,3,2,target=2,返回3.
16 | `public static <T> Collection<T> unmodifiableCollection(Collection<? extends T> c)` | 返回一个不可变的视图 | 封装了一下,重写了所有可能修改集合的方法,抛出异常
17 | `public static <T> Set<T> unmodifiableSet(Set<? extends T> s)` | 不可变的set | 接下来是几个set的变种,sortedset之类的.
18 | `public static <T> List<T> unmodifiableList(List<? extends T> list)` | 不可变的list.
19 | `public static <K,V> Map<K,V> unmodifiableMap(Map<? extends K, ? extends V> m)` | 不可变的Map
20 | `public static <T> Collection<T> synchronizedCollection(Collection<T> c) ` | 强行是用synchronized同步的集合类| 返回的也是封装,重写之后的类,接下来和上面不可变一样,是list,map,set及其变种.
21 | `c static <E> Collection<E> checkedCollection(Collection<E> c, Class<E> type)`  | 一堆进行了类型检查的集合类 | 也有map等等变种.
22 | `public static <T> Iterator<T> emptyIterator()` | 返回一个空的迭代器 | 接下来有许多空的list,set,map等等.
23 | `public static <T> Set<T> singleton(T o)` | 返回只有一个元素的set.
24 | `public static <T> List<T> singletonList(T o)` | 返回只有一个元素的List.
25 | `public static <K,V> Map<K,V> singletonMap(K key, V value)` | 返回只有一个元素的Map.
26 | `public static <T> Enumeration<T> enumeration(final Collection<T> c)` | 返回当前集合的枚举
27 | `public static <T> ArrayList<T> list(Enumeration<T> e)` | 从枚举返回ArrayList.
28 | `public static int frequency(Collection<?> c, Object o)` | 返回输入对象在集合中的出现次数.
29 | `public static boolean disjoint(Collection<?> c1, Collection<?> c2)` | 返回两个集合是都有交集 | 有交集返回false,没有返回true.
30 | `public static <T> boolean addAll(Collection<? super T> c, T... elements)` | 将给定的元素全部添加到给定集合中 | 集合本身可以添加全部,但是必须要求也是集合参数,比如你有两个独立的元素,就可以直接使用这个类而不是用两个元素构造一个集合,然后调用集合本身的addall.
31 | `public static <E> Set<E> newSetFromMap(Map<E, Boolean> map)` | 返回当前map的keyset. | set持有原来的map的引用.
32 | `public static <T> Queue<T> asLifoQueue(Deque<T> deque)` | 将一个deque转换为队列,并且是LIFO(后进先出).






<br>
<br>
<br>
<br>
<h4>ChangeLog</h4>
2019-05-01 完成
<br>
<br>


**以上皆为个人所思所得，如有错误欢迎评论区指正。**

**欢迎转载，烦请署名并保留原文链接。**

**联系邮箱：huyanshi2580@gmail.com**

**更多学习笔记见个人博客------><a href="{{ site.baseurl }}/">呼延十</a>**
