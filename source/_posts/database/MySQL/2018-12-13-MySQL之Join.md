---
layout: post
tags:
  - MySQL
---

## 介绍

MySQL 中的join可以分为如下三类:

* INNER JOIN（内连接,或等值连接）：获取两个表中字段匹配关系的记录。
* LEFT JOIN（左连接）：获取左表所有记录，即使右表没有对应匹配的记录。
* RIGHT JOIN（右连接）： 与 LEFT JOIN 相反，用于获取右表所有记录，即使左表没有对应匹配的记录。

## 语法

`... FROM table1 INNER|LEFT|RIGHT JOIN table2 ON conditiona`

## 实例

使用的测试数据库:
```SQL
mysql> select * from student;
+-----------+----------+
| name      | classNum |
+-----------+----------+
| huyanshi  |        5 |
| hublanker |        5 |
+-----------+----------+
2 rows in set (0.00 sec)

mysql> select * from student_grade;
+----------+-------+
| name     | grade |
+----------+-------+
| huyanshi |   100 |
| hahhh    |    80 |
+----------+-------+
2 rows in set (0.00 sec)

mysql>

```

### 1. 内连接

对上述两张表进行内连接,连接条件为name字段相等.

会返回在两张表中都存在的数据.

```SQL
mysql> select * from student join student_grade on student.name = student_grade.name ;
+----------+----------+----------+-------+
| name     | classNum | name     | grade |
+----------+----------+----------+-------+
| huyanshi |        5 | huyanshi |   100 |
+----------+----------+----------+-------+
1 row in set (0.00 sec)

mysql>
```

当没有连接条件时,join相当于cross join,即求笛卡尔积.

```sql
mysql> select * from student join student_grade;
+-----------+----------+----------+-------+
| name      | classNum | name     | grade |
+-----------+----------+----------+-------+
| huyanshi  |        5 | huyanshi |   100 |
| hublanker |        5 | huyanshi |   100 |
| huyanshi  |        5 | hahhh    |    80 |
| hublanker |        5 | hahhh    |    80 |
+-----------+----------+----------+-------+
4 rows in set (0.00 sec)

mysql>
```
笛卡尔积在一些场景中有应用,比如:A表示所有学生的记录,B表是所有课程的记录,那么AB两张表的笛卡尔积可以表示所有可能的选课情况.

## 2.左外连接

对上述两张表进行左外连接,连接条件为name相等.可以看到,当`huyanshi`有相同的字段在第二张表时,显示连接后的所有信息,第二张表没有符合条件的信息时,相关字段为空.
```sql
mysql> select * from student left join student_grade on student.name = student_grade.name ;
+-----------+----------+----------+-------+
| name      | classNum | name     | grade |
+-----------+----------+----------+-------+
| huyanshi  |        5 | huyanshi |   100 |
| hublanker |        5 | NULL     |  NULL |
+-----------+----------+----------+-------+
2 rows in set (0.00 sec)
mysql>
```
## 3.右外连接

与左外连接相反.

```SQL
mysql> select * from student right join student_grade on student.name = student_grade.name ;
+----------+----------+----------+-------+
| name     | classNum | name     | grade |
+----------+----------+----------+-------+
| huyanshi |        5 | huyanshi |   100 |
| NULL     |     NULL | hahhh    |    80 |
+----------+----------+----------+-------+
2 rows in set (0.00 sec)

mysql>
```

## 注意事项

### 1. 当外连接的连接条件有对单表进行限定的时候,先进行单表的过滤,之后进行连接.但是并不影响结果的行数.

```SQL
mysql> select * from student left join student_grade on student.name = student_grade.name and student_grade.grade = 80 ;
+-----------+----------+------+-------+
| name      | classNum | name | grade |
+-----------+----------+------+-------+
| huyanshi  |        5 | NULL |  NULL |
| hublanker |        5 | NULL |  NULL |
+-----------+----------+------+-------+
2 rows in set (0.00 sec)

mysql>
```

这个例子中,先对第二张表进行了grade=80的过滤,然后才进行了连表.但是在过滤后,并没有和第一张表中相同name的值了,因此第二张表全部为null.


完。


<br>
<br>
<br>
<br>
<h4>ChangeLog</h4>
2018-12-12 完
<br>
<br>

**以上皆为个人所思所得，如有错误欢迎评论区指正。**

**欢迎转载，烦请署名并保留原文链接。**

**联系邮箱：huyanshi2580@gmail.com**

**更多学习笔记见个人博客------><a href="{{ site.baseurl }}/">呼延十</a>**
