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

本文学习一下.fnm文件的格式与内容。

fnm文件主要存储域的基础信息，前面我们知道了，在`fdt,fdm,fdx`三个文件中，配合存储了域的值信息，其中在`fdt`文件中，存储域的值信息时，为了将每个值与域名能对应起来，存储了`FieldNumberAndType`. 



## .fnm文件整体结构

![2021-01-30-16-03-51](http://img.couplecoders.tech/2021-01-30-16-03-51.png)

其中包括：


1. FieldSize: 以变长int存储的field总数
2. Name: field的名字，string格式
3. Number: field的编号，变长int
4. Bits: 以bit的形式，存储了４个布尔变量,分别为:
    4.1 hasVectors: 是否有向量的
    4.2: omitNorms:　是否有忽略归一化的
    4.3 storePayloads: 未知
    4.4: softDeleteField:  是否软删除
5. IndexOptionType: 索引选项类型
6. DocValueType: docValue存储的类型
7. DocValueGen: DocValue辅助字段
8. Attributes: 一些属性值
9. PointDimensionCount: 未知
10. PointIndexDimensionCount: 未知
11. PointNumBytes: 未知

## 相关写入代码分析





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