---
layout: post
tags:
  - 开发者工具
  - Java
  - Linux
  - DEBUG
  - 轮子
---

本文仅测试及学习Arthas命令的使用方式,对原理不做探讨,有兴趣的胖友可以戳下方美团博客的链接,讲解的十分不错.

## 相关链接

<a href="https://alibaba.github.io/arthas/">arthas中文官方网站</a>

<a href="https://tech.meituan.com/2019/02/28/java-dynamic-trace.html">美团博客关于java动态追踪的一篇文章,讲解了部分原理,推荐阅读</a>

<a href="https://alibaba.github.io/arthas/commands.html">官方的命令参考手册</a>
## 介绍

arthas是什么?能做什么?

这里copy官方文档的一段话来告诉大家.

Arthas 是Alibaba开源的Java诊断工具，深受开发者喜爱。

当你遇到以下类似问题而束手无策时，Arthas可以帮助你解决：

1. 这个类从哪个 jar 包加载的？为什么会报各种类相关的 Exception？
2. 我改的代码为什么没有执行到？难道是我没 commit？分支搞错了？
3. 遇到问题无法在线上 debug，难道只能通过加日志再重新发布吗？
4. 线上遇到某个用户的数据处理有问题，但线上同样无法 debug，线下无法重现！
5. 是否有一个全局视角来查看系统的运行状况？
6. 有什么办法可以监控到JVM的实时运行状态？


Arthas支持JDK 6+，支持Linux/Mac/Winodws，采用命令行交互模式，同时提供丰富的 Tab 自动补全功能，进一步方便进行问题的定位和诊断。

## 安装

推荐使用:
```
wget https://alibaba.github.io/arthas/arthas-boot.jar
java -jar arthas-boot.jar
```
选择已经运行的java进程即可.

之后会进入arthas命令行,也可以选择在浏览器打开`127.0.0.1:8563`,通过webUI来操作.
## 功能

#### dashboard

可以查看当前JVM的内存信息以及线程信息.

![](http://img.couplecoders.tech/markdown-img-paste-20190307111318573.png)

#### thread

直接使用可以列出所有的线程,也可以使用`thread 1`,来查看具体某个线程的堆栈信息.(后面的数字为线程ID).

![](http://img.couplecoders.tech/markdown-img-paste-20190307111605128.png)

#### jad

反编译某个class,`jad demo.MathGame`,会在命令行打印出反编译之后的源码.

#### watch
通过`watch`命令来持续观测某一个方法的返回值.

```
watch demo.MathGame primeFactors returnObj
```

![](http://img.couplecoders.tech/markdown-img-paste-20190307111856226.png)

#### 退出

使用exit/quit命令,暂时退出,后续可以继续连接.

使用`shutdown`命令彻底断开连接并reset class文件.

#### sc,sm

查看对应的类加载信息,方法加载信息.

![](http://img.couplecoders.tech/markdown-img-paste-20190307112246591.png)

#### trace

查看方法的内部调用路径,并返回每个节点的耗时情况.

![](http://img.couplecoders.tech/markdown-img-paste-20190307112519548.png)

#### stack
输出当前方法被调用的调用路径
![](http://img.couplecoders.tech/markdown-img-paste-20190307112627142.png)


## 联系我
最后，欢迎关注我的个人公众号【 呼延十 】，会不定期更新很多后端工程师的学习笔记。
也欢迎直接公众号私信或者邮箱联系我，一定知无不言，言无不尽。
![](http://img.couplecoders.tech/%E6%89%AB%E7%A0%81_%E6%90%9C%E7%B4%A2%E8%81%94%E5%90%88%E4%BC%A0%E6%92%AD%E6%A0%B7%E5%BC%8F-%E6%A0%87%E5%87%86%E8%89%B2%E7%89%88.png)

完.

<br>
<br>
<br>
<br>
<h4>ChangeLog</h4>
2019-03-07      完成
<br>
<br>


**以上皆为个人所思所得，如有错误欢迎评论区指正。**

**欢迎转载，烦请署名并保留原文链接。**

**联系邮箱：huyanshi2580@gmail.com**

**更多学习笔记见个人博客------><a href="{{ site.baseurl }}/">呼延十</a>**
