---
layout: post
tags:
  - Lucene
  - 搜索
---

## 前言

这篇文章介绍。fdx 文件格式。

## .fdx 文件整体格式

![2021-01-28-19-21-27](http://img.couplecoders.tech/2021-01-28-19-21-27.png)

看起来比较简单，实际写入代码是 fdt,fdm,fdx 三个文件中最复杂的。

其中内容包括：
1. IndexHeader. 索引文件头，前面说过，就不细说了。
2. Footer: 索引文件脚，不细说。
3. ChunkDocsNum: 一个数组，含义是：每个 Chunk 中的 doc 数量。
4. ChunkStartPoint: 一个数组，含义是：每个 chunk 的内容在 fdt 文件中文件地址。

鉴于存储方式比较复杂，我们就直接快进到源代码。

## 写入代码分析

在`CompressingStoredFieldsWriter`类的构造函数中，初始化了`FieldsIndexWriter`类的实例，由它来进行 fdx 文件的写入，看看他的构造函数。

```java
  FieldsIndexWriter(Directory dir, String name, String suffix, String extension,
                    String codecName, byte[] id, int blockShift, IOContext ioContext) throws IOException {
    this.dir = dir;
    this.name = name;
    this.suffix = suffix;
    this.extension = extension;
    this.codecName = codecName;
    this.id = id;
    this.blockShift = blockShift;
    this.ioContext = ioContext;
    // docNum 的 tmp 文件
    this.docsOut = dir.createTempOutput(name, codecName + "-doc_ids", ioContext);
    boolean success = false;
    try {
      CodecUtil.writeHeader(docsOut, codecName + "Docs", VERSION_CURRENT);

      // StartPoint 的 tmp 文件
      filePointersOut = dir.createTempOutput(name, codecName + "file_pointers", ioContext);
      CodecUtil.writeHeader(filePointersOut, codecName + "FilePointers", VERSION_CURRENT);
      success = true;
    } finally {
      if (success == false) {
        close();
      }
    }
  }

```

在构造函数中，没有创建 fdx 文件，而是创建了两个临时文件，`docsOut`和`filePointOut`. 分别用于存储前面提到的两份数据。`每个 Chunk 中的 doc 数量`及`每个 chunk 的内容在 fdt 文件中文件地址`.

之后，每次向 fdt 文件中，写入一个 chunk 的内容，同时会调用下方的方法，写入当前 chunk 的 doc 数量，及 fdt 文件地址。注意写入的是临时文件。

```java
  void writeIndex(int numDocs, long startPointer) throws IOException {
    assert startPointer >= previousFP;
    // doc num
    docsOut.writeVInt(numDocs);
    // filepoint
    filePointersOut.writeVLong(startPointer - previousFP);
    previousFP = startPointer;
    totalDocs += numDocs;
    totalChunks++;
  }
```

在所有数据写入完成后，会调用`FieldsIndexWriter`类的 finish 方法，来进行生成真正的 fdx 文件。该方法比较复杂，让我们一步步捋一下。

```java
  /**
   * 在这里生成的 fdx 文件，从两个 tmp 文件里面找到每个 chunk 的 doc 数量，fdt 文件中存储的字节数，
   * 这两个内容，写到 meta 文件和 fdx 文件中，配合起来存储的
   * <p>
   * 这个类本身就是为了 fdx 文件搞的，就是为了写 fdt 的索引，写得少很正常
   */
  void finish(int numDocs, long maxPointer, IndexOutput metaOut) throws IOException {
    if (numDocs != totalDocs) {
      throw new IllegalStateException("Expected " + numDocs + " docs, but got " + totalDocs);
    }
    CodecUtil.writeFooter(docsOut);
    CodecUtil.writeFooter(filePointersOut);
    IOUtils.close(docsOut, filePointersOut);

    // dataOut　是 fdx 文件，是用来对 fdt 文件做索引的文件，所以 fdt 文件写入内容，我这里记录每个 chunk 的 doc 数量，占用字节数即可
    // 所以这里只能调用一次么，无论是多少个多大的 field，都只能调用一次这里么
    // 写 fdx 文件
    try (IndexOutput dataOut = dir.createOutput(IndexFileNames.segmentFileName(name, suffix, extension), ioContext)) {
      // 这个 header，48 个字节。
      CodecUtil.writeIndexHeader(dataOut, codecName + "Idx", VERSION_CURRENT, id, suffix);

      metaOut.writeInt(numDocs);
      metaOut.writeInt(blockShift);
      metaOut.writeInt(totalChunks + 1);
      // 这个 filePointer, 此时只写了一个 header 的长度，48
      long filePointer = dataOut.getFilePointer();
      metaOut.writeLong(filePointer);

      try (ChecksumIndexInput docsIn = dir.openChecksumInput(docsOut.getName(), IOContext.READONCE)) {
        CodecUtil.checkHeader(docsIn, codecName + "Docs", VERSION_CURRENT, VERSION_CURRENT);
        Throwable priorE = null;
        try {
          // 这里做的配合是，　meta 里面存了 min/斜率等，真实的数组偏移量在 dataOut 里面存储
          final DirectMonotonicWriter docs = DirectMonotonicWriter.getInstance(metaOut, dataOut, totalChunks + 1, blockShift);
          long doc = 0;
          docs.add(doc);
          // 注意，这里是每一 chunk, 而不是 per document
          for (int i = 0; i < totalChunks; ++i) {
            // 每个 chunk 的 doc 数量
            doc += docsIn.readVInt();
            docs.add(doc);
          }
          docs.finish();
          if (doc != totalDocs) {
            throw new CorruptIndexException("Docs don't add up", docsIn);
          }
        } catch (Throwable e) {
          priorE = e;
        } finally {
          CodecUtil.checkFooter(docsIn, priorE);
        }
      }
      dir.deleteFile(docsOut.getName());
      docsOut = null;

      long filePointer1 = dataOut.getFilePointer();
      metaOut.writeLong(filePointer1);
      try (ChecksumIndexInput filePointersIn = dir.openChecksumInput(filePointersOut.getName(), IOContext.READONCE)) {
        CodecUtil.checkHeader(filePointersIn, codecName + "FilePointers", VERSION_CURRENT, VERSION_CURRENT);
        Throwable priorE = null;
        try {
          // 其实由于我测试的时候只有一两个 doc，肯定在一个 chunk, 所以 dataOut 里面都没写入啥东西
          final DirectMonotonicWriter filePointers = DirectMonotonicWriter.getInstance(metaOut, dataOut, totalChunks + 1, blockShift);
          long fp = 0;
          // 这里存储的是每一个 chunk 的实际数据的字节长度
          for (int i = 0; i < totalChunks; ++i) {
            fp += filePointersIn.readVLong();
            filePointers.add(fp);
          }
          if (maxPointer < fp) {
            throw new CorruptIndexException("File pointers don't add up", filePointersIn);
          }
          filePointers.add(maxPointer);
          filePointers.finish();
        } catch (Throwable e) {
          priorE = e;
        } finally {
          CodecUtil.checkFooter(filePointersIn, priorE);
        }
      }
      dir.deleteFile(filePointersOut.getName());
      filePointersOut = null;

      // meta 里面再搞个索引
      long filePointer2 = dataOut.getFilePointer();
      metaOut.writeLong(filePointer2);
      metaOut.writeLong(maxPointer);

      CodecUtil.writeFooter(dataOut);
    }
  }

```

需要注意，此时所有的 field 数据已经写入。进行文件的转换操作而已。

1. 向两个临时文件写入 Footer, 之后将其关闭。
2. 打开真正的 fdx 文件，写入 Header.
3. 向之前介绍过的 fdm 文件中，写入部分元数据。不是这篇文章重点，就不详细解释了。
4. 打开刚才的临时文件`DocsOut`, 把数据读出来。使用`DirectMonotonicWriter`来将数据写入 fdx 文件。对`DirectMonotonicWriter`类不熟悉的话，可以阅读 [DirectMonotonicWriter 源码解析](http://huyan.couplecoders.tech/java/2020/11/21/lucene%E7%B3%BB%E5%88%97(%E5%9B%9B)DirectMonotonicWriter%E6%BA%90%E7%A0%81%E5%88%86%E6%9E%90/). 之后将 Docs 的临时文件删除。
5. 打开刚才的临时文件`filePointOut`, 把数据读出来，调用`DirectMonotonicWriter`进行写入 fdx 文件。之后将临时文件删除。
6. 向 fdx 文件写入 Footer. 关闭文件。

## 如何索引？

从名字上可以看出来，fdx 文件是用来作为 fdt 文件的索引的。作用就是：能够方便快速查询到指定的 doc 的 field 信息。

那么它是如何作为索引的呢，三个 field 相关文件的对应关系是怎样的。

<font color="red">以下内容为猜想内容，如果你看到这条红字，不要相信。未来的某一天，我看到代码且确认了下面的内容，我会回来删掉这行红字。</font>

![2021-01-28-20-20-25](http://img.couplecoders.tech/2021-01-28-20-20-25.png)

当我们拿到一个 DocId, 该如何通过这三个文件拿到该 doc 的具体 field 信息呢？

首先，fdx 及 fdm 文件都比较小，可以全部加载到内存中。

1. 根据 fdm 中的 ChunkDocsNumIndex, 可以找到在 fdx 文件中，存储 Chunk 中 doc 数量的起始文件地址。
2. 读出每个 Chunk 的 doc 数量，用 docId, 即可以算出 该 DocId 位于第几个 Chunk 的第几个 Doc.
3. 根据 fdx 文件中 ChunkDocsNum 和 ChunkStartPoint 文件时平行数据的关系，即可以求出，DocId 所在的 chunk, 其 field 信息在 fdt 文件中的起始文件位置。
4. 将 fdt 文件中，该 chunk 的数据读入，即可获取到给定 DocId 的具体内容。

不用完整的遍历 fdt 文件，而是通过 fdx 及 fdm 做了一些索引操作。比较高效。

## 总结

fdx 文件中，主要是存储以 chunk 为单位的 doc 数量，对应 chunk 在 fdt 文件中的起始位置。由这些数据可以对 fdt 文件进行随机方法而不用顺序访问，加快了读取速度。

为了对 fdx 文件中的数据进行压缩，防止读取到内存中过大，需要 fdm 进行一些配合存储。通过`DirectMonotonicWriter`进行压缩写入。

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
