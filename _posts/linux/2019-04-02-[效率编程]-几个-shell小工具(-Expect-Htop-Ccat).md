---
layout: post
category: [开发者工具,效率编程,Linux]
tags:
  - 开发者工具
  - 效率编程
  - Linux
---

## 背景介绍

总结记录几个shell小工具,都是很常用且很好用的东西.

* expect : 实现人机交互的一个命令行工具
* ccat : linux 下上色版本的cat
* htop : 上色增强版本的top
* 软连接
* z: 快速的cd

最终实现了,高效的登录至服务器,不用输入密码.以及使用ccat查看源码,使用htop观察机器内存等信息.

## Expect

#### 介绍

*Expect是Unix系统中用来进行自动化控制和测试的软件工具，由Don Libes制作.*

通俗的讲,就是允许你在脚本里设定一些"原本要手动输入"的东西.

#### 安装

mac OS: `brew install expect`

#### 几个重要的命令

* send:向进程发送字符串，用于模拟用户的输入。注意一定要加\r回车
* expect:从进程接收字符串
* spawn:启动进程(由spawn启动的进程的输出可以被expect所捕获)
* interact:用户交互

#### Demo

```shell
#!/usr/local/bin/expect
set server [lindex $argv 0]
set timeout -1
set passwd XXXXXXX
spawn ssh jump
expect {
    "*Enter passphrase*" {send "$passwd\r";exp_continue}
    "*Welcome to*" {send "$server\r";}
}
interact
```

这是实现的一个expect的简单应用.实现了自动登录跳板机并选择机器进行登入.具体解释一下.

* 第一行注释,说明此文件使用expect解释器
* 第二行设置一个变量,`server=输入的第一个参数`
* 第三行设置一个变量,`passwd=密码`
* 第四行新起了一个进程来执行`ssh jump`命令,
* expect命令匹配到`Enter passphrase`时输入密码.
* 匹配到`welcome*`时输入`server`.
* 交给用户来交互

<a href="http://xstarcd.github.io/wiki/shell/expect.html" 很不错的expect教程</a> 中有多个常用的expect的示例.可以参考.


## ccat

#### 安装

`brew install ccat`

#### 效果

输出一个java文件

![2019-04-02-17-34-21](http://img.couplecoders.tech/2019-04-02-17-34-21.png)

## htop

#### 安装

`brew install htop`

#### 常用功能键
```
            F1 : 查看htop使用说明
            F2 : 设置
            F3 : 搜索进程
            F4 : 过滤器，按关键字搜索
            F5 : 显示树形结构
            F6 : 选择排序方式
            F7 : 减少nice值，这样就可以提高对应进程的优先级
            F8 : 增加nice值，这样可以降低对应进程的优先级
            F9 : 杀掉选中的进程
            F10 : 退出htop

            / : 搜索字符
            h : 显示帮助
            l ：显示进程打开的文件: 如果安装了lsof，按此键可以显示进程所打开的文件
            u ：显示所有用户，并可以选择某一特定用户的进程
            s : 将调用strace追踪进程的系统调用
            t : 显示树形结构

            H ：显示/隐藏用户线程
            I ：倒转排序顺序
            K ：显示/隐藏内核线程    
            M ：按内存占用排序
            P ：按CPU排序    
            T ：按运行时间排序

            上下键或PgUP, PgDn : 移动选中进程
            左右键或Home, End : 移动列表    
            Space(空格) : 标记/取消标记一个进程。命令可以作用于多个进程，例如 "kill"，将应用于所有已标记的进程
```

#### 效果

![2019-04-02-17-35-13](http://img.couplecoders.tech/2019-04-02-17-35-13.png)

在这个界面,可以使用`f3`搜索,`f4`过滤,具体操作


## linux设置软连接

经过上面的第一个步骤,我们有了一个`jump`的脚本,但是每次都要去执行脚本也是一件非常麻烦的事情.

我们希望可以像使用`mysql`等等命令那样在全局都可以.

这里有两种实现方式:

#### 软连接

在`/usr/local/bin`目录下设置一个目标脚本的软连接即可.

```bash
ln -s ~/jump /usr/local/bin/jump
```

#### 使用zsh的全局别名

在~/.zshrc文件中加入`alias="~/jump"`即可.


## Z

这个名字真的是简洁.

这是一个快速管理你的cd命令的脚本.<a href="https://github.com/rupa/z">github仓库</a>

基本实现就是:

你安装了z,之后你的cd会被记录到.z文件,然后当你想切换目录的时候,只需要`z xx + tab`即可. xx是你想去的目录的部分名字即可,z使用正则表达式来匹配,所以只要你输入的`xx`足够`不重复`,基本是无敌精准的.

#### 安装

使用zsh的朋友,打开`~/.zshrc`,将其中的`plugins={git}` 添加z,变成`plugins={git z}`,然后执行`source ~/.zshrc`即可.

#### 使用

先瞎cd几下.然后`z`:

![2019-04-02-20-25-53](http://img.couplecoders.tech/2019-04-02-20-25-53.png)

## 参考文章

<a href="http://xstarcd.github.io/wiki/shell/expect.html"> 很不错的expect教程</a>

<a href="http://xstarcd.github.io/wiki/shell/expect_handbook.html"> 中文版expect教程</a>


完.

<br>
<br>
<br>
<br>
<h4>ChangeLog</h4>
2019-04-02      完成
2019-04-03      添加Z
<br>
<br>


**以上皆为个人所思所得，如有错误欢迎评论区指正。**

**欢迎转载，烦请署名并保留原文链接。**

**联系邮箱：huyanshi2580@gmail.com**

**更多学习笔记见个人博客------><a href="{{ site.baseurl }}/">呼延十</a>**
