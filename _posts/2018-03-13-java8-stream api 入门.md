<h2>什么是Stream，为什么需要Stream</h2>
Stream 作为 Java 8 的一大亮点，它与 java.io 包里的 InputStream 和 OutputStream 是完全不同的概念。它也不同于 StAX 对 XML 解析的 Stream，也不是 Amazon Kinesis 对大数据实时处理的 Stream。    

Java 8 中的 Stream 是对集合（Collection）对象功能的增强，它专注于对集合对象进行各种非常便利、高效的聚合操作（aggregate operation），或者大批量数据操作 (bulk data operation)。Stream API 借助于同样新出现的 Lambda 表达式，极大的提高编程效率和程序可读性。    

同时它提供串行和并行两种模式进行汇聚操作，并发模式能够充分利用多核处理器的优势，使用 fork/join 并行方式来拆分任务和加速处理过程。通常编写并行代码很难而且容易出错, 但使用 Stream API 无需编写一行多线程的代码，就可以很方便地写出高性能的并发程序。所以说，Java 8 中首次出现的java.util.stream 是一个函数式语言+多核时代综合影响的产物。 
<p align="right">----这段介绍引用自IBM的《Java 8 中的 Streams API 详解》    
文章写的非常好，给我很大启发，链接会在文末给出</p>   

<h3>流的使用过程</h3>
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

















参考文章：  
<a href ="https://www.ibm.com/developerworks/cn/java/j-lo-java8streamapi/">Java 8 中的 Streams API 详解</a>  

