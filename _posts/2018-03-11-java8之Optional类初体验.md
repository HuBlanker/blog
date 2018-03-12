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

