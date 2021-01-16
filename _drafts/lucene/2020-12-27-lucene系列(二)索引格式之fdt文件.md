 # fdt 文件


 # 这个文件存储了什么？

 正排的方式，存了每个doc对应的field数量及所有内容.

 # 能干什么？

 完事了查询的时候，能根据这个找到每个doc的具体值，　你开始给了人家什么。不是可以完整的查出来么，你根据id，查所有信息就是这么查的？

 为啥我们线上，全部使用的不存储的，　因为我们不使用这个当做正排，　我们召回id，然后有自己的正排文件　嘻嘻。
 
 构造函数中先写一个header.

1. codecHeader: Magic, codec-name,version.
2. SegmentInfo-ID, 一个唯一的字符串序列，当前segment的唯一标示
3. Segment-suffix. 传了个空进来。

每次存储一个doc，先在内存中buffer，之后在触发flush之后，统一写入。

所以fdt文件每次flush时要写:

1. chunk-header: 每一个块的header. 
    * docbase : 这个块里的第一个docID.
    * numBufferedDocs << | slice . 当前块里面缓冲了多少个doc,以及是否分片
    * 存储每个文档有多少个field.　（数组）
    * 存储每个文档的field长度   (数组)

这里在存储数组时有个特殊的技巧：
* 如果所有值都一样,那就存一个０，　然后存一个值就好了
* 如果不一样，就比较花了。　详细可以看：org.apache.lucene.codecs.compressing.CompressingStoredFieldsWriter#saveInts。

把这么多的doc的内容全部写进去，分为是否进行分片，然后使用压缩。



等完事了，　写入一个footer. org.apache.lucene.codecs.CodecUtil#writeFooter


通用的footer. 　
1. Magic. header的magic的反码
2. 0000
3. CRC32