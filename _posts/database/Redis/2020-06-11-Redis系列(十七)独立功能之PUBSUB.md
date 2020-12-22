---
layout: post
category: [Redis]
tags:
  - Redis
---

前面我们提到，可以使用 Redis 的列表结构作为消息队列来使用，但是它有一个致命的弱点，那就是不支持消息多播，一个消息只能被一个消息消费掉。这在分布式系统流行的今天，肯定是不能接受的，或者说应该场景及其有限的。

那么今天我们就学习一下 Redis 在 5.0 之前，对于多播消息队列的一个解决方案。**PUBSUB**.

## 目录

- [介绍](#介绍)
- [简单使用](#简单使用)
    - [相关命令](#相关命令)
    - [Redis 客户端](#redis-客户端)
    - [Java 代码使用](#java-代码使用)
    - [python 代码使用](#python-代码使用)
- [实现原理](#实现原理)
    - [渠道订阅](#渠道订阅)
    - [模式订阅](#模式订阅)
    - [发布消息](#发布消息)
- [应用场景](#应用场景)
- [总结](#总结)
- [参考文章](#参考文章)
- [联系我](#联系我)

## 介绍

**PUBSUB**, 即：publisher/subscriber. 发布与订阅的意思。

通过 **Channel** 这个概念，将发布者与订阅者联系起来，首先有一些订阅者，订阅某一个渠道，之后发布者向这个渠道发布信息，就会被所有订阅者接受到。

## 简单使用

### 相关命令

首先是订阅相关命令，redis 支持直接选择 channel 进行匹配，也支持按照正则表达式进行模式匹配，同时又因为有取消订阅的操作。因此相关的订阅命令有 4 个。

**SUBSCRIBE** 
SUBSCRIBE channel [channel ...]

使得当前的客户端订阅多个 channel.

**PSUBSCRIBE** 
PSUBSCRIBE pattern [pattern ...]

使得当前客户端订阅多个模式。

**UNSUBSCRIBE**
UNSUBSCRIBE [channel [channel ...]]

使得当前客户端取消订阅多个渠道

**PUNSUBSCRIBE**
PUNSUBSCRIBE [pattern [pattern ...]]

使得当前客户端取消订阅多个模式。

而发布消息只可以对单个的 channel 进行发布

**PUBLISH**
PUBLISH channel message

当前客户端对该渠道发布该消息

除此之外，还有一个用来查看发布订阅模块相关信息的命令。

**PUBSUB**

PUBSUB subcommand [argument [argument ...]]

subscommand 支持一下命令：

**CHANNELS**: 

PUBSUB CHANNELS [pattern]

查看当前服务器被订阅的渠道，pattern 参数是可选的，如果填写了，就返回匹配的渠道，如果没填，就返回所有渠道。

![2020-01-28-02-04-27](http://img.couplecoders.tech/2020-01-28-02-04-27.png)

**NUMSUB**: 

PUBSUB NUMSUB [channel-1 ... channel-N]

返回指定渠道的订阅者数量。

![2020-01-28-02-06-05](http://img.couplecoders.tech/2020-01-28-02-06-05.png)

如图所示，当前`huyanshi`渠道订阅者数量为 12, 都是本文搞出来的，在后面的客户端操作订阅了两个，在 java 代码中订阅了 10 个。

**NUMPAT**

PUBSUB NUMPAT

这个子命令用来返回当前服务器被订阅模式的数量。

### Redis 客户端

PUBSUB 模块是 Redis 原生支持的一个模块，因此我们可以直接通过 Redis 客户端来使用。下面是客户端使用的一个简单例子。

![2020-01-28-01-23-27](http://img.couplecoders.tech/2020-01-28-01-23-27.png)

在上图中，我首先在右侧启动了两个客户端，执行了`subscribe huyanshi`命令来订阅了`huyanshi`这个 channel. 之后再左侧的客户端中，想`huyanshi`发布`test_info`信息，可以看到，右边的两个订阅者客户端立即收到了消息。

### Java 代码使用

在代码中，我们实现了`JedisPubSub`的一个内部子类，重写了它的几个回调方法，当订阅成功，取消订阅成功，收到信息时打印相关信息。

之后启动了 10 个线程，来监听 **huyanshi** , 最后向这个 channel 发送信息。

```java 
package redis;

import org.apache.commons.pool2.impl.GenericObjectPoolConfig;
import redis.clients.jedis.*;

import java.util.stream.IntStream;
import java.util.stream.Stream;

/**
 * Author: huyanshi
 * Date:   2020/01/28.
 * Brief:
 */
public class PubSubTest {

    public static void main(String [] args) throws InterruptedException {
        GenericObjectPoolConfig genericObjectPoolConfig = new GenericObjectPoolConfig();
        genericObjectPoolConfig.setMaxTotal(20);
        JedisPool pool = new JedisPool(genericObjectPoolConfig, "localhost");
        JedisPubSub pubSub = new JedisPubSub() {
            @Override
            public void onMessage(String channel, String message) {
                System.out.println("received message:" + channel + " -" + message);
            }

            @Override
            public void onSubscribe(String channel, int subscribedChannels) {
                System.out.println("subscribed channel:" + channel);
            }

            @Override
            public void onUnsubscribe(String channel, int subscribedChannels) {
                System.out.println("unsubscribe channel:" + channel);
            }
        };

        IntStream.range(0,10).forEach(i->{
            Thread t = new Thread(()->{
                Jedis resource = pool.getResource();
                resource.subscribe(pubSub, "huyanshi");
                resource.close();
            });
            t.start();
        });
        Thread.sleep(1000);
        Long publish = pool.getResource().publish("huyanshi", "test_info");
        System.out.println(publish);

    }

}
```

打印的信息符合我们的预期，但是又没有什么价值，这里就不贴了。

### python 代码使用

```python
"""
File: redis_pub_dub.py
Author: liupanfeng
Date: 2020-01-28
Brief: 
"""

import redis
import time

client = redis.StrictRedis()
p = client.pubsub()
p.subscribe("huyanshi")
time.sleep(1)
print(p.get_message())
client.publish("huyanshi", "test_info")
time.sleep(1)
print(p.get_message())
client.publish("huyanshi", "test_info")
time.sleep(1)
print(p.get_message())
```

打印信息如下：

```text
{'type': 'subscribe', 'pattern': None, 'channel': b'huyanshi', 'data': 1}
{'type': 'message', 'pattern': None, 'channel': b'huyanshi', 'data': b'test_info'}
None
```

代码逻辑比较简单，这里就不做解释了。

## 实现原理

PUBSUB 模块并不算是一个很复杂的模块，尤其在使用方面来讲，前面粗暴的介绍了一下它的几种使用方法，基本涵盖了日常我们的使用方式。对它的相关命令也简单做了介绍，那么现在就来介绍一下 Redis 是怎么实现发布订阅模块的。

### 渠道订阅

为了保存当前服务器上的渠道被订阅信息，Redis 服务器状态里保存了一个字典。

```c 
struct redisServer{
    //其他
    ...
    // 渠道订阅者信息
    dict *pubsub_channels;
}
```

这个字典的键是渠道的名称，值是一个链表，存储了所有订阅当前渠道的客户端。

当发生订阅于取消订阅操作的时候，Redis 会对对应的链表进行添加于删除操作。

### 模式订阅

与渠道订阅关系的保存方式不同，模式订阅并没有采用字典，而是直接使用了链表。

```c 
struct redisServer{
    //其他
    ...
    // 模式订阅者信息
    list *pubsub_patterns;
}
```

链表的每一个元素都是`pubsubPattern`结构，它的定义如下：

```c
typedef struct pubsubPattern{
    // 客户端
    redisClient *client;
    // 模式
    robj *pattern;
}pubsubPattern;
```

也就是说，Redis 将所有的模式匹配信息单独保存，不考虑将相同的模式进行一个合并，因为即使合并了，在对模式进行增加或者删除操作时，还是不能避免全部扫描进行对比，那么又何苦呢。

当增加或者删除模式订阅时，Redis 直接对这个链表进行操作，进行相应节点的增删即可。

### 发布消息

熟悉了 Redis 如何保存渠道订阅和模式订阅的信息之后，发布消息就不是特别困难了。

当 Redis 接受到发布消息的请求之后，需要将消息发给所有的可能匹配的客户端，也就是渠道订阅者和模式订阅者都需要发送。

**渠道订阅**: 根据发送消息的渠道，从渠道订阅者的字典中取到对应的值，然后遍历链表，当消息发送给所有订阅的客户端。

**模式三樱桃**: 直接遍历模式订阅的链表，逐个匹配当前发布的渠道和`pubsubPattern`中的模式是否匹配，如果匹配则将消息发送给该客户端即可。

## 应用场景

如果说在 Redis5.0 之前，pubsub 模块尚且算是有点用的话，那么现在我个人觉得已经可以完全放弃 pubsub 了。

pubsub 模块最大的缺点就是它不支持消息的持久化，也就是说，必须双方同时在线，这在业务系统中是很难绝对保证的。

PubSub 的生产者传递过来一个消息，Redis 会直接找到相应的消费者传递过去。如果一个消费者都没有，那么消息直接丢弃。如果开始有三个消费者，一个消费者突然挂掉了，生产者会继续发送消息，另外两个消费者可以持续收到消息。但是挂掉的消费者重新连上的时候，这断连期间生产者发送的消息，对于这个消费者来说就是彻底丢失了。

如果 Redis 停机重启，PubSub 的消息是不会持久化的，毕竟 Redis 宕机就相当于一个消费者都没有，所有的消息直接被丢弃。

因为 PubSub 有这个缺点，它几乎找不到合适的大规模落地场景。

当然，也不是全然可以不用学习和了解。比如在前面介绍分布式锁的文章中，`Redisson`的分布式锁实现中，就应用了 pubsub.

它的分布式锁在竞争锁失败时，会自动订阅一个渠道，而在锁释放的时候，也会发布解锁信息，通知所有的竞争方来重新获取锁。

在 Redis 5.0 版本中，新加入了 `Stream`数据结构，它是一个类似于`Kafka`的支持持久化及多播的消息队列。我觉得对于 Redis 的所有的消息队列需求，都可以尝试用它来解决，而不是 PUBSUB.

## 总结

本文首先介绍了 PUBSUB 模块的基本使用方法，包括相关命令，reids 客户端操作及 java/python 代码操作。之后简单介绍了 Redis 内部实现此模块的一些原理，最后向大家安利了一下`Stream`这个轻量级的消息队列。一定要去用一下试试看噢~.

## 参考文章

《Redis 设计与实现（第二版》

[Redis 官网](https://redis.io/)

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