---
layout: post
category: MySQL
tags:
  - MySQL
---

在<a href="{{ site.baseurl }}/mysql/2018/09/02/mysql-常用命令记录与数据导入导出/">mysql常用命令与数据导入导出</a>中记录过常用的sql语句,其中包括了插入语句.

今天单独记录一下mysql的插入语句的更多用法.

## 本文测试使用数据库
数据库建表语句及当前的数据:
```sql

mysql> show create table student;
+---------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| Table   | Create Table                                                                                                                                                                            |
+---------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| student | CREATE TABLE `student` (
  `name` varchar(45) NOT NULL COMMENT '姓名',
  `classNum` int(11) NOT NULL COMMENT '班级号',
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8      |
+---------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
1 row in set (0.00 sec)

mysql> select * from student;
+-----------+----------+
| name      | classNum |
+-----------+----------+
| hublanker |        5 |
| huyanshi  |        5 |
| test1     |       10 |
+-----------+----------+
3 rows in set (0.00 sec)
```

## 1.insert into

这是最常用的插入语句,具体示例如下:

```SQL
insert into student(name,classNum) values("test2",20);
```

在数据库中成功插入了一条:名字为`test2`,班级为`20`的数据.


在使用`insert into`的时候,经常会有一个问题,就是主键冲突怎么办?

在数据库中插入主键重复的数据,会导致出错,如下:
```sql
mysql> insert into student(name,classNum) values("test2",20);
ERROR 1062 (23000): Duplicate entry 'test2' for key 'PRIMARY'
mysql>
```

那么重复的值我们需要制定一些策略,这就用到了下面两个语句.

## replace into

当主键重复时,我们想`不要报错,用新的数据替换掉旧的数据`.

可以使用replace语句,示例如下:

```SQL
mysql> select * from student;
+-----------+----------+
| name      | classNum |
+-----------+----------+
| hublanker |        5 |
| huyanshi  |        5 |
| test1     |       10 |
| test2     |       20 |
+-----------+----------+
4 rows in set (0.00 sec)

mysql> replace into student(name,classNum) values("test2",21);
Query OK, 2 rows affected (0.00 sec)

mysql> select * from student;
+-----------+----------+
| name      | classNum |
+-----------+----------+
| hublanker |        5 |
| huyanshi  |        5 |
| test1     |       10 |
| test2     |       21 |
+-----------+----------+
4 rows in set (0.00 sec)
```

我们试图插入一条`name=test2,classNum=21`的数据,但是`test2`在数据库中主键已经存在,那么使用replace语句执行插入后,会发现,`主键为test2的值仍然存在,但是classNum替换为了21`.

## insert ignore into

当主键重复时,有些场景下我们想`不要报错,忽略掉新的数据就好`.

这种情形下我们可以使用`insert ignore into`语句,示例如下:

```SQL
mysql> select * from student;
+-----------+----------+
| name      | classNum |
+-----------+----------+
| hublanker |        5 |
| huyanshi  |        5 |
| test1     |       10 |
| test2     |       21 |
+-----------+----------+
4 rows in set (0.00 sec)

mysql> insert ignore into student(name,classNum) values("test2",22);
Query OK, 0 rows affected, 1 warning (0.00 sec)

mysql> select * from student;
+-----------+----------+
| name      | classNum |
+-----------+----------+
| hublanker |        5 |
| huyanshi  |        5 |
| test1     |       10 |
| test2     |       21 |
+-----------+----------+
4 rows in set (0.00 sec)
```

我们试图向数据库中插入一条`name=test2,classNum=22`的数据,但是`test2`主键已经存在,那么此条插入语句被忽略掉,可以看到在执行该语句前后,数据库的值没有任何变化.


## 总结

在日常测试机生产中,面对各种各样的情形,我们可以灵活使用上面几种插入语句,来达到我们的目的.



<br>
<br>
<br>
<br>
<h4>ChangeLog</h4>
2018-12-16 完成
<br>
<br>

**以上皆为个人所思所得，如有错误欢迎评论区指正。**

**欢迎转载，烦请署名并保留原文链接。**

**联系邮箱：huyanshi2580@gmail.com**

**更多学习笔记见个人博客------><a href="{{ site.baseurl }}/">呼延十</a>**
