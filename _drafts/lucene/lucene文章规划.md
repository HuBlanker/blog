



1. 变长存储
2. Z存储
3. DirectMonotonicWriter及内部的DirectWriter.
4. field相关的三个文件格式
5. fnm文件

ArrayUtil 类的源码分析，整理，　但是不一定要写篇博客。

.doc 文件存了啥
pos
pay

--- 

写给lucene的bug邮件

`````text
There is a param use error in org.apache.lucene.util.RadixSelector#select(int, int, int, int, int).

What is we expected in this method is:

if the range becomes narrow or when the maximum level of recursion has been exceeded, then we get a fall-back selector(it's a IntroSelector). 

So, we should use the recursion level(param f)  compare to LEVEL_THRESHOLD. NOT the byte index of value(param d).

effect: 

This bug will not affect the correctness of the program. but affect performance in some bad case. In average, RadixSelector and IntroSelector are all in linear time. This bug will let we choose a fall-back selector too early, then the constant of O(n) will be bigger.



other evidence:

In comments, said we use recursion level (f) not byte index of value(d).
 if d is right, then the param f could be deleted because of it was not used by any method.
verification:

It also can select right value if i change d -> f.
I did some benchmark works. but the result was unstable on random data.


Thanks for your read. I'm new of lucene. So please reply me if I am wrong. Or fix it in future.



I will do benchmark. But I can't promised the result is better. If you need the result. Ask for me.


```

Utils.kd tree
kd tree , kdb tree . bkd tree. 
introselector
radixselector

nvd
nvm



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
