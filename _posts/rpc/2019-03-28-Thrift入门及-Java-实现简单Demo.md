---
layout: post
category: [Thrift,RPC]
tags:
  - Thrift
  - RPC
---

本文示例代码: <a href="https://github.com/HuBlanker/someprogram/tree/master/javaprogram/src/main/java/thrift_demo">github传送门</a>

本文并未与spring boot集成,仅实现了demo.可以将本文中的类作为spring中的bean使用即可.

其实一开始是想集成的,后来发现thrift已经够头大了,就暂时放弃了,后面单独写一篇吧.集成比较简单一些.

## 背景介绍

我终于从一个写Http接口的转职到了写RPC接口的.(微笑)

所以我需要学习一下RPC框架,至于为什么学习`Thrift`而不是`Dubbo`或者其他,因为工作在用`Thrift`,所以先学习一下这个咯.

## Thrift介绍(摘自维基百科)

*Thrift是一种接口描述语言和二进制通讯协议，[1]它被用来定义和创建跨语言的服务。[2]它被当作一个远程过程调用（RPC）框架来使用，是由Facebook为“大规模跨语言服务开发”而开发的。它通过一个代码生成引擎联合了一个软件栈，来创建不同程度的、无缝的跨平台高效服务，可以使用C#、C++（基于POSIX兼容系统[3]）、Cappuccino、[4]Cocoa、Delphi、Erlang、Go、Haskell、Java、Node.js、OCaml、Perl、PHP、Python、Ruby和Smalltalk。[5]虽然它以前是由Facebook开发的，但它现在是Apache软件基金会的开源项目了。该实现被描述在2007年4月的一篇由Facebook发表的技术论文中，该论文现由Apache掌管*

## 详细步骤

### 1. 安装Thrift

这里只提供Mac OS的安装方法,其他平台的可以在网上搜索一下.

在shell里面执行:

`brew install thrift`.

如果未安装brew,强烈建议安装.

安装命令:

`/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"`

### 2.新建项目

新建一个Maven项目并在其`pom.xml`中添加下列依赖项.

```xml
    <dependency>
      <groupId>org.apache.thrift</groupId>
      <artifactId>libthrift</artifactId>
      <version>0.12.0</version>
    </dependency>
```
### 3. 定义接口文件

注: thrift文件的具体语法这里不做说明,比较简单,仅在附录中添加常用的一些类型备忘.需要的朋友可直接在文末查看.

这里写的是个demo,我们定义两个接口,一个是根据id查询用户,一个是判断用户是否存在.

```thrift
namespace java thrift_demo

service  UserService {
  string getName(1:i32 id)
  bool isExist(1:string name)
}
```

### 4. 根据接口定义生成java文件

在命令行中进入`user.thrift`所在的目录,然后执行`thrift -r -gen java user.thrift`.

会发现在当前目录下生成了`gen-java`文件夹,将文件夹中的`userService`文件copy到项目名录下.

这个文件定义了`接口`,`入参`,`出参`,是客户端和服务器共同使用的一个文件.也是thrift框架很重要的一部分.

### 5.编写服务端的具体实现.

服务端要必须实现`UserService`中的`UserService.Iface`接口,为其提供具体的业务逻辑.

代码如下:

```java
package thrift_demo.server;

import org.apache.thrift.TException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import thrift_demo.UserService;

/**
 * Created by pfliu on 2019/03/28.
 */
public class UserServiceImpl implements UserService.Iface {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    private final static String HUYANSHI = "HUYANSHI";

    @Override
    public String getName(int id) throws TException {
        logger.info("received getName, id = {}:", id);
        return HUYANSHI;
    }

    @Override
    public boolean isExist(String name) throws TException {
        logger.info("receive isExist, name = {}", name);
        return HUYANSHI.equals(name);
    }
}

```


### 6. 编写服务器启动类

服务启动类不涉及到业务逻辑,只是调用thrift的一些方法,监听tcp的某个端口.文中是`2345`端口.

```java
package thrift_demo.server;

import org.apache.thrift.protocol.TBinaryProtocol;
import org.apache.thrift.server.TServer;
import org.apache.thrift.server.TThreadPoolServer;
import org.apache.thrift.transport.TServerSocket;
import org.apache.thrift.transport.TServerTransport;
import org.apache.thrift.transport.TTransportFactory;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import thrift_demo.UserService;

/**
 * Created by huyanshi on 2019/03/28.
 */
public class Server {

    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    private void startServer() {
        UserService.Processor processor = new UserService.Processor<UserService.Iface>(new UserServiceImpl());
        try {
            TServerTransport transport = new TServerSocket(2345);
            TThreadPoolServer.Args tArgs = new TThreadPoolServer.Args(transport);
            tArgs.processor(processor);
            tArgs.protocolFactory(new TBinaryProtocol.Factory());
            tArgs.transportFactory(new TTransportFactory());
            tArgs.minWorkerThreads(10);
            tArgs.maxWorkerThreads(20);
            TServer server = new TThreadPoolServer(tArgs);
            server.serve();
        } catch (Exception e) {
            logger.error("thrift服务启动失败", e);
        }
    }

    public static void main(String[] args) {
        Server server = new Server();
        server.startServer();
    }
}
```

上面实现的是单线程,仅做demo,日常启动多个线程的情况比较多.

### 7. 编写客户端代码

客户端代码比较简单,创建了客户端调用对应的方法即可.

平时我们做服务端开发的时候,一般不用开发客户端,仅在测试类中做简单实现即可.

```java
package thrift_demo.client;

import org.apache.thrift.TException;
import org.apache.thrift.protocol.TBinaryProtocol;
import org.apache.thrift.protocol.TProtocol;
import org.apache.thrift.transport.*;
import thrift_demo.UserService;

/**
 * Created by huyanshi on 2019/03/28.
 */
public class Client {
    private static final String SERVER_IP = "localhost";
    private static final int SERVER_PORT = 2345;//Thrift server listening port
    private static final int TIMEOUT = 3000;

    private void startClient(String userName) {
        TTransport transport = null;
        try {
            transport = new TSocket(SERVER_IP, SERVER_PORT, TIMEOUT);
            // 协议要和服务端一致
            TProtocol protocol = new TBinaryProtocol(transport);
            UserService.Client client = new UserService.Client(protocol);
            transport.open();
            System.out.println(client.getName(1));
            System.out.println(client.isExist("haha"))
        } catch (TTransportException e) {
            e.printStackTrace();
        } catch (TException e) {
            e.printStackTrace();
        } finally {
            if (null != transport) {
                transport.close();
            }
        }
    }

    public static void main(String[] args) {
        Client client = new Client();
        client.startClient("Tom");
    }

}
```

### 8. 启动服务端

可以看到上面的服务端启动类,就是一个包含`main`方法的类.直接启动即可.

### 9. 启动客户端进行测试.

同上,启动即可.

可以分别查看两端日志是否符合预期.

## 总结

<font color="red">前文的所有步骤进行了验证,接下来的就是意识流分析了,由于我也第一天接触thrift,不保证正确,看看即可.</font>

RPC是什么呢?远程过程调用,我们希望可以像调用本地方法一样调用远程的方法.

这个过程是这样的:

![2019-03-29-09-36-07](http://img.couplecoders.tech/2019-03-29-09-36-07.png)

这太麻烦了,所以就有了RPC框架,RPC框架的目的就是封装除了黄色部分之外的其他所有步骤,使得除了第一步和最后一步其他步骤不可见.

怎么实现呢?(严重意识流预警,目前认识,完了打脸了我就回来改)

依我目前对thrift的了解:

1. 定义一个接口文件,thrift生成Java类.这个类客户端和服务端共同拥有并使用.
2. 服务端根据文件中定义的接口,做出具体的实现.
3. 客户端链接服务端,调用文件中的客户端的方法,thrift负责序列化反序列化以及反射等等操作.拿到结果.


本文示例代码: <a href="https://github.com/HuBlanker/someprogram/tree/master/javaprogram/src/main/java/thrift_demo">github传送门</a>
## 参考文章

https://www.cnblogs.com/duanxz/p/5516558.html

https://zh.wikipedia.org/wiki/Thrift

## 附录 

* 基本类型：
  * bool：布尔值，true 或 false，对应 Java 的 boolean
  * byte：8 位有符号整数，对应 Java 的 byte
  * i16：16 位有符号整数，对应 Java 的 short
  * i32：32 位有符号整数，对应 Java 的 int
  * i64：64 位有符号整数，对应 Java 的 long
  * double：64 位浮点数，对应 Java 的 double
  * string：utf-8编码的字符串，对应 Java 的 String
*  结构体类型：
    * struct：定义公共的对象，类似于 C 语言中的结构体定义，在 Java 中是一个 JavaBean
* 容器类型：
  * list：对应 Java 的 ArrayList
  * set：对应 Java 的 HashSet
  * map：对应 Java 的 HashMap
* 异常类型：
  * exception：对应 Java 的 Exception
* 服务类型：
  * service：对应服务的类

<br>
<br>
<br>
<br>
<h4>ChangeLog</h4>
2019-03-28     完成
<br>
<br>


**以上皆为个人所思所得，如有错误欢迎评论区指正。**

**欢迎转载，烦请署名并保留原文链接。**

**联系邮箱：huyanshi2580@gmail.com**

**更多学习笔记见个人博客------><a href="{{ site.baseurl }}/">呼延十</a>**
