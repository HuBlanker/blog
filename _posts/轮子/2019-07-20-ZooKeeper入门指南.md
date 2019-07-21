---
layout: post
category: [轮子]
tags:
  - 轮子
---


## 目录

- [目录](#目录)
- [前言](#前言)
- [ZooKeeper是什么?](#zookeeper是什么)
- [ZooKeeper的安装](#zookeeper的安装)
    - [单机模式](#单机模式)
    - [集群模式](#集群模式)
- [ZooKeeper的使用](#zookeeper的使用)
    - [zkCli客户端使用](#zkcli客户端使用)
    - [java代码操作](#java代码操作)
- [ZooKeeper 应用场景](#zookeeper-应用场景)
- [参考文章](#参考文章)

## 前言

其实ZooKeeper在我们日常的开发中基本上是隐形的....大多数时间只是偶尔从其中读取一些配置信息.

但是呢,如果不清楚他的原理的话,使用起来总感觉有那么一些....不得劲.因此今天稍微的学习一下ZooKeeper.

## ZooKeeper是什么?

ZooKeeper是一个分布式的协调服务,可以再分布式系统中共享配置,协调锁资源等等.

他的数据模型类似于文件树的样子.

![2019-07-20-20-24-46](http://img.couplecoders.tech/2019-07-20-20-24-46.png)

每一个节点称之为一个Znode.其中存放了节点数据,子节点信息,还有节点的一些元数据.

## ZooKeeper的安装

在线上部署的时候,ZooKeeper都是集群部署的,这里我们也介绍一下单机模式的安装.

### 单机模式
单机安装非常简单，只要获取到 Zookeeper 的压缩包并解压到某个目录如：/home/zookeeper-3.2.2 下，Zookeeper 的启动脚本在 bin 目录下，在你执行启动脚本之前，还有几个基本的配置项需要配置一下，Zookeeper 的配置文件在 conf 目录下，这个目录下有 zoo_sample.cfg 和 log4j.properties，将 zoo_sample.cfg 改名为 zoo.cfg，因为 Zookeeper 在启动时会找这个文件作为默认配置文件。下面介绍一下这个配置文件中各个配置项的意义。

```
tickTime=2000 
dataDir=D:/devtools/zookeeper-3.2.2/build 
clientPort=2181
```

* tickTime：这个时间是作为 Zookeeper 服务器之间或客户端与服务器之间维持心跳的时间间隔，也就是每个 tickTime 时间就会发送一个心跳。
* dataDir：顾名思义就是 Zookeeper 保存数据的目录，默认情况下，Zookeeper 将写数据的日志文件也保存在这个目录里。
* clientPort：这个端口就是客户端连接 Zookeeper 服务器的端口，Zookeeper 会监听这个端口，接受客户端的访问请求。

当这些配置项配置好后，你现在就可以启动 Zookeeper 了，启动后要检查 Zookeeper 是否已经在服务，可以通过 netstat – ano 命令查看是否有你配置的 clientPort 端口号在监听服务。

### 集群模式
由于我目前并没有那么多机器,因此我们使用伪集群的方式安装,即在一台物理机上运行多个ZooKeeper的实例.

Zookeeper 的集群模式的安装和配置也不是很复杂，所要做的就是增加几个配置项。集群模式除了上面的三个配置项还要增加下面几个配置项：

```
initLimit=5 
syncLimit=2 
server.1=192.168.211.1:2888:3888 
server.2=192.168.211.2:2888:3888
```

* initLimit：这个配置项是用来配置 Zookeeper 接受客户端（这里所说的客户端不是用户连接 Zookeeper 服务器的客户端，而是 Zookeeper 服务器集群中连接到 Leader 的 Follower 服务器）初始化连接时最长能忍受多少个心跳时间间隔数。当已经超过 10 个心跳的时间（也就是 tickTime）长度后 Zookeeper 服务器还没有收到客户端的返回信息，那么表明这个客户端连接失败。总的时间长度就是 5*2000=10 秒
* syncLimit：这个配置项标识 Leader 与 Follower 之间发送消息，请求和应答时间长度，最长不能超过多少个 tickTime 的时间长度，总的时间长度就是 2*2000=4 秒
* server.A=B：C：D：其中 A 是一个数字，表示这个是第几号服务器；B 是这个服务器的 ip 地址；C 表示的是这个服务器与集群中的 Leader 服务器交换信息的端口；D 表示的是万一集群中的 Leader 服务器挂了，需要一个端口来重新进行选举，选出一个新的 Leader，而这个端口就是用来执行选举时服务器相互通信的端口。如果是伪集群的配置方式，由于 B 都是一样，所以不同的 Zookeeper 实例通信端口号不能一样，所以要给它们分配不同的端口号。

除了修改 zoo.cfg 配置文件，集群模式下还要配置一个文件 myid，这个文件在 dataDir 目录下，这个文件里面就有一个数据就是 A 的值，Zookeeper 启动时会读取这个文件，拿到里面的数据与 zoo.cfg 里面的配置信息比较从而判断到底是那个 server。

## ZooKeeper的使用

### zkCli客户端使用

首先,ZooKeeper提供了客户端供我们使用,在terminal中执行:`./usr/local/zookeeper/bin/zkCli.sh -server 192.168.228.101:2181`即可连接到对应的ZooKeeper服务端.

**创建节点**

`create /hello world`

可以创建一个`/hello`的节点,其中的数据为`world`.

**查询节点**

1. 查询节点的结构

`ls /`  - 可以查询`/`目录下节点的结构.

2. 查询节点的数据

`get /hello` - 可以获取/hello的数据.


3. 修改节点的值

`set /hello world-01` - 将/hello节点的值修改为`world-01`.

4. 删除节点

`delete /hello`

删除的节点必须为空,否则无法删除.

所有的示例如下:

![2019-07-21-11-34-38](http://img.couplecoders.tech/2019-07-21-11-34-38.png)

### java代码操作

和上面的操作相同,下面的代码也是展示常用的增删改查节点的操作.

```java
/**
 * Created by pfliu on 2019/07/21.
 */
public class ZooKeeperUtil {
    public static void main(String[] args) throws Exception {
        // 初始化
        // 监控所有被触发的事件
        ZooKeeper zk = new ZooKeeper("localhost:" + 2181,
                2000, event -> System.out.println("触发了" + event.getType() + "事件！"));

        // 创建节点
        zk.create("/code", "codeData".getBytes(), ZooDefs.Ids.OPEN_ACL_UNSAFE, CreateMode.PERSISTENT);
        zk.create("/code/son", "codeSonData".getBytes(), ZooDefs.Ids.OPEN_ACL_UNSAFE, CreateMode.PERSISTENT);

        // 获取数据
        System.out.println(new java.lang.String(zk.getData("/code", false, null)));
        System.out.println(new java.lang.String(zk.getData("/code/son", false, null)));

        // 修改节点
        zk.setData("/code", "codeDateAfterUpdate".getBytes(), -1);

        // 判断节点是否存在
        System.out.println(zk.exists("/code/son", false));
        System.out.println(zk.exists("/code/son/noexist", false));

        //删除节点
        try {
            zk.delete("/code", -1);
        } catch (KeeperException e) {
            if (e instanceof KeeperException.NodeExistsException) {
                System.out.println("there is son data in this node.");
            }
        }
        zk.delete("/code/son", -1);
    }
}
```
注意,删除节点的时候,如果该节点有子节点,会报错,所以在代码中加入了异常判断.

## ZooKeeper 应用场景

ZooKeeper实现了一个类似于观察者模式的系统,它可以帮我们管理各方都比较关心的数据,接受大家的订阅,在数据发生改变的时候通知所有订阅者.那么我们可以拿ZooKeeper做什么呢?

* 统一命名服务
* 分布式配置管理
* 集群管理
* 分布式锁

## 参考文章

https://www.ibm.com/developerworks/cn/opensource/os-cn-zookeeper/index.html

<br>


完。
<br>
<br>
<br>
<br>
<h4>ChangeLog</h4>
2019-07-22 完成
<br>
<br>


**以上皆为个人所思所得，如有错误欢迎评论区指正。**


**欢迎转载，烦请署名并保留原文链接。**


**联系邮箱：huyanshi2580@gmail.com**


**更多学习笔记见个人博客------><a href="{{ site.baseurl }}/">呼延十</a>**