# DirectWriter
DirectWriter是Lucene为整型数组重编码成字节数组的工具，它的底层包含一系列编码器，将整型数组的所有元素按固定位长度的位存储。它按Bit存储，预留长度过长会浪费空间，短了会因为截断导致错误。因此需要在数组中查找最大值，由它的长度作为存储的长度。

假设有一组数据{3,16,7,12}，它们会用二进制表示是{101, 10000, 111, 1100}。占用有效位最长的是10000（5个bit），因此需要用5个bits来表示一个数值，得到如下结果。



需要注意的是，DirectWriter存储的最小单位是bit，为了充分使用Byte中每个bit会出现如下图情况，相当于把byte[]的位展开了成bit[]。

DirectWriter的Buffer是限制内存使用，避免OOM的手段，Lucene默认Buffer大小是1024Bytes。它包含压缩的long[]和压缩后的byte[]，它们两者占用内存不大于1024字节，一旦达到限制条件会将Buffer的数据编码输出。



DirectWriter用重编码方式进行数组压缩的功能，它在整个数组的所有元素都不大的情况下能带来不错的压缩效果。

# DirectMonotonicWriter
DirectMonotonicWriter是DirectWriter的扩展结构，它在DirectWriter之上加入分组的功能。数据分片是为了让每个分片内的数据分布平稳，即标准差比较小、数据波动幅度更平缓。

它不是通用方案，它仅适用于单调递增的数组。它通过计算两者之间的增量，让所有元素迅速缩小。所以这是非常适合存储文件地址之类比较连续的数据。比如{100,102,103,105}，最终会变成{100,2,1,2}。如果将第一个元素存到.dvm文件，则变成{0,2,1,2}，仅需要一个字节即可。



StartFP是数据写入在.dvd文件的起始位置，BLOCK_SHIFT决定每个Block的大小，BlockIdx指向具体的Block位置。 每个Block都是一个独立的DirectWriter，它们有各自的元数据信息。每个Block内部是一个DirectWriter结构，这里没有展开来。

DirectMonotonicWriter的每个Block实现上是由DirectWriter编码，它还为每个Block创建索引并且保存在.dvm文件中。写入过程会记录整个Block的平均值和最小值。

使用DirectMonotonicWriter的前提是数据必须从小到大排序的，在增长平缓情况下能够达到非常不错的压缩效果。

