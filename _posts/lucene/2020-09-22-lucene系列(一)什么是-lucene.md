---
layout: post
category: [lucene, 搜索]
tags:
  - lucene
  - 搜索
---



## 前言

上一个系列还没有完结，我又来开新坑啦～

接触搜索/推荐相关工作，也有两年了。工作里对lucene的接触不少，却也不精。最近工作里没有那么忙，因此想通过学习源码的方式，来对lucene进行一个系统的学习。

此外，听闻lucene源码堪称面对对象设计届的典范，也想从中吸收一些代码设计/开发方面的知识。最近老是感觉自己写的代码有问题，想尝试优化却感觉非常吃力，经常一顿操作下来提升的很有限。

## lucene简介

以下内容来自维基百科：

>Lucene是一套用于全文检索和搜索的开放源码程序库，由Apache软件基金会支持和提供。Lucene提供了一个简单却强大的应用程序接口，能够做全文索引和搜索。Lucene是现在最受欢迎的免费Java信息检索程序库。

全文检索(Full Text Retrieval)全文检索是指以全部文本信息作为检索对象的一种信息检索技术。最为常见的全文检索搜索引擎就是google和百度了，他们通过对互联网上的所有网页内容进行分析，索引，提供给我们秒级的搜索体验。其次，当前移动端各种APP，很多都内置了搜索功能，这些也是垂直领域的搜索实现。他们与google/百度的区别就是，只提供当前APP内信息的搜索，而不是互联网上的所有网页。

假设有10篇文章，每一篇都有标题和正文。当我们想找到正文中包含**原子能**的对应文章时，我们应该怎么做？

首先，最粗暴的办法，我们可以顺序读取每一篇文章，逐个字符进行判断，如果其中有连续的三个字符是 **原子能**，我们就记录下来这篇文章的标题，如此全部扫描一遍，我们就完成了一次搜索。

这个方法是相当简单粗暴，且有效的。在计算机性能十分强劲的情况下，对于1G的文件进行搜索，都可以使用这个方法(Linux下的grep命令，经常使用的话应该知道即使在GB级别的文件做些简单的搜索，通常性能也是能接受的)。

但是，数据量会远大于1G，搜索的要求也更加复杂，不是简单的字符串匹配，而是多种条件的组合。此时就需要全文搜索了。

像google这种搜索引擎，可以在0.5s的时间，搜索到与"全文搜索引擎"相关的1230w结果，这显然使用的不是顺序的逐个字符对比，而是类似于lucene的全文搜索了。
![2020-12-23-22-01-48](http://img.couplecoders.tech/2020-12-23-22-01-48.png)

lucene能做到在秒级对大量数据进行查询，依赖的就是被称之为**索引**的结构。对于索引的理解，有很多现成的例子，比如在很多书籍后，都会提供一个关键词到页码的映射，这就是一种索引，可以让我们不用通读整本书，就能找到自己关心的部分。

*在《数学之美》这本书中，作者认为全文检索的本质就是布尔代数。随着对全文检索的逐渐深入了解，越来越觉得这句话的精准，在全文检索的索引/搜索阶段，根本原理就是最简单的布尔代数，剩下的只是工程实现的复杂度问题了。*


## lucene-beta

lucene 目前已经在开发9.0版本了，整个工程分为多个模块，十分复杂。

在学习lucene源码之前，我一直在想，应该以什么路线去学习lucene，总不能随机找一个类开始看吧，那样怕是会陷入细节的汪洋大海中。

最初的想法是，从构建索引开始，走构建索引->写入磁盘->搜索请求->query分析->相关性打分->返回结果这条路线，逐步学习。

后来突然产生了一个大胆的想法，我想尝试**抽象全文检索的本质**，写一个各方面都最简单的全文检索工具(最好只有一两个类的那么简单)，之后就这个工具的各个方面如何进化成lucene的对应模块，各种缺陷lucene是如何改进的, 来进行lucene的学习。

这就是这节的标题**lucene-beta**的来源。

在我的预期中，这样做应该会有两个优点：
1. 能够更加贴近本质，不至于在局部的细节中迷失。
2. 从问题推向结论，更加符合情理。能够更加深刻的感受到**如此这般**的必要性。如无必要，那么单纯炫技又有什么意思呢？


```java
public class LuceneBeta {
    private static final Logger logger = LoggerFactory.getLogger(LuceneBeta.class);

    public static void main(String[] args) {
        LuceneBeta beta = new LuceneBeta();
        String[] arr = new String[]{"原子能研究所", "原子弹威力很大"};
        Map<Character, int[]> index = beta.build(arr);
        int[] searchRet = beta.search('威', index);
        System.out.println(Arrays.toString(searchRet));
    }

    /**
     * 对传入的字符串数组进行字符级别的构建索引
     */
    public Map<Character, int[]> build(String[] arr) {
        Set<Character> all = new HashSet<>();
        for (String s : arr) {
            for (char c : s.toCharArray()) {
                all.add(c);
            }
        }
        Map<Character, int[]> index = new HashMap<>();

        for (Character c : all) {
            int[] perContains = new int[arr.length];
            for (int w = 0; w < arr.length; w++) {
                if (arr[w].contains(String.valueOf(c))) {
                    perContains[w] = 1;
                } else {
                    perContains[w] = 0;
                }
            }
            index.put(c, perContains);
        }

        logger.info("build {} strings. indexed: ", arr.length);
        for (Map.Entry<Character, int[]> e : index.entrySet()) {
            logger.info("{} ==> {}", e.getKey(), Arrays.toString(e.getValue()));
        }
        return index;
    }


    /**
     * 查询目标字符都在哪些字符串中出现过
     */
    public int[] search(char target, Map<Character, int[]> index) {
        if (!index.containsKey(target)) {
            return null;
        }
        int[] ints = index.get(target);
        int[] tmp = new int[index.size()];
        int j = 0;
        for (int i = 0; i < ints.length; i++) {
            if (ints[i] == 1) {
                tmp[j] = i;
                j++;
            }
        }
        int[] ret = new int[j];
        System.arraycopy(tmp, 0, ret, 0, j);
        return ret;
    }

}

```

说要简单，那就要简单到底，全部代码70行。它实现了什么功能呢？

<font color="red">在给定的一系列字符串中，可以搜索某个字符出现的所有字符串编号</font>

google可以**根据你给的关键字找到对应的网页**, 上面的代码可以**根据你提供的关键字符，查找对应的字符串**, 源码已经开发了，就等融资上市了，我就是下一个google...

虽然上面的代码极其简单，但是为了后续对应lucene的分析，我还是要认真的归纳其中的每一个步骤。

上面的程序中，分为两个部分，即两个方法**build** 和　**search**.

首先是**build**过程:

1. 遍历输入的字符串，拿到所有出现的字符。
2. 对于每一个字符，统计一个字符数组，其中每一位代表当前字符在该编号的字符串中是否出现。1代表出现，0代表未出现。　如"原"在输入的两个字符串中均有出现,那么它对应的统计数组就是[1,1].
3. 将所有的字符及其统计数组，作为一份"索引"返回。

**search过程**

1. 如果输入的字符不存在，直接返回空
2. 取出对应该字符的统计数组，由二进制的表示办法，还原成原始的字符串编号。
3. 返回所有出现该字符的字符串编号。

## lucene源码架构介绍

lucene 作为一个成熟的开源软件，其包括了多个模块，其中最核心的是lucene.core包。其中又分为以下几个目录：

![2020-12-24-16-21-40](http://img.couplecoders.tech/2020-12-24-16-21-40.png)

其中：

*  org.apache.lucene.analysis 主要负责词法分析及语言处理.
*  org.apache.lucene.codecs 主要负责文本内容到倒排索引的编码和解码.
*  org.apache.lucene.document 提供了对用户内容的抽象Document,及Fields.
*  org.apache.lucene.index 主要负责对索引的读写。
*  org.apache.lucene.search 主要负责搜索过程。
*  org.apache.lucene.store 主要负责索引的持久化等内容。
*  org.apache.lucene.util 工具包。


## 结语

本文实现了极简版的lucene-beta, 当然不是为了真的替代lucene。只是对全文搜索做一个简单的抽象，用简单的功能映射lucene优秀的实现. 逐一的去学习。

最后一个小节简单的介绍了lucene.core包下的几个目录，后续的主要源码学习，将以lucene-beta中的问题为引导，分模块的逐步进行。

lucene 源码学习，正式开始啦～

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