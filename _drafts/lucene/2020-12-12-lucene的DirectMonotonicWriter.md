
# DirectMonotonicWriter
DirectMonotonicWriter是DirectWriter的扩展结构，它在DirectWriter之上加入分组的功能。数据分片是为了让每个分片内的数据分布平稳，即标准差比较小、数据波动幅度更平缓。

它不是通用方案，它仅适用于单调递增的数组。它通过计算两者之间的增量，让所有元素迅速缩小。所以这是非常适合存储文件地址之类比较连续的数据。比如{100,102,103,105}，最终会变成{100,2,1,2}。如果将第一个元素存到.dvm文件，则变成{0,2,1,2}，仅需要一个字节即可。



StartFP是数据写入在.dvd文件的起始位置，BLOCK_SHIFT决定每个Block的大小，BlockIdx指向具体的Block位置。 每个Block都是一个独立的DirectWriter，它们有各自的元数据信息。每个Block内部是一个DirectWriter结构，这里没有展开来。

DirectMonotonicWriter的每个Block实现上是由DirectWriter编码，它还为每个Block创建索引并且保存在.dvm文件中。写入过程会记录整个Block的平均值和最小值。

使用DirectMonotonicWriter的前提是数据必须从小到大排序的，在增长平缓情况下能够达到非常不错的压缩效果。

