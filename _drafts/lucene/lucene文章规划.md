







# util

1. 变长存储
2. Z存储
3. DirectMonotonicWriter及内部的DirectWriter.
4. field相关的三个文件格式
5. fnm文件

---

完事的

ArrayUtil 类的源码分析，整理，　但是不一定要写篇博客。


doc文件
看一下倒排文件格式，及生成过程等等等。

docValue模块: 在processField方法里，　分为三部分，倒排，stored正排，docValue正排。已经学习完了第二个。第三个后面可以学，快速抓住核心啊，看倒排。lucene最重要的就是倒排你看两个正排不理倒排的吗？？？
分词模块