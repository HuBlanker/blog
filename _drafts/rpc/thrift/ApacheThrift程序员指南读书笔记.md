# 书的组织方式

1. 基础概念,架构
2. 一层层解析thrift, transport, server等. IDL.
3. 各种语言的示例, 以及序列化,与其他接口的IDL对比, Thrift性能测试等.


# 第一部分 基础概念

## 第一章 介绍

跨语言现状

![s00204405282022](http://img.couplecoders.tech/s00204405282022.png)

支持的语言
![s00284605282022](http://img.couplecoders.tech/s00284605282022.png)

* 强类型的序列化

为了解决跨语言,需要**数据序列化层**.

为啥不用JSON?
- 丢field咋办
- field咋排序
- 接收到当前语言不支持的类型咋办?

所以搞了IDL和强类型, IDL生成源码,源码提供强类型序列化和反序列化逻辑, Thrift保证: 写的类型都能被多种语言读取写入.

  * IDL:

1. 强制让你独立思考你的接口,与复杂的实现分离.
2. 强类型的好处, 1.容易扩展维护 2.不容易出错.
3. 为了健壮点, 支持增删属性,类型变更等等功能.

  * 接口进化问题(Thrift接口进化功能)

需要滚动上线, 不能停服.  增量更新, 现代化的CI.

  * 模块化序列化
protocols, 插件化. 
    * binary 速度
    * compact 大小
    * json 可读性
    * 模块化你还可以实现自己的序列化协议.


* 服务实现

    服务的实现也是生成代码的, 多种语言的客户端可以连接.

    Thrift有服务的外壳. 解决了客户端不断重复连接的困难.

    轻量级微服务,比Tomcat省资源.

    模块化的传输层,可以加上自己的传输层

   优雅: Protocols 序列化数据, 成bit流. Transports 读写字节. 让多种操作成为可能.

   TZLibTransport 可以进行高比例的压缩传输. 

   你可以, 分流数据打日志, (trace应用), 请求多个服务(copy流量), 加密,或者其他操作.



Java,c++,python 的服务示例.


对比: SOAP, REST, Protocol Buffers, and Apache Avro

Protocol Buffers 聚焦于统一的序列化系统, 基于他, 有多个rpc系统.


* 优势
  * 性能
  * 扩展 多语言,多平台


* 服务和序列化
* 模块化 : 插件化的序列化和传输层
* 性能
* 扩展性
* 丰富的IDL
* 灵活性
* 社区驱动开源

### 第一章总结

```text
 Apache Thrift is a cross-language serialization and service implementation framework.
 Apache Thrift supports a wide array of languages and platforms.
 Apache Thrift makes it easy to build high performance services.
 Apache Thrift is a good fit for service-oriented and microservice architectures.
 Apache Thrift is an Interface Definition Language (IDL)–based framework.
 IDLs allow you to describe interfaces and generate code to support the inter-
faces automatically.
 IDLs allow you to describe types used in messaging, long-term storage, and ser-
vice calls.
 Apache Thrift includes a modular serialization system, providing several built-in
serialization protocols and support for custom serialization solutions.
 Apache Thrift includes a modular transport system, providing built-in memory
disk and network transports, yet makes it easy to add additional transports.
 Apache Thrift supports interface evolution, empowering CI/CD environments
and Agile teams.
```

## 第二章

五层模型:

```text


 The RPC Server library
 RPC Service Stubs
 User-Defined Type Serialization 
 The Serialization Protocol library 
 The Transport library

```

![s01151205292022](http://img.couplecoders.tech/s01151205292022.png)

### 2.1 传输层

隔离上层和设备细节. 协议层不用了解底层细节,就可以读写字节流. 动态选择传输层, 支持插件化的设备选择.

TTransport 接口.

![s01251105292022](http://img.couplecoders.tech/s01251105292022.png)

每种语言可以添加自己的方法,比如c++添加了"borrow和consume".


* 终端传输. 支持内存,文件,网络设备.

TMemoryBuffer, TSimpleFileTransport,TSocket. 用了Socket.

很多还支持http呢.

* 层次化传输

可以嵌套,然后用一个终端传输即可. 

![s01344105292022](http://img.couplecoders.tech/s01344105292022.png)

搞一个传输栈, 一层一层.

TFramedTransport 带框的.

带了4字节的前缀.

客户端和服务器要用兼容的传输层来交流信息. 

buffered, 缓冲.

TBufferedTransport, 带缓冲不带框架的传输.


* 服务传输层

TServerTransport, TServerSocket 用来建立连接等. 

![s01511305292022](http://img.couplecoders.tech/s01511305292022.png)

![s01511905292022](http://img.couplecoders.tech/s01511905292022.png)

### 2.2 协议层

类型系统, 常用基础类型+三个集合类.


传输层只处理字节流,数据类型由协议层处理.

```text
 The Binary Protocol—Simple and fast
 The Compact Protocol—Smaller data size without excessive overhead
 The JSON Protocol—Standards-based, human-readable, broad interoperability
```

TProtocol, 

### 2.3 IDL 

定义应用级别的类型和接口. 自动生成序列化.

读取IDL文件,生成序列化代码和服务端/客户端插口.

* 用户定义类型序列化

* RPC 服务

processor

  * 客户端插口  

调用过程: 

![s02155205292022](http://img.couplecoders.tech/s02155205292022.png)
  * 服务处理器(processor)

  processor, 

  * 服务操作者 (handler)

  ### 2.4 服务器 

  服务的主体, service的主体是server.

  server主要是并发性,java有几种,go有routines.

  ### 2.5 安全性

  不咋支持,


  ### 总结

```text
   Transports provide device independence for the rest of the Apache Thrift framework.
 Endpoint transports perform byte I/O on physical or logical devices, such as networks, files, and memory.
 Layered transports add functionality to existing transports in a modular fash- ion, such as message framing and buffering.
 Any number of layered transports can be stacked on top of a single endpoint transport to create a transport stack.
 Server transports aren’t true transports; rather they are factories, accepting cli- ent connections and manufacturing new transports for each connecting client.
 Protocols are modular serialization engines. The primary Apache Thrift proto- cols are
– Binary: Simple and fast binary representations of data
– Compact: Trades CPU overhead for a smaller data footprint
– JSON: Trades speed and size for readability and broad interoperability
 Apache Thrift IDL allows user-defined types and service interfaces to be defined.
 The Apache Thrift IDL compiler generates self-serializing representations of IDL user-defined types in various output languages.
 The Apache Thrift IDL compiler generates client and server stubs for IDL- defined service interfaces in various output languages.
 The Apache Thrift Server library allows IDL-defined services to be deployed with minimal coding effort and a range of concurrency models.
```

  ## 第三章 构造,测试,调试.

  1. 安装IDL编译器,也就是thrift环境.

  IDL解析器,特定语言生成器,两部分. 

  平台安装,虚拟机安装,源码安装,网络下载二进制包几种安装方法. 

  源码结构树:

  测试等,

  3.4 debug rpc服务

* 抓包分析: WireShark

* 接口没做缓冲.

* 接口升级导致的版本不一致, 俗称不重合. 比如服务端同名接口返回String, 而客户端老版本要Int,都可以正常的收发数据包,但是客户端无法解析,
就关闭链接, 然后报错咯.



* IO栈不一致,也就是客户端和服务端的协议和传输要一致.

* 仪器code
TCPDump, 看一天的tcp.

Secu- rity Onion

Apache Thrift server platforms

Server Event: hook:
启动,链接,接受请求, 客户端断开.

TServerEventHandler: 

* 附加技术

https://github.com/pinterest/thrift-tools

### 第二章总结

```text
Key chapter takeaways
 You can download prebuilt Apache Thrift IDL compilers for Windows from the Apache Thrift website and you can acquire Apache Thrift container images on Docker Hub.
 You can build the Apache Thrift IDL compiler from source using Autotools or CMake.
 The Apache Thrift source tree offers a wealth of example code in the test and tutorial directories, as well as add-ons in the contrib directory.
 The Apache Thrift language library source is found with unit tests beneath the /lib directory.
 Cross-language tests allow you to test the interaction of any language client with any language server.
 Network and RPC introspection tools can help you debug the most common Apache Thrift interoperability problems, including I/O stack misalignment, interface incompatibilities, and lack of message buffering.
```


# 第二部分 写thrift程序

模块化, 跨语音序列化,rpc框架.

基于强大的,可扩展的,插件化的,分层的架构. 

![s23572905292022](http://img.couplecoders.tech/s23572905292022.png)

## 第四章 传输层: 传输字节流

独立的读写字节流,到内存块,文件,网络套接字,或者其他物理或者逻辑设备.

![s00045305302022](http://img.couplecoders.tech/s00045305302022.png)

### 4.1 终端传输, 内存和磁盘


读写到内存/文件.

* 内存 

TMemoryBuffer

* file 

TSimpleFileTransport

### 4.2 传输接口

![s13283805302022](http://img.couplecoders.tech/s13283805302022.png)

### 4.3 网络传输 (终端传输)

TSocket 

java/c++/python的Socket使用.

#### 4.4 服务端传输


一般自带的服务器(NONBLockingServer)带了传输层(TServerSocket), 但是也可以手动搞个传输出来.




#### 4.5 分层的传输层

分层模型可以更好的添加代码.


层级传输可以像终端传输一样, 栈式的,足够灵活的使用.

TFramedTransport, TBufferedTransport.

### 总结

```text
 Transports are the lowest layer of the Apache Thrift software stack.
 All Apache Thrift features depend on transports.
 Transports implement the TTransport interface.
 The TTransport interface defines device-independent, byte-level read and write
operations.
 Endpoint transports implement TTransport and perform read/write opera-
tions against a device.
 Endpoint transports are offered in most languages for memory, disk, and net-
work devices.
 Server transports use the factory pattern to manufacture network transports as
client connections are accepted.
 Layered transports implement TTransport and provide additional features on
top of an underlying transport.
 Layered transports enable separation of concerns and reuse in the transport
stack.
 The TFramedTransport is a commonly used layered transport and is required to
connect to non-blocking servers.
 A transport stack may include any number of layered transports but must always
lead to endpoint transports at the bottom of the stack.
```

## 第五章 用协议来序列化数据


语言, 操作系统, 硬件,
无关的,独立的,序列化协议

json/xml:

* 二进制块怎么传输?
* 属性确实或者多了怎么办?
* 混合类型怎么支持? 


支持多种协议,方便的自定义序列化.

TProtocol接口

给定协议可以写入多个传输层.

TBinaryProtocol,TCompactProtocol,TJSONProtocol

必须在传输层的最顶层,套上一个序列化接口.


#### 5.1 二进制序列化 TBinaryProtocol


#### 5.2 序列化接口


一大堆read/write. 支持所有thriftIDL支持的类型.

##### 5.2.1 Apache Thrift serialization

关于不支持flaot/ 4-byte float的讨论,


1. 不兼容
2. 工作量太大

所以一直不支持.

* string

用UTF-8.

Java是UCF-16, 就转换呗



UCF-8 全支持, 紧凑,没有字节顺序的浪费,因此用这个.

*  binary 

序列化过程中不改动.

自己定义这块二进制是干啥的,自己反解析咯.

*  集合

list/set/map

thrift的集合, 有一个begin和end方法,

begin和end里面记录了集合中的元素数量.


不做唯一性检查,各种语言自己做.
所以python这种duck typing的有点问题,list能发起set的调用,但是收不到.

* struct

begin和end 

每一个属性有writeFieldbegin和end.


有skip()方法,可以跳过一些类型. 跳过多少个等等.

序列化struct的代码也是生成的.

* 消息 messages

入参用Message封装.
返回参数用Result来进行封装.

这两个就是Message.

Message包含: name, type, seqID.

name就是方法名, id用来搞异步调用,大部分情况都是0.

type是下面这四种类型: 

![s23572806052022](http://img.couplecoders.tech/s23572806052022.png)


##### 5.2.2 c++的TProtocol


#### 5.3 序列化对象

