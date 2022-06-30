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

##### 5.3.3 对象体进化,迭代 


#### 5.4 紧凑序列化协议

#### 5.4 json序列化


#### 5.4 怎么选Protocol

1. binary是通用的.
2. compact体积小, 性能可能会好, 也可能由于cpu导致变差.
3. json人类可读

#### 总结

```text

Apache Thrift protocols serialize application data into a standard format readable by any Apache Thrift language library supporting that protocol. The combination of transports and protocols creates a plug-in style architecture making Apache Thrift an extensible platform for data serialization, supporting a choice of protocols and the possible addition of new serialization protocols over time.
 Apache Thrift protocols provide cross-language serialization.
 The TProtocol interface provides the abstract interface for all Apache Thrift
serialization formats.
 Protocols depend on the transport layer TTransport interface to read and write
serialized bytes.
 One serialization protocol can be substituted for another with little or no
impact on upper layers of software.
 The TProtocol interface defines the Apache Thrift type system exposed
through Apache Thrift IDL.
 Protocols support the serialization of
– RPC messages
– Structs
– Collections —List, set, and map
– Base types—Ints, doubles, strings, and so on
 Apache Thrift supplies three main protocols:
– Binary—The default protocol, supported by the most languages, is fast and
efficient.
– Compact—Trades CPU overhead for reduced serialization size.
– JSON—A text-based, widely interoperable, human-readable protocol with
higher CPU overhead and relatively large serialization size.
```


## 第六章 IDL 

### 6.1 接口

thrift框架, 聚焦于
"让程序员设计和构造跨语言的分布式计算接口",两部分组成:

`UserDefined types` 用户定义类型, 在系统间进行交换的数据.
`services` 暴露的一系列方法

认真干业务, 而不是注意rpc和跨语言的序列化.



* 尽量让IDL中的定义精确
* 不能精确的部分应该以文档说明
* 保持接口抽象并且远离具体实现细节


IDL和c++语言不同,

没有分隔符

### 6.2 IDL 

* IDL文件名 (正式点就好)
* 元素名 每个元素必须有名字,不重复,区分大小写
* 关键词 30个关键字 , 注意union. 好几个列, 但是一次只有一个可用. 还有一堆保留字, 别用,是别的语言的关键词, 用了容易出错.

![s22075206132022](http://img.couplecoders.tech/s22075206132022.png)

![s22101306132022](http://img.couplecoders.tech/s22101306132022.png)


### 6.3 IDL 编译器

#### 6.3.1 编译阶段和错误信息

三阶段:

1. 寻找关键字,名字,操作符等
2. 使用预发规则解析成程序元素列表
3. 元素列表解析成特定语言的code. 

#### 6.3.2 命令行参数

![s22095806132022](http://img.couplecoders.tech/s22095806132022.png)

Graphviz 支持的一个图形化的开源语音, 能直接画图, 还可以.

Java语言支持的一些额外参数:

![s22540106132022](http://img.couplecoders.tech/s22540106132022.png)


**-gen html 可以生成html的说明文件哦.**

### 6.4 注释 语法

### 6.5 命名空间

namespace 语言 空间名

多个语言各自玩.

### 6.6 内建类型

##### 6.6.1 基础类型

![s17290006142022](http://img.couplecoders.tech/s17290006142022.png)


* 只有有符号整数
* string和binary很像,具体是某些语言不一样.
* bool 可能翻译成1/0.
* 只有double, 没有float和bigdicimal.
* void 只能是方法返回值.


##### 6.6.2 集合类型

![s17375206142022](http://img.couplecoders.tech/s17375206142022.png)

* 自定义的c++集合
* 有序的JAVA集合.

##### 6.6.3 字面量

常量和默认值,等字面量赋值.

### 6.7 常量

### 6.8 类型定义

给类型自定义个名字, 更加清晰和自描述的.

### 6.9 枚举

问题不大, 都是了解了的.

### 6.10 结构体,属性,等等

default默认都会写入, 但是optional没有值就不写入. 

optional属性有setter方法.会设置isset的flag, 调用这个才会序列化. 注意检查这一项.

不同的requiredness, 对默认值的处理不一样, required和default, 是写入方为主,默认值在网络传输, optional是在读取方设置, 不走网络传输了.

默认值版本不一致问题,没办法. 

optional最好别弄默认值. 因为不传输, 读取方直接设置的默认值,很容易有版本问题,和写入方设想的不一样,出现一些不可预知的问题. 所以最好别弄. 

* 异常

* unions

### 6.11 servings

### 6.12 引用外部文件

### 6.13 注解

### 总结

```text

Apache Thrift IDL is an expressive yet compact interface definition language. It pro- vides modern features while supporting a wide range of implementation languages.
 IDLs support the process of developing explicit mechanical contracts between clients and servers.
 Apache Thrift supports a selection of commenting styles, including doc strings, that can be used to generate documentation with the Apache Thrift IDL com- piler and other tools (such as Doxygen).
 Apache Thrift IDL supports a small but flexible set of base types:
– binary – bool – byte – double – i16
– i32
– i64
– string – void
 Apache Thrift IDL supports three container types:
– list – set – map
 Apache Thrift IDL supports interface constants.
 Apache Thrift IDL supports several user-defined types:
– typedef – enum
– struct
– union
– exception
 Apache Thrift IDL doesn’t support type inheritance.
 Apache Thrift IDL doesn’t support self-referential types or forward definitions
(with experimental exceptions).
 The service keyword allows RPC service interfaces to be defined.
 Apache Thrift supports interface inheritance but not overloading or overriding.
 IDL files can include other IDL files, allowing large interfaces to be organized
across files.
 The namespace keyword supports namespace and package generation in vari-
ous target languages.
```

**Doxygen**



## 第七章 用户定义类型 

### 7.1 简单的用户定义类型例子


### 7.2 类型设计

* 命名空间
* 常量 
* 结构体
* 基础类型
* 类型定义
* 属性ID   -> 废弃的属性应该和他的ID一起注释后放在原地,让后续维护的人知道这个ID别用. 容易造成混乱哦.
* 枚举 -> 废弃的编号不应该重用.
* 集合 
* union -> 我们的feature-key 是不是很合适这种类型呢?
* 必须或者可选 -> 默认挺好的,optional有些不传输能省网卡,required能保证一定有,但是不太好演进.


### 7.3 序列化对象到磁盘

基本上都是之前讲过的.

### 7.4 在类型序列化之下. (更底层的东西么)

生成的类包含四部分:

* 属性列表
* 默认构造函数
* read方法 -> 用给定的序列化协议
* write方法 -> 用给定的序列化协议




#### 7.4.1 write方法序列化 

#### 7.4.2 read方法反序列化


### 7.5 类型演化

类型或者接口演化, 是很重要滴.

除了ID, 其他都可以随便改. 每种演化方案,都有对应的处理办法咯.

* 属性改名字
在默认的三个protocol中,随便改,因为并不传输name. 只传输ID和TYPE.

* 新增一个必须的属性
最常见的演化类型. 是向后兼容的. 
反序列化的时候, 不认识的属性就忽略了. 
新的程序接收到旧的数据,比较宽容,大不了给新的field搞个默认值.
  - 必须字段 初始化后,最好别添加必须的字段了,除非一次性换完所有应用.
  - 默认字段 这个挺好,就是如果没有默认值,旧的程序不序列化这个字段.
  - 可选字段 这个也不错. 比较灵活
  - 最佳时间  默认字段+默认值 或者可选字段+没有默认值. 都不要乱用ID就好.

* 已有的属性不再需要了
  - 直接注释掉即可
  - 不要重用ID 
  - 不能删除required的属性
  - 注意删除没有默认值的属性

* 属性的类型要修改
  - 新旧程序不认识这个字段,会忽略. 
  - 如果是可预期会更改类型,建议使用Union. 

* 属性的必要性要修改
 - required不要改
 - optional和default比较随意改.

* 属性的默认值需要修改.
 - 会导致细小的,程序定义的错误,不是安全的.

 ### 7.6 zlib 压缩

 c++/java/python三种语言的应用.

 ### 第七章总结

 ```text 
 Apache Thrift IDL provides a rich set of tools for describing data types that can be exchanged across languages and platforms. The Apache Thrift framework also pro- vides a flexible and comprehensive set of type serialization features:
 Structs are the Apache Thrift IDL mechanism for creating cross-language, user- defined types.
 Structs have one or more fields, each with a name, ID, type, requiredness, and, optionally, a default value.
 Optional requiredness fields offer the most serialization flexibility, allowing user code to decide whether to serialize them or not:
– Optional fields are a good choice for any data that may not need to be serial-
ized on all occasions, particularly data fields of large size.
– Optional fields must typically be set with language-specific set methods to
ensure that the UDT serializes them when the write() method is called.
– Optional fields must be tested for existence after de-serialization and prior to
access in case they were not found during the de-serialization process.
 Typedefs allow new semantic types to be created from existing types.
 Enums allow new enumeration types to be created.
 Unions are used to create fields that have more than one possible type or repre-
sentation:
– All union fields are optional.
– Union values must be set with set methods in most languages.
– Only one type should be set at a time within a union.
 UDTs can be serialized by calling their write() method and de-serialized by calling their read() method.
 Apache Thrift Interface Evolution features allow UDTs to change over time without breaking existing applications:
– New fields can be added.
– Old fields can be removed.
– Fields can be represented with a selection of types when unions are used.
 The TZlibTransport can be layered on top of memory and file endpoint trans-
ports to compress serialized objects:
– The TZlibTransport isn’t supported by all languages.
```

## 第八章  实现服务

