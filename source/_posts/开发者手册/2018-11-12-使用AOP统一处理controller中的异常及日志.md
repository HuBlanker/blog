---
layout: post
tags:
  - 开发者手册
  - Spring Boot
---

## 什么是AOP

以下摘自百度百科：

*在软件业，AOP为Aspect Oriented Programming的缩写，意为：面向切面编程，通过预编译方式和运行期动态代理实现程序功能的统一维护的一种技术。AOP是OOP的延续，是软件开发中的一个热点，也是Spring框架中的一个重要内容，是函数式编程的一种衍生范型。利用AOP可以对业务逻辑的各个部分进行隔离，从而使得业务逻辑各部分之间的耦合度降低，提高程序的可重用性，同时提高了开发的效率。*

AOP也是面试中的一大重难点，我目前只学会了应用，具体原理还需要继续学习，这里不多介绍了，建议朋友们先了解一下AOP。

## 为什么要使用AOP
作为一个后端开发，我们日常要开发各种各样的接口，而代码难免有运行错误，通常情况下我们需要对错误进行包装，不能直接返回异常信息给前端。

当发生错误时，我们应该返回如下图的信息。
![](http://img.couplecoders.tech/markdown-img-paste-2018111223541282.png)

而不是这样简单粗暴的异常信息。

![](http://img.couplecoders.tech/markdown-img-paste-20181112235554223.png)

当你的异常信息覆盖足够广，前端调用时返回的错误信息可以很直白的帮助我们debug，也更方便前端读取错误码选择如何告知用户。

这时候我们在controller中要打印日志，并且处理异常，代码很容易变成下面这种臃肿的样子。

```java
  @GetMapping(value = "kmp")
  public BaseResponse kmp(@RequestParam String big, @RequestParam String small) {
    logger.info("kmp request,big=%s,small=%s", big, small);
    BaseResponse baseResponse = new BaseResponse();
    try {
      baseResponse.result = analyticsService.stringIndex(big, small);
    } catch (Exception e) {
      logger.info("kmp error,error=%s", e);
      return new BaseResponse(BaseError.FAIL);
    }
    logger.info("kmp response,result=%s", baseResponse);
    return baseResponse;
  }
```

上面的代码中，我们打印了入参和出参，并且统一处理了所有的异常，如果需要更加精细的异常处理，如NullPointException和NumberFormatException返回不同的值，那么我们需要catch多个异常，代码会更加臃肿。

可是在上面的代码中，我们的业务逻辑是什么呢？

`baseResponse.result = analyticsService.stringIndex(big, small);`

只是调用了`analyticsService`的一个方法，就需要这么大费周章的，这是不科学的。这就可以使用AOP来处理了。

同时，异常处理也是AOP的一个景点使用场景。
## 环境配置

在pom.xml中添加依赖的包
```
<dependency>
     <groupId>org.aspectj</groupId>
     <artifactId>aspectjweaver</artifactId>
     <version>1.8.13</version>
</dependency>
```

## 如何使用AOP

首先，我们来改造一个这个controller。

```java
@GetMapping(value = "kmp")
public Object kmp(@RequestParam String big, @RequestParam String small) {
  return analyticsService.stringIndex(big, small);
}
```

可以看到，我们的controller单纯的调用了一下业务方法，然后将其结果返回。

那么问题来了？日志呢？异常呢？别急，在`切面`中。

```java
@Aspect
@Component
public class ExceptionAspect {

  private Logger logger = LoggerFactory.getLogger(this.getClass());

  /**
   * 在方法调用之前，打印入参
   */
  @Before(value = "execution(public * com.huyan.demo.controller.AnalyticsController.*(..))")
  public void before(JoinPoint joinPoint) {
    String className = joinPoint.getTarget().getClass().getName();
    String methodName = joinPoint.getSignature().getName();
    Object[] args = joinPoint.getArgs();
    StringBuilder params = new StringBuilder();
    for (Object arg : args) {
      params.append(arg).append(" ");
    }
    logger.info(className + "的" + methodName + "入参为：" + params.toString());
  }

  /**
   * 过程中监测，catch到异常之后返回包装后的错误信息，并打印日志
   */
  @Around(value = "execution(public * com.huyan.demo.controller.AnalyticsController.*(..))")
  public BaseResponse catchException(ProceedingJoinPoint joinPoint) {
    try {
      BaseResponse baseResponse = new BaseResponse(BaseError.SUCCESS);
      baseResponse.result = joinPoint.proceed();
      return baseResponse;
    } catch (Throwable e) {
      String className = joinPoint.getTarget().getClass().getName();
      String methodName = joinPoint.getSignature().getName();
      logger.warn("在" + className + "的" + methodName + "中，发生了异常：" + e);
      return new BaseResponse(BaseError.FAIL);
    }
  }

  /**
   * 返回之后，打印出参
   */
  @AfterReturning(value = "execution(public * com.huyan.demo.controller.AnalyticsController.*(..))", returning = "returnVal")
  public void afterReturin(JoinPoint joinPoint, Object returnVal) {
    String className = joinPoint.getTarget().getClass().getName();
    String methodName = joinPoint.getSignature().getName();
    logger.info(className + "的" + methodName + "结果为：" + returnVal.toString());
  }

}
```

在切面中，通过`execution`表达式来定义切点，在本例中，定义的是controller中的AnalyticsController类的所有任意返回值的public方法。

定义的切点中的所有方法，在调用前会进入切面打印入参，返回后会进入切面打印返回值，在执行方法的过程中，如果产生异常，则打印日常信息并返回包装后的错误值。

## AOP优势

可以看到，在使用切面后，原先每个方法中的日志及异常处理，统一的挪到了切面类中进行，这样极大的减少了代码量，使得在controller中的业务代码更加清晰。同时，也方便我们在一个类中统一的管理，当我们需要对一种新的异常进行额外的处理，不用去几十个controller中对每一个方法进行处理，只需要在切面中添加catch语句即可。

## AOP的其他应用场景

性能监控，访问统计以及权限验证也是AOP的经典场景，后续会继续学习分享。

## 参考链接

https://blog.csdn.net/qq_21361539/article/details/79695719



<br>
完。

<br>
<br>
<br>
<br>
<h4>ChangeLog</h4>
2018-11-11 完成
<br>
<br>

**以上皆为个人所思所得，如有错误欢迎评论区指正。**

**欢迎转载，烦请署名并保留原文链接。**

**联系邮箱：huyanshi2580@gmail.com**

**更多学习笔记见个人博客------><a href="{{ site.baseurl }}/">呼延十</a>**
