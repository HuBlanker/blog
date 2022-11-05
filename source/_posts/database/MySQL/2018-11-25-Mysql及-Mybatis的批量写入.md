---
layout: post
tags:
  - MySQL
  - MyBatis
---

在工作中,我们经常需要提供一些批量插入的接口,常见使用场景比如:初始化.

这时候如果在程序内部使用循环的方式插入,则会非常的慢,因为MySQL的每一次插入都需要创建连接,关闭连接,性能十分低下.

所幸MySQL有提供批量插入的方法,即建立一次数据库连接,将所有数据进行插入.

下面记录一下MySQL中的批量插入以及使用MyBatis进行批量插入的一些方法.


## MySQL的批量插入语法

MySQL的批量插入十分简单,在正常的插入语句VALUES后增加多个值得排列即可,值之间使用逗号分隔.

```SQL
insert into student values ("huyanshi",1),("xiaohuyan",2);
```

![](http://img.couplecoders.tech/markdown-img-paste-20181125014726198.png)

## Mybatis的批量插入(MySQL)

MyBatis的批量插入,其实底层使用的也是MySQL的上述功能,这里只是记录下载代码层面如何实现.

首先在Mapper层中定义如下方法:

```java
int addStudentBatch(@Param("students") List<Student> students);
```

然后在对应的XML文件中写入如下语句:

```xml
<insert id="addStudentBatch">
  insert into
  student(name,class)
  values
  <foreach collection ="students" item="student" index= "index" separator =",">
    (
    #{student.name},
    #{student.class}
    )
  </foreach >

</insert>
```

注意:Collection中的名字与mapper中的参数名相对应,item与类名相对应.


完。


<br>
<br>
<br>
<br>
<h4>ChangeLog</h4>
2018-11-25 完.
<br>
<br>

**以上皆为个人所思所得，如有错误欢迎评论区指正。**

**欢迎转载，烦请署名并保留原文链接。**

**联系邮箱：huyanshi2580@gmail.com**

**更多学习笔记见个人博客------><a href="{{ site.baseurl }}/">呼延十</a>**
