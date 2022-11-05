---
layout: post
tags:
  - Redis
---


## 前言

Redis的性能是很好的,但是仍然有其性能上限.Redis提供了Pipline功能,可以在某些场景下极大的提升qps.

## 为什么需要pipline

先介绍两个概念:`Request/Response protocols` 和 `RTT`.

Redis是一个使用TCP进行通讯的C/S架构,也被叫做`请求/响应协议`.

也就是说在redis处理一条命令的时候,需要:

1. 客户端将请求发送至服务器,然后阻塞(一般情况下)地等待响应.
2. 服务器处理请求并且将结果返回至客户端.

可以发现在这个过程中有两个信息的发送事件,这个事件叫做RTT(Round Trip Time).pipline主要节省的就是rtt时间.

## 使用pipline的性能测试

我们使用的客户端为Jedis,分别进行`10000`,`100000`次操作,邮箱变量有本地redis以及远程redis(因为远程通信的网络延迟一般也是避免不了的).测试结果如下:

times | 不使用pipline | 使用pipline
--- | --- | ---
本地10000 | 406ms | 38ms
本地100000 | 3557ms | 131ms
远程10000 | 43641ms | 76ms
远程100000 | 388632ms | 3433ms

从实验结果可以看出,RTT占用的时间是非常大的,远远比redis本身处理命令占用的时间更多.因此在提升性能的时候,我们应该首先节省RTT时间.


测试代码如下:

```java
    public static void main(String[] args) {
        Ticker ticker = new Ticker();
        Jedis jedis = new Jedis("localhost");
        jedis.select(2);

        ticker.tick("start");

        for (int i = 0; i < TIMES; i++) {
            jedis.incr(i + "_1");
        }
        ticker.tick("no pip");

        Pipeline pipeline = jedis.pipelined();
        for (int i = 0; i < TIMES; i++) {
            pipeline.incr(i + "_2");
        }
        ticker.tick("pip");

        System.out.println(ticker.toString());

    }
```


## 参考文章

[官方介绍](https://redis.io/topics/pipelining)

<br>
完。
<br>
<br>
<br>
<br>
<h4>ChangeLog</h4>
2019-06-13 完成
<br>
<br>


**以上皆为个人所思所得，如有错误欢迎评论区指正。**


**欢迎转载，烦请署名并保留原文链接。**


**联系邮箱：huyanshi2580@gmail.com**


**更多学习笔记见个人博客------><a href="{{ site.baseurl }}/">呼延十</a>**