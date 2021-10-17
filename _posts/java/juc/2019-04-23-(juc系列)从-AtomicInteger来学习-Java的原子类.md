---
layout: post
category: [Java面试,Java,多线程,java.util.concurrent]
tags:
  - Java面试
  - Java
  - 多线程
  - java.util.concurrent
---


本文源码基于: <font color='red'>JDK13</font>


## 前言

Java的`concurrent`包一直都是很重要的知识点,因为他是进阶高级工程师必备,而其中的`atomic`包中的原子类是最为经常使用到的,所以学习一下`atomic`下的一些类的源码.

Java原子类实现了线程安全的操作,比如`AtomicInteger`实现了对int值的安全的加减等.

所以我们学习主要分为两部分,首先学习为什么可以实现线程安全?其次是学习这些类的API,加强记忆方便后续使用.

## 怎么实现线程安全?

这个我们以`AtomicInteger`为例,其中的`incrementAndGet()`方法实现方式为:

```java
    //API
    public final int incrementAndGet() {
        return unsafe.getAndAddInt(this, valueOffset, 1) + 1;
    }

    //CAS
    public final int getAndAddInt(Object var1, long var2, int var4) {
        int var5;
        do {
            var5 = this.getIntVolatile(var1, var2);
        } while(!this.compareAndSwapInt(var1, var2, var5, var5 + var4));

        return var5;
    }
```

可以看到实现比较简单,调用了`Unsafe`类的`getAndAddInt`方法,该方法的实现也贴了出来,其中调用了两个native方法.

实现原子操作的机制是:CAS.

CAS:compare and swap,比较交换,当且仅当目标值等于给定值的时候才进行写入操作.具体原理可以google一下.

可以看到在上面的`getAndAddInt`方法中,显示获取了当前内存地址的值,然后进行比较交换,如果相同则成功,不相同则轮询.

## AtomicInteger的常用API

- incrementAndGet: 自增一且返回新值.
- getAndIncrement: 获取当前值之后将其自增.
- decrementAndGet: 自减一之后返回新值.
- getAndDecrement: 获取当前值之后自减.

- get: 获取当前值.
- set: 设置一个值.
- getAndSet: 设置新值,返回旧值.

## AtomicBoolean的常用API

- getAndSet:设置新值返回旧值.
- get: 返回当前值.
- set: 设置一个值.

- compareAndSet: CAS实现的set.

## AtomicLong 略过

## AtomicReference

原子的引用....可以随便放进去什么值.

API出来了get和set外:

- updateAndGet: 更新值并获取新值.
- getAndUpdate: 获取旧值之后更新值.

注意传入的参数是声明的V.

## AtomicIntegerArray

int数组的原子类.

和`AtomicInteger`并没有什么不同,只是对传入的数组下标进行了一下计算,来实现对数组的某个index上的值的原子更改.


完.好水啊...以为原子类要看很久呢.

<br>
<br>
<br>
<br>
<h4>ChangeLog</h4>
2019-04-23  完成   
<br>
<br>


**以上皆为个人所思所得，如有错误欢迎评论区指正。**

**欢迎转载，烦请署名并保留原文链接。**

**联系邮箱：huyanshi2580@gmail.com**

**更多学习笔记见个人博客------><a href="{{ site.baseurl }}/">呼延十</a>**
