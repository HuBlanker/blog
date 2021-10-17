---
layout: post
category: [java8,java]
tags:
  - Java
  - Java8
---
前些天在写代码时，突然发现某一位大佬的代码中充斥着stream来操作List，自己的for循环相比之下黯然失色，遂决定要尽快学习一下。接下来突然的一周加班阻塞了我的行程，导致今天才有时间开始。

<h3>lambda表达式</h3>  
lambda表达式允许将函数作为参数传递进方法中。lambda有什么作用呢？我目前的理解是：  
**make your code elegant！！！**  

在java 8 以前，java是不允许将函数复制给变量的，比如：

```java
		lambda = public void print(String s){
		System.out.println(s);
		}
```
这种操作是不允许的。  

那么在java 8 中，这个lambda是什么类型呢？是一个“函数型接口”，函数型接口与普通接口最大的区别就是函数型接口只有一个函数需要被实现。为了防止后续人员对函数型接口进行添加，java8新增了@FunctionalInterface注解，可以防止函数型接口被添加函数（注意：default和static方法并不受约束，仍旧可以添加使用）。  
像这样：  

```java
	  @FunctionalInterface
	  public interface MyLambdaInterface {
	    void doSomething(String s);
	  }
```
ok，做完这些我们就可以开始使用lambda了。下面的代码可以在一个方法中打印字符车。  

```java
	MyLambdaInterface lambdaInterface = (e) -> System.out.println(e);
	lambdaInterface.doSomething("huyashi is good！");
```
这样的情况下已经比java7及以前简洁了太多太多。不信你可以自己用java7实现一个类似的效果。  

但是lambda就仅止于此吗？NO！如果你有5个方法，每个方法都是接受String而返回void，每个方法仅仅使用一次。java7却要求定义5个不同的接口实现类，而lambda只需要5行代码。  

上述情况只是lambda的最简单使用姿势，你当然可以定义负责的接口，如多个参数，具有返回值，只需要在赋值lambda时用花括号将函数的实现括起来就好。

一个简单的小栗子:  

```java
	@FunctionalInterface
	  public interface HardInterface {
	    String  add(String s, int i);
	  }
```
使用：

```java
	 HardInterface hardInterface = (String s, int i) -> {
	      s = s.substring(0, 1);
	      i = i + 10;
	      return s+i;
	    };
	    hardInterface.add("huyanshi",110);
```

总结一下：  
lambda表达式替代了原先的匿名类的作用，将  
1.编写接口实现类，实现该接口中的方法。  
2.new 一个实现类的实例。
简化为：**new 一个接口的实例并将一个方法赋值给它**  

Lambda结合FunctionalInterface Lib, forEach, stream()，method reference等新特性可以使代码变的更加简洁！
