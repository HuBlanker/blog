---
layout: post
tags:
  - Java
  - Java面试
  - Java集合
---

在前面的一片文章写了<a href="{{ site.baseurl }}/源码阅读/2018/10/16/HashMap源码阅读/">HashMap的源码阅读</a>，这次来说一下HashTable的一些知识。

在阅读源码过后，我发现HashMap与HashTable的实现方式基本一致，因此这篇文章不再介绍HashTable中每个方法的源码实现，知识列举两者的区别与联系，有兴趣的读者可以点击上面的链接去看一下HashMap的实现。

## 区别

1.HashTable不能存储空值，而HashMap可以。

![](http://img.couplecoders.tech/markdown-img-paste-20181103235721436.png)

在HashTable的源码中`put()`方法，开始就检查了存入的值是否为空，如果为空则抛出了空指针异常。

2.HashTable是线程安全的，而HashMap不是。

查看源码可以发现，HashTable中所有改变值得操作都使用了`synchronized`关键字修饰。

`synchronized`关键字可以保证同一时间可以保证只有一个线程可以访问该实例。

## 结论

1.如果需要存储空值，则不能使用HashTable。

2.HashTable使用`synchronized`关键字来保证了线程安全性，但是在单线程的使用环境下，会造成一定的性能浪费，在使用前需要进行选择。

## 注意事项

1.可否让HashMap线程安全？

答案是：可以,通过下面的方式可以获得同步的Map。

```java
HashMap<String,String> hashMap = new HashMap<>();
Map syMap = Collections.synchronizedMap(hashMap);
```

2.在Java5之后，更加建议使用`ConcurrentHashMap`，该类线程安全且性能远优于HashTable。




<br>
完。

<br>
<br>
<br>
<br>
<h4>ChangeLog</h4>
2018-11-03 完成
<br>
<br>

**以上皆为个人所思所得，如有错误欢迎评论区指正。**

**欢迎转载，烦请署名并保留原文链接。**

**联系邮箱：huyanshi2580@gmail.com**

**更多学习笔记见个人博客------><a href="{{ site.baseurl }}/">呼延十</a>**
