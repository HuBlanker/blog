---
layout: post
category: [开发者工具,效率编程]
tags:
  - 开发者工具
  - 效率编程
---

## 前言

线上(真-线上/测试环境)代码出了问题,总是要在本地复现,然后debug,这个过程是在是不太友好,而且线上的很多数据本地没有,经常耽误好久的时间来同步数据.

前文介绍过一种在运行时DEBUG及修改Java代码的方式,[阿里开源java动态追踪工具 Arthas的使用](http://huyan.couplecoders.tech/%E5%BC%80%E5%8F%91%E8%80%85%E5%B7%A5%E5%85%B7/java/linux/debug/2019/03/07/%E9%98%BF%E9%87%8C%E5%BC%80%E6%BA%90Java%E5%8A%A8%E6%80%81%E8%BF%BD%E8%B8%AA%E5%B7%A5%E5%85%B7-Arthas%E7%9A%84%E4%BD%BF%E7%94%A8/).其主要针对的是线上修改代码及JVM实时查看.

但是有很多问题,我们更想要IDE的DEBUG功能,比如线上跑了NPE,本地没有办法复现因为可能是线上的数据问题,这时候就会想,如果可以在线上这里打个断点,就知道是谁为空了.

幸好Java是有远程DEBUG的支持的,而且Intellij-IDEA也实现了相关的功能,今天学习并且记录一下.

## 启动参数

首先在服务端使用JVM的`-Xdebug`参数启动Jar包.

`java -Xdebug -Xrunjdwp:transport=dt_socket,server=y,suspend=n,address=5555 -jar huyan-demo.jar `

参数说明：

* -Xdebug：JVM在DEBUG模式下工作；

* -Xrunjdwp：JVM使用(java debug wire protocol)来运行调试环境；

* transport：监听Socket端口连接方式,常用的dt_socket表示使用socket连接.

* server：=y表示当前是调试服务端，=n表示当前是调试客户端；

* suspend：=n表示启动时不中断.

* address：=8000表示本地监听5555端口。

## IDEA配置

服务端以DEBUG模式启动了jar包之后,基本上就完成了,只需要在IDEA中做一些配置,如下图:

![2019-07-04-11-48-21](http://img.couplecoders.tech/2019-07-04-11-48-21.png)

添加一个新的启动项,选择`Remote`,之后在配置信息里面填入你启动的服务端的`IP地址`及`调试端口`.

之后点击debug按钮,像本地一样的开始debug吧~.


<br>


完。
<br>
<br>
<br>
<br>
<h4>ChangeLog</h4>
2019-07-04 完成
<br>
<br>


**以上皆为个人所思所得，如有错误欢迎评论区指正。**


**欢迎转载，烦请署名并保留原文链接。**


**联系邮箱：huyanshi2580@gmail.com**


**更多学习笔记见个人博客------><a href="{{ site.baseurl }}/">呼延十</a>**