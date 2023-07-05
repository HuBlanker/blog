# modules 

graphjet-adapters: 把Cassovary 包装成graphjet. 适配器.

graphjet-core: 核心 

graphjet-demo: 使用案例. 



# graphjet-core

com.twitter.graphjet.stats 一些指标记录的代码. 后续可以参考一下.

com.twitter.graphjet.math 工具包 


com.twitter.graphjet.hashing 一些hash相关的内容, 不是当前重点. 

com.twitter.graphjet.directed api+一个对外图的类.


com.twitter.graphjet.bipartite 二部图的核心 

com.twitter.graphjet.algorithms 一些算法的实现.



## com.twitter.graphjet.bipartite

包下面有一些类, 在子包看完之后再看这块. 



### com.twitter.graphjet.bipartite.api 

![20230506144251](http://img.couplecoders.tech/20230506144251.png)



* BipartiteGraph extends LeftIndexedBipartiteGraph, RightIndexedBipartiteGraph

左索引/右索引图 = 双向索引二部图. 
提供了对图的操作以及算法接口等. 

* WithEdgeMetadataIntIterator extends IntIterator, WithEdgeMetadata 

带有边的元数据.

边的迭代器.


* NodeMetadataEdgeIterator extends EdgeIterator 

边的迭代器, 可以访问节点元数据的边的迭代器. 

* DynamicBipartiteGraph 

动态二部图, 支持写入边+移除边.


* EdgeTypeMask 

边类型的编码. 


* NodeMetadataDynamicBipartiteGraph

左右节点带有元数据, 边带有元数据的二部图


* OptimizableBipartiteGraph 

可以优化的二部图, 主要是优化边索引的存储. 


* OptimizableBipartiteGraphSegment 

空的, 定义一下有这样一个段的接口 


* ReadOnlyIntIterator

只读的迭代器 


* ReusableNodeIntIterator 

可以复用的迭代器 .

* ReusableNodeRandomIntIterator 

可以复用的随机访问的迭代器 


* RightNodeMetadataDynamicBipartiteGraph

右节点有元数据的动态二部图 


### com.twitter.graphjet.bipartite.edgepool

边池的源码. 


![20230506161552](http://img.couplecoders.tech/20230506161552.png)

* EdgePool 

单边的边索引池子.  定义了一些边的写入操作, 获取操作等. 

* EdgePoolReaderAccessibleInfo 

获取边和元数据. 

* AbstractOptimizedEdgePool 

二维数组存储边池, 没有处理读写的同步, 因此只接受读请求. 

* OptimizedEdgePool 

上面这种边池存储的普通实现 

* WithEdgeMetadataOptimizedEdgePool

带有元数据的Optimized实现.

* AbstractPowerLawDegreeEdgePool 

指数增长的边池, 也就是论文中提到的那种实现方案. 

* PowerLawDegreeEdgePool 

指数增长的边池的普通实现.

* WithEdgeMetadataPowerLawDegreeEdgePool 

指数增长的边池的带有元数据的实现.


* AbstractRegularDegreeEdgePool 

常规的边池, 假设每个顶点的边有最大限制, 且顶点的边都比较集中在最大限制数字附近. 

* RegularDegreeEdgePool

常规边池的普通实现,

* WithEdgeMetadataRegularDegreeEdgePool

常规边池的带有元数据的实现. 

* 三种边池对应的边的迭代器. 还有随机的迭代器. 共6个类. 

* RecyclePoolMemory 回收内存工具类. 

### com.twitter.graphjet.bipartite.optimizer 

优化的工具包, 暂时不看. 


### com.twitter.graphjet.bipartite.segment 

分段. 

类图比较大, 不截图了. 

* ReusableLeftIndexedBipartiteGraphSegment, ReusableRightIndexedBipartiteGraphSegment

可复用的左右索引的图段落. 


* ReusableInternalIdToLongIterator InternalIdToLongIterator

内部ID转成Long的迭代器.

* BipartiteGraphSegment 

抽象类, 二部图的一个段落. 双向的. 

管理一定量的节点和边. 抽象了公共的索引, 因为可以插拔式的使用各种边池, 左右索引可以使用不同的边池. 

是线程安全的. 

* LeftIndexedBipartiteGraphSegment 

左边索引的二部图的段落. 没看出来单独改了什么内容. 

* LeftIndexedPowerLawBipartiteGraphSegment 

指数增长的 段落. 

* LeftIndexedPowerLawSegmentProvider 

指数增长的段落生成器. 

* LeftRegularBipartiteGraphSegment 

常规的左边索引段落. 及其生成器. 

* BipartiteGraphSegmentProvider

抽象了生成 LeftIndexedBipartiteGraphSegment 的部分代码. 主要对外提供: 生成一个新的段落. 

* IdentityEdgeTypeMask 

没确定具体含义, 后面补充. 

* NodeMetaDdata* 一堆类. 

带有元数据的上面这些段落及其生成器的实现. 

* PowerLawBipartiteGraphSegment 

指数增长的二部图的段落实现. 及其段落生成器. 

* RightNodeMetadataLeftIndexedBipartiteGraphSegment* 

右边节点元数据的左边索引的段落及其生成器. 


###  父包下面的类 

* ReusableBipartiteGraph

二部图定义, 左边节点的边. 


* ReusableLeftIndexedBipartiteGraph 

左边索引的二部图. 

* ReusableNodeLongIterator 

节点遍历

* ChronologicalMultiSegmentIterator 

时间序遍历所有分段. 

* LeftIndexedMultiSegmentBipartiteGraph

左边索引的多分段的二部图. 

* LeftIndexedPowerLawMultiSegmentBipartiteGraph 

左边索引的多分段的指数增长的二部图. 

* MultiSegmentBipartiteGraph 

多分段的二部图. 

* MultiSegmentIterator 

多分段的迭代器 

* MultiSegmentPowerLawBipartiteGraph 

多分段, 指数存储的二部图. 

* MultiSegmentRandomIterator 

多个分片的随机迭代器. 

* NodeMetadataLeftIndexedMultiSegmentBipartiteGraph

节点元数据, 左侧索引的多分段二部图. 

* NodeMetadataLeftIndexedPowerLawMultiSegmentBipartiteGraph

上面的指数存储版本. 

* RightNodeMetadataLeftIndexedPowerLawMultiSegmentBipartiteGraph

右边节点元数据的, 

* RightNodeMetadataMultiSegmentIterator 

右边节点元数据的多分段迭代器. 


* SmallLeftRegularBipartiteGraph 

小的, 常规二部图. 






