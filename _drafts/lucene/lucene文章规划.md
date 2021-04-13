



1. 变长存储
2. Z存储
3. DirectMonotonicWriter及内部的DirectWriter.
4. field相关的三个文件格式
5. fnm文件


.doc 文件存了啥
pos
pay

Utils.kd tree
kd tree , kdb tree . bkd tree. 
introselector
radixselector



kdi/kdm/kdd, 这三个文件存储了PointValue. PointValue使用bkd, 所以这三个其实配合起来,就是BKD.

---


每种类型的值， 如何被索引，如何被搜索



nvd
nvm

lucene脑图


---

dii 
dim 



write_lock

dvd
dvm

tim
之类的几个.



之类的那几个

tim
docValue模块
等等，　倒排相关文件很多呢，你急个锤子.


看一下倒排文件格式，及生成过程等等等。 要看倒排啦

docValue模块: 在processField方法里，　分为三部分，倒排，stored正排，docValue正排。已经学习完了第二个。第三个后面可以学，快速抓住核心啊，看倒排。lucene最重要的就是倒排你看两个正排不理倒排的吗？？？
分词模块
