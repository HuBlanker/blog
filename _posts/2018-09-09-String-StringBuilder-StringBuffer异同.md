---
layout: post
category: 源码阅读
---

 字符串在编程中使用的非常频繁，同时又是面试中的常见题型，那么我们的对字符串相关类String，StringBuilder，StringBuffer的理解真的正确吗？今天就通过对三个类源码的阅读，来进一步加强理解。  


 ## 目录
 * <a href="#2">String概述</a>
 * <a href="#3">StringBuilder 和StringBuffer</a>
 * <a href="#4">异同</a>
 * <a href="#5">性能比较</a>
 * <a href="#6">结论</a>
 * <a href="#7">扩展(详细源码阅读及方法解析)</a>



 <h2 id="2"> String概述</h2>
  ![](http://img.couplecoders.tech/Fi_sBbtlLREpBuY49ajeMrLaildf.png)
打开String类的源码，可以发现String类是被final所修饰的，因此String类不可以被继承。  

同样的，用来保存值得char数组 value也是被final修饰的，这就可以得出关于String的一个很重要的结论。  

**String是字符串常亮，值是不可改变，通常我们对String的操作都是通过new一个新的String对象来完成的**  

如下图中的subString方法和replace方法。
![substring](http://img.couplecoders.tech/markdown-img-paste-20180921000114583.png)

![replace](http://img.couplecoders.tech/markdown-img-paste-20180921000240260.png)


 <h2 id="3"> StringBuilder和StringBuffer</h2>

 既然已经有了String这个功能完备的嘞，那么为什么还需要StringBuilder和StringBuffer呢？


 让我们来看一下这两个类的源代码：
 ![buffer](http://img.couplecoders.tech/markdown-img-paste-20180921002301146.png)

 ![](http://img.couplecoders.tech/markdown-img-paste-20180921002336352.png)

 可以看出，这两个类共同继承于**AbstractStringBuilder**，那么打开这个类的源码看一下：

 ![AbstractStringBuilder](http://img.couplecoders.tech/markdown-img-paste-20180921002434384.png)

 可以看到，这个抽象类中也是以char数组的形式来保存字符串，但是，这个数组是可变的，我们看一下append方法的代码：  

![append](http://img.couplecoders.tech/markdown-img-paste-20180921002947941.png)

 append()是最常用的方法，它有很多形式的重载。上面是其中一种，用于追加字符串。如果str是null,则会调用appendNull()方法。这个方法其实是追加了'n'、'u'、'l'、'l'这几个字符。如果不是null，则首先扩容，然后调用String的getChars()方法将str追加到value末尾。最后返回对象本身，所以append()可以连续调用。


那么StringBuffer、StringBuilder的区别在哪里呢？

这是StringBuffer的length方法和capacity方法。

![](http://img.couplecoders.tech/markdown-img-paste-2018092100342915.png)

这是AbstractStringBuilder的length方法和capacity方法(Stringbuilder没有进行重写)。

![](http://img.couplecoders.tech/markdown-img-paste-20180921003635251.png)

很明显，Stringbuffer对大部分方法添加了 synchronized关键字，来保证线程安全。


 <h2 id="4"> 异同</h2>

从上面的一些源码中可以简单分析出String，StringBuilder，StringBuffer的一些异同点，如下：  
* String是常量，不可改变，StringBuffer、StringBuilder是变量，值是可变的
* StringBuilder是线程不安全的，而StringBuffer线程安全。 String是常量，线程当然安全。


<h2 id="5"> 性能比较</h2>

说了这么多，在实际应用过程中，到底应该注意点什么呢？

下面来实际测试一下：  

```java
public Map<String, Map<String, String>> stringAnalytics() {
    Map<String, Map<String, String>> result = new HashMap<>();
    Map<String, String> time = new HashMap<>();

    long pre = System.currentTimeMillis();
    String s = "";
    for (int i = 0; i < 50000; i++) {
      s += i;
    }
    time.put("String", String.valueOf(System.currentTimeMillis() - pre));

    long preBuilder = System.currentTimeMillis();
    StringBuilder sb = new StringBuilder();
    for (int i = 0; i < 50000; i++) {
      sb.append(i);
    }
    time.put("StringBuilder", String.valueOf(System.currentTimeMillis() - preBuilder));

    long preBuffer = System.currentTimeMillis();
    StringBuffer stringBuffer = new StringBuffer();
    for (int i = 0; i < 50000; i++) {
      stringBuffer.append(i);
    }
    time.put("StringBuffer", String.valueOf(System.currentTimeMillis() - preBuffer));

    result.put("time", time);
    System.out.print(result);
    return result;
  }
```

在上面的代码，分别使用String，StringBuilder，StringBuffer进行了50000的字符串拼接操作(String使用+方法，其他两个类使用append方法)，每次拼接的值为当前循环的数字。在该部分执行前后记录当前系统时间，最后算出消耗时间。

得到的结果如下图：  

![](http://img.couplecoders.tech/markdown-img-paste-2018092100463015.png)

* String消耗16.153秒
* StringBuilder消耗0.005秒
* StringBuffer消耗0.013秒

<h2 id="6"> 结论</h2>
终于到了喜闻乐见的结论时候：  

PS:以下结论使用于大部分情况，实际编译编码过程中会有编译优化等原因稍微影响结论，但不能代表大多数。

**1.当字符串改动较小的时候，使用String**  
原因：方便且线程安全

**2.当字符串需要频繁进行改动，且单线程使用StringBuilder**  
原因：由5中可知，StringBuilder是效率最高的了。

**3.当字符串需要频繁改动，且多线程调用。使用StringBuffer**  
原因：StringBuffer中添加了对多线程应用时的保护，可以保证线程安全，且性能下降并不严重，在可接受范围内。










<br>
<br>
<br>
<br>
<h4>ChangeLog</h4>
2018-09-22 完成
<br>
<br>

**以上皆为个人所思所得，如有错误欢迎评论区指正。**

**欢迎转载，烦请署名并保留原文链接。**

**联系邮箱：huyanshi2580@gmail.com**

**更多学习笔记见个人博客------><a href="{{ site.baseurl }}/">呼延十</a>**
