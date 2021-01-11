


* org.apache.lucene.index.IndexFileNames  记录了一些文件名的生成规则
* Directory 操作文件夹下的所有文件的抽象层

org.apache.lucene.index.DocumentsWriter#updateDocuments 添加/更新文档操作



org.apache.lucene.util.Accountable 统计内存占用的，这个玩意靠谱




# org.apache.lucene.index.SegmentInfos

第一个比较重要的类，　

是分片对象的一个集合，　同时定义了分片和文件系统之间的操作方法。

当前还在活跃的分片，　记录在segment_N文件中，可能会同时存在多个文件，以Ｎ最大的一个文件为准。（旧的segment_N文件不删除的原因是当前暂时不能删除，　或者用户使用了一些自定义的删除策略导致的）

Segment_N根据名字列出了所有的segment,还有一些编码的细节及generate of deletes. (后面这句没懂)

**在注释里，写了segment_N文件的具体存储格式。**

 org.apache.lucene.index.SegmentInfo 具体的一个segment相关信息
 org.apache.lucene.index.SegmentCommitInfo 持有一个只读的segmentInfo, 还有一些提交前添加的信息


 # codec

 codec包，定义了每个版本的各种文件的详细格式，当然可能存在lucene9中，　还有一种文件自从lucene5以来都没有改，　所以还在使用，问题不大。

 入口是org.apache.lucene.codecs.Codec类，它持有一个默认的全局Codec实例，具体是哪个版本的，　由 META-INF/servers 目录下的文件决定，　之后由java spi 机制，加载进来。

 当前我看的源码，是９.0.0，所以加载的是org.apache.lucene.codecs.lucene90.Lucene90Codec，　这个类里，直接对各种文件应该使用的Format进行了实例化，所以想知道某个文件应用的是哪个类定义的格式，直接来这里看，之后具体的Formater注释里就有详细的文件格式定义了。

 比如词向量的文件格式，用的依然是5.0之后的格式，Lucene50TermVectorsFormat, 这个类的注释里，详细定义了（.tvd）文件中的内容，及每一项内容的具体含义，还有(.tvx)文件的。他之后其实应用的是：org.apache.lucene.codecs.TermVectorsWriter。　这个的压缩版本，org.apache.lucene.codecs.compressing.CompressingTermVectorsWriter　比较麻烦，　暂时不细看了。

