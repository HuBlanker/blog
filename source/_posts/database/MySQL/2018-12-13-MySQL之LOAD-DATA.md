---
layout: post
category: mysql
tags:
  - MySQL
---

load data很适合用来做数据迁移,在数据量比较大的时候,导出及导入的性能仍然不错.

## 导出数据

```SQL
mysql> select * from student into outfile '/var/lib/mysql-files/ttt.txt';
Query OK, 2 rows affected (0.00 sec)

mysql>
```

该操作会将所查询的表格中的所有数据写入txt文件中,可以设定分隔符等一些信息,在这里不做演示.

## 导入数据


```sql
mysql> load data infile '/var/lib/mysql-files/tt.txt' into table student;
Query OK, 2 rows affected (0.00 sec)
Records: 2  Deleted: 0  Skipped: 0  Warnings: 0
```

该操作会按照默认分隔符,从文件中读取数据并插入到指定的数据表中.


## 直接将数据库导入到另一台主机

使用以下命令将导出的数据直接导入到远程的服务器上，但请确保两台服务器是相通的，是可以相互访问的：
```SQL
$ mysqldump -u root -p database_name | mysql -h other-host.com database_name
```


完。

## 注意事项

在导出数据时,会出现以下错误.

**ERROR 1290 (HY000): The MySQL server is running with the --secure-file-priv option so it cannot execute this statement**

```sql
mysql> select * from student into outfile '~/Desktop/tt.txt';
ERROR 1290 (HY000): The MySQL server is running with the --secure-file-priv option so it cannot execute this statement
mysql>
```

这是因为mysql默认的导出路径不是指定路径,你可以使用`show global variables like '%secure_file_priv%'`命令查看mysql的默认路径.

```sql
mysql> show global variables like '%secure_file_priv%';
+------------------+-----------------------+
| Variable_name    | Value                 |
+------------------+-----------------------+
| secure_file_priv | /var/lib/mysql-files/ |
+------------------+-----------------------+
1 row in set (0.00 sec)

```

之后可以选择将文件导出到默认路径或者修改默认路径.

修改方法见<a href="https://blog.csdn.net/fdipzone/article/details/78634992">mysql5.7导出数据提示--secure-file-priv选项问题的解决方法</a>


我选择导出到默认路径,,因为我不想重启mysql...

完.

<br>
<br>
<br>
<br>
<h4>ChangeLog</h4>
2018-12-14 完
<br>
<br>

**以上皆为个人所思所得，如有错误欢迎评论区指正。**

**欢迎转载，烦请署名并保留原文链接。**

**联系邮箱：huyanshi2580@gmail.com**

**更多学习笔记见个人博客------><a href="{{ site.baseurl }}/">呼延十</a>**
