---
layout: post
category: [Java面试,Java]
tags:
  - Java面试
  - Java
---

## 前言

在学习ConcurrentHashMap源码的过程中,发现自己对并发编程简直是一无所知,因此打算从最基础的volatile开始学习.

volatile虽然很基础,但是对于毫无JMM基础的我来说,也是十分晦涩,看了许多文章仍然不能很好的表述出来.

后来发现一篇文章(参考链接第一篇),给了我一些启示:用回答问题的方式来学习知识及写博客,因为对我这种新手来说,回答别人的问题,总比自己"演讲"要来的容易许多.

## volatile的用法

**volatile只可以用来修饰变量,不可以修饰方法以及类**

```java
public class Singleton {  
    private volatile static Singleton singleton;  
    private Singleton (){}  
    public static Singleton getSingleton() {  
    if (singleton == null) {  
        synchronized (Singleton.class) {  
        if (singleton == null) {  
            singleton = new Singleton();  
        }  
        }  
    }  
    return singleton;  
    }  
}
```

这是很经典的双重锁校验实现的单例模式,想必很多人都看到过,代码中可能会被多个线程访问的`singleton`变量使用volatile修饰.

## volatile的作用及原理

当一个变量被volatile修饰时,会拥有两个特性:

1. 保证了不同线程对该变量操作的内存可见性.(当一个线程修改了变量,其他使用次变量的线程可以立即知道这一修改).
2. 禁止了指令重排序.

### 1. 保证内存可见性

JMM操作变量的时候不是直接在主存进行操作的,而是每个线程拥有自己的工作内存,在使用前,将该变量的值copy一份到自己的工作内存,读取时直接读取自己的工作内存中的值.写入操作时,先将修改后的值写入到自己的工作内存,再讲工作内存中的值刷新回主存.

类似于下图:
![](http://img.couplecoders.tech/markdown-img-paste-20181121233954405.png)

为什么这么搞呢?当然是为了提高效率,毕竟主存的读写相较于CPU中的指令执行都太慢了.

这样就会带来一个问题.当执行

`i = i + 1;(i初始化为0)`

语句时,单线程操作当然没有问题,但是如果两个线程操作呢?得到的结果是2吗?

不一定.

让我们详细分解一下执行这句话的操作.

**读取内存中的i=0到工作内存`(1)`->工作内存中的i=i+1=1`(2)`- > 将工作内存中的i=1刷新回主存`(3)`.**

这是单线程操作的情况,那么假设当线程1执行到了`(2)`的时候,线程2开始了,进行完了(1)步骤,那么这时候的情况是什么呢?

线程1位于``(2)``,线程2位于`(1)`.

线程1的工作内存中i=1,线程2的工作内存中i=0,之后分别进行余下的步骤,最后拿到的结果为`1`.

这是什么原因造成的呢?因为普通的变量没有保证内存可见性.即:**线程1已经修改了i的值,其他的线程却没有得到这个消息.**

volatile保证了这一点,用volatile修饰的变量,**读取操作与普通变量相同.但是写入操作发生后会立即将其刷新回主存,并且使其他线程中对这一变量的缓存失效!**

缓存失效了怎么办呢?去再次读取主存呗,主存此时已经修改了(立即刷新了),则保证了内存可见性.

####小栗子:

```java
public class VolatileTest {

  private static Boolean stop = false;//(1)
  private static volatile Boolean stop = false;//(2)


  public static void main(String args[]) throws InterruptedException {
    //新建立一个线程
    Thread testThread = new Thread() {
      @Override
      public void run() {
        System.out.println();
        int i = 1;
        //不断的对i进行自增操作
        while (!stop) {
          i++;
        }
        System.out.println("Thread stop i=" + i);
      }
    };
    //启动该线程
    testThread.start();
    //休眠一秒
    Thread.sleep(1000);
    //主线程中将stop置为true
    stop = true;
    System.out.println(Thread.currentThread() + "now, in main thread stop is: " + stop);
    testThread.join();
  }

}
```

这段代码在主线程的第二行定义了一个布尔变量stop, 然后主线程启动一个新线程，在线程里不停得增加计数器i的值，直到主线程的布尔变量stop被主线程置为true才结束循环。

主线程用Thread.sleep停顿1秒后将布尔值stop置为true。

因此，我们期望的结果是，上述Java代码执行1秒钟后停止，并且打印出1秒钟内计数器i的实际值。

然而，执行这个Java应用后，你发现它进入了死循环,程序没有停止.

将`(1)`处的代码改为`(2)`处的,即对stop的变量添加volatile修饰,你会发现程序如我们预期的那样停止了.

### 2.禁止指令重排序

JVM在不影响**单线程执行结果**的情况下回对指令进行重排序,比如:

```java
int i = 1;//(1)
int j = 2;//(2)
int h = i * j;//(3)
```
上述代码中,(3)执行依赖于(1)(2)的执行,但是(1)(2)的执行顺序并不影响结果,也就是说当我们进行了上述的编码,JVM真正执行的可能是(1)(2)(3),也可能是(2)(1)(3).

这在单线程中是无所谓的,还会带来性能的提升.

但是在多线程中就会出现问题,比如下面的代码:

```java
//线程1
context = loadContext();//(1)
inited = true;//(2)


//线程2
while(!inited ){ //根据线程A中对inited变量的修改决定是否使用context变量
   sleep(100);
}
doSomethingwithconfig(context);
```
如果每个线程中的指令都顺序执行,则没有问题,但是在线程1中,两个语句并无依赖关系,因此可能会发生重排序,如果发生了重排序:

```java
inited = true;//(2)
context = loadContext();//(1)
```

线程1重排序之后先执行了(2)语句,在线程2中,程序跳出了循环,执行`doSomethingwithconfig`,因为他认为context已经进行了初始化,然后并没有,就会出现错误.

**使用volatile关键字修饰`inited`变量,JVM就会阻止对`inited`相关的代码进行重排序.这样就能够按照既定的顺序指执行.**

## volatile总结

volatile是轻量级同步机制,与synchronized相比,他的开销更小一些,同时安全性也有所降低,在一些特定的场景下使用它可以在完成并发目标的基础上有一些性能上的优势.但是同时也会带来一些安全上的问题,且比较难以排查,使用时需要谨慎.

## volatile的使用场景

使用volatile修饰的变量最好满足以下条件:

1. 对变量的写操作不依赖于当前值
2. 该变量没有包含在具有其他变量的不变式中

这里举几个比较经典的场景:
1. 状态标记量,就是前面例子中的使用.
2. 一次性安全发布.双重检查锁定问题(单例模式的双重检查).
3. 独立观察.如果系统需要使用最后登录的人员的名字,这个场景就很适合.
4. 开销较低的“读－写锁”策略.当读操作远远大于写操作,可以结合使用锁和volatile来提升性能.


## 注意事项

volatile并不能保证操作的原子性,想要保证原子性请使用synchronized关键字加锁.


## 参考链接
http://www.techug.com/post/java-volatile-keyword.html
http://www.importnew.com/23535.html



完。


<br>
<br>
<br>
<br>
<h4>ChangeLog</h4>
2018-11-22 完成
<br>
<br>

**以上皆为个人所思所得，如有错误欢迎评论区指正。**

**欢迎转载，烦请署名并保留原文链接。**

**联系邮箱：huyanshi2580@gmail.com**

**更多学习笔记见个人博客------><a href="{{ site.baseurl }}/">呼延十</a>**
