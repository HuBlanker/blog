---
layout: post
category: [Java,JUC, PriotiryBlockingQueue]
tags:
  - Java
  - PriotiryBlockingQueue
  - JUC
---




本文源码基于: <font color='red'>JDK13</font>


## PriorityBlockingQueue 优先级阻塞队列


### 官方注释翻译

一个无界的阻塞队列，使用相同的排队规则`PriorityQueue`并且提供阻塞的操作. 因为这个队列逻辑上是误解的，尝试添加操作可能会失败，由于资环耗尽了(比如OOM).

这个类不接受null元素. 一个优先级队列依赖于自然序并且不保证`non-comparable(不支持比较的元素)`的元素顺序.

这个类和他的迭代器实现了`Collection`和`Iterator`接口所有可选的方法，这个迭代器提供了`iterator()`和`spliterator()`， 不保证遍历元素的顺序.

如果你需要排序的遍历，可以使用`Arrays.sort(pq.toArray())`. 另外，方法`drainTo`可以用来移除一些元素，并且把他们放到另外一个集合中.

这个类的操作，不保证相同优先级的元素的顺序. 如果你需要强制一个顺序，你可以定义定制化的类或者比较器，使用第二个key来打破第一个key相同的情况.

举个例子，这里有一个类提供了`FIFO`顺序去比较元素。

```java
 class FIFOEntry<E extends Comparable<? super E>>
     implements Comparable<FIFOEntry<E>> {
   static final AtomicLong seq = new AtomicLong(0);
   final long seqNum;
   final E entry;
   public FIFOEntry(E entry) {
     seqNum = seq.getAndIncrement();
     this.entry = entry;
   }
   public E getEntry() { return entry; }
    
   public int compareTo(FIFOEntry<E> other) {
       // 首先调用`CompareTo`来获取优先级
     int res = entry.compareTo(other.entry);
     // 如果第一个优先级一样, 就根据seqNum再给定一个优先级.
     if (res == 0 && other.entry != this.entry)
       res = (seqNum < other.seqNum ? -1 : 1);
     return res;
   }
 }
```

实现了`CompareTo`,首先使用原始类的`CompareTo`，如果优先级相等，就是用内部自定义的`seqNum`来比较优先级.

这个类也是java集合框架的一个成员.


### 源码


#### 定义

```java
@SuppressWarnings("unchecked")
public class PriorityBlockingQueue<E> extends AbstractQueue<E>
        implements BlockingQueue<E>, java.io.Serializable {
```

实现了队列的接口以及阻塞队列的接口.

#### 属性

```java

    // 实际保存数据的数组
    private transient Object[] queue;

     // 元素数量
    private transient int size;

     // 比较器，定义了元素的优先级
    private transient Comparator<? super E> comparator;

     // 锁
    private final ReentrantLock lock = new ReentrantLock();

     // 不为空的等待条件
    private final Condition notEmpty = lock.newCondition();

     // 锁
    private transient volatile int allocationSpinLock;

     // 用于帮助序列化的一个类，没啥用
    private PriorityQueue<E> q;
```

使用数组来保存元素，保存了当前的数量，以及一个比较器，用于定义元素之间的优先级.

#### 构造函数

```java

    public PriorityBlockingQueue() {
        this(DEFAULT_INITIAL_CAPACITY, null);
    }
    public PriorityBlockingQueue(int initialCapacity) {
        this(initialCapacity, null);
    }

    public PriorityBlockingQueue(int initialCapacity,
                                 Comparator<? super E> comparator) {
        if (initialCapacity < 1)
            throw new IllegalArgumentException();
        this.comparator = comparator;
        this.queue = new Object[Math.max(1, initialCapacity)];
    }

    public PriorityBlockingQueue(Collection<? extends E> c) {
        boolean heapify = true; // true if not known to be in heap order
        boolean screen = true;  // true if must screen for nulls
        if (c instanceof SortedSet<?>) {
            SortedSet<? extends E> ss = (SortedSet<? extends E>) c;
            this.comparator = (Comparator<? super E>) ss.comparator();
            heapify = false;
        }
        else if (c instanceof PriorityBlockingQueue<?>) {
            PriorityBlockingQueue<? extends E> pq =
                (PriorityBlockingQueue<? extends E>) c;
            this.comparator = (Comparator<? super E>) pq.comparator();
            screen = false;
            if (pq.getClass() == PriorityBlockingQueue.class) // exact match
                heapify = false;
        }
        Object[] es = c.toArray();
        int n = es.length;
        // If c.toArray incorrectly doesn't return Object[], copy it.
        if (es.getClass() != Object[].class)
            es = Arrays.copyOf(es, n, Object[].class);
        if (screen && (n == 1 || this.comparator != null)) {
            for (Object e : es)
                if (e == null)
                    throw new NullPointerException();
        }
        this.queue = ensureNonEmpty(es);
        this.size = n;
        if (heapify)
            heapify();
    }

```

实现了四个构造方法，前三个都是对初始容量及比较器的赋值. 第四个构造函数支持将给定集合中的元素初始化到队列中.


#### 入队操作
```java

    public boolean add(E e) {
        return offer(e);
    }

    public boolean offer(E e) {
        if (e == null)
            throw new NullPointerException();
        // 加锁
        final ReentrantLock lock = this.lock;
        lock.lock();
        int n, cap;
        Object[] es;
        // 扩容
        while ((n = size) >= (cap = (es = queue).length))
            tryGrow(es, cap);
        try {
            // 根据是否有特定的比较器，将当前元素上浮到正确的优先级位置.
            final Comparator<? super E> cmp;
            if ((cmp = comparator) == null)
                siftUpComparable(n, e, es);
            else
                siftUpUsingComparator(n, e, es, cmp);
            // 数量+1,通知不为空的等待线程
            size = n + 1;
            notEmpty.signal();
        } finally {
            lock.unlock();
        }
        return true;
    }

    public void put(E e) {
        offer(e); // never need to block
    }

    public boolean offer(E e, long timeout, TimeUnit unit) {
        return offer(e); // never need to block
    }
```

`add, offer, put, offer(time,unit)`四个方法，本质上都是调用的同一个`offer`，为啥呢?

因为这个优先级队列，本质上是无界的，也就是说，没有`队列满了`的情况，因此前面的等待条件，只有`notEmpty`而没有和其他队列一样的`notFull`。

这个方法比较简单:

1. 如果容量不够扩容
2. 直接放进队列中，然后根据是否有特定的比较其，进行上浮，一直到自己的优先级应该在的位置
3. 通知所有等待队列不为空的线程即可.

两个上浮操作:

```java

    private static <T> void siftUpComparable(int k, T x, Object[] es) {
        Comparable<? super T> key = (Comparable<? super T>) x;
        // 遍历
        while (k > 0) {
            // 父节点
            int parent = (k - 1) >>> 1;
            Object e = es[parent];
            // 父节点和当前节点对比
            if (key.compareTo((T) e) >= 0)
                break;
            es[k] = e;
            k = parent;
        }
        // 找到的位置给新的节点
        es[k] = key;
    }

    // 和上面的方法一样，只不过比较器是给定的，不是用元素本身的CompareTo。
    private static <T> void siftUpUsingComparator(
        int k, T x, Object[] es, Comparator<? super T> cmp) {
        while (k > 0) {
            int parent = (k - 1) >>> 1;
            Object e = es[parent];
            if (cmp.compare(x, (T) e) >= 0)
                break;
            es[k] = e;
            k = parent;
        }
        es[k] = x;
    }
```

因为队列中的元素，其实是一个平衡的二叉堆，因此在给定的元素，寻找优先级所在的位置时， 使用类似于堆的上浮操作即可.


#### 出队操作

```java

    // 如果为空，返回null
    public E poll() {
        final ReentrantLock lock = this.lock;
        lock.lock();
        try {
            return dequeue();
        } finally {
            lock.unlock();
        }
    }

    public E take() throws InterruptedException {
        final ReentrantLock lock = this.lock;
        lock.lockInterruptibly();
        E result;
        try {
            while ( (result = dequeue()) == null)
                notEmpty.await();
        } finally {
            lock.unlock();
        }
        return result;
    }

    public E poll(long timeout, TimeUnit unit) throws InterruptedException {
        long nanos = unit.toNanos(timeout);
        final ReentrantLock lock = this.lock;
        lock.lockInterruptibly();
        E result;
        try {
            while ( (result = dequeue()) == null && nanos > 0)
                nanos = notEmpty.awaitNanos(nanos);
        } finally {
            lock.unlock();
        }
        return result;
    }
```

队列的几个出队方法，核心都是调用`dequeue()`方法，只是在获取元素为空时，处理策略不一致.

* poll 返回null
* take 永久阻塞
* poll(time,unit) 阻塞给定时间.


核心的出队方法如下:

```java

    private E dequeue() {
        // assert lock.isHeldByCurrentThread();
        final Object[] es;
        final E result;

        // 获取数组第一个，也就是堆顶的元素
        if ((result = (E) ((es = queue)[0])) != null) {
            final int n;
            // 最后一个元素
            final E x = (E) es[(n = --size)];
            es[n] = null;
            if (n > 0) {
                // 将他放在堆顶，然后下沉，使堆符合优先级
                final Comparator<? super E> cmp;
                if ((cmp = comparator) == null)
                    siftDownComparable(0, x, es, n);
                else
                    siftDownUsingComparator(0, x, es, n, cmp);
            }
        }
        return result;
    }
```

也算是常见的堆的出堆代码了，首先获取堆顶元素，之后将堆的最后一个元素，放在堆顶，进行下沉，使整个堆符合优先级.

下沉代码:

```java

    private static <T> void siftDownComparable(int k, T x, Object[] es, int n) {
        // assert n > 0;
        Comparable<? super T> key = (Comparable<? super T>)x;
        int half = n >>> 1;           // loop while a non-leaf
        while (k < half) {
            // 堆顶元素的孩子节点
            int child = (k << 1) + 1; // assume left child is least
            Object c = es[child];
            int right = child + 1;
            if (right < n &&
                ((Comparable<? super T>) c).compareTo((T) es[right]) > 0)
                c = es[child = right];
            if (key.compareTo((T) c) <= 0)
                break;
            es[k] = c;
            k = child;
        }
        es[k] = key;
    }

```

将给定节点与右边子节点进行比较，如果不符合优先级，交换位置. 递归执行.

#### 总结


一个带有优先级的阻塞队列. 支持使用元素本身的`CompareTo`以及给定比较器`Comparator`.

优先级的实现，使用堆. 因此内部保存元素的载体是一个数组. 

由于设计是无界的队列，因此入队方法永远不会阻塞，只会逐渐撑爆内存. `put`方法不会阻塞. 出队方法像其他阻塞队列一样，会阻塞.

对数组的读写使用`ReentrantLock`来保证线程安全性. 

阻塞操作使用`Condition`来实现阻塞等待与唤醒.


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