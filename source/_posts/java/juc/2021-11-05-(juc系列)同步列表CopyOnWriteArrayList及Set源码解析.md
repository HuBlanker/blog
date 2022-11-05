---
layout: post
tags:
  - Java
  - JUC
  - CopyOnWriteArrayList
  - CopyOnWriteArraySet
---

本文源码基于: <font color='red'>JDK13</font>

## CopyOnWriteArrayList

### 官方注释翻译

`ArrayList`的一个线程安全的变体，所有可变的操作(比如add/set等)都使用底层数组的一个拷贝.

这经常是非常昂贵的，但是在便利操作远远大于更该操作的情况下更加高效. 如果你不想或者不能进行同步遍历， 那么这个类就有用了.

快照风格的遍历器，使用一个当遍历器创建时，对数组状态的一个引用.  这个引用在遍历的生命周期里是不会改变的。 因此没有干扰且迭代器不会抛出`ConcurrentModificationException`.

从迭代器创建之后，所有的添加移除等更改操作都不会反映出来. 迭代器不支持元素的更改操作，这些方法都抛出异常.

所有的元素都支持，包括null.

### 源码

#### 定义

```java

public class CopyOnWriteArrayList<E>
implements List<E>, RandomAccess, Cloneable, java.io.Serializable {
private static final long serialVersionUID = 8673264195747942595L;

```

一个列表.

#### 属性

```java

    final transient Object lock = new Object();

    private transient volatile Object[] array;
```

一个`lock`用来对数组加锁，一个实际保存数据的数组.

为什么使用内置锁而不是`ReentrantLock`呢？

注释中说：如果两者都可以，我们更加偏好(温和的偏好)内置锁。

#### 构造方法


```java

    public CopyOnWriteArrayList() {
        setArray(new Object[0]);
    }

    public CopyOnWriteArrayList(Collection<? extends E> c) {
        Object[] es;
        if (c.getClass() == CopyOnWriteArrayList.class)
            es = ((CopyOnWriteArrayList<?>)c).getArray();
        else {
            es = c.toArray();
            // defend against c.toArray (incorrectly) not returning Object[]
            // (see e.g. https://bugs.openjdk.java.net/browse/JDK-6260652)
            if (es.getClass() != Object[].class)
                es = Arrays.copyOf(es, es.length, Object[].class);
        }
        setArray(es);
    }

    public CopyOnWriteArrayList(E[] toCopyIn) {
        setArray(Arrays.copyOf(toCopyIn, toCopyIn.length, Object[].class));
    }
```

三个构造方法，分别创建

* 空的列表
* 根据已有集合创建列表
* 根据已有数组创建列表


#### add 方法


作为一个列表，重要的接口就是那几个，添加，删除，获取，遍历. 首先来看一下添加.


```java
    public boolean add(E e) {
        // 加锁
        synchronized (lock) {
            // 获取数组
            Object[] es = getArray();
            int len = es.length;
            // 数组拷贝
            es = Arrays.copyOf(es, len + 1);
            // 新的元素放置在最后
            es[len] = e;
            // 数组放回去
            setArray(es);
            return true;
        }
    }
```

这个`add`逻辑并不难，简单看下注释即可，重点是，这种全量的数组拷贝，看起来性能就很一般.

**添加到指定位置**

```java

    public void add(int index, E element) {
        // 加锁
        synchronized (lock) {
            Object[] es = getArray();
            int len = es.length;
            // 参数检查
            if (index > len || index < 0)
                throw new IndexOutOfBoundsException(outOfBounds(index, len));
            Object[] newElements;
            // 需要移动的元素
            int numMoved = len - index;
            if (numMoved == 0)
                // 没有需要移动的，直接拷贝
                newElements = Arrays.copyOf(es, len + 1);
            else {
                // 拷贝部分
                newElements = new Object[len + 1];
                System.arraycopy(es, 0, newElements, 0, index);
                System.arraycopy(es, index, newElements, index + 1,
                                 numMoved);
            }
            // 指定位置放置元素
            newElements[index] = element;
            // 放回数组
            setArray(newElements);
        }
    }
```

没什么说的，直接加锁，然后计算一下需要移动的元素，数组拷贝即可.

#### get 方法

```java

    public E get(int index) {
        return elementAt(getArray(), index);
    }

    static <E> E elementAt(Object[] a, int index) {
        return (E) a[index];
    }

```

由于使用数组保存数据，因此索引操作比较简单，直接获取数组对应的下标即可.


#### remove 方法

* 根据下标移除

```java

    public E remove(int index) {
        // 加锁
        synchronized (lock) {
            Object[] es = getArray();
            int len = es.length;
            // 找到该元素
            E oldValue = elementAt(es, index);
            // 计算需要移动的数据
            int numMoved = len - index - 1;
            Object[] newElements;
            // 拷贝
            if (numMoved == 0)
                newElements = Arrays.copyOf(es, len - 1);
            else {
                newElements = new Object[len - 1];
                System.arraycopy(es, 0, newElements, 0, index);
                System.arraycopy(es, index + 1, newElements, index,
                                 numMoved);
            }
            // 设置新数组
            setArray(newElements);
            return oldValue;
        }
    }

```

直接加锁，然后根据指定的下标，进行元素拷贝，将该位置空出来.

* 根据元素移除

```java

    public boolean remove(Object o) {
        Object[] snapshot = getArray();
        int index = indexOfRange(o, snapshot, 0, snapshot.length);
        return index >= 0 && remove(o, snapshot, index);
    }
```

首先根据元素，找到对应的下标，之后调用上面的`根据下标移除元素`即可.


#### 迭代器

```java

    public Iterator<E> iterator() {
        return new COWIterator<E>(getArray(), 0);
    }
```

在调用获取迭代器的一瞬间，将内部的数组获取一份，构造新的迭代器.

看一下这个迭代器的实现.

```java
    static final class COWIterator<E> implements ListIterator<E> {
        // 数据的快照及遍历的指针
        private final Object[] snapshot;
        private int cursor;

        COWIterator(Object[] es, int initialCursor) {
            cursor = initialCursor;
            snapshot = es;
        }

        // 是否有下一个
        public boolean hasNext() {
            return cursor < snapshot.length;
        }

        // 是否有前一个
        public boolean hasPrevious() {
            return cursor > 0;
        }

        // 获取下一个，移动指针即可
        @SuppressWarnings("unchecked")
        public E next() {
            if (! hasNext())
                throw new NoSuchElementException();
            return (E) snapshot[cursor++];
        }

        @SuppressWarnings("unchecked")
        public E previous() {
            if (! hasPrevious())
                throw new NoSuchElementException();
            return (E) snapshot[--cursor];
        }

        public int nextIndex() {
            return cursor;
        }

        public int previousIndex() {
            return cursor - 1;
        }

        /**
         * Not supported. Always throws UnsupportedOperationException.
         * @throws UnsupportedOperationException always; {@code remove}
         *         is not supported by this iterator.
         */
        public void remove() {
            throw new UnsupportedOperationException();
        }

        /**
         * Not supported. Always throws UnsupportedOperationException.
         * @throws UnsupportedOperationException always; {@code set}
         *         is not supported by this iterator.
         */
        public void set(E e) {
            throw new UnsupportedOperationException();
        }

        /**
         * Not supported. Always throws UnsupportedOperationException.
         * @throws UnsupportedOperationException always; {@code add}
         *         is not supported by this iterator.
         */
        public void add(E e) {
            throw new UnsupportedOperationException();
        }

        @Override
        public void forEachRemaining(Consumer<? super E> action) {
            Objects.requireNonNull(action);
            final int size = snapshot.length;
            int i = cursor;
            cursor = size;
            for (; i < size; i++)
                action.accept(elementAt(snapshot, i));
        }
    }

```

保存了一份数组的快照，以及移动的指针。需要注意的是，不支持所有的更改操作.

每一个调用`next`，指针向后移动即可.


#### 总结

`CopyOnWriteArrayList`使用数组保存数据，内部使用`synchronized`进行同步.

1. 由于每次更改元素，都需要加锁，然后对数组进行全量的拷贝，因此可以预见，元素的添加移除等效率都一般.
2. 遍历时，在调用迭代器的瞬间，对当前的数组进行快照，之后访问的全是这个快照，所有之间的更改操作不可见，迭代器也不支持元素的更改.


适用于读多写少的并发场景. 


## CopyOnWriteArraySet

### 官方注释翻译

一个使用`CopyOnWriteArrayList`来进行所有操作的`Set`。因此，它和`CopyOnWriteArrayList`共享下面这些属性:

* 最试用与读多写少的应用场景，并且你需要减少遍历期间线程之间的干扰.
* 线程安全
* 更改操作都比较耗时，因为他们通常拷贝了内部的整个底层数组.
* 遍历器不支持所有的更改操作
* 使用遍历器进行遍历操作，很快但是不能表现出其他线程的干扰, 迭代器依赖于不可更改的数组快照.

简单的使用实例:


```java

class Handler { void handle(); ... }

class X {
    private final CopyOnWriteArraySet<Handler> handlers
        = new CopyOnWriteArraySet<>();
    public void addHandler(Handler h) { handlers.add(h); }

    private long internalState;
    private synchronized void changeState() { internalState = ...; }

    public void update() {
        changeState();
        for (Handler handler : handlers)
            handler.handle();
    }
}
```

用`CopyOnWriteArraySet`来保存了一系列的处理器，当状态变更时需要响应变更.

### 源码

#### 定义

```java

public class CopyOnWriteArraySet<E> extends AbstractSet<E>
implements java.io.Serializable {
```

一句废话: 实现了基础的Set接口.


#### 属性

```java

    private final CopyOnWriteArrayList<E> al;

```

前面已经说过，内部使用`CopyOnWriteArrayLis`来实现，因此属性很简单，只保存了真实存储数据的`CopyOnWriteArrayLis`.


#### 构造方法
```java

    public CopyOnWriteArraySet() {
        al = new CopyOnWriteArrayList<E>();
    }

    public CopyOnWriteArraySet(Collection<? extends E> c) {
        if (c.getClass() == CopyOnWriteArraySet.class) {
            @SuppressWarnings("unchecked") CopyOnWriteArraySet<E> cc =
                (CopyOnWriteArraySet<E>)c;
            al = new CopyOnWriteArrayList<E>(cc.al);
        }
        else {
            al = new CopyOnWriteArrayList<E>();
            al.addAllAbsent(c);
        }
    }

```

两个构造方法，一个创建空的集合，一个根据给定的集合，将所有元素添加到新的集合中去.


#### add 方法
```java

    public boolean add(E e) {
        return al.addIfAbsent(e);
    }
```

调用`CopyOnWriteArrayLis`的`addIfAbsent`方法，如果不存在该元素，则添加. 

利用底层的`addIfAbsent`来实现了`Set`的唯一性语义.


#### 移除方法

```java
    public boolean remove(Object o) {
        return al.remove(o);
    }
```

直接调用`CopyOnWriteArrayLis`的移除方法即可.


由于`Set`从定义上，没有索引/下标等概念，因此主要的方法也就是添加、移除，遍历了.


#### 遍历


```java

    public Iterator<E> iterator() {
        return al.iterator();
    }
```

调用了底层实现的遍历器.


#### 总结


太水了我。。。。


使用`CopyOnWriteArrayList`来实现了一个`Set`的语义.在`CopyOnWriteArrayList`的基础上，只有一点更改.

**添加时，需要判断集合中是否已经存在该元素**,通过`AddIfAbsent`来实现了.

其他所有属性和`CopyOnWriteArrayList`保持了完全的一致.


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