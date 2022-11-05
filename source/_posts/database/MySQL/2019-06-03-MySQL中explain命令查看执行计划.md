---
layout: post
tags:
  - Java
  - 读书笔记
  - 高性能MySQL
---
## 目录


- [目录](#目录)
- [前言](#前言)
- [id](#id)
- [select_type](#select_type)
- [table](#table)
- [partitions](#partitions)
- [type](#type)
- [possible_keys](#possible_keys)
- [key](#key)
- [key_len](#key_len)
- [ref](#ref)
- [rows](#rows)
- [extra](#extra)
- [参考文章](#参考文章)


## 前言

使用explain命令可以查看一条查询语句的执行计划,这篇文章记录一下查询计划的各个属性的值极其含义.

![2019-06-03-20-47-12](http://img.couplecoders.tech/2019-06-03-20-47-12.png)

那么我们按照图中的顺序逐个字段的看一下.

<font color="red">本文采用官网的数据库样本,下载地址:[MySQL官方数据库](https://dev.mysql.com/doc/index-other.html)</font>

## id

一组数据,表示任务被执行的顺序,序号越大的任务越先执行.

## select_type




id | select_type |description
--- | --- | ---
| 1 | SIMPLE| 不包含任何子查询或union等查询
| 2| PRIMARY | 包含子查询最外层查询就显示为 PRIMARY
| 3| SUBQUERY| 在select或 where字句中包含的查询
| 4 | DERIVED | from字句中包含的查询
| 5 | UNION | 出现在union后的查询语句中
| 6 | UNION RESULT | 从UNION中获取结果集，例如上文的第三个例子

## table

查询的数据表，当从衍生表中查数据时会显示<derivedx> x 表示对应的执行计划id。


## partitions

表的分区字段,没有分区的话则为null.

## type

这条查询语句访问数据的类型.所有可取值的范围:

* ALL   扫描全表数据
* index 使用索引
* range 索引范围查找
* ref 非唯一性索引扫描，返回匹配某个单独值的所有行。常见于使用非唯一索引即唯一索引的非唯一前缀进行的查找
* eq_ref 唯一性索引扫描，对于每个索引键，表中只有一条记录与之匹配。常见于主键或唯一索引扫描
* const,system 当MySQL对查询某部分进行优化，并转换为一个常量时，使用这些类型访问
* .NULL：MySQL在优化过程中分解语句，执行时甚至不用访问表或索引


## possible_keys

这次查询可能使用的索引,但是不一定是真正使用的索引.

## key

查询真正使用的索引,若没有使用索引，显示为NULL.

## key_len

使用索引的长度,在使用联合索引的时候可以根据这一列来推算使用了哪些最左前缀索引.

计算方式:

* 所有字段如果没有设置为`not null`,则需要加一个字节.
* 定长字段占用实际的字节长度,比如:int占用4个字节,datatime占用4个字节.
* 变长字段占用多占用两个字节,比如varchar(20)将会占用20*4+2 = 82个字节.
* 不同的字符集占用字节不一样,上面举例是使用的utf8mb4字符集.

## ref
表示上述表的连接匹配条件，即哪些列或常量被用于查找索引列上的值

## rows
返回估算的结果集数目，并不是一个准确的值。

## extra

包含一些其他信息,常见的有以下几种:

* Using index 表示相应的select操作中使用了覆盖索引（Covering Index）
*  Using where 表示拿到记录后进行“后过滤”（Post-filter）,如果查询未能使用索引，Using where的作用只是提醒我们MySQL将用where子句来过滤结果集
* Using temporary 表示mysql在这个查询语句中使用了临时表.
* Using filesort 表示使用了文件排序,即查询中的排序无法通过索引来完成.


## 参考文章

[MySQL官方文档](https://dev.mysql.com/doc/refman/5.7/en/explain-output.html#explain-extra-information)

<br>
完。
<br>
<br>
<br>
<br>
<h4>ChangeLog</h4>
2019-06-03 完成
<br>
<br>


**以上皆为个人所思所得，如有错误欢迎评论区指正。**


**欢迎转载，烦请署名并保留原文链接。**


**联系邮箱：huyanshi2580@gmail.com**


**更多学习笔记见个人博客------><a href="{{ site.baseurl }}/">呼延十</a>**