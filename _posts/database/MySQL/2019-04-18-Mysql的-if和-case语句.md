---
layout: post
category: mysql
tags:
  - MySQL
---

## if语句

在查询中使用if,语法如下:

`if('表达式','真值','假值')`.

比如在数据中库存储的`性别`字段为1或者0,查询时想获取`男`,`女`.

此时可以使用如下语句:

```sql
select 
      s.name    '姓名',
      if(s.sex = 1,'男','女')  '性别'
from student s  
```

结果:
![2019-04-19-10-34-02](http://img.couplecoders.tech/2019-04-19-10-34-02.png)

## case语句

当两种选择是可以使用if,有多种选择的时候就需要case语句了.

比如在上例子中,我们存储了一些不希望暴露性别的用户,存储的值为3.此时想要查询可以:

```sql
select
  s.name    '姓名',
  case s.sex
    when 1 then '男' 
    when 0 then '女'
    else '保密'
  end       '性别'
from student s 
```

结果:

![2019-04-19-10-34-25](http://img.couplecoders.tech/2019-04-19-10-34-25.png)

## mysql的"\G"使用

在查询某个特别多字段的表的时候,输出的结果我们很难看明白,很想让`字段名` 和`值`一一对应来方便阅读,这时可以在语句末尾加上`\G`即可.

效果图:

![2019-04-19-10-34-51](http://img.couplecoders.tech/2019-04-19-10-34-51.png)



<br>
<br>
<br>
<br>
<h4>ChangeLog</h4>
2019-04-18 完
<br>
<br>

**以上皆为个人所思所得，如有错误欢迎评论区指正。**

**欢迎转载，烦请署名并保留原文链接。**

**联系邮箱：huyanshi2580@gmail.com**

**更多学习笔记见个人博客------><a href="{{ site.baseurl }}/">呼延十</a>**
