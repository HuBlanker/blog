---
layout: post
tags:
  - Redis
---

## 前言

在上一篇文章中，介绍了 Redis 的所有命令的基本含义及其用法。但是 Redis 的命令太多，导致上一篇文章只能简单的进行总结，而有一些命令是那么简单的话语总结不了的，因此在这里单独的进行讲解。

当然，这种复杂的命令，不属于线上常用数据结构内部，而是一些监控和 debug 用到的。

## 目录


- [前言](#前言)
- [目录](#目录)
- [SCAN](#scan)
    - [scan 原理](#scan-原理)
    - [联想](#联想)
    - [其他 scan](#其他-scan)
- [INFO](#info)
- [MONITOR](#monitor)
- [OBJECT](#object)
- [参考文章](#参考文章)
- [联系我](#联系我)


## SCAN

好吧，这个是线上用的。

对 Redis 的很多操作都是已知 key 而去操作或者查找 value, 那么当我们不知道 key 或者仅仅知道一部分，想找到对应的 key 应该怎么办呢？

`keys`命令提供了根据正则来匹配 key 的能力，但是一般线上的 redis 是禁用掉这个 key 的。原因如下：

1. keys 直接返回所有的 key, 万一数量太多，我们看不过来。
2. 他会遍历所有的 key, 如果 reids 实例中的 key 数量太大，这个遍历的 O(n) 过程可能会导致服务器卡顿，从而影响对线上的服务。

2.8 之后版本的 redis 为我们提供了另一个批量扫描的，可控的遍历方法。也就是`SCAN`命令。

它通过批量遍历的方式，来避免卡顿服务器。

`SCAN cursor [MATCH pattern] [COUNT count] [TYPE type]`

* cursor 
这是游标，第一次填写 0 即可，之后每次请求带着上一次返回的游标，直到游标为 0 则遍历完成。
* pattern 
模式匹配，同 keys 一样，它也提供了按照正则模式进行匹配的功能。
* count 
一个数量，但是注意，这个数量并不是像 mysql 一样保证只返回这么多，而是遍历这么多，至于有多少满足条件的值，就看缘分了。即使 redis 返回了空列表，也不意味着遍历结束了，遍历结束的标志是 cursor=0.
* type
在 6.0 之后的版本，scan 加入了一个新的选项 type, 可以在扫描时只获取某个类型的 key, 但是这个 type 不区分所有的数据类型，比如 geohash, hyperloglog 等数据类型其实内部是使用 sorted set 等其他数据类型实现的，那么 scan 并不能区分它们，会把他们都当做 zset.

```text
redis 127.0.0.1:6379> GEOADD geokey 0 0 value
(integer) 1
redis 127.0.0.1:6379> ZADD zkey 1000 value
(integer) 1
redis 127.0.0.1:6379> TYPE geokey
zset
redis 127.0.0.1:6379> TYPE zkey
zset
redis 127.0.0.1:6379> SCAN 0 TYPE zset
1) "0"
2) 1) "geokey"
   2) "zkey"
```

### scan 原理

这么好使的 scan 是怎么实现的呢？

设想一下，如果我们的服务器上的数据是一个不会变化的数组，是不是就简单了好多。我们只需要 从客户端给的游标开始遍历，获取 limit 个后，把当前的的下标作为游标返回给客户端即可。这样不仅简单还天然支持多个平行的 scan, 因为我们的服务是无状态的，状态都在游标中。

但是现实没有这么美好，我们都知道 redis 的 所有 key 存储在一个大字典中，这个字典的实现就是 redis 中的字典。

那么它是一维数组＋二维链表。

游标就是一维数组上的槽，count 选项控制的也是遍历多少个槽。

每一次遍历，redis 在遍历 limit 个槽及其链接的链表之后，将结果返回，这也是为什么 scan 不保证每次 scan 返回数据量的原因，因为不是所有的槽上都有链表，而且链表上的元素也是有多有少的。

然而更麻烦的来了，字典是会有扩容以及缩容操作的，扩容及缩容都伴随着 rehash. rehash 会改变元素的槽位，也就是没有办法直接进行顺序遍历，否则就会造成重复遍历或者遗漏。

Redis 使用了高位进位假发来进行遍历，一顿花里胡哨的操作，可以保证遍历的槽位没有重复值。

>花里胡哨的操作：本质上是找到扩容之后元素 rehas 的规律，之后通过高位进位假发来规避掉。
> 距离：我们当前需要遍历下标为二进制`110`的元素，但是不幸发生了 rehash. rehash 之后的元素会落到`0110 或 1110`上，这时我们只需要调整指针，从 0110 开始遍历就能保证没有重复了。
想看特别详细的关于这个遍历的解释，可以查看这里：[scan 的详细介绍](https://juejin.im/book/5afc2e5f6fb9a07a9b362527/section/5b029e5e5188254266432000)

更麻烦的是，Redis 为了解决 rehash 大字典带来的卡顿，使用了渐进式的 rehash 过程，也就是说，有一段时间内，字典内部是有两张哈希表的。

对于这个情况，redis 会扫描两张表，然后将结果融合之后返回给客户端。

### 联想

前阵时间，我将这个思路应用到了具体的项目中，算是对 scan 思路的一个具体实践。

场景：我有一个服务 A, 程序里维护了千万级别的一个 list, 服务 B 每次启动前，需要从服务 A 中获取一段时间的列表，这个列表可大可小，可能没有值，也有可能是 600w（峰值）.

600w 个对象的大小远远超出了 thrift 限制的 16M, 因此我没有办法一次请求拿到所有的值。

后来借鉴 scan 的实现方式，写了一个 scan 接口。

这个接口就是上面我提到的美好状况下的 scan 场景。服务 A 中的数组基本上是不太改变，只会增加的。同时真的就是一个简单的数组。

因此我只需要用 cursor=0 进行请求，然后向后遍历找到 limit 个符合条件的值，之后返回当前的下标作为下一次的 cursor.

当遍历完成之后，返回一个 cursor=0, 客户端就识趣的不再请求了。600w 数据 30s 也就请求完了，而且不会再受限于数据包大小。

### 其他 scan

scan 是一系列的命令，除了有用来遍历 key 的 scan 之外，还有遍历集合的`sscan`. 遍历字典的`hscan`, 遍历有序集合的`zscan`等等，他们的实现原理基本上一样，功能也是类似的（其他 scan 没有 type 选项）. 因为本质上上面讲的那几个数据类型，底层实现都是用到了字典的，那么就和 scan 没有太大的区别了。

## INFO

INFO 命令格式化的输出 Redis 服务端的基本信息及一些统计信息。它的使用方式如下：

`INFO [section]`. 其中 section 可以是以下值，代表了不同的模块的相关信息：

* **server**: Redis Server 的一些基础信息
* **clients**: 客户端连接相关信息
* **memory**: 内存使用信息
* **persistence**: RDB ,AOF 等持久化信息
* **stats**: 基础统计信息
* **replication**: 主从 DB 同步信息
* **cpu**: cpu 占用相关统计
* **commandstats**: 命令统计相关信息
* **cluster**: 集群信息
* **keyspace**: 数据库信息
* **all**: 返回所有 section 的信息
* **default**: 返回默认的 section 的信息

返回值是一个 string 的 list, 类似下面这样：

```text
redis> INFO
# Server
redis_version:999.999.999
redis_git_sha1:3c968ff0
redis_git_dirty:0
redis_build_id:51089de051945df4
redis_mode:standalone
os:Linux 4.8.0-1-amd64 x86_64
arch_bits:64

# CPU
used_cpu_sys:2660.77
used_cpu_user:27170.64
used_cpu_sys_children:0.00
used_cpu_user_children:0.00

# Cluster
cluster_enabled:0

# Keyspace
db0:keys=2305145,expires=4,avg_ttl=1221252880772
```

每个 section 以 `#`开头，其他的值都是 `field:value`的样子。

由于 action 非常多，而且每个 action 中的属性也非常多，因此这里就不一一介绍了。只挑几个比较有用的属性来看一下。全量的属性可以查看官网 [https://redis.io/commands/info](https://redis.io/commands/info).

* redis 的每秒操作数 (operation per second)
```shell
redis-cli info stats | grep ops

# instantaneous_ops_per_sec:3518
```

* redis 的客户端连接数
```shell
redis-cli info clients | grep connect

# connected_clients:421
```

* redis 的内存占用
```shell
redis-cli info memory | grep human

# used_memory_rss_human:576.36M
```

## MONITOR

monitor 命令对应的官网地址：[https://redis.io/commands/monitor](https://redis.io/commands/monitor)

它可以回放对应的 redis 服务器的所有命令，来帮助我们进行 debug. 

![2020-01-17-17-18-27](http://img.couplecoders.tech/2020-01-17-17-18-27.png)

这里我启动了两个客户端，左边的客户端用`monitor`命令进行监控，右边的客户端进行正常的操作，可以看到所有的命令都会展示出来。

这个命令经常用于 debug. 比如新写了个功能，有 bug, 你想知道数据有没有被写到 redis. 此时你可以

```shell
redis-cli monitor | grep "your_key" 
```
来进行不断的监听。

但是，<font color="red">注意：monitor 命令是有损耗的</font>.

这里我直接取用了 Redis 官网的数据，在 Redis 服务进行正常服务时，吞吐量如下：

```text
$ src/redis-benchmark -c 10 -n 100000 -q
PING_INLINE: 101936.80 requests per second
PING_BULK: 102880.66 requests per second
SET: 95419.85 requests per second
GET: 104275.29 requests per second
INCR: 93283.58 requests per second
```

当对一个启动了 monitor 的服务器进行压测，吞吐量如下：

```text 
$ src/redis-benchmark -c 10 -n 100000 -q
PING_INLINE: 58479.53 requests per second
PING_BULK: 59136.61 requests per second
SET: 41823.50 requests per second
GET: 45330.91 requests per second
INCR: 41771.09 requests per second
```

可以看到，吞吐量下降了 50%还多，如果你继续增加监听的客户端的数量，吞吐量还会继续下降。因此，<font color="red"> 对于线上的压力大的 Redis 进行 monitor 操作要慎重</font>

## OBJECT

OBJECT 允许我们根据某个 KEY 去查看 redis 对象的内部信息。比如内部编码等。可以用来帮助我们进行 debug, 或者像官网上说的那样，用来做一个缓存的分级删除等。

它的使用格式如下：

`OBJECT sub-command key`.

其中`sub-command`可以是以下的几种：

* OBJECT REFCOUNT <key> 查看对象的引用计数，主要是用于 debug.
* OBJECT ENCODING <key> 查看对象内部存储的编码方法。
* OBJECT IDLETIME <key> 查看对象的空转时长。`空转时长=当前时间-对象的最后一次访问时间`. 在内存淘汰策略为 LRU 时用这个
* OBJECT FREQ <key> 查看对象的访问频率，在内存淘汰策略为 LFU 时候用到
* OBJECT HELP 帮助文档。

示例：

```text 
redis> lpush mylist "Hello World"
(integer) 4
redis> object refcount mylist
(integer) 1
redis> object encoding mylist
"ziplist"
redis> object idletime mylist
(integer) 10
```

## 参考文章

《Redis 的设计与实现（第二版）》

<br>

完。
<br>

## 联系我
最后，欢迎关注我的个人公众号【 呼延十 】，会不定期更新很多后端工程师的学习笔记。
也欢迎直接公众号私信或者邮箱联系我，一定知无不言，言无不尽。
![](http://img.couplecoders.tech/%E6%89%AB%E7%A0%81_%E6%90%9C%E7%B4%A2%E8%81%94%E5%90%88%E4%BC%A0%E6%92%AD%E6%A0%B7%E5%BC%8F-%E6%A0%87%E5%87%86%E8%89%B2%E7%89%88.png)

<br>

**以上皆为个人所思所得，如有错误欢迎评论区指正。**

**欢迎转载，烦请署名并保留原文链接。**

**联系邮箱：huyanshi2580@gmail.com**

**更多学习笔记见个人博客或关注微信公众号 &lt; 呼延十 &gt;------><a href="{{ site.baseurl }}/">呼延十</a>**