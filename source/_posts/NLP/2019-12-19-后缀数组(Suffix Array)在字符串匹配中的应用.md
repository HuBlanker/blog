---
layout: post
tags:
  - Java
  - 数据结构
  - 算法
---

## 前言

首先抛出一个问题: `给定300w字符串A, 之后给定80w字符串B, 需要求出 B中的每一个字符串, 是否是A中某一个字符串的子串. 也就是拿到80w个bool值`.

当然, 直观的看上去, 有一个暴力的解法, 那就是 双重循环, 再调用字符串德`contains`方法, 想法很美好, 现实很残酷. 如果你真的这么实现了(是的, 我做了.), 就会发现,效率低到无法接受.具体的效率测评在后文给出.

此时我们可以用一个叫`Suffix Array`的数据结构来辅助我们完成这个任务.

## Suffix Array 介绍

>在计算机科学里, 后缀数组（英语：suffix array）是一个通过对字符串的所有后缀经过排序后得到的数组。此数据结构被运用于全文索引、数据压缩算法、以及生物信息学。

>后缀数组被乌迪·曼伯尔（英语：Udi Manber）与尤金·迈尔斯（英语：Eugene Myers）于1990年提出，作为对后缀树的一种替代，更简单以及节省空间。它们也被Gaston Gonnet 于1987年独立发现，并命名为“PAT数组”。

>在2016年，李志泽，李建和霍红卫提出了第一个时间复杂度（线性时间）和空间复杂度（常数空间）都是最优的后缀数组构造算法，解决了该领域长达10年的open problem。


让我们来认识几个概念:
* 子串
　　字符串S的子串r[i..j]，i<=j，表示S串中从i到j-1这一段，就是顺次排列r[i],r[i+1],...,r[j-1]形成的子串。 比如 **abcdefg**的0-3子串就是 **abc**.
* 后缀
　　后缀是指从某个位置 i 开始到整个串末尾结束的一个特殊子串。字符串r的从第i个字符开始的后缀表示为Suffix(i)，也就是Suffix(i)=S[i...len(S)-1]。比如 **abcdefg** 的 `Suffix(5)` 为 **fg**.
* 后缀数组(SA[i]存放排名第i大的后缀首字符下标)
　　后缀数组 SA 是一个一维数组，它保存1..n 的某个排列SA[1] ，SA[2] ，...,SA[n] ，并且保证Suffix(SA[i])<Suffix(SA[i+1])， 1<=i<n 。也就是将S的n个后缀从小到大进行排序之后把排好序的后缀的开头位置顺次放入SA 中。
* 名次数组（rank[i]存放suffix(i)的优先级）
名次数组 Rank[i] 保存的是 Suffix(i) 在所有后缀中从小到大排列的“名次”


看完上面几个概念是不是有点慌? 不用怕, 我也不会. 我们要牢记自己是工程师, 不去打比赛, 因此不用实现完美的后缀数组. 跟着我的思路, 用简易版后缀数组来解决前言中的问题.

## 应用思路

首先, 大概的想明白一个道理. A是B的子串, 那么A就是B的一个后缀的前缀. 比如`pl`是`apple`的子串. 那么它是`apple`的后缀`ple`的前缀`pl`.

好的, 正式开始举栗子.

题目中的A, 有300w字符串.我们用4个代替一下.

```
apple
orange
pear
banana
```

题目中的B, 有80w字符串. 我们用一个代替一下.

```
ear
```
.

我们的目的是, 找`ear`是否是A中四个字符串中的某一个的子串. 求出一个`TRUE/FALSE`.

那么我们首先求出A中所有的字符串德所有子串.放到一个数组里.

比如 **apple**的所有子串为:

```text
apple
pple
ple
le
e
```

将A中所有字符串的所有子串放到 **同一个** 数组中, 之后把这个数组按照字符串序列进行排序.

*注: 为了优化排序的效率, 正统的后缀数组进行了大量的工作, 用比较复杂的算法来进行了优化, 但是我这个项目是一个离线项目, 几百万排序也就一分钟不到, 因此我是直接调用的`Arrays.sort`.如果有需要, 可以参考网上的其他排序方法进行优化排序.*

比如只考虑apple的话, 排完序是这样子的.

```
apple
e
le
ple
pple
```

为什么要进行排序呢? 为了应用二分查找, 二分查找的效率是`O(logN)`,极其优秀.

接下来是使用待查找字符串进行二分查找的过程, 这里就不赘述了. 可以直接去代码里面一探究竟.

## 代码实现

```java
package com.huyan.sa;

import java.util.*;

/**
 * Created by pfliu on 2019/12/28.
 */
public class SuffixArray {

    private List<String> array;


    /**
     * 用set构建一个后缀数组.
     */
    public static SuffixArray build(Set<String> stringSet) {
        SuffixArray sa = new SuffixArray();
        sa.array = new ArrayList<>(stringSet.size());
        // 求出每一个string的后缀
        for (String s : stringSet) {
            sa.array.addAll(suffixArray(s));
        }
        sa.array.sort(String::compareTo);
        return sa;
    }

    /**
     * 求单个字符串的所有后缀数组
     */
    private static List<String> suffixArray(String s) {
        List<String> sa = new ArrayList<>(s.length());
        for (int i = 0; i < s.length(); i++) {
            sa.add(s.substring(i));

        }
        return sa;
    }

    /**
     * 判断当前的后缀数组,是否有以s为前缀的.
     * 本质上: 判断s是否是构建时某一个字符串德子串.
     */
    public boolean saContains(String s) {
        int left = 0;
        int right = array.size() - 1;
        while (left <= right) {
            int mid = left + ((right - left) >> 1);
            String suffix = array.get(mid);
            int compareRes = compare1(suffix, s);
            if (compareRes == 0) {
                return true;
            } else if (compareRes < 0) {
                left = mid + 1;
            } else {
                right = mid - 1;
            }
        }
        return false;
    }

    /**
     * 比较两个字符串,
     * 1. 如果s2是s1的前缀返回0.
     * 2. 其余情况走string的compare逻辑.
     * 目的: 为了在string中使用二分查找,以及满足我们的,相等就结束的策略.
     */
    private static int compare1(String s1, String s2) {
        if (s1.startsWith(s2)) return 0;
        return s1.compareTo(s2);
    }

}
```

实现的比较简单,因为是一个简易的SA. 主要分为两个方法:
* build(Set<String>): 将传入的所有字符串构建一个后缀数组.
* saContains(String): 判断传入的字符串是否是某个后缀的前缀(本质上, 判断传入的字符串是否是构建时某一个字符串德子串).

## 评估

我们对性能做一个简易的评估.

评估使用代码:

```java
    @Test
    public void perf() throws IOException {
        // use sa
        long i = System.currentTimeMillis();
        List<String> A = Files.readAllLines(Paths.get("/Users/pfliu/data/old_data/A.txt"));
        SuffixArray sa = SuffixArray.build(new HashSet<>(A));

        int right = 0;
        int wrong = 0;
        List<String> B = Files.readAllLines(Paths.get("/Users/pfliu/data/old_data/B.txt"));
        for (String s : B) {
            if (sa.saContains(s)) {
                right++;
            } else {
                wrong++;
            }
        }
        log.info("use sa. all={}, right={}, wrong={}. time={}", B.size(), right, wrong, System.currentTimeMillis() - i);



        // violence
        wrong = 0;
        right = 0;
        //count
        int count = 0;
        long time = System.currentTimeMillis();
        for (String s : B) {
            boolean flag = false;
            for (String s1 : A) {
                if (s1.contains(s)) {
                    flag = true;
                    right++;
                    break;
                }
            }
            if (!flag) wrong++;
            if (++count % 1000 == 0) {
                log.info("use biolence. deal {} word. now right ={}, wrong ={}, time={}", count, right, wrong, System.currentTimeMillis() - time);
                time = System.currentTimeMillis();
            }
        }
    }
```

这里是输出部分日志(我没有等待暴力解法跑完):

```text
16:29:35.440 [main] INFO com.huyan.sa.SuffixArrayTest - use sa. all=815971, right=433402, wrong=382569. time=35371
16:29:49.748 [main] INFO com.huyan.sa.SuffixArrayTest - use biolence. deal 1000 word. now right =855, wrong =145, time=14301
16:30:11.807 [main] INFO com.huyan.sa.SuffixArrayTest - use biolence. deal 2000 word. now right =1625, wrong =375, time=22059
16:30:38.272 [main] INFO com.huyan.sa.SuffixArrayTest - use biolence. deal 3000 word. now right =2343, wrong =657, time=26465
16:31:07.080 [main] INFO com.huyan.sa.SuffixArrayTest - use biolence. deal 4000 word. now right =3019, wrong =981, time=28808
16:31:36.550 [main] INFO com.huyan.sa.SuffixArrayTest - use biolence. deal 5000 word. now right =3700, wrong =1300, time=29470
16:32:07.141 [main] INFO com.huyan.sa.SuffixArrayTest - use biolence. deal 6000 word. now right =4365, wrong =1635, time=30590
16:32:39.338 [main] INFO com.huyan.sa.SuffixArrayTest - use biolence. deal 7000 word. now right =5030, wrong =1970, time=32197
16:33:13.781 [main] INFO com.huyan.sa.SuffixArrayTest - use biolence. deal 8000 word. now right =5641, wrong =2359, time=34443
16:33:47.392 [main] INFO com.huyan.sa.SuffixArrayTest - use biolence. deal 9000 word. now right =6269, wrong =2731, time=33611
16:34:21.783 [main] INFO com.huyan.sa.SuffixArrayTest - use biolence. deal 10000 word. now right =6878, wrong =3122, time=34391
```

我的评估集: A=80w. B=310w.


可以看到, 结果很粗暴.

使用 **SA**的计算完所有结果,耗时35s.
暴力解法,计算1000个就需要30s. 随着程序运行, cpu时间更加紧张. 还可能会逐渐变慢.

## 结论

可以看出, 在这个题目中, SA的效率相比于暴力解法是碾压性质的. 

需要强调的是, 这个"题目"是我在工作中真实碰到的, 使用暴力解法尝试之后, 由于效率太低, 在大佬指点下使用了SA. 30s解决问题.

因此, 对于一些常用算法, 我们不要抱着 "我是工程师,又不去算法比赛,没用" 的心态, 是的, 我们不像在算法比赛中那样分秒必争, 但是很多算法的思想, 却能给我们的工作带来极大的提升.

<br>

## 参考文章

https://blog.csdn.net/u013371163/article/details/60469533

https://zh.wikipedia.org/zh-hans/%E5%90%8E%E7%BC%80%E6%95%B0%E7%BB%84

完。
<br>
<br>
<br>


## 联系我
最后，欢迎关注我的个人公众号【 呼延十 】，会不定期更新很多后端工程师的学习笔记。
也欢迎直接公众号私信或者邮箱联系我，一定知无不言，言无不尽。
![](http://img.couplecoders.tech/%E6%89%AB%E7%A0%81_%E6%90%9C%E7%B4%A2%E8%81%94%E5%90%88%E4%BC%A0%E6%92%AD%E6%A0%B7%E5%BC%8F-%E6%A0%87%E5%87%86%E8%89%B2%E7%89%88.png)


<br>
<h4>ChangeLog</h4>
2019-12-28 完成
<br>
<br>




**以上皆为个人所思所得，如有错误欢迎评论区指正。**


**欢迎转载，烦请署名并保留原文链接。**


**联系邮箱：huyanshi2580@gmail.com**


**更多学习笔记见个人博客或关注微信公众号 &lt;呼延十 &gt;------><a href="{{ site.baseurl }}/">呼延十</a>**