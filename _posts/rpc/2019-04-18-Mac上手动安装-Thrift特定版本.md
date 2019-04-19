---
layout: post
category: [Thrift,RPC,开发环境搭建]
tags:
  - Thrift
  - RPC
  - 开发环境搭建
---

## 背景

在上文中[Thrift入门](http://huyan.couplecoders.tech/thrift/rpc/2019/03/28/Thrift%E5%85%A5%E9%97%A8%E5%8F%8A-Java-%E5%AE%9E%E7%8E%B0%E7%AE%80%E5%8D%95Demo/)中,提到了在Mac环境的安装,使用的是`brew install thrift`,这样子会自动安装最新版本.

但是线上代码库使用的是老版本,在本地编译就会出现错误,所以需要手动安装一个老版本.在本文中手动安装`0.11.0`.

## 步骤

#### 1.查看brew 支持的thrift版本

```shell
brew info thrift
brew search thrift
```

第一个命令会查看最新的thrift,第二个命令会查找支持brew的所有thrift版本,如果你需要的版本在里面,直接安装即可.

![2019-04-18-23-52-27](http://img.couplecoders.tech/2019-04-18-23-52-27.png)

#### 2.卸载老版本的thrift

使用brew进行卸载

```
brew uninstall thrift
```

#### 3. 安装thrift的依赖包

```
brew install boost openssl libevent bison
```

**NOTE:**

如果你想安装超过`0.9.3`的版本,那么你需要检查一下`bison`的版本,因为如果你的bison版本低于`2.5`,在安装thrift的时候会报错.**configure: error: Bison version 2.5 or higher must be installed on the system!**

执行:`bison -V`查看版本,如果低于2.5则进行以下操作.

执行:`brew install bison` 安装最新版本的bison.

之后进入`/usr/bin`目录下,将mac默认的bison文件移除掉,将通过brew安装的bison拷贝到这里来.

```
cd /usr/bin
sudo mv bison bison111
sudo cp /usr/local/Cellar/bison/3.0.4/bin/bison ./
```

如果你的OX版本过高,会出现使用sudo权限也无法在`/usr/bin`目录操作的情况,需要首先获取权限.关闭`Rootless`.

可以参照[这篇文章](https://www.jianshu.com/p/22b89f19afd6).

#### 4.安装thrift

在官网下载你想要的的版本的tar包.

[官网地址](http://archive.apache.org/dist/thrift/)

之后依次执行以下命令安装thrift.
```
tar -zxvf thrift-0.11.0  
cd thrift-0.11.0
./configure 
make 
make install  
```

5. 验证一下

执行`thrift -version`,如果输出正确的版本即为成功.

## 参考文章

https://blog.csdn.net/liaomengge/article/details/55001579
https://www.jianshu.com/p/22b89f19afd6



<br>
<br>
<br>
<br>
<h4>ChangeLog</h4>
2019-04-18     完成
<br>
<br>


**以上皆为个人所思所得，如有错误欢迎评论区指正。**

**欢迎转载，烦请署名并保留原文链接。**

**联系邮箱：huyanshi2580@gmail.com**

**更多学习笔记见个人博客------><a href="{{ site.baseurl }}/">呼延十</a>**
