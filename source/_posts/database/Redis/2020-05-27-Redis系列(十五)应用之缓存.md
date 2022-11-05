---
layout: post
category: [Redis, 缓存]
tags:
  - Redis
  - 缓存
---

这篇文章其实很尴尬，Redis 有很多可以讲的，缓存也有很多可以讲的，但是侧重于 Redis 的缓存。.. 有点难搞。

本文会简单介绍 Redis 怎么用于缓存，之后讲一下 最近学习的缓存框架，可以很方便的集成 Redis. `JetCache`.


- [Redis 缓存介绍](#redis-缓存介绍)
    - [序列化](#序列化)
    - [过期时间](#过期时间)
    - [减少代码侵入](#减少代码侵入)
- [JetCache](#jetcache)
    - [spring-示例](#spring-示例)
    - [java 原生示例](#java-原生示例)
- [总结](#总结)
- [参考文章](#参考文章)
- [联系我](#联系我)


## Redis 缓存介绍

用 Redis 来做缓存，主要就是看上了它的高性能。还有精准的过期时间等等。

由于我们要缓存的对象多种多样，Redis 是没有那么多对应的数据结构的。幸好 Redis 的字符串是线程安全的，因此我们可以将所有需要缓存的对象序列化后，直接用 Redis 的字符串对象进行缓存。

因此我认为用 Redis 进行缓存主要有三个要点：

1. 序列化
2. 过期时间
3. 减少代码侵入

### 序列化

缓存过程中，序列化的目的，是将一个对象转换成一个字符串方便于存储。这个的方案多种多样，常见的有直接二进制化，json 格式序列化，thrift 序列化，protobuf 序列化等等。

这个就来到了序列化的战争，其实都可以。但是我个人建议，需要缓存内容可读的时候使用 json. 不需要的时候用最方便的，比如你是 thrift 项目那就用 thrift 序列化。你在用 google 全家桶，你就直接用 protobuf.

如果缓存量很大，那么需要加上额外一个指标，就是信息的压缩率。Redis 毕竟花的是内存，能省点还是省一点。

### 过期时间

这个其实涉及到了缓存失效以及数据一致性的问题，根据你缓存的作用各自取舍即可。

比如用作 DB 缓存，那么可以设置永不过期，当 DB 里的信息被更改之后，通过广播通知 Redis 删除即可。

比如用作 API 缓存，那么可以设置 1 分钟，来防止大量的突发请求打爆服务器。

更多的时间里，我们是知道过期时间的，比如一个系统，会每天 0 点更新前一天的战力排行榜，这个内容会被全服玩家频繁查看且不会更改，是缓存的好材料。这个时候的缓存时间只需要略大于一天即可。

### 减少代码侵入

这个是我个人十分看重的一点，因为缓存的相关代码对于业务毫无帮助，但是操作很频繁，因此代码很多。

当你的系统有大量需要缓存的内容的时候，就发现相似的代码散步在各处。且每次新增都要写一些类似的代码。

解决这个问题的方案，个人接触到的有两种。

1. 为一些基础 model 类生成 code, 在 JDBC 代码里面加入查询缓存的操作。
2. 基于注解的实现，这也是现在比较主流的实现方式。（可惜我搞不了）.

两种方式算是各有千秋吧。

第一种方式在代码上很直观，直接查看生成的 code 即可。而且在调用方眼里也是完全隐藏的。
第二种方法代码上漂亮一些，管理起来也方便一些。但是要求开发人员清楚注解作用，而且参数项会很多。如果不是完全清楚原理，调试起来会很头大。

下文要讲到的`JetCache` 主要就是支持注解实现。

## JetCache

## 介绍

JetCache 的官方代码仓库：[https://github.com/alibaba/jetcache](https://github.com/alibaba/jetcache).

>JetCache 是一个基于 Java 的缓存系统封装，提供统一的 API 和注解来简化缓存的使用。 JetCache 提供了比 SpringCache 更加强大的注解，可以原生的支持 TTL、两级缓存、分布式自动刷新，还提供了 Cache 接口用于手工缓存操作。 当前有四个实现，RedisCache、TairCache（此部分未在 github 开源）、CaffeineCache(in memory) 和一个简易的 LinkedHashMapCache(in memory)，要添加新的实现也是非常简单的。

我们可以看到，JetCache 于 Redis 并不是绑定关系，它是一个队 cache 接口的封装，Redis 只是其中一种缓存的具体实现。

它有以下特性：

* 通过统一的 API 访问 Cache 系统
* 通过注解实现声明式的方法缓存，支持 TTL 和两级缓存
* 通过注解创建并配置 Cache 实例
* 针对所有 Cache 实例和方法缓存的自动统计
* Key 的生成策略和 Value 的序列化策略是可以配置的
* 分布式缓存自动刷新，分布式锁 (2.2+)
* 异步 Cache API (2.2+，使用 Redis 的 lettuce 客户端时）
* Spring Boot 支持

它的一些要求：

JetCache 需要 JDK1.8、Spring Framework4.0.8 以上版本。Spring Boot 为可选，需要 1.1.9 以上版本。如果不使用注解（仅使用 jetcache-core），Spring Framework 也是可选的，此时使用方式与 Guava/Caffeine cache 类似。

画重点：<font color="red">使用注解，必须依赖于 Spring 框架。</font>

官方仓库中包含了很多文档，都写得很不错，强烈推荐，这里不再搬运了，前面只是为了方便介绍，如果需要详细了解的，请直接查看仓库中 Wiki. [https://github.com/alibaba/jetcache/wiki/Home_CN](https://github.com/alibaba/jetcache/wiki/Home_CN).

### spring-示例

首先我们就来看看当前的主流解决方案，也就是通过注解来实现缓存。

*记得上面我说过基于注解调试很头疼吗？毫无输出信息，我调试这点 demo 都头大了。*

首先，让我们引入依赖：

```xml
        <dependency>
            <groupId>com.alicp.jetcache</groupId>
            <artifactId>jetcache-starter-redis</artifactId>
            <version>2.5.14</version>
        </dependency>
```

然后在 springboot 项目的启动类上加上如下注解，来开始缓存功能。

```java
@SpringBootApplication
@EnableAsync
@EnableMethodCache(basePackages = "com.huyan.demo")
@EnableCreateCacheAnnotation
public class DemoApplication {

  public static void main(String[] args) {
    SpringApplication.run(DemoApplication.class, args);
  }
}
```

之后，新建一个`service 类`, 并且将他实现。

```java
// service
public interface UserService {
    @Cached(name = "userCache.", expire = 3600, cacheType = CacheType.REMOTE)
    User getUserById(long userId);
}

// service impl
@Service
public class UserServiceImpl implements UserService {

    @Override
    public User getUserById(long userId) {
        return new User(1, "a");
    }
}

// user 类的定义
public class User implements Serializable {
    int userId;
    String userName;
}
```

好了，让我们启动这个类，来康康到底会发生什么。同时监听 Redis, 看看对 Redis 的操作。

![2020-01-23-00-36-24](http://img.couplecoders.tech/2020-01-23-00-36-24.png)

可以看到，在第一次请求该接口的时候，尝试获取缓存，之后发现缓存为空，调用了代码里实际的逻辑，`new User(1, "a");` 拿到了这个返回值，之后将这个对象序列化，写入 Redis.

之后的每一次查询请求都是直接返回的缓存值了。从图片中的监听可以看到，每次请求都走了 Redis.

熬过了所有困难部分，剩下的就完全不难了。

### java 原生示例


很遗憾，我的工作中和自己的瞎写代码的时候都不怎么用 spring, 我有一个 spring 项目还是专门用来写示例的，因此我们需要找找怎么直接引入这个包，`JetCache`提供了对应的 CacheAPI, 使用示例如下。

全部代码见: [JetCacheTest](https://github.com/HuBlanker/someprogram/blob/master/javaprogram/src/main/java/cache/JetCacheTest.java)

```java
package cache;

import com.alicp.jetcache.Cache;
import com.alicp.jetcache.embedded.LinkedHashMapCacheBuilder;
import com.alicp.jetcache.redis.lettuce.RedisLettuceCacheBuilder;
import com.alicp.jetcache.support.*;
import io.lettuce.core.RedisClient;

import java.util.Collections;
import java.util.concurrent.TimeUnit;

/**
 * Author: huyanshi
 * Date:   2020/01/22.
 * Brief:  jetcache 测试
 */
public class JetCacheTest {

    public static void main(String[] args) {
        // 创建一个本地的缓存
        Cache<String, Integer> cache = LinkedHashMapCacheBuilder.createLinkedHashMapCacheBuilder()
                .limit(100)
                .expireAfterWrite(5, TimeUnit.SECONDS)
                .buildCache();
        // 加入缓存
        cache.put("10", 10);
        // 获取全部缓存
        System.out.println(cache.getAll(Collections.singleton("10")));

        // Redis 缓存
        RedisClient client = RedisClient.create("redis://127.0.0.1");
        // 创建
        Cache<Long, Integer> orderCache = RedisLettuceCacheBuilder.createRedisLettuceCacheBuilder()
                .keyConvertor(FastjsonKeyConvertor.INSTANCE)
                .valueEncoder(JavaValueEncoder.INSTANCE)
                .valueDecoder(JavaValueDecoder.INSTANCE)
                .redisClient(client)
                .keyPrefix("orderCache")
                .expireAfterWrite(2000, TimeUnit.SECONDS)
                .buildCache();

        // 添加
        orderCache.put(10000L, 1);
        // 获取并打印
        System.out.println(orderCache.get(10000L));

    }
}
```

代码比较简单，因为`JetCache`本身的目的就是封装 CacheAPI, 尽量想让所有对 Cache 的操作都符合同一套接口定义，所以基本上我们只需要使用`put/get`就好了。

代码中，连接了本地的 Redis 进行操作，需要注意的是客户端没有使用 Jedis, 而是使用了`lettuce`.

## 总结

首先，用`Redis 来做缓存`, 基本上是没有什么难点的，就是简单的字符串数据结构的使用，难点基本在于`缓存系统`, 比如过期，缓存击穿，缓存雪崩等等怎么预防及解决的问题，但是那就不在本文的讨论里了，

其次，`JetCache`作为一个三方的 cache 库，我觉得还是十分不错的，支持远程 cache(Reids, 且支持两个客户端）, 也支持本地 cache. 支持基于 spring 的注解模式，也支持原生的 java-code 开发，使用起来还算愉快。

缺点呢就是依赖的其他包的版本太老了，导致有很多的版本冲突，比如依赖的 Jedis 竟然还是 2.x 版本，这也就是为什么上面的代码我用了 lettuce 的原因。

我翻了翻 github 的提交记录，在一个月前有人尝试进行 Jedis 升级了，目前好像升级了注解相关部分，而 java 原生 API 这边，好像目前还没有动静，希望可以尽快升级，大家开心的使用吧。

## 参考文章

https://github.com/alibaba/jetcache/wiki

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