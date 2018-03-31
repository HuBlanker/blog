--- 
layout: post
categories: java8
---

<h2>什么是Stream，为什么需要Stream</h2>
Stream 作为 Java 8 的一大亮点，它与 java.io 包里的 InputStream 和 OutputStream 是完全不同的概念。它也不同于 StAX 对 XML 解析的 Stream，也不是 Amazon Kinesis 对大数据实时处理的 Stream。    

Java 8 中的 Stream 是对集合（Collection）对象功能的增强，它专注于对集合对象进行各种非常便利、高效的聚合操作（aggregate operation），或者大批量数据操作 (bulk data operation)。Stream API 借助于同样新出现的 Lambda 表达式，极大的提高编程效率和程序可读性。    

同时它提供串行和并行两种模式进行汇聚操作，并发模式能够充分利用多核处理器的优势，使用 fork/join 并行方式来拆分任务和加速处理过程。通常编写并行代码很难而且容易出错, 但使用 Stream API 无需编写一行多线程的代码，就可以很方便地写出高性能的并发程序。所以说，Java 8 中首次出现的java.util.stream 是一个函数式语言+多核时代综合影响的产物。 
<p align="right">----这段介绍引用自IBM的《Java 8 中的 Streams API 详解》    
文章写的非常好，给我很大启发，链接会在文末给出</p>   

<h2>流的使用过程</h2>
使用流的过程分为三个步骤：  
1.创建一个流  
2.对其进行操作(可以是多个操作)  
3.关闭一个流

<h4>1.创建流</h4>
java8提供了多种构造流的方法  

* Collection  
* 数组  
* BufferedReader  
* 静态工厂  
* 自己构建  
* 其他  

创建流的示例代码如下：  

```java
    List<String> strList = new ArrayList<>();
    strList.add("HuHanShi");
    strList.add("HuBlanker");
    String[] strings = {"HuHanShi", "HuBlanker"};

    //Collection
    Stream<String> stream = strList.stream();
    stream = strList.parallelStream();

    //数组
    stream = Arrays.stream(strings);
    stream = Stream.of(strings);

    //BufferedReader
    stream = new BufferedReader(new InputStreamReader(System.in)).lines();

    //静态工厂
    IntStream streamInt = IntStream.range(0, 10);

    //自己生成流如果有需要放到最后面说

    //其他：随机生成一个int的流
    streamInt = new Random().ints();
    //其他：按照给定的正则表达式切割字符串后得到一个流
    stream = Pattern.compile(",").splitAsStream("wo,w,wa,a");
    stream.forEach(System.out::println);//输出结果为：wo w wa a
```

<h4>2.操作流</h4>
当把数据结构包装成流之后，就要开始对里面的元素进行各种操作了。  
流的操作分为两种：  
Intermediate：这类型的方法不会修改原来的流，而是会返回一个新的流以便后续操作。例如：map,filter,sorted.  
Terminal：这类型的方法会真正的将流进行遍历，在使用过后，流也将会被“消耗”，无法继续操作。  
接下来将对常用的(我看过的)流的操作方法一一举例说明：  

**map()**  

对当前的流进行一个操作并将得到的结果包装成一个新的流返回。  

```java
//str是个字符串列表，将其转换成大写。
	strList.stream().map(String::toUpperCase).collect(Collectors.toList());
```

<b id="flatmap">**flatMap()**  </b>

flatMap与map的区别是他会将stream内部的结构扁平化，对每一个值都将其转化为一个流，最后将所有刘扁平化为一个流返回。

```java
    Stream<List<Integer>> moreStream = Stream
        .of(Arrays.asList(1, 8), Arrays.asList(2, 4), Arrays.asList(2, 4, 5, 6));

    moreStream.flatMap(Collection::stream).forEach(System.out::println);
```  
输出结果为：1，8，2，4，2，4，5，6.  
而不是：[1,8],[2,4],[2,4,5,6].  

**filter()**  

filter 对原始 Stream 进行某项测试，通过测试的元素被留下来生成一个新 Stream。

```java
	//留下包含“Hu”的字符串
    strList.stream().filter(perStr -> perStr.contains("Hu")).forEach(System.out::print);
```  

**forEach()**  

forEach 方法接收一个 Lambda 表达式，然后在 Stream 的每一个元素上执行该表达式。
forEach是Terminal操作，当遍历完成时，流被消耗无法继续对其进行操作。

错误示例：  

```java
	//上面的几个示例中用到了forEach来进行打印操作，所以只举一下错误的例子。
	//！这句话是错误的，当forEach之后无法再进行map操作。
    strList.stream().forEach(System.out::print).map();

```   

**peek()**  

有人要问了，我想对每一个元素进行操作一下但是后续还要用怎么办呢，当然是有办法的，那就是peek()方法。

```java
	//先将strList中的字符串打印一遍之后将其转换为大写。
    strList.stream().peek(System.out::print).map(perStr->perStr.toUpperCase()).collect(Collectors.toList());
```  

**reduce()**  

这个方法的主要作用是把 Stream 元素组合起来。它提供一个起始值（种子），然后依照运算规则（BinaryOperator），和前面 Stream 的第一个、第二个、第 n 个元素组合。从这个意义上说，字符串拼接、数值的 sum、min、max、average 都是特殊的 reduce。  

```java
    Integer sum  = moreStream.flatMap(Collection::stream).reduce(0,(a,b)->a+b);
```  
这个例子将<a herf="#flatmap">flatMap</a>中的结果进行了累加操作。  
reduce()还可以用与字符串连接，求最大最小值等等。

**sorted()**    

对stream中的值进行排序。

```java
strList.sort(String::compareTo);
```  
相比于数组的排序，stream的排序可以先剔除掉一些不需要排序的值，可以减少无用操作。  


**接下来将一些原理(类型)差不多的放一起说一哈。**  

**limit()/skip()** 

取前n个元素/跳过前n个元素。

```java
//对strList先取前两个再扔掉第一个然后打印，结果为：HuBlanker。
strList.stream().limit(2).skip(1).forEach(System.out::print);
```  
**findFirst()**  

取stream得第一个值，值得一提的是返回值为Optional<>.  
Optional是一个容器，可以包含一个值，使用它可以尽量避免NullPointException。
具体见：<a herf="http://your123.com/2018/03/11/java8-Optional%E7%B1%BB%E5%88%9D%E4%BD%93%E9%AA%8C/">java8 Optional 类初体验</a>

```java
    String first = strList.stream().findFirst().get();
```  
  
**min()/max()/distinct()**    

取最小/最大/无重复值。  
min和max操作可以通过reduce方法实现，但是因为经常使用所以单独写了出来。

```java
    Arrays.asList(1,1,2,3,4,5,6).stream().min(Integer::min);
    Arrays.asList(1,1,2,3,4,5,6).stream().min(Integer::max);
    Arrays.asList(1,1,2,3,4,5,6).stream().distinct();
```
**Match类方法**

match类方法返回一个boolean值。
- allMatch：Stream 中全部元素符合传入的 predicate，返回 true
- anyMatch：Stream 中只要有一个元素符合传入的 predicate，返回 true
- noneMatch：Stream 中没有一个元素符合传入的 predicate，返回 true  

```java
    numList.stream().noneMatch(a -> a > 0);
    numList.stream().allMatch(a -> a > 0);
    numList.stream().anyMatch(a -> a > 0);
```  

<h4>3.关闭一个流(将流转化为其他数据结构)</h4>
当我们对一个流进行了足够的操作之后，希望将其转换为数据，List等数据结构方便存储。Stream在转换为其他数据结构的时候也是极其方便的。  

```java
    //List
    numList.stream().collect(Collectors.toList());
    //Set
    numList.stream().collect(Collectors.toSet());
    //Array
    numList.stream().toArray();
    //String
    numList.stream().toString();
```

<h2>结束语</h2>
stream的基本用法到这里就差不多啦，以后有时间的话将自己使用的一些具体栗子逐渐补充一下，毕竟有栗子我们看起来总是更加容易懂一些。  
最后！让我再来引用来自IBM的Stream API 详解中的结束语来结束这篇写了好几天的文章吧。    

**Stream 的特性可以归纳为：**

- 不是数据结构
- 它没有内部存储，它只是用操作管道从 source（数据结构、数组、generator function、IO channel）抓取数据。
- 它也绝不修改自己所封装的底层数据结构的数据。例如 Stream 的 filter 操作会产生一个不包含被过滤元素的新 Stream，而不是从 source 删除那些元素。
- 所有 Stream 的操作必须以 lambda 表达式为参数
- 不支持索引访问
- 你可以请求第一个元素，但无法请求第二个，第三个，或最后一个。不过请参阅下一项。
- 很容易生成数组或者 List
- 惰性化
- 很多 Stream 操作是向后延迟的，一直到它弄清楚了最后需要多少数据才会开始。
- Intermediate 操作永远是惰性化的。
- 并行能力
- 当一个 Stream 是并行化的，就不需要再写多线程代码，所有对它的操作会自动并行进行的。
- 可以是无限的
- 集合有固定大小，Stream 则不必。limit(n) 和 findFirst() 这类的 short-circuiting 操作可以对无限的 Stream 进行运算并很快完成。


<h4>参考文章：  </h4>
<a href ="https://www.ibm.com/developerworks/cn/java/j-lo-java8streamapi/">Java 8 中的 Streams API 详解</a>  
<br>
<br>
<br>
<br>

<h4>ChangeLog</h4>
2018-03-18      完成

<br>
**以上皆为个人所思所得，如有错误欢迎评论区指正。**

**欢迎转载，烦请署名并保留原文链接。**

**联系邮箱：huyanshi2580@gmail.com**

**更多学习笔记见个人博客------><a href="https://hublanker.github.io/blog/">呼延十</a>**
