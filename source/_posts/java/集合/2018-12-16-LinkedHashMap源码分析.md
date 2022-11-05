---
layout: post
tags:
  - Java
  - Java面试
  - Java集合
  - 源码阅读
---

<font color="red">LInkedHashMap是基于HashMap的,因此如果不太清楚HashMap的实现的话,请先阅读<a href="{{ site.baseurl }}/源码阅读/java/2018/10/16/HashMap源码阅读/">HashMap 源码阅读 </a></font>

<br/>
<br/>
我们都知道,HashMap 是无序的,也就是说,遍历时候的顺序与访问的顺序无关.

而在一些场景下,我们即需要HashMap的特性,又需要它能够保持一定的顺序呢?

JAVA 在 JDK1.4 以后提供了 LinkedHashMap 来帮助我们实现了有序的 HashMap！

LinkedHashMap可以有两种保存的顺序:插入顺序及访问顺序.

在如下的代码中,我们以`1,2,4,3`的顺序分别向`HashMap`,`插入顺序的LinkedHashMap`,`访问顺序的LinkedHashMap`中插入四条数据,并在`访问顺序的LinkedHashMap`中按照`4231`的顺序访问元素.

代码如下:

```java
public void linkedHashMapTest() {
  Map<String, Integer> test = new LinkedHashMap<>();
  test.put("1", 1);
  test.put("2", 2);
  test.put("4", 4);
  test.put("3", 3);
  System.out.println();
  System.out.print("LinkedHashMap:");
  test.forEach((key, value) -> System.out.print(value));

  //hashmap
  Map<String, Integer> test1 = new HashMap<>();
  test1.put("1", 1);
  test1.put("2", 2);
  test1.put("4", 4);
  test1.put("3", 3);
  System.out.println();
  System.out.print("HashMap:");
  test1.forEach((key, value) -> System.out.print(value));

  //linkedHashMap 按照访问顺序
  Map<String, Integer> test2 = new LinkedHashMap<>(16,0.75f,true);
  test2.put("1", 1);
  test2.put("2", 2);
  test2.put("4", 4);
  test2.put("3", 3);

  test2.get("4");
  test2.get("2");
  test2.get("3");
  test2.get("1");
  System.out.println();
  System.out.print("linkedHashMap ---with use:");
  test2.forEach((key, value) -> System.out.print(value));
}
```
输出结果如下:

```
LinkedHashMap:1243
HashMap:1234
linkedHashMap ---with use:4231
```


可以看到,HashMap是无序的,遍历结果的顺序和插入顺序无关,是`key`值的自然排序,而LinkedHashMap的顺序是插入顺序或者访问顺序.

## LInkedHashMap怎么保存顺序的?

在HashMap的基础上,对每个节点添加指向上一个元素和下一个元素的"指针",这样在数据的保存时,仍使用HashMap的原理.同时,添加向前向后指针,使得所有的节点形成双向链表,在遍历时使用双向链表遍历,保证顺序.

## 源码阅读

下面将通过阅读LinkedHashMap的源码来学习使用这个类.

### 类的定义

```java
public class LinkedHashMap<K,V>
    extends HashMap<K,V>
    implements Map<K,V>{

    }
```

LinkedHashMap集成了HashMap类以及实现了Map接口,那么LinkedHashMap作为HashMap的子类,天然集成了HashMap的所有方法,也拥有了HashMap的一切特性.

### 类的成员

```java
/**
 * The head (eldest) of the doubly linked list.
 */
transient LinkedHashMap.Entry<K,V> head;

/**
 * The tail (youngest) of the doubly linked list.
 */
transient LinkedHashMap.Entry<K,V> tail;

/**
 * The iteration ordering method for this linked hash map: <tt>true</tt>
 * for access-order, <tt>false</tt> for insertion-order.
 *
 * @serial
 */
final boolean accessOrder;
```

LInkedHashMap新增了三个成员变量,首先是双链表的头部节点和尾部节点.然后是一个标识位,标识此LinkedHashMap使用插入顺序还是访问顺序.
那么`LinkedHashMap.Entry`是什么呢?

```java
static class Entry<K,V> extends HashMap.Node<K,V> {
    Entry<K,V> before, after;
    Entry(int hash, K key, V value, Node<K,V> next) {
        super(hash, key, value, next);
    }
}
```

**他继承自HashMap的内部类Node,之后又添加了指向上一节点的before和指向下一节点的after,这样就形成了双向链表,用来记录元素的顺序.**

### 构造方法

![](http://img.couplecoders.tech/markdown-img-paste-20181216184342333.png)

LinkedHashMap的构造方法共有5个,除了最后一个,其他的在内部实现都是调用了`父类HashMap`对应的构造方法,并将标识位`accessOrder`置为false.(默认值即false).在最后一个构造方法中,将`accessOrder`置为参数传入的值.

### get()方法

```java
public V get(Object key) {
    Node<K,V> e;
    if ((e = getNode(hash(key), key)) == null)
        return null;
    if (accessOrder)
        afterNodeAccess(e);
    return e.value;
}

void afterNodeAccess(Node<K,V> e) { // move node to last
    LinkedHashMap.Entry<K,V> last;
    if (accessOrder && (last = tail) != e) {
        LinkedHashMap.Entry<K,V> p =
            (LinkedHashMap.Entry<K,V>)e, b = p.before, a = p.after;
        p.after = null;
        if (b == null)
            head = a;
        else
            b.after = a;
        if (a != null)
            a.before = b;
        else
            last = b;
        if (last == null)
            head = p;
        else {
            p.before = last;
            last.after = p;
        }
        tail = p;
        ++modCount;
    }
}
```

LinkedHashMap对get方法进行了重写,具体流程为:
1. 调用父类HashMap的的getNode()方法,如果结果值为空,则返回空.
2. 如果`accessOrder`为true,则调用`afterNodeAccess()`方法将当前访问的元素移动到链表的末尾.(当初始化为访问顺序的LinkedHashMap时,才会执行此操作.)
3. 如果`accessOrder`为false,返回`getNode()`获得的值.

### put()方法

```java
Node<K,V> newNode(int hash, K key, V value, Node<K,V> e) {
    LinkedHashMap.Entry<K,V> p =
        new LinkedHashMap.Entry<K,V>(hash, key, value, e);
    linkNodeLast(p);
    return p;
}

private void linkNodeLast(LinkedHashMap.Entry<K,V> p) {
    LinkedHashMap.Entry<K,V> last = tail;
    tail = p;
    if (last == null)
        head = p;
    else {
        p.before = last;
        last.after = p;
    }
}
```

LInkedHashMap并没有重写`put()`方法,但是重写了put()方法中会调用的newNode()方法,代码如上面所示.

在重写后的`newNode()`方法中,调用父类的构造方法新建一个节点后,调用`linkNodeLast()`方法,将新插入的节点链接在双链表的尾部.

### remove()方法

```java
void afterNodeRemoval(Node<K,V> e) { // unlink
    LinkedHashMap.Entry<K,V> p =
        (LinkedHashMap.Entry<K,V>)e, b = p.before, a = p.after;
    p.before = p.after = null;
    if (b == null)
        head = a;
    else
        b.after = a;
    if (a == null)
        tail = b;
    else
        a.before = b;
}
```

LinkedHashMap也没有重写`remove()`方法,但是对remove方法中`removeNode()`方法中调用的回调函数**afterNodeRemoval**进行了重写.

在按照HashMap的方式删除节点后,将该节点同步的从双链表中移除掉.

### containsVaule()方法

```java
public boolean containsValue(Object value) {
    for (LinkedHashMap.Entry<K,V> e = head; e != null; e = e.after) {
        V v = e.value;
        if (v == value || (value != null && value.equals(v)))
            return true;
    }
    return false;
}
```

想必与`HashMap`,LinkedHashMap重写后的`containsVaule()`更为高效一些,直接在双链表中进行遍历判断是否存在value相等的值.

## forEach

```java
public void forEach(BiConsumer<? super K, ? super V> action) {
    if (action == null)
        throw new NullPointerException();
    int mc = modCount;
    for (LinkedHashMap.Entry<K,V> e = head; e != null; e = e.after)
        action.accept(e.key, e.value);
    if (modCount != mc)
        throw new ConcurrentModificationException();
}
```

LinkedHashMap的遍历方式上面的代码所示:

直接从双链表的头部开始遍历,逐个输出即可.

## 总结

在读懂了HashMap的源码后,LinkedHashMap会显得比较简单,因为他的大多数操作都是在HashMap的基础上完成的.

LinkedHashMap有几个比较关键的问题如下:

#### 1.如何实现的元素有序?

在HashMap的基础上,对每一个节点添加向前向后指针,这样所有的节点形成了双向链表,自然就是有序的.


#### 2.如何保证顺序的正确以及同步

通过重写的一些关键的方法,在元素发生`增删改查`等行为时,除了在Hash桶上进行操作,也对链表进行相应的更新,以此来保证顺序的正确.

#### 3.如何实现两种顺序(插入顺序或者访问顺序)?

通过内部的标识位`accessOrder`来记录当前LinkedHashMap是以什么为序,之后再处理元素时通过读取`accessOrder`的值来控制链表的顺序.

#### 4.为什么重写`containsValue()`而不重写`containsKey()`?

可以看一下他们分别是怎么实现的,就知道原因了.

在HashMap中:

```java
public boolean containsValue(Object value) {
    Node<K,V>[] tab; V v;
    if ((tab = table) != null && size > 0) {
        for (int i = 0; i < tab.length; ++i) {
            for (Node<K,V> e = tab[i]; e != null; e = e.next) {
                if ((v = e.value) == value ||
                    (value != null && value.equals(v)))
                    return true;
            }
        }
    }
    return false;
}

public boolean containsKey(Object key) {
    return getNode(hash(key), key) != null;
}
```

containsKey()是通过hash值直接计算出该key对应的数组下标,之后在该hash桶的链表上进行查找相同的key.

containsValue()是对table进行遍历,对其中的每一个hash桶的所有值进行遍历,去寻找相同的value.

而在LinkedHashMap中,如果都改为对双向链表的遍历来寻找key和value.

无疑在value的查找时会有性能的提升,而对于key的查找则更为低效了.

如果改为遍历双向链表进行查找key值,则从`key->hash->index`的方法退化到逐一遍历,丧失了HashMap的最大特性.


<br>
完。

<br>
<br>
<br>
<br>
<h4>ChangeLog</h4>
2018-12-16 完成
<br>
<br>

**以上皆为个人所思所得，如有错误欢迎评论区指正。**

**欢迎转载，烦请署名并保留原文链接。**

**联系邮箱：huyanshi2580@gmail.com**

**更多学习笔记见个人博客------><a href="{{ site.baseurl }}/">呼延十</a>**
