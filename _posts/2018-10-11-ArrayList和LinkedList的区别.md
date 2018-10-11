---
layout: post
category: 源码阅读
---

PS：推荐大家先去了解一下链表这个数据结构。

ArrayList和LinkedList可以说是日常业务开发中最常使用的容器类了，同时，他们的区别也是面试高发区，虽然很简单，但是我们总是不能说的完整，今天就通过对他们源码的阅读来进一步加深理解。

首先，看他们类的定义可以发现：
![](http://img.couplecoders.tech/markdown-img-paste-20181011174000106.png)

![](http://img.couplecoders.tech/markdown-img-paste-20181011174024404.png)

他们都是实现了List<E>接口，这个接口干了什么呢？

这个接口定义了对列表的一些基本操作，如```add,contains,indexof,remove```等基本方法，由他的实现类各自进行实现。

因此，当你只是需要一个列表进行常规的添加移除查找操作，那么ArrayList和LinkedList在使用体验(不考虑性能)上基本没有区别，你甚至不用关心他的内部实现，而是调用一些List<E>接口的方法就ok。

那么他们的具体实现有哪些区别呢？


下面对他们常用的方法进行源码的阅读。
### ArrayList

#### 成员变量

![](http://img.couplecoders.tech/markdown-img-paste-20181011174948431.png)

ArrayList有两个成员变量，图中可以看到，一个Object的数组，一个int类型的size，用来定义数组的大小。

#### get()方法
![](http://img.couplecoders.tech/markdown-img-paste-20181011175724911.png)

首先检查传入的index，然后返回数组在该index的值。

#### add()方法

![](http://img.couplecoders.tech/markdown-img-paste-20181011180017237.png)

首先确保容量够用，然后将新加入的对象放在数组尾部。

#### remove()方法

![](http://img.couplecoders.tech/markdown-img-paste-20181011180632931.png)

首先确保容量够用，然后计算出需要移动的数量，例如size=10，要删除index=5的元素，则需要移动后面的四个元素，然后调用```System.arraycopy()```方法，将数组的后面4个依次向前移动一位，然后将数组最后一位置为null。


### LinkedList

#### 成员变量

![](http://img.couplecoders.tech/markdown-img-paste-20181011181337422.png)
LinkedList本身的属性比较少，主要有三个，一个是size，表明当前有多少个节点；一个是first代表第一个节点；一个是last代表最后一个节点。


#### get()方法

![](http://img.couplecoders.tech/markdown-img-paste-20181011181529768.png)

首先检查传入的index是否合法，然后调用了```node(index)```方法，那么来看看```node()```方法。

![](http://img.couplecoders.tech/markdown-img-paste-20181011181656533.png)

判断index值是否大于总数的一半。

如果小于，则从first节点向后遍历，直到找到index节点，然后返回该节点的值。

如果大于，则从last节点向前遍历，直到找到index节点，然后返回该节点的值。

#### add()方法

![](http://img.couplecoders.tech/markdown-img-paste-20181011182034991.png)
![](http://img.couplecoders.tech/markdown-img-paste-20181011182020860.png)

add方法，直接调用了linklast方法，将传入的值作为最后一个节点链接在链表上。

#### remove()方法


![](http://img.couplecoders.tech/markdown-img-paste-20181011182342319.png)

![](http://img.couplecoders.tech/markdown-img-paste-20181011182356842.png)

remove方法的思路是什么呢？从头开始遍历链表，当找到要删除的节点，将他删除。删除的方法呢？将该节点的前后节点链接起来，类似于下图：

![链表删除.jpg](http://img.couplecoders.tech/链表删除.jpg)



### 对比

由上面的常用方法可以发现

1.ArrayList使用数组存储元素，因此在查询时速度较快，直接返回该位置的元素即可，时间复杂度为O(1);而LinkedList使用双向链表存储元素，在查询时需要从头或者尾遍历至查询元素，时间复杂度为O(n/2);

2.还是因为存储方式的问题，ArrayList在插入或者删除时，需要移动插入位置之后的所有元素，因此速度较慢，时间复杂度为O(n)。而LinkedList只需要找到该位置，移动”指针”即可,时间复杂度为O(1)。

### 结论

其实在日常的开发中，ArrayList更受欢迎，而且可以完成很多的任务，但是仍有一些特殊的情景适合使用LinkedList。他们的使用场景如下：

**当你对列表更多的进行查询，即获取某个位置的元素时，应当优先使用ArrayList；当你对列表需要进行频繁的删除和增加，而很少使用查询时，优先使用LinkedList；**


### 注意事项！

1.上述结论适用于普遍的情景，有些极端情况不一定符合。比如频繁的在数组结尾附近插入数据，ArrayList也快于LinkedList。

2.LinkedList使用的空间大于ArrayList，因为本质上，ArrayList在每个位置存储了元素，而LinkedList存储了元素+前面节点+后面节点。

### 扩展

我们知道ArrayList和LinkedList都是有size的，那么当添加的元素过多，他们怎么扩容呢？

**ArrayList：**

ArrayList使用数组存储元素，因此扩容时为：

![](http://img.couplecoders.tech/markdown-img-paste-20181011200252465.png)

可以看到，每次扩容后的大小为之前的1.5倍。```        int newCapacity = oldCapacity + (oldCapacity >> 1);
```,而且之后有一个复制全部元素的操作，这个操作很费时间。

**LinkedList：**

由于LinkedList是一个双向链表，因此不需要扩容机制，直接在前后添加元素即可。

**因此：在使用ArrayList时，如果你能预估大小，最好直接定义初始容量，这样能节省频繁的扩容带来的额外开支。**

初始化定义容量的构造方法为：
![](http://img.couplecoders.tech/markdown-img-paste-20181011200659199.png)。


### 后记

其实想写这个很久了，一直拖延着，今天终于回忆起了面试的时候被ArrayList和LinkedList支配的恐惧。(都喜欢问，一直问(校招))。因此趁热打铁，阅读了他们的源码并记录下来。相信常常回顾之下不会再受困于此，也能让日常工作的编码水平有些许提升。



完。






<br>
<br>
<br>
<br>
<h4>ChangeLog</h4>
2018-10-11 完成
<br>
<br>




**以上皆为个人所思所得，如有错误欢迎评论区指正。**

**欢迎转载，烦请署名并保留原文链接。**

**联系邮箱：huyanshi2580@gmail.com**

**更多学习笔记见个人博客------><a href="{{ site.baseurl }}/">呼延十</a>**
