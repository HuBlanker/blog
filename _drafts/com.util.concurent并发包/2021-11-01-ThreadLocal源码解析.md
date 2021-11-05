---
layout: post
category: [Java,ThreadLocal]
tags:
  - Java
  - ThreadLocal
---




## 前言

## ThreadLocal 源码解析


### 官方注释翻译

这个类提供线程本地的属性. 这些变量和其他变量不一样，每个线程只有一个，通过`get、set`来访问. `ThreadLocal`实例通常是`private static`的属性，
用来联系线程与状态(比如用户id，失误id等.)

比如，下面这个类生成每个线程本地的唯一标示福. 线程的id在第一次调用`ThreadId.get()`时被赋值，并且在后续的调用中保持不变.

```java
   import java.util.concurrent.atomic.AtomicInteger;
  
   public class ThreadId {
       // Atomic integer containing the next thread ID to be assigned
       private static final AtomicInteger nextId = new AtomicInteger(0);
  
       // Thread local variable containing each thread's ID
       private static final ThreadLocal<Integer> threadId =
           new ThreadLocal<Integer>() {
               @Override protected Integer initialValue() {
                   return nextId.getAndIncrement();
           }
       };
  
       // Returns the current thread's unique ID, assigning it if necessary
       public static int get() {
           return threadId.get();
       }
   }
```

只要线程是活着的，并且`ThreadLocal`实例是可以访问的， 每个线程持有一个对线程局部变量副本的隐式引用. 当一个线程离开后，他的所有本地实例副本都会被垃圾收集.

### 源码

```java

    public ThreadLocal() {
    }

```
构造方法是空的，因为这个类只需要提供一个简单的实例即可，我们直接看重要的`get/set`方法.


#### get 获取当前线程的该变量

```java

    public T get() {
        Thread t = Thread.currentThread();
        // 获取当前线程的所有`ThreadLocal`值.
        ThreadLocalMap map = getMap(t);
        // 如果有
        if (map != null) {
            // 获取当前threadLocal的值
            ThreadLocalMap.Entry e = map.getEntry(this);
            // 返回结果
            if (e != null) {
                @SuppressWarnings("unchecked")
                T result = (T)e.value;
                return result;
            }
        }
        // 如果当前线程没有任何的threadLocal值，初始化一下
        return setInitialValue();
    }
```

1. 获取当前线程的`所有ThreadLocal`值. 也就是如果你定义了100个ThreadLocal， 这里拿到的也是全集. (这里是个内部类，等会再说.
2. 从所有的ThreadLocal中获取当前ThreadLocal对应的值. 涉及到`ThreadLocalMap`的key.
3. 返回值.
4. 如果当前线程没有任何`ThreadLocal`值，初始化.

一个一个看涉及到的方法:

####  setInitialValue 初始化

先看最简单的初始化属性:

```java

    private T setInitialValue() {
        // 获取当前`threadLocal`的初始值
        T value = initialValue();
        Thread t = Thread.currentThread();
        // 放进当前线程的map中
        ThreadLocalMap map = getMap(t);
        if (map != null) {
            map.set(this, value);
        } else {
            createMap(t, value);
        }
        if (this instanceof TerminatingThreadLocal) {
            TerminatingThreadLocal.register((TerminatingThreadLocal<?>) this);
        }
        // 返回这次初始化的值
        return value;
    }
```

已经绕不过去`ThreadLocalMap`了，直接看一下:


#### ThreadLocalMap 

从名字可以看出来这是一个map，其中节点是:

```java
static class Entry extends WeakReference<ThreadLocal<?>> {
    /** The value associated with this ThreadLocal. */
    Object value;

    Entry(ThreadLocal<?> k, Object v) {
        super(k);
        value = v;
    }
}
```

key是`ThreadLocal`的引用，value是记录的值.

```java

        private static final int INITIAL_CAPACITY = 16;

        private Entry[] table;

        /**
         * The number of entries in the table.
         */
        private int size = 0;

        /**
         * The next size value at which to resize.
         */
        private int threshold; // Default to 0
```

* 存放元素的数组
* 当前元素数量
* 扩容阈值

算是map的经典结构了.

#### get
```java

        private Entry getEntry(ThreadLocal<?> key) {
            int i = key.threadLocalHashCode & (table.length - 1);
            Entry e = table[i];
            if (e != null && e.get() == key)
                return e;
            else
                return getEntryAfterMiss(key, i, e);
        }
```

对`ThreadLocal`取hash值后，直接从下标取值即可. 如果下标没有值，miss了，就计算下下标重新获取.


#### set

```java

        private void set(ThreadLocal<?> key, Object value) {

            Entry[] tab = table;
            int len = tab.length;
            int i = key.threadLocalHashCode & (len-1);

            for (Entry e = tab[i];
                 e != null;
                 e = tab[i = nextIndex(i, len)]) {
                ThreadLocal<?> k = e.get();

                if (k == key) {
                    e.value = value;
                    return;
                }

                if (k == null) {
                    replaceStaleEntry(key, value, i);
                    return;
                }
            }

            tab[i] = new Entry(key, value);
            int sz = ++size;
            if (!cleanSomeSlots(i, sz) && sz >= threshold)
                rehash();
        }
```

计算下标进行值的写入，如果发生了hash碰撞，就调整下标即可.

##### 总结

ThreadLocalMap 是一个特殊实现的`HashMap`. key是对`ThreadLocal`实例的虚引用，值是用户写入的值. 支持`get`和`set`接口.


#### ThreadLocal.set(T)

```java

    public void set(T value) {
        Thread t = Thread.currentThread();
        ThreadLocalMap map = getMap(t);
        if (map != null) {
            map.set(this, value);
        } else {
            createMap(t, value);
        }
    }

```

获取当前线程的`ThreadLocalMap`，进行值的写入.

如果当前线程没有初始化，就创建一个map,进行值的写入.

```java

    void createMap(Thread t, T firstValue) {
        t.threadLocals = new ThreadLocalMap(this, firstValue);
    }
```

### 总结

`ThreadLocal`听起来比较复杂，实际实现很简单，只是值的保存位置放在了`Thread`中.


使用:


```java
private static ThreadLocal<Long> tl = new ThreadLocal():

void doSome(){
    tl.get();
    tl.set();
}

```

使用很简单，创建一个空的`ThreadLocal`即可，之后每次调用`get``set`都会拿到当前线程的本地该变量.

实际上设置的变量值并没有存在`ThreadLocal`中，而是在`Thread.threadLocals`中.

该属性是一个`ThreadLocalMap`，是一个特殊实现的map。

key是ThreadLocal的弱引用，value是具体的值.

因此在获取时，只需要取当前线程，拿到所有的ThreadLocal值，之后获取当前`ThreadLocal`的值即可.

在写入时，同理.

那么创建`ThreadLocal`实例的意义在哪？这个类的实例其实约等于你定义的这个变量名字，只不过变量名字是方便自己及别人阅读。

`ThreadLocal`实例用来在`ThreadLocalMap`中作为key，因此肯定也是需要每个属性独立的初始化的.


## ThreadLocalRandom

简单提一下`ThreadLocalRandom`， 虽然名字是`ThreadLocalxxxx`但是他并没有使用`ThreadLocal`来实现.

在`Thread`类中，存储了协助`ThreadLocalRandom`的属性:


```java

// 随机种子
@jdk.internal.vm.annotation.Contended("tlr")
    long threadLocalRandomSeed;

// 随机探针
@jdk.internal.vm.annotation.Contended("tlr")
    int threadLocalRandomProbe;

// 第二种子
@jdk.internal.vm.annotation.Contended("tlr")
    int threadLocalRandomSecondarySeed;
```

random的行为也是通过这几个属性完成的. ThreadLocal的行为是通过什么完成的呢?
```java

    public static ThreadLocalRandom current() {
        if (U.getInt(Thread.currentThread(), PROBE) == 0)
            localInit();
        return instance;
    }
```

`current`方法用来获取当前线程的`ThreadLocalRandom`. 首先检测下当前线程的`种子，探针`等是否初始化，没有的话就初始化，已经初始化就什么都不做了.返回一个静态的`instance`。

注意，这里为什么可以用静态常量，而`ThreadLocal`必须每个属性新new一个实例呢？

因为`ThreadLocal`虽然也是在`Thread`中存储，但是是一个Map，map需要有key，来区分多个`ThreadLocal`变量的值，因此每一个`ThreadLocal`都需要实例化。

而`ThreadLocalRandom`是单功能的，在`Thread`中的属性也都是简单的int，long。使用静态变量唯一实例就OK.


### nextInt()

```java

    public int nextInt() {
        return mix32(nextSeed());
    }
    final long nextSeed() {
        Thread t; long r; // read and update per-thread seed
        U.putLong(t = Thread.currentThread(), SEED,
                  r = U.getLong(t, SEED) + GAMMA);
        return r;
    }


    private static int mix32(long z) {
        z = (z ^ (z >>> 33)) * 0xff51afd7ed558ccdL;
        return (int)(((z ^ (z >>> 33)) * 0xc4ceb9fe1a85ec53L) >>> 32);
    }
```

以`nextInt`为例， 首先获取当前线程的种子，更新新的种子，将种子转成`int`值进行返回. 
所有的读取，写入操作，全部使用`Unsafe`完成，以保证线程安全性.

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