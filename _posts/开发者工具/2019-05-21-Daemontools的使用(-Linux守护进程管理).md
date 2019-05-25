---
layout: post
category: [Linux,轮子]
tags:
  - Linux
  - 轮子
---


## 目录

- [目录](#目录)
- [前言](#前言)
- [安装](#安装)
- [使用](#使用)
- [参考文章](#参考文章)


## 前言

Daemontools是一个在linux上可以进行守护进程管理的工具,当我们有一些程序需要常驻后台,万一不小心挂掉了他可以帮我们重启服务.

[这是他的官网,很简陋但是很有用](https://cr.yp.to/daemontools/install.html)

## 安装

1. 新建文件夹

```shell
    mkdir -p /package
    chmod 1755 /package
    cd /package
```

2. 下载Daemontools然后解压.

```shell
     gunzip daemontools-0.76.tar
     tar -xpf daemontools-0.76.tar
     rm -f daemontools-0.76.tar
     cd admin/daemontools-0.76
```

3. 安装

```shell

package/install

```

## 使用

进行完上面简单的步骤,就可以开始使用了,我们模拟一种简单的使用场景.

首先我们有一个服务想要部署,那么在我们习惯的地方建立文件夹,放进入我们的jar包,log文件等等.比如在`~/test`下.

![2019-05-21-23-41-02](http://img.couplecoders.tech/2019-05-21-23-41-02.png)

之后我们编写我们的启动脚本,我们可以在`run`文件中写入,比如这里我们写个脚本,输出`1-49`.

```shell
#!/bin/bash

for i in {1..49}
do
	echo $i >> test.log
done

```

然后,将整个`test`文件建立一个软连接到`/service`下,即在`/service`下执行:`sudo ln -s ~/test`.

到此,所有前期工作已经完成了,我们来验证一下,

执行:`sudo svc -u ./`,即启动当前目录下的服务.然后持续观察log,会发现,Daemontools将run脚本无限次的执行下去,所以log中会不断的循环打印`1-49`.

当我们想要停止服务的时候呢,使用`-d`参数.`sudo svc -d ./`.

该命令还支持以下参数:

```
-u : up, 如果services没有运行的话，启动它，如果services停止了，重启它。 
-d : down, 如果services正在运行的话，给它发送一个TERM(terminate)信号，然后再发送一个CONT（continue）信号，在它停止后，不再启动它。 
-o : once, 如果services没有运行，启动它，但是在它停止后不再启动了。就是只运行一次。 
-p : pause, 给services发送一个停止信号。 
-c : continue, 给services发送一个CONT信号。 
-h : hang up， 给services发送一个HUP信号。 
-a : alarm， 给services发送一个ALRM信号。 
-i ： interrupt， 给services发送一个INT信号。 
-t : Terminate, 给services发送一个TERM信号。 
-k : kill, 给services发送一个KILL信号。 
-x : exit, supervise在services停止后会立刻退出， 但是值得注意的是，如果你在一个稳定的系统中使用了这个选项，你已经开始犯错了：supervise被设计成为永远运行的。 

```

可以按需取用,不过最常用的还是`-d`,`-u`,毕竟组合起来就是重启,重启大法好啊.

## 参考文章

https://cr.yp.to/daemontools.html

<br>
完。
<br>
<br>
<br>
<br>
<h4>ChangeLog</h4>
2019-05-21 完成
<br>
<br>
**以上皆为个人所思所得，如有错误欢迎评论区指正。**


**欢迎转载，烦请署名并保留原文链接。**


**联系邮箱：huyanshi2580@gmail.com**


**更多学习笔记见个人博客------><a href="{{ site.baseurl }}/">呼延十</a>**