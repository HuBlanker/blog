---
layout: post
category: Linux
tags:
  - Linux
---


记忆力不咋好到底能不能做程序员啊，，，  

以下是对常用linux命令的记录，部分常用命令可能未做记录。

功能 | 命令 | 备注
---| --- | ---
创建文件夹 | mkdir 文件夹名|
创建文件 | vi 文件名 | 可以用来创建文件命令较多，我习惯使用vim
查看进程 | ps -aux &#124; grep tomcat | 搜索运行的tomcat 进程
查看进程 | ps -l | 可以查看此次登录后产生的进程
杀死进程 | kill -9 #### | ##为查看到的进程编号
安装deb包| dpkg -i xxx.deb | xxx为文件名
查看操作系统 | uname  | 详细使用见<a href="#1">uname命令</a>


1.Linux用户组管理

```shell
//添加用户组
# groupadd group1
//删除用户组
# groupdel group1
//修改用户组
# groupmod -g 102 group2
```

2.Linux用户管理

```shell
//添加用户并且指定其用户组
# useradd -s /bin/sh -g group –G adm,root gem
//添加用户并指定该用户主目录
# useradd –d /usr/sam -m sam
//删除用户并删除其主目录
# userdel -r sam
//修改当前用户密码
# passwd
//超级用户修改其他用户密码
# passwd username
//查看用户组文件
# vi /etc/group
//查看用户密码
# vi /etc/passwd
//给用户添加root权限，在group文件中将用户加入root权限组
```

3.查看操作记录

学会了这个，不仅可以及时甩锅？？？还可以学习大佬的操作记录，免得一直问大佬啦！
```bash
//查看当前用户的操作记录
# history
//root权限的用户查看其他用户的操作记录
# cat /home/用户名/.history
```


<h4 id="1">uname命令</h4>
uname 可以查看操作系统的详细信息，具体可以使用`uname --help`查看，在linux命令行下输入可得到如下结果：
![](http://img.couplecoders.tech/markdown-img-paste-20181028224402923.png)

翻译如下：
![1.png](http://img.couplecoders.tech/1.png)
，具体可以自行查看。



## 参考文章

<a href="http://www.runoob.com/linux/linux-user-manage.html">菜鸟教程 linux用户与用户组</a>



<br>
完。

<br>
<br>
<br>
<br>
<h4>ChangeLog</h4>
2018-10-28 完成
<br>
<br>

**以上皆为个人所思所得，如有错误欢迎评论区指正。**

**欢迎转载，烦请署名并保留原文链接。**

**联系邮箱：huyanshi2580@gmail.com**

**更多学习笔记见个人博客------><a href="{{ site.baseurl }}/">呼延十</a>**
