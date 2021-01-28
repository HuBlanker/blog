---
layout: post
category: [Lucene,搜索]
tags:
  - Lucene
  - 搜索
---

## 前言

本文介绍一下.fdt文件的存储格式.

fdt文件,以正排的方式, 存储了field的原始**真实**数据. 也就是说, 你添加到所有中的所有field内容. 都会存储在此文件中.

## .fdt 文件整体结构

![2021-01-27-21-47-15](http://img.couplecoders.tech/2021-01-27-21-47-15.png)

其中**Header**和**Footer**, 与其中文件并无差别. 详细字段解释可以看 [Lucene系列(二)索引格式之fdm文件](http://huyan.couplecoders.tech/lucene/%E6%90%9C%E7%B4%A2/2020/12/27/lucene%E7%B3%BB%E5%88%97(%E4%BA%94)%E7%B4%A2%E5%BC%95%E6%A0%BC%E5%BC%8F%E4%B9%8Bfd%EF%BD%8D%E6%96%87%E4%BB%B6/)


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





![2021-01-18-21-38-12](http://img.couplecoders.tech/2021-01-18-21-38-12.png)


## 参考文章


<br>


完。
<br>
<br>
<br>


## 联系我
最后，欢迎关注我的个人公众号【 呼延十 】，会不定期更新很多后端工程师的学习笔记。
也欢迎直接公众号私信或者邮箱联系我，一定知无不言，言无不尽。
![](http://img.couplecoders.tech/%E6%89%AB%E7%A0%81_%E6%90%9C%E7%B4%A2%E8%81%94%E5%90%88%E4%BC%A0%E6%92%AD%E6%A0%B7%E5%BC%8F-%E6%A0%87%E5%87%86%E8%89%B2%E7%89%88.png)


<br>
<br>




**以上皆为个人所思所得，如有错误欢迎评论区指正。**


**欢迎转载，烦请署名并保留原文链接。**


**联系邮箱：huyanshi2580@gmail.com**


**更多学习笔记见个人博客或关注微信公众号 &lt;呼延十 &gt;------><a href="{{ site.baseurl }}/">呼延十</a>**