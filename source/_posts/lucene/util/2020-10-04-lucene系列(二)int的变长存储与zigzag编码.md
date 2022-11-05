---
layout: post
tags:
  - Lucene
  - 搜索
  - Byte
---

## 前言

lucene 代码量还是比较多的，在没有看的很明白的情况下，先写一写新学到的工具类的一些操作吧~也是收获很多。

在 lucene 写入索引文件时，为了节省空间，经常会对数据进行一些压缩，这篇文章介绍一种对 int, long 类型有用的压缩方式。即变长存储。

它在 lucene 中的应用十分广泛，有事没事就用一下，因此为了熟练的理解代码，我们还是来一探究竟吧~

在 lucene8.7.0 版本的代码中，它没有单独定义成类，可能是因为是一个小的功能点吧~

对变长数据的写入实现在`org.apache.lucene.store.DataOutput#writeVInt`中，对变长数据的读取实现在`org.apache.lucene.store.DataInput#readVInt`.

## 定义

什么叫做变长存储？我们以`writeVInt`为例，看看注释：

>Writes an int in a variable-length format. Writes between one and five bytes. Smaller values take fewer bytes. Negative numbers are supported, but should be avoided.
VByte is a variable-length format for positive integers is defined where the high-order bit of each byte indicates whether more bytes remain to be read. The low-order seven bits are appended as increasingly more significant bits in the resulting integer value. Thus values from zero to 127 may be stored in a single byte, values from 128 to 16,383 may be stored in two bytes, and so on.

简单翻译一下：

> 以可变长度格式写入一个整数。写入 1-5 个字节。越小的值占用的字节越少。支持负数但是尽量别用。
VByte 是正整数的变长格式，每个 byte 的高位用来标识是否还有更多的字节需要读取。低位的 7 个 bit 位代表实际的数据。将逐渐读取到的低位附加作为越来越高的高位，就可以拿到原来的整数。

0~127 只需要一个字节，128~16383 需要两个字节，以此类推。

**从这里看到，变长整数存储的压缩率，是和数字大小有关系的，数字越小，压缩率越高，如果全是最大的 int, 反而需要更多的字节来存储。**

## 实现

我们实现一个简单的工具类，能实现上述的变长存储 (lucene 代码 copy 出来）, 之外提供一些辅助我们看源码的方法。

```java
public class VariableInt {

    /**
     * transfer int to byte[] use variable format
     */
    public static byte[] writeVInt(int i) {
        int bytesRequired = bytesRequired(i);
        byte[] res = new byte[bytesRequired];
        int idx =0;
        while ((i & ~0x7F) != 0) {
            res[idx++] = ((byte) ((i & 0x7F) | 0x80));
            i >>>= 7;
        }
        res[idx] = (byte) i;
        return res;
    }

    /**
     * transfer byte[] to int use variable format
     */
    public static int readVInt(byte [] vs) throws IOException {
        int idx = 0;
        byte b = vs[idx++];
        // 大于 0, 说明第一位为 0, 说明后续没有数据需要读取
        if (b >= 0) return b;
        int i = b & 0x7F;
        b = vs[idx++];
        i |= (b & 0x7F) << 7;
        if (b >= 0) return i;
        b = vs[idx++];
        i |= (b & 0x7F) << 14;
        if (b >= 0) return i;
        b = vs[idx++];
        i |= (b & 0x7F) << 21;
        if (b >= 0) return i;
        b = vs[idx];
        // Warning: the next ands use 0x0F / 0xF0 - beware copy/paste errors:
        i |= (b & 0x0F) << 28;
        if ((b & 0xF0) == 0) return i;
        throw new IOException("Invalid vInt detected (too many bits)");
    }

    /**
     * compute int need bytes.
     */
    public static int bytesRequired(int i) {
        if (i < 0) throw new RuntimeException("I Don't Like Negative.");
        if ((i >>> 7) == 0) return 1;
        if ((i >>> 14) == 0) return 2;
        if ((i >>> 21) == 0) return 3;
        if ((i >>> 28) == 0) return 4;
        return 5;
    }
}

```

除了读取写入意外，提供了一个计算 int 数字需要几个 byte 来存储的方法。在我们 debug 源码时，可以帮助我们分析写入的索引文件。

VariableLong 的代码就不贴了。和 Variable 基本相同，只是变长的长度从 1-5 变成了 1-9 而已。

## zigzag 编码

在 Lucene 实现的 DataOutPut 中，我们可以看到`writeZint(int i)`方法，经过了解，它使用 zigzag 编码+变长存储来存储一个整数。

什么是 zigzag 编码？

首先我们回顾一下计算机编码：

- 原码：最高位为符号位，剩余位表示绝对值；
- 反码：除符号位外，对原码剩余位依次取反；
- 补码：对于正数，补码为其自身；对于负数，除符号位外对原码剩余位依次取反然后+1。

为了方便及其他问题，计算机使用**补码**来存储整数。

那么我们的变长整数就有一个问题。他对于负数很不友好。

- 1 这个 int 整数，本身存储使用 4 个字节，通过上文的变长编码，使用一个字节即可。
- -1 这个 int 整数，他的补码为：`11111111111111111111111111111111`, 也就是说全部是 1. 你这时候用变长编码来存储，需要 5 个字节，压缩的目的达不到了。反而多占了空间。

那么基于一个共识：**小整数用的多，因此需要变长编码**. **小的负整数也不少，变长编码会压缩率不高甚至反向压缩**.

因此诞生了 zigzag 编码，它可以有效的处理负数。它的底层逻辑是：**按绝对值升序排列，将整数 hash 成递增的 32 位 bit 流，其 hash 函数为 h(n) = (n << 1) ^ (n >> 31)**,

hash 函数的作用如图所示：

![2021-01-24-02-28-35](http://img.couplecoders.tech/2021-01-24-02-28-35.png)

设想一下这个 hash 函数做了什么？

对于小的负整数而言：

1. 左移 1 位可以消去符号位，低位补 0
2. 有符号右移 31 位将符号位移动到最低位，负数高位补 1，正数高位补 0
3. 按位异或
    对于正数来说，最低位符号位为 0，其他位不变
    对于负数，最低位符号位为 1，其他位按位取反

那么-1 的表示变成了`00000000000000000000000000000001`, 比较小，适合使用变长编码了。
1 的表示变成了`00000000000000000000000000000010`, 虽然增大了一点，但是仍然很小，也适合使用变长编码了。

总结一下：

zigzag 编码解决了使用变长编码时小的负整数压缩率太低的问题，它基于一个共识，就是我们使用的小整数（包括正整数和负整数） 是比较多的。因此将负整数映射到正整数这边来操作。

对应表是：

整数 | zigzag
--- | ---
0 | 0
-1 | 1
1 | 2
-2 | 3
2 | 4
-3 | 5 
3 | 6

## zigzag 实现

这个 zigzag 的实现比较简单，在上面已经实现了变长编码的基础上。只需要实现一个简单的 hash 函数就好了。

```java
    /**
     * transfer int to byte[] use zig-zag-variable format
     */
    public static byte[] writeZInt(int i) {
        // zigzag 编码
        i = (i >> 31) ^ (i << 1);
        return writeVInt(i);
    }

    /**
     * transfer byte[] to int use zig-zag-variable format
     */
    public static int readZInt(byte[] vs) throws IOException {
        int i = readVInt(vs);
        return ((i >>> 1) ^ -(i & 1));
    }
```

完美。

## 总结

本文简单介绍了。
1. 使用变长编码来对整数进行压缩，对于小正整数能取得不错的压缩率。
2. 使用 zigzag 编码对整数进行编码，可以解决掉变长编码对于小负整数压缩率低的难点。

因此，当你确认你的待压缩数字，都是比较小的正负整数，就使用 zigzag+变长编码来进行压缩吧，压缩率 25~50%还是可以做到的。

很多需要序列化的开源程序，都是用 zigzag+变长编码来进行整数的压缩，比如 google 的 protobuf, apache 的 avro 项目，apache 的 lucene 项目，都在一些场景使用了这套连招，快快使用吧~.

<br>

完。
<br>

## 联系我
最后，欢迎关注我的个人公众号【 呼延十 】，会不定期更新很多后端工程师的学习笔记。
也欢迎直接公众号私信或者邮箱联系我，一定知无不言，言无不尽。
![](http://img.couplecoders.tech/%E6%89%AB%E7%A0%81_%E6%90%9C%E7%B4%A2%E8%81%94%E5%90%88%E4%BC%A0%E6%92%AD%E6%A0%B7%E5%BC%8F-%E6%A0%87%E5%87%86%E8%89%B2%E7%89%88.png)

<br>

**以上皆为个人所思所得，如有错误欢迎评论区指正。**

**欢迎转载，烦请署名并保留原文链接。**

**联系邮箱：huyanshi2580@gmail.com**

**更多学习笔记见个人博客或关注微信公众号 &lt; 呼延十 &gt;------><a href="{{ site.baseurl }}/">呼延十</a>**