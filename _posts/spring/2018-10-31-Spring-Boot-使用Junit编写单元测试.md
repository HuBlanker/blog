---
layout: post
category: [开发环境搭建,Spring Boot]
tags:
  - Spring Boot
---

## 摘要

单元测试是我们工作中必不可少的一个环节，同时，我们在项目中验证自己的一些想法时，使用单元测试也是极其方便的。

本文将介绍如何在spring boot项目里进行单元测试，并展示一个基本示例。

## 使用方法

### 1.添加项目依赖

在pom.xml文件中添加相关依赖
![](http://img.couplecoders.tech/markdown-img-paste-20181031115344628.png)


### 2.创建测试包和测试类

![](http://img.couplecoders.tech/markdown-img-paste-20181031115506664.png)


<font color="red" size="4">一般新建的spring boot项目会自动完成前面两个步骤，这里写出来方便大家遇到问题调试。</font>

### 3.编写测试类

![](http://img.couplecoders.tech/markdown-img-paste-20181031154523199.png)

这里注入了项目中的一个普通的service，大家可以理解为你项目中任意一个方法。

添加了`before`和`after`来监测测试方法的运行。

图中的`testStatus()`方法，是对`analyticsService.rotateInt(103)`的监测，该方法返回一个int类型。

我们看一下`Assert.assertEquals()`方法的定义：
![](http://img.couplecoders.tech/markdown-img-paste-20181031160708280.png)

从定义中可以清楚地看到，当`期待值301`与`实际值analyticsService.rotateInt(103)`不相等时，打印message。

断言方法有许多种，有兴趣的可以取查看API。

### 4.运行测试用例

如果想测试单个方法，可以点击图中红框处运行，如果想运行整个类中的所有测试用例，可以点击类名左边的绿色按钮运行所有测试用例。

当我们的项目中有许多个测试类时，可以将测试类打包运行，具体方法这里不再赘述。

### 注意事项

#### @Ignore注解

当我们想在打包测试中忽略某几个未准备好的测试用例，只需要将该注解写在测试方法/测试类上即可。



## 参考链接

https://blog.csdn.net/weixin_39800144/article/details/79241620



<br>
完。

<br>
<br>
<br>
<br>
<h4>ChangeLog</h4>
2018-10-31 完成
<br>
<br>

**以上皆为个人所思所得，如有错误欢迎评论区指正。**

**欢迎转载，烦请署名并保留原文链接。**

**联系邮箱：huyanshi2580@gmail.com**

**更多学习笔记见个人博客------><a href="{{ site.baseurl }}/">呼延十</a>**
