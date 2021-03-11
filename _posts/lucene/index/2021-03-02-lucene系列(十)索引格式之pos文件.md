---
layout: post
category: [Lucene,搜索,索引文件]
tags:
  - Lucene
  - 搜索
  - 索引文件
---

<font color="red">本文使用Lucene代码版本: 8.7.0</font>

## 前言

本文学习一下.pos文件的格式与内容。

pos文件中存储了每个term对应的位置信息.　与doc文件在同一模块进行写入.

因此文件格式与doc总体上讲也是基本相同的，因为不用存储跳跃数据(doc文件中的跳跃数据包含了pos文件的文件位置，可以协助查找)，文件反而简单了许多.


## .pos文件整体结构

![2021-03-11-21-35-57](http://img.couplecoders.tech/2021-03-11-21-35-57.png)


其中的字段解释：

* IndexHeader: 索引头
* Term: 一个term的位置信息
* Footer: 索引尾.

---

* PackedIntBlock 一整个块(128个Doc)的位置信息，使用PackedInt进行编码
* VintBlock 最后剩下的不满的一个块的位置信息及payload/offset信息，使用VInt进行编码.

*将最后一个不满128的块的payload/offset存储在pos文件而不是理论上应该的pay文件，我猜是为了方便*

---

* posDelta: term在doc中的位置信息，采用增量编码.
* docData: 这是我自己起的名字，是最后一个不满128个doc的块中，一个doc的所有信息，具体包含内容见下方.


---

* posDelta: term在doc中的位置信息，增量编码》
* payloadLength: payload的长度.
* payloadData: payload具体的字节信息.
* offsetStartDelta: term在doc中的偏移信息，采用增量编码.
* offsetLength: 偏移长度信息.


如果清楚doc文件中如何存储，那么pos文件以及下一篇文章的pay文件就不在话下啦～.

## 相关写入代码分析

### 初始化

在**org.apache.lucene.codecs.lucene84.Lucene84PostingsWriter#Lucene84PostingsWriter**构造方法中，　对该文件进行了初始化及`IndexHeader`的写入:

![2021-03-11-21-45-05](http://img.couplecoders.tech/2021-03-11-21-45-05.png).

### PackedIntBlock写入

**org.apache.lucene.codecs.lucene84.Lucene84PostingsWriter#addPosition**方法负责在内存中添加每一个文档的位置，负载，偏移量等等信息，在其中如果发现缓存够一个块(128个), 就会调用`PForUtil`进行一次编码写入：

![2021-03-11-21-47-30](http://img.couplecoders.tech/2021-03-11-21-47-30.png)

### Vint写入

每缓冲够一个快(128doc), 就会进行压缩写入，最后必然会剩下一个可能不足128的块，　采用变长Int进行编码，需要注意的是，在pos文件的`VIntBlock`中，不仅仅写入了位置信息，还同时存储了payload/offset信息。

写入代码位于: `org.apache.lucene.codecs.lucene84.Lucene84PostingsWriter#finishTerm`.

![2021-03-11-21-50-04](http://img.couplecoders.tech/2021-03-11-21-50-04.png)



## 结语

比较简单，罗列一下.

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