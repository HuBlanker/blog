---
layout: post
category: [Redis]
tags:
  - Redis
---

## 目录

- [目录](#目录)
- [背景介绍](#背景介绍)
- [public](#public)
- [DB](#db)
- [string](#string)
- [list](#list)
- [sets](#sets)
- [sorted sets](#sorted-sets)
- [hashes](#hashes)
- [streams](#streams)
- [bitmaps](#bitmaps)
- [hyperloglogs](#hyperloglogs)
- [geospatial index](#geospatial-index)

## 背景介绍

以下摘自：Redis 官网。

> Redis is an open source (BSD licensed), in-memory data structure store, used as a database, cache and message broker. It supports data structures such as strings, hashes, lists, sets, sorted sets with range queries, bitmaps, hyperloglogs, geospatial indexes with radius queries and streams. Redis has built-in replication, Lua scripting, LRU eviction, transactions and different levels of on-disk persistence, and provides high availability via Redis Sentinel and automatic partitioning with Redis Cluster.

总的来说，Redis 是一个基于内存的高性能的键值型数据库，也就是常说的 NoSQL, 可以用来作为数据库或者缓存。并且支持多种数据结构，包括字符串，散列，列表，集合，带有范围查询的排序集，位图，HyperLogLog，具有半径查询的地理空间索引和流。

各种语言都提供了 Redis 的客户端，比如 Java 的`Jedis`和 python 的`redis-py`.

同时 Redis 也提供交互式的客户端，在 mac 上执行：

`brew install redis`进行安装，安装完成后执行：

`redis-cli` 进入交互式的客户端，即可开始使用。

本文主要用来记录针对各种数据结构的操作命令，来源主要是 Redis 官网加上自己的理解。由于英语问题，不保证理解一定正确。大家可以参考 [redis 官网](https://redis.io) 来进行学习。

## public

- **help**: 这个命令很重要，只要你用的好，可以查看所有命令的用法，可以起到一个临时提示的作用，比如这个命令有哪些选项等等。使用方法：`help`之后根据提示输入：`help command`, 即可以查看该命令的详细方法签名。输入`help @group`可以查看该 group 相关的命令，比如`list`,`set`.

- **keys**: 使用模式匹配，返回匹配的 key, 使用`*`进行查看全量的 key. 注意：不要在线上使用这个命令，不可控。`keys **`

- **exists**: 查看某个 key 是否存在，存在返回 1, 不存在返回 0.`exists key`. 

- **scan**: 遍历所有的 key, 因为做了分页，所以是安全的。`sacn cursor match * count 100`. `*`可以进行模式匹配。`cursor`初次使用为 0, 之后每一次为上一次`scan`返回的游标。

- **type**: 查看某个 key 的类型，返回描述。`type key`.

- **del**: 删除 key, 可以删除多个。`del key1 key2`

- **expire**: 设置过期时间，`expire key seconds`.

- **ttl**: 查看 key 的剩余生存时间，`ttl key`

- **pttl**: 以毫秒形式查看 key 的过期时间，`pttl key`

- **move**: 将当前数据库中的某个 key 移到新的数据库。`move key db`

- **dump**: 拿到序列化后的 value. `dump key`.

- **resotre**: 用上一个命令拿到的值回复某个 key.`resotre key seconds 序列化的 value`

- **object**: 查看指定 key 值的内部结构。

- **MONITOR**: 可以监控 redis 服务器，看他处理的每个请求。可以在 redis 客户端中执行`monitor`, 也可以直接在 shell 种执行：`redis-cli monitor`.

## DB

这块其实也是 public 的一部分，我单独将其写出来一下。

- **select**: 选择数据库，默认为 16 个数据库可以选择。`select index`

- **flushdb**: 删除当前 db 的所有 key. `flushdb`.

- **swapdb**: 交换两个数据库。`swapdb index1 index2`.

- **randomkey**: 在当前库里随机返回一个 key. `randomkey`.

- **monitor**: 监视器，可以监视某个 redis 接受的所有命令。`redis-cli monitor`. 直接在命令行中执行。

## string

- **set**: 设置某个 key 的 value.`set key value`
- **get**: 获取某个 key 的 value. `get key`
- **strlen**: 返回字符串的长度。`strlen key`
- **append**: 如果 key 存在并且为字符串，则追加值，如果 key 不存在，则创建并追加，此时相当于 set. 成功后返回追加后字符串的长度。`append key value`
- **getrange**: 根据输入的偏移来返回子字符串。支持-1 偏移，代表最后一个字符。`getrange key start end`
- **setrange**: 在 key 的指定偏移量处写入新的值。`setrange key offset value`
- **incr**: 操作整数。当你的 key 中存储的是整数的时候，会将整数加 1. 需要注意的是，key 为空的时候会被置为 0 然后加 1.key 的值为不能解释为数字的字符串时会报错。`incr key`
- **decr**: `incr`的反操作，递减 1.`decr key`
- **incrby**: 递增某个增量。其他同`incr`一样。`incrby key one_int_value`.
- **decrby**: `incrby` 的反操作。递减某个量。`decrby key one_int_value`
- **mget**: 一次性获取多个 key. 注意如果 key 不存在会返回`nil`, 所以这条命令永远不会出错。`mget key1 key2 ...`
- **mset**: 一次性写入多个 key-value. 不会失败，并且是原子操作。也就是说所有值必然会更新。`mset key1 value1 key2 value2`
- **msetnx**: 批量的非空写入，注意是原子操作，所以当某一个 key 存在，所以 key 都不会被写入。`msetnx key1 value1 key2 value2`
- **setex**: 设置 key=value 且过期时间为 seconds. 原子操作，相当于`set + expire`. 语法`set key seconds value`
- **setnx**: 是`set if not exists`, 当 key 不存在时写入，存在时不做任何操作。`setnx key value`
- **getset**: 设置新值并返回旧值。`getset key new_value`
- **psetex** : 和`setex`相似，区别只是设置的过期时间单位为毫秒。`psetex key ms value`

## list

- **LPUSH**: 向队头放入一个元素。`LPUSH key v1 v2 v3`.
- **RPUSH**: 向队尾放入一个元素。`RPUSH key v1 v2 v3`.

- **LPOP**: 从队头弹出一个元素。`LPOP key`.
- **RPOP**: 从队尾弹出一个元素。`RPOP key`.

- **LLEN**: 获取队列的长度。`LLEN key`.
- **LINDEX**: 获取指定 index 的值。`LINDEX key 0`.0,1,2 是队头的 index,-1,-2,-3 是队尾的 index.
- **LINSERT**: 在队列中某个值的前/后插入一个新元素。`LINSERT key before|after pivot value`.O(n) 的时间复杂度。

- **LRANGE**: 返回范围内的元素，支持-1 从尾部计算。`LRANGE key 0 -1`可以返回全部值。注意，时间复杂度是 O(N+S).

- **LREM**: 删除指定数量个 value.`LREM key count value`.count 大于零时从头到尾数，count<0 时从后向前数，count=0 删除所有指定的 value.
- **LSET**: 设置指定 index 上的值。`LSET key index value`. 时间复杂度为 O(n).

- **LTRIM**: 修剪 list, 仅保留指定范围内的值。`LTRIM key start end`. 事件负责度 O(n).

- **LPUSHX**: 在队头插入一个元素，当 key 不存在时，不做操作。`LPUSHX key v`.
- **RPUSHX**: 在队尾插入一个元素，当 key 不存在时，不做操作。`RPUSHX key v`.

- **BLPOP**: 从队列头部，阻塞式的弹出一个元素，支持多个键，支持超时和永不超时。`BLPOP key1 key2 3`.

- **BRPOP**: 从队列尾部，阻塞式的弹出一个元素，支持多个键，支持超时和永不超时。`BLPOP key1 key2 3`.

- **RPOPLPUSH**: 将一个队列的最后一个元素弹出并且放到另一个队列的头部。`RPOPLPUSH source-list destination-list`.
- **BRPOPLPUSH**: 阻塞版本的上一个命令。

## sets

- **SADD**: 向集合中添加一个或者多个元素。`SADD key v1 v2 v3`.

- **SCARD**:  返回集合的元素数量。`SCARD key`.

- **SPOP**: 随机从集合中弹出一定数量的元素。`SPOP key count`.

- **SMOVE**: 将某个元素从一个集合移到另一个集合。`SMOVE source target member`.

- **SMEMBERS**: 返回该集合的所有成员。`SMEMBERS key`.

- **SISMEMBER**: 给定元素是否是集合中的一员，返回 1 或者 0.`SISMEMBER key v`.

- **SRANDMEMBER**: 随机获取指定数量个成员。`SRANDMEMBER count`,O(1) 或者 O(n). 看 count 咯。
- **SREM**: 从给定集合中删除指定的多个元素。`SREM key v1 v2 v3`.

- **SSCAN**: 扫描集合。以较小的代价查找一些元素。`sscan key 0 match o* count 10`. 将返回 set 中以 o 开头的 10 个元素，可以继续使用游标来扫描。

- **SDIFF**: 返回第一个集合和其他集合不同的元素。`SDIFF key1 key2 key3`.
例如：
```
key1 = {a,b,c,d}
key2 = {c}
key3 = {a,c,e}
SDIFF key1 key2 key3 = {b,d}
```
O(n) 的时间复杂度，n 是所有 set 的集合总数。

- **SDIFFSTORE**: 和上一个命令差不多，只不过会把结果存在第一个 set 中，覆盖存储。`SDIFFSTORE key1 key2 key3`.O(n) 的时间复杂度。

- **SINTER**: 求多个集合的交集，`SINTER key1 key2 key3`. 时间复杂度是 O(m * n).m 是 key1 的元素数量，n 是后面所有集合的最小元素数量。

- **SINTERSTORE**: 上一个命令的存储版本，将结果覆盖到第一个 set 中。

- **SUNION**: 求并集。`SUNION key key1 key2`.

- **SUNIONSTORE**: 上一个命令的存储版本，将结果存储在 key 中。

## sorted sets

- **ZADD**: 向有序集中添加元素。支持多个（分数-值）, 且支持额外的指令。`ZADD [NX | XX]  [CH]  [INCR]  score1 value1 score2 value2`. 指令也可以没有，有的话规定一些重复之类的规则。时间复杂度：对每一个（分数-值）来说都是为 O(log(n))

- **ZREM**: 从集合中移除一个或者多个元素。`ZREM key v1 v2`.O(m*log(n))

- **ZSCORE**: 获取元素的分值。`ZSCORE key v`.O(1).

- **ZRANK**: 返回该值在集合中的排名，从低到高排序的名次。`ZRANK key value`.O(log(n)).
- **ZREVRANK**: 返回该值在集合中的排名，从高到低排序的名次。`ZREVRANK key value`.O(log(n)).

- **ZPOPMAX**: 弹出分数最高的 x 个值。`ZPOPMAX key count`.O(log(N)*M).
- **ZPOPMIN**: 弹出分数最低的 x 个值。`ZPOPMIN key count`.O(log(N)*M).

- **BZPOPMAX**: 从有续集中弹出分数最大的值。阻塞版本。`BZPOPMAX key key2 key3 time`.time 为阻塞时间，同样 0 代表永不超时。O(n).
- **BZPOPMIN**: 和上面命令一样，只不过弹出的是分数最小的值。O(n).

- **ZCARD**: 返回有续集的元素个数。`ZCARD key`.O(1) 的时间复杂度。
- **ZCOUNT**: 返回在给定分值区间内的元素数量。`ZCOUNT key min max`.O(log(n)).

- **ZRANGE**: 返回给定分数范围内的值。`ZRANGE key start end WITHSOCRES`.
  - WITHSCORES: 返回值是否带有分值。
  - 分值相同时使用字典排序。
  - O(log(N)+M)
- **ZRANGEBYLEX**: 根据值的起始和截止返回范围内的值。`ZRANGEBYLEX key min max [LIMIT offset count]`, 字典序版本的上一个命令。
- **ZRANGEBYSCORE**: 根据分值的起始和截止返回范围内的值。`ZRANGEBYSCORE key min max [LIMIT offset count]`,
- 这里是三个上面三个的反序命令，分值或者字母序列的从高到低。懒得写。

- **ZLEXCCOUNT**: 根据值进行字典排序版本的上一个命令。`ZLEXCCOUNT key min max`.O(log(n)).

- **ZINCRBY**: 给某个元素增加给定的分值。`ZINCRBY key score value`.O(log(n)).

- **ZSCAN**: 扫描集合，和`set`部分的命令差不多。

- **ZINTERSTORE**: 求给定集合的交集并存在指定的集合中（覆盖存储）, 还有一些其他的选项供操作。`ZUNIONSTORE destination numkeys key [key ...] [WEIGHTS weight [weight ...]] [AGGREGATE SUM|MIN|MAX]`
  - WEIGHTS: 指定每个集合在算出最后的分数之前的乘法因子。
  - AGGREGATE: 指定聚合的方式，可以是求和，最大，最小值。
  - 时间复杂度很复杂。..
- **ZUNIONSTORE**: 上一个命令的并集版本。

## hashes

- **HSET**: 写入一条数据，key 对应的列的数据。`HSET key field value`.

- **HGET**: 获取某个 key 的某个列的值。`HGet key field`.

- **HMGET**: 获取多个列的值的列表。`HMGET key field1 field2`.

- **HMSET**: 一次写入多个列-值。`HMSET key field1 v1 field2 v2`.

- **HSETX**: 仅当该列不存在的时候写入。`HSETX key field value`.

- **HDEL**: 删除一个或者多个列。`HDEL key field field field`
- **HEXISTS**: 检查是否包含某个列。`HEXISTS key field`. 返回 0 或者 1.

- **HGETALL**: 返回当前 key 中的所有字段和值。`HGETALL key`. 时间复杂度是 O(n).
- **HINCRBY**: 对某个列的值进行增加。`HINCRBY key field number`. 只支持 feild 是 64 位有符号整数。

- **HINCRBYFLOAT**: 增加一个浮点数。其余和上面的命令一样。`HINCRBYFLOAT key field float`.

- **HKEYS**: 返回所有的列名。`HKEYS key`.
- **HLEN**: 返回列的数据。`HLEN key`.

- **HSCAN**: 扫描所有的列-值。返回的规则和其他的 scan 一样。`HSCAN key 0 match uu* count 10`

- **HSTRLEN**: 返回该列的值的长度。`HSTRLEN key field`.

- **HVALS**: 返回所有的值。只有值没有列名。`HVALS key`. 时间复杂度为 O(n).

## streams 

本章节的命令签名较长且变化较多，因此不再提供示例命令和方法签名，可以去下面的链接中学习。

[stream 相关命令](https://redis.io/commands#stream)

- **XINFO**: 用于检索有关流和关联的消费者组的不同信息。有三种子命令，STREAMS,GROUPS,CONSUMERS.

- **XADD**: 将给定的条目添加到 Stream 中，如果 stream 不存在，则以 key 创建一个 Stream.

- **XRANGE**: 从 Stream 中查找指定范围的条目并返回。

- **XREVRANGE**: **XRANGE **的倒序版本，接受参数也是倒序。

- **XLEN**: 返回 Stream 中的项目数量。

- **XDEL**: 从 Stream 删除给定 ID 的项目。

- **XREAD**: 从一个或者多个 Stream 中读取数据，仅返回 ID 大于传入 ID 的信息。

- **XTRIM**: 将 Stream 修剪的只保留给定数量的项目，有多种修剪策略，目前只实现了一种。

- **XREADGROUP**: 使用消费者组从 Stream 中读取信息。

- **XACK**: 确认已经处理消息。

- **XCLAIM**: 更改消息的所有权，可以是其他消费者来处理此消息，

- **XPENDING**: 查看正在处理的消息的信息。

- **XGROUP**: 创建，销毁，管理消费者组。也有多个子命令，CREATE,SETID,DESTROY,DELCONSUMER.

## bitmaps

其实 bitmap 不是一个实际的数据结构，只是在 string 数据结构上的一组面向位的操作，因为 string 数据结构是二进制安全的，所以这个是可行的。

- **SETBIT**: 设置某个 key 在某个位置的 bit 值。`SETBIT key offset value`.
- **GETBIT**: 获取某个 key 在某个位置的 bit 值。`GETBIT key offset`.

- **BITCOUNT**: 获取某个范围内 bit=1 的总数。`BITCOUNT key start end`.
- **BITPOS**: 获取某个范围内第一个 0 或者 1 出现的位置。`BITPOS key 0 1 2`.

## hyperloglogs

hyperloglog 的原理这里就不讲了，完了多看看之后单独记录一下。

- **PFADD**: 添加一个或者多个元素。`PFADD key1 v1 v2 v3`.O(1).

- **PFCOUNT**: 返回不重复的元素的个数，可以统计多个 key. 同时，返回值是有一定 (0.81%) 错误率的近似值。`PFCOUNT key1 key2 key3`.O(n).

- **PFMERGE**: 将多个 key1 的内容合并到一个 key 中。`PFMERGE target key1 key2`.O(n),n 是 key 的数量。
## geospatial index

- **GEOADD**: 想指定的 key 中添加一个或者多个地理位置，格式为`经度，纬度，名称`.`GEOADD key longitude latitude member [longitude latitude member ...]`

- **GEOHASH**: 返回一个或者多个 GEO 值的 hash.`GEOHASH key member [member ...]`

- **GEOPOS**: 获取某个成员的坐标。`GEOPOS key member [member ...]`

- **GEODIST**: 返回两个成员之间的距离，可以指定多种单位。`GEODIST key member1 member2 [unit]`.

- **GEORADIUS**: 返回指定点为球心，指定距离为半径内的坐标集。`GEORADIUS key longitude latitude radius m|km|ft|mi [WITHCOORD] [WITHDIST] [WITHHASH] [COUNT count] [ASC|DESC] [STORE key] [STOREDIST key]`

- **GEORADIUSBYMEMBER**: 与上一个命令相似，只是返回的是成员名称。`GEORADIUSBYMEMBER key member radius m|km|ft|mi [WITHCOORD] [WITHDIST] [WITHHASH] [COUNT count] [ASC|DESC] [STORE key] [STOREDIST key]`.

完。

<br>
<h4>ChangeLog</h4>
2019-04-04 开始连载
2019-05-06 完成
<br>

**以上皆为个人所思所得，如有错误欢迎评论区指正。**

**欢迎转载，烦请署名并保留原文链接。**

**联系邮箱：huyanshi2580@gmail.com**

**更多学习笔记见个人博客------><a href="{{ site.baseurl }}/">呼延十</a>**
