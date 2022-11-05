---
layout: post
category: 开发环境搭建
tags:
  - 开发环境搭建
  - MyBatis
---

很多工具都有一个共同点,第一眼看上去总是很麻烦,让人望而生畏,却忽略掉了他能带来的效率的提升,比如:Intellij的数据库连接功能,我用intellij快两年了,今天才第一次使用...

所以今天趁着周末,学习几个实用插件.

## 1.MyBatis-Generator

这个插件十分的知名,同时也有很多的衍生产品,基本目的是实现,dao层的逆向生成.

当你创建完数据库表格后,根据你的数据库表格,自动生成对应的model类以及mapper接口.

使用方式有许多种,比如通过maven引入插件的,<a href="http://huihui.couplecoders.tech/2018/11/08/SpringBoot-mybatis%E9%80%86%E5%90%91%E7%94%9F%E6%88%90%E5%B7%A5%E5%85%B7/">点击这里查看详情</a>.

上述方法需要自己修改配置文件,下面讲一种简单点的.

1.在intellij中搜索`better-mybatis-Generator`并下载.

![](http://img.couplecoders.tech/markdown-img-paste-20181202214111434.png)

2.使用intellij连接数据库,点击右键`database`->`+号`->`mysql`之后输入自己创尔数据库账号和密码.之后在某张表格上点击右键-`mybaits-Generator`.

![](http://img.couplecoders.tech/markdown-img-paste-20181202222725354.png)


3.界面很简单,我们可以在上面配置生成的dao层接口名称,实体类名称等等,但是sql不建议生成,sql还是自己写不容易造成失误以及慢查询等问题.

![](http://img.couplecoders.tech/markdown-img-paste-20181202223025297.png)

**这个插件操作十分简单,可以帮你批量生成类及一些方法,实属利器.**


**遇到问题可以查看官方教程,<a href="https://github.com/kmaster/better-mybatis-generator">点击这里哦</a>**
遇到问题可以查看官方教程.

## 2.gsonformat

日程工作中,会有许多根据JSON文本来生成POJO的场景,最典型的就是接入第三方的接口.

对方给你提供一个接口文档和一个可以调试的接口,你需要结仇他的数据并处理.如果这个接口返回的字段很多,那么根据返回值构造POJO将是一场灾难.

比如:我接过的墨迹天气的接口......

这种重复的工作怎么可以有我们来完成呢?使用gsonformat!

1.首先下载安装,在intellij插件中搜索即可.

2.新建一个实体类,类名取自己想取的类名,如:Human.

![](http://img.couplecoders.tech/markdown-img-paste-20181202220414489.png)

3.在属性的位置按快捷键`command+n`或者邮件鼠标点击`generate`,点击`gsonformat`.

4.之后将你的json文本copy到输入框中.
![](http://img.couplecoders.tech/markdown-img-paste-2018120222072910.png)

5.点击确定,在出现的页面中对生成的类进行一些调整.列名及参数类型都可以进行编辑.

![](http://img.couplecoders.tech/markdown-img-paste-20181202220844749.png).

**图中仅为示例,实际上我亲测过较为复杂的json文本,仍可以识别正确,只是在对子类的取名上不太智能,需要自己修改子类名称.**

完。

<br>
<br>
<br>
<h4>ChangeLog</h4>
2018-12-02 完成
<br>
<br>


**以上皆为个人所思所得，如有错误欢迎评论区指正。**

**欢迎转载，烦请署名并保留原文链接。**

**联系邮箱：huyanshi2580@gmail.com**

**更多学习笔记见个人博客------><a href="{{ site.baseurl }}/">呼延十</a>**
