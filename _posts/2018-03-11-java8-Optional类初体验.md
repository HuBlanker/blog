--- 
layout: post
category: [java8,java]
---
众所周知，在java语言开发中，NullPointerException是一直被大家所深恶痛绝的。然而在以前的java版本中，对空值的判断有繁琐而无趣。且十分影响代码的美观。例如下面这种情况：  

```java
	    User user = ......;
	    
	    if (user != null){
	      String name = user.getName();
	      if (name != null){
	        log.debug(name);
	      }
	      log.debug("the name is not exist!");
	    }else {
	      log.debug("the user is not exist!");
		}
```		
这种代码真的是，，，，，，脑壳疼。  
然而在java 8 中，这种情况得以改善了！那就是引入了Optional类。  

Optional实际上是个容器：它可以保存类型T的值，或者仅仅保存null。Optional提供很多有用的方法，这样我们就不用显式进行空值检测。

所幸OPtional 类的源码加上注释不过三百多行，我就将其中的方法一一道来。 
 
<h4>构造方法</h4>
Optional的构造方法有三种，Optional.of(),Optional.ofNullable(),Optional.empty()。  
**Optional.of(T)**  
这种构造方式要求栓如的值不能为空，否则直接回抛出NullPointException。  
**Optional.ofNullable(T)**  
这种构造方式可以接受空值，当参数为空值时调用Optional.empty()构造一个空的Optional对象。  
**Optional.empty()**  
字面意思。  
<h4>其他方法</h4>
**isPresent()**
返回boolean，表示Optional的值是否为空。
强烈不见使用此方法，因为它的作用和  

```java
return user != null
```
一毛一样，甚至我觉得他还没有后者通俗易懂。。  
**get()**  
取到Optional内部的value，即构造时传入的对象。
不建议。。。接下来的就是重点了！

**ifPresent(Consumer<? super T> consumer)**  
通俗点讲，这个方法的作用是：存在则对它做点什么。  
栗子：  

```java
 	Optional<User> userOpt = Optional.of(user);
    userOpt.ifPresent(System.out::println);
    
    // no elegant method!
    if (userOpt.isPresent()){
      System.out.println(userOpt.get());
    }
```  
<h4>几个orElse</h4>  
**orElse(T)**   
作用：存在则返回，为空则返回默认值。  

```java
userOpt.orElse(new User());
```  
userOpt不为空时则返回他的值，为空值返回一个默认值，即新的User对象。  

**orElseGet(Supplier<? extends T> other)**
作用:存在则返回，不存在则返回一个有函数产生的对象。  

```java
	userOpt.orElseGet(()-> make());

  	User make(){
    	return  new User("huyanshi",18,"china");

  	}
```  
这里的make()方法很没有必要，，，，可以直接由orElse()来设置默认值的，但是我偷懒了。。  

**orElseThrow(Supplier<? extends X> exceptionSupplier)**
作用：存在则返回，不存在则抛出异常，具体抛啥异常可以自己定义。  

```java
userOpt.orElseThrow(MyException::new);
```  
<h4>map</h4>
**map(map(Function<? super T,? extends U> mapper))**  
  如果有值，则对其执行调用mapping函数得到返回值。如果返回值不为null，则创建包含mapping返回值的Optional作为map方法返回值，否则返回空Optional。
map方法用来对Optional实例的值执行一系列操作。通过一组实现了Function接口的lambda表达式传入操作。  

```java
//map方法执行传入的lambda表达式参数对Optional实例的值进行修改。  
//为Lambda表达式的返回值创建新的Optional实例作为map方法的返回值。  
Optional<String> upperName = myValue.map((value) -> value.toUpperCase());  
System.out.println(upperName.orElse("No value found"));
```
**flatMap(Function<? super T,Optional<U mapper)**  
如果有值，为其执行mapping函数返回Optional类型返回值，否则返回空Optional。flatMap与map（Funtion）方法类似，区别在于flatMap中的mapper返回值必须是Optional。调用结束时，flatMap不会对结果用Optional封装。  
flatMap方法与map方法类似，区别在于mapping函数的返回值不同。map方法的mapping函数返回值可以是任何类型T，而flatMap方法的mapping函数必须是Optional。  

```java
//map方法中的lambda表达式返回值可以是任意类型，在map函数返回之前会包装为Optional。   
//但flatMap方法中的lambda表达式返回值必须是Optionl实例。   
upperName = myValue.flatMap((value) -> Optional.of(value.toUpperCase()));  
System.out.println(upperName.orElse("No value found")); 
```
*map和flatmap使用方法类似，区别仅在于mapper方法的返回值类型不同，flatmap方法不会发展返回值再使用Optional进行封装，因此传入的方法必须返回Optional类型。*  
**filter**  
如果有值并且满足断言条件返回包含该值的Optional，否则返回空Optional。  
filter个方法通过传入限定条件对Optional实例的值进行过滤。  
对于filter函数我们可以传入实现了Predicate接口的lambda表达式。

```java
userOpt.filter(user1 -> user1.getName().length() > 6);
```
如果user的名字长度大于6则返回自身，小于6则返回一个空值。  

完。
