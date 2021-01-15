



 # 这个文件存储了什么？



 # 能干什么？

# 具体点的


构造函数初始化的时候，其实里面包含了两个文件:

1. codec + -doc_ids. 
2. codec + file_pointers.

这两个都是tmp文件目录，后续直接删了

构造函数，对这两个output进行了初始化，一人写了一个header进去。


---


每次flush的时候，在finish里面，把当前的numDocs写进去,　然后写一下FilePointer的差值，能记录field的总长度，　这个FP，是fdt文件的指针哦。


最终finish时，调用org.apache.lucene.codecs.compressing.FieldsIndexWriter#finish。

1. 给两个tmp文件写个footer，然后就关闭了。
2. dataOut，用fdx的扩展名，新建一个真的输出文件
3. 给它写个header
4. 写一下每个chunk的doc的数量.
5. 写一下每个chunk的总大小.
6. 写个footer.
7. 注意在这个过程中，meta文件帮忙记录了几次FilePointer.　应该是有协作


# 他是怎么作为fdt文件的索引的？