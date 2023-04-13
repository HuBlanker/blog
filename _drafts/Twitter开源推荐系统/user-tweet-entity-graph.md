# 概述

用户与推特的交互关系图, 图遍历可以拿到候选集, 基于GraphJet框架. 还有一些其他的应用.
* 用户-用户图
* 用户-推特图
* 用户-视频图

等.

# UTEG (user-tweet-entity-graph)

https://github.com/twitter/the-algorithm/tree/main/src/scala/com/twitter/recos/user_tweet_entity_graph

这里简单介绍了UTEG. 主要还是靠GraphJet实现.

- thrift服务提供对外服务.
- kafka获取数据,保持状态.
- 24-48小时保存在内存里,更早的行为dump下来.

# GraphJet 

> a general-purpose high-performance in-memory storage engine
> 通用目的,高性能,基于内存的存储引擎.

源码: https://github.com/twitter/GraphJet 
pdf: http://www.vldb.org/pvldb/vol9/p1281-sharma.pdf


pdf阅读:





