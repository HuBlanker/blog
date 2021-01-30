---
layout: post
category: [Lucene,搜索,索引文件,Lucene工具]
tags:
  - Lucene
  - 搜索
  - 索引文件
  - Lucene工具
---

## 前言

来学习一下`DirectMonotonicWriter`类的代码. <font color="red">源码版本: 8.7.0</font> 

## 介绍

先上一下源码注释:

>Write monotonically-increasing sequences of integers. This writer splits data into blocks and then for each block, computes the average slope, the minimum value and only encode the delta from the expected value using a DirectWriter.

简单翻译:

>用来写入单调递增的int序列. 
>它把数据分成块,然后对于每一个块, 计算平均斜率,最小值,然后只使用`DirectWriter`来编码给定数字的delta(翻译成增量,有更好的翻译再来修改,欢迎建议).


它不是一个通用的解决方案, 只适用于单调递增数组, 他通过计算元素之的增量, 让所有元素迅速变小. 之后使用`DirectWriter`来进行压缩存储,以获得更好的压缩率. 因此它很适合存储文件地址之类比较连续的数据.

## 实例

让我们通过一个实例, 来知道这个类做了什么,之后再学习一下具体的代码.

假如要存储4个数字, {100,102,103,105}.

首先算一下平均斜率: `avgInc = (105-100) / 3 = 1.6666666`.
之后对每个数字计算`符合斜率的期望值与实际值的差值`, 算法为: `expected = (long) (avgInc * (long) idx)`, 然后使用每个数字减去期望值,数组变成了 {100,101,100,100}.

求出最小值, `min = 100`.

然后,对于每个位置的数字, 计算它与最小值的差值. 数组变成了: {0,1,0,0 }

算一下`maxDelta`, 这个值是上面最后生成的数组中, 最大的一个数字,如果上面的数组全部是0, 这个值也为0, 就说明给定的原始数组是一个标准的单调递增的等差数列, 那么就不用存原始值了,直接用最小值和斜率就能全部算出来. 如果不为0, 那么`maxDelta`就是用`DirectWriter`存储时的最大值, 不知道为啥`DirectWriter`存储需要提前告知最大值的可以看这里~ [lucene中DirectWriter类的源码学习](http://huyan.couplecoders.tech/lucene/%E6%90%9C%E7%B4%A2%EF%BC%8C%E6%95%B4%E6%95%B0%E7%BC%96%E7%A0%81/2020/12/16/lucene%E7%B3%BB%E5%88%97(%E4%B8%89)DirectWriter%E6%BA%90%E7%A0%81%E5%88%86%E6%9E%90/)

用maxDelta计算出需要的最大bit数. `bitsPerValue`.

之后进行实际的写入.

1. 将`min,avgInc, Offset, bitsPerValue`, 写入meta文件.
2. 将各种生成,改变之后的数组写入data文件.


我们写个单测, 将上面的信息实际写入文件. 让我们看看十六进制的文件.

Meta文件:

![2021-01-25-01-47-14](http://img.couplecoders.tech/2021-01-25-01-47-14.png)

图中:
1. 是计算的最小值: 100L. long型占用8个字节
2. 是AvgInc的int表示. 他将1.666666用int表示如图
3. 这是我们的第一个block. 所以相对偏移量为0. 用8个字节存储了0.
4. 我们最后的数组为[0,1,0,0], 在`DirectWriter`中,每一个数字只使用1个bit就可以表示. 因此这里存储了1, 只占用一个字节.

![2021-01-25-01-49-49](http://img.couplecoders.tech/2021-01-25-01-49-49.png)

这是data文件, 如果了解`DirectWriter`的话, 可以知道, 这次写入是以byte为单位的. 因此前面的`40=0100 0000`, 前面的`0100`就是我们存储的值, 与上面分析相符合. 后面4位0是byte自动填充的.

而后面三个字节的0, 是`DirectWriter`自动写入的,与我们此次实验无关.


## 原理 

根据上面的meta信息及data信息,是完全可以推算出原始值的(压缩了而解压不了岂不是笑话).

![2021-01-25-01-32-42](http://img.couplecoders.tech/2021-01-25-01-32-42.png)

一个单调递增数组(只讨论正数), 连接首尾之后, 必然是一条在第一象限的类似于图中的直线.

我数学不好...

这条直线是`y=ax+b`. 我们记录下来: `b`,也就是min值.`a`就是斜率. 记下来这两个信息就可以还原出这条直线.

之后我们有一个数组, 下标可以带入公式算出对应下标的期望值,数组具体位置上保存着, `实际值与期望值之间的差值, 再减去最小值`. 就可以还原每一个点了, 也就是原始数据.

## 源码学习

上面一不小心说多了, 好多剧透了, 所以源码部分就简单看一下.

### 属性

```java

  // 一块有多少个int,　这里是 2的shift次方个
  public static final int MIN_BLOCK_SHIFT = 2;
  public static final int MAX_BLOCK_SHIFT = 22;

  // 这个类，　其实不知道是为了谁写
  // 但是仍然不妨碍一个记录元数据，一个记录真正的数据，
  // 写field信息可以用，其他的docValue之类的也可以
  final IndexOutput meta;
  final IndexOutput data;

  // 总数, 不区分chunk,block等等，对于这个类来说，就是你想要我写多少个。
  final long numValues;

  // data文件初始化的时候的文件写入地址.
  final long baseDataPointer;

  // 内部缓冲区
  final long[] buffer;
  // 当前已经buffer了多少个
  int bufferSize;
  // 总数计数，bufferSize会被清除的
  long count;
  boolean finished;

```

具体解释见注释, 注意一下有个buffer即可.

### 构造方法

```java
  DirectMonotonicWriter(IndexOutput metaOut, IndexOutput dataOut, long numValues, int blockShift) {
    if (blockShift < MIN_BLOCK_SHIFT || blockShift > MAX_BLOCK_SHIFT) {
      throw new IllegalArgumentException("blockShift must be in [" + MIN_BLOCK_SHIFT + "-" + MAX_BLOCK_SHIFT + "], got " + blockShift);
    }
    if (numValues < 0) {
      throw new IllegalArgumentException("numValues can't be negative, got " + numValues);
    }


    // 根据总数，以及每块的数据，来算总共需要的块的数量。　算法约等于，总数 / (2 ^ blockShift);
    // 这里只是校验一下这两个数字的合法性，实际限制在
    final long numBlocks = numValues == 0 ? 0 : ((numValues - 1) >>> blockShift) + 1;
    if (numBlocks > ArrayUtil.MAX_ARRAY_LENGTH) {
      throw new IllegalArgumentException("blockShift is too low for the provided number of values: blockShift=" + blockShift +
          ", numValues=" + numValues + ", MAX_ARRAY_LENGTH=" + ArrayUtil.MAX_ARRAY_LENGTH);
    }
    this.meta = metaOut;
    this.data = dataOut;
    this.numValues = numValues;
    // blockSize算到了，　然后缓冲区的大小就是blockSize或者极限情况下很少，就是numValues.
    final int blockSize = 1 << blockShift;
    this.buffer = new long[(int) Math.min(numValues, blockSize)];
    this.bufferSize = 0;
    this.baseDataPointer = dataOut.getFilePointer();
  }

```

注意buffer大小的计算, 如果数据足够多, buffer的大小为: 2 << blockShift. 否则buffer为numValues.

### add 方法

```java
  /**
   * Write a new value. Note that data might not make it to storage until
   * {@link #finish()} is called.
   *
   * @throws IllegalArgumentException if values don't come in order
   *                                  写一个新的值，
   *                                  但是不一定立即存储，可能在finish的时候才存储
   *                                  如果传入的值不是递增的，就报错
   */
  public void add(long v) throws IOException {
    // 检查是否是单调递增
    if (v < previous) {
      throw new IllegalArgumentException("Values do not come in order: " + previous + ", " + v);
    }
    // 内部缓冲区满，意味着，分块的一块满了, 缓冲区是之前根据分块大小算好的
    if (bufferSize == buffer.length) {
      flush();
    }

    // 缓冲区没满，先放到内存buffer里面
    buffer[bufferSize++] = v;
    previous = v;
    count++;
  }

```

和常见的output一样,一个朴实无华的内存buffer,如果buffer满了则调用flush.

注意在add时会检测当前值是否大于上一个, 来保存传入数据是单调递增的.

### flush方法

```java
  /**
   * // 一个块满了，或者最终调用finish了，就写一次
   * <br/>
   * <br/>
   * <b>计算方法终于搞明白了，存储一个单调递增数组，要存储斜率，最小值，以及delta，再加上index就可以算出来</b>
   * 举例 [100,101,108] 经过计算之后存储的[3,0,3], 斜率4.0. 最小值97.
   * 开始计算：
   * 1. 100 = 97 + 3 + 0 * 4.0
   * 2. 101 = 97 + 0 + 1 * 4.0
   * 3. 108 = 97 + 3 + 2 * 4.0
   * 完美
   * <br/>
   * <br/>
   * 一个block，这么搞一下
   *
   * @throws IOException
   */
  private void flush() throws IOException {
    assert bufferSize != 0;

    // 斜率算法, 最大减去最小除以个数，常见算法
    final float avgInc = (float) ((double) (buffer[bufferSize - 1] - buffer[0]) / Math.max(1, bufferSize - 1));

    // 根据斜率，算出当前位置上的数字，比按照斜率算出来的数字，多了多少或者小了多少，这就是增量编码
    // 当前存了个３，预期是500,那就存储-497.
    // 有啥意义么？　能把大数字变成小数字？节省点空间？
    // 这里会把单调递增的数字，算一条执行出来，首尾连接点. 然后每个数字对着线上对应点的偏移距离，画个图会好说很多，一个一元一次方程么？
    for (int i = 0; i < bufferSize; ++i) {
      final long expected = (long) (avgInc * (long) i);
      buffer[i] -= expected;
    }

    // 但是存的不是真实值，而是偏移量
    long min = buffer[0];
    for (int i = 1; i < bufferSize; ++i) {
      min = Math.min(buffer[i], min);
    }

    // 每个位置上存储的，不是偏移量了，而是偏移量与最小的值的偏移量
    // 然后算个最大偏移量
    long maxDelta = 0;
    for (int i = 0; i < bufferSize; ++i) {
      buffer[i] -= min;
      // use | will change nothing when it comes to computing required bits
      // but has the benefit of working fine with negative values too
      // (in case of overflow)
      maxDelta |= buffer[i];
    }

    // 元数据里面开始写, 最小值，平均斜率，data文件从开始到现在写了多少，
    meta.writeLong(min);
    meta.writeInt(Float.floatToIntBits(avgInc));
    // 当前block, 相对于整个类开始写的时候, 的偏移量
    meta.writeLong(data.getFilePointer() - baseDataPointer);
    // 是不是意味着全是0, 也就是绝对的单调递增,等差数列的意思？
    // 如果是等差数列，就不在data里面写了，直接在meta里面记一下最小值就完事了，之后等差就好了
    if (maxDelta == 0) {
      // 最大偏移量为，那就写个0
      meta.writeByte((byte) 0);
    } else {
      // 最大需要多少位
      final int bitsRequired = DirectWriter.unsignedBitsRequired(maxDelta);
      // 把缓冲的数据实际的写到data文件去
      DirectWriter writer = DirectWriter.getInstance(data, bufferSize, bitsRequired);
      for (int i = 0; i < bufferSize; ++i) {
        writer.add(buffer[i]);
      }
      writer.finish();

      // 写一下算出来的最大需要多少位
      meta.writeByte((byte) bitsRequired);
    }

    // 缓冲的数据归零，这样就能一直用内存里的buffer了
    bufferSize = 0;
  }

```

每当一个block满了,或者最终进行flush. 都是以当前的block为单位:

进行计算最小值,斜率, 及对数组进行转换. 

之后将最小值,斜率, data文件偏移量, 每个数字需要的bit数量等元数据,写入对应的元数据文件中.

将按照上面分析的规则, 进行转换过的数组, 调用`DirectWriter`,写入data文件中.

### finish

```java
  /**
   * This must be called exactly once after all values have been {@link #add(long) added}.
   * 所有数字都被调用过all之后，
   * 要调用且只能调用一次finish.
   */
  public void finish() throws IOException {
    if (count != numValues) {
      throw new IllegalStateException("Wrong number of values added, expected: " + numValues + ", got: " + count);
    }
    // 保证只能调用一次
    if (finished) {
      throw new IllegalStateException("#finish has been called already");
    }
    // 调用finish的时候，有缓冲就直接写，反正也只能调用一次
    if (bufferSize > 0) {
      flush();
    }
    finished = true;
  }

```

也是常见的朴实无华, 检查下相关参数,然后调用一下flush,将最后一点数据写入磁盘即可.

## 总结

`DirectMonotonicWriter`类, 用来压缩存储单调递增的整数数组. 它会写入两个文件, 其中`meta`文件存储计算后的元数据, `data`文件存储转换后的数组.

他内部进行了分块, 然后以块为单位, 通过计算最小值,斜率等辅助参数, 将原始数据转换成相对增量,以将大整数转换成为小整数. 之后使用`DirectWriter`来进行按bit的压缩存储. 结合`DirectWriter`对小整数压缩率较高的特点, 这个类实现了对单调递增数组的高压缩率的压缩存储.


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