---
layout: post
category: [Java,DEBUG,面试]
tags:
  - Java
  - DEBUG
  - 面试
---

这篇文章主要是记录自己做的一些小的测试.主要包括内存溢出,栈溢出,以及死锁问题.

PS:文章中使用了`Arthas`工具,用来动态监控JVM的一些资源,非常好用,强烈安利一下.

# OOM

OutOfMemory ,内存不够用了,一般是什么原因呢?

1. 给应用程序分配的内存太小,只能通过增大内存来解决.

2. 内存泄漏.有一部分内存"无用"了,但是因为编码问题导致的没有被垃圾回收掉,产生了泄漏,最终导致了内存溢出(OOM).

我们来手动写一个OOM.

```java
package javatest;

import java.util.HashMap;
import java.util.Map;

/**
 * created by huyanshi on 2019/3/6
 */
public class OOMTest {

  static class Key{
    int id;

    public Key(int i){
      int id;
    }

    @Override
    public int hashCode() {
      return this.id;
    }
  }

  public static void main(String [] args ) {

    Map<Key, String> testMap = new HashMap<>();
    while (true) {
      for (int i = 0; i < 10000; i++) {
        if (!testMap.containsKey(new Key(i))) {
          testMap.put(new Key(i), "Number:" + i);
        }
      }
    }
  }

}
```

注意:直接运行可能得到OOM有点慢,可以设置一下Xmx参数小一点.

实现原理:不断的new出新的对象,并将它们放进一个Map里面保持引用.这样一直无法回收,终会OOM.

同时,也可以通过一些工具,比如阿里的`Arthas`来动态的监控JVM的内存使用情况,如下图.

![](http://img.couplecoders.tech/markdown-img-paste-20190306232820950.png)

是可以肉眼看到内存使用量以及占用率不断上升的.


# StackOverFlow

栈溢出,首先和内存溢出一样,我们考虑一下栈里面放的是什么?

执行方法时的一些调用环境(比如参数及局部变量),那么什么时候会栈溢出呢?

1. 无限的递归,相当于你的参数无限多,那么栈放不下.

2. 局部变量太大了,正常分配的栈空间(1M)不够用.


我们用递归来实现一下:

```java
package javatest;

/**
 * created by huyanshi on 2019/3/6
 */
public class StackOverFlowTest {


  public static void main(String[] args) {

    new StackOverFlowTest().fun(10);
  }


  public int fun(int n) {
    return fun(n);
  }

}

```

所以当发生StackOverFlow的时候,记得检查一下递归调用的结束条件.

# 死锁

死锁是指两个或两个以上的进程在执行过程中，由于竞争资源或者由于彼此通信而造成的一种阻塞的现象，若无外力作用，它们都将无法推进下去。此时称系统处于死锁状态或系统产生了死锁，这些永远在互相等待的进程称为死锁进程。

造成死锁的条件有四个:

1. 互斥条件：指进程对所分配到的资源进行排它性使用，即在一段时间内某资源只由一个进程占用。如果此时还有其它进程请求资源，则请求者只能等待，直至占有资源的进程用毕释放。

2. 请求和保持条件：指进程已经保持至少一个资源，但又提出了新的资源请求，而该资源已被其它进程占有，此时请求进程阻塞，但又对自己已获得的其它资源保持不放。
3. 不剥夺条件：指进程已获得的资源，在未使用完之前，不能被剥夺，只能在使用完时由自己释放。

4. 环路等待条件：指在发生死锁时，必然存在一个进程——资源的环形链，即进程集合{P0，P1，P2，···，Pn}中的P0正在等待一个P1占用的资源；P1正在等待P2占用的资源，……，Pn正在等待已被P0占用的资源。


手动写一个:

```java
package javatest;

/**
 * created by huyanshi on 2019/3/6
 */
public class DeadLockTest {

  public static void main(String[] args) {
    Sy sy = new Sy(0);
    Sy sy2 = new Sy(1);
    sy.start();
    sy2.start();
  }
}

class Sy extends Thread {

  private int flag;

  static Object x1 = new Object();
  static Object x2 = new Object();

  public Sy(int flag) {
    this.flag = flag;
  }

  @Override
  public void run() {
    System.out.println(flag);
    try {
      if (flag == 0) {
        synchronized (x1) {
          System.out.println(flag + "锁住了x1");
          Thread.sleep(1000);
          synchronized (x2) {
            System.out.println(flag + "锁住了x2");
          }
          System.out.println(flag + "释放了x1和x2");
        }
      }
      if (flag == 1) {
        synchronized (x2) {
          System.out.println(flag + "锁住了x2");
          Thread.sleep(1000);
          synchronized (x1) {
            System.out.println(flag + "锁住了x1");
          }
          System.out.println(flag + "释放了x1和x2");
        }
      }
    } catch (InterruptedException e) {
      e.printStackTrace();
    }
  }
}
```

实现原理:

定义一个类,类有两个静态对象对象,创建一个对象去锁住1,然后请求对2加锁.

再创建一个对象锁住2,然后请求对1加锁.

使用的锁为synchronized关键字.

然后使用监控工具查看当前jvm的线程,可以发现main方法中启动的两个线程阻塞住了.而且一直也无法释放.

![](http://img.couplecoders.tech/markdown-img-paste-20190307000225982.png)
完.



<br>
<br>
<br>
<br>
<h4>ChangeLog</h4>
2019-03-06 完成
<br>
<br>

**以上皆为个人所思所得，如有错误欢迎评论区指正。**

**欢迎转载，烦请署名并保留原文链接。**

**联系邮箱：huyanshi2580@gmail.com**

**更多学习笔记见个人博客------><a href="{{ site.baseurl }}/">呼延十</a>**
