---
layout: post
category: [Java8,Java]
tags:
  - Java
  - Java8
  - 实际问题解决
---
PS:
1. 本文的代码保证正确性,原则是:下一次使用时直接copy可用.
2. 工作中遇到新的需求会更新此文.

对日期及时间的处理,我们都不陌生,但是总会有你不熟悉的新需求产生,毕竟产品经理的奇思妙想是很多的.

本文记录日常工作中使用到的获取特殊时间点的一些方式,不一定出厂最优解,但我会努力改进至最优解.


#### 时间戳转换为LocalDateTime

```java
long showTime = System.currentTimeMillis();
LocalDateTime localDateTime = LocalDateTime.ofInstant(Instant.ofEpochMilli(showTime),ZoneId.of("Asia/Shanghai"));
```

#### LocalDateTime格式化输出

```java
String s = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"));
System.out.println(s);
```

#### 获取当天的时间戳范围(0点-24点)

```java
long start = Timestamp.valueOf(LocalDateTime.of(LocalDate.now(), LocalTime.MIN)).getTime();
long end = Timestamp.valueOf(LocalDateTime.of(LocalDate.now(), LocalTime.MAX)).getTime();
```

#### 获取当前时间一天前的时间戳

```java
long time = Timestamp.valueOf(LocalDateTime.now().minusDays(1)).getTime();
```

#### 日期的字符串转换为时间戳

```java
private Long dateTimeStrToTimeStamp(String dateTime) {
    //解析日期
    LocalDateTime localDateTime = LocalDateTime
        .parse(dateTime.substring(0,19), DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"));
    //获取时间戳
    return Timestamp.valueOf(localDateTime).getTime();
  }
```

#### 获取下周一和下周日的LocalDate

```java
LocalDate start = LocalDate.now().plusDays(8 - LocalDate.now().getDayOfWeek().getValue());
LocalDate end = LocalDate.now().plusDays(14  - LocalDate.now().getDayOfWeek().getValue());
```




<br>
<br>
<br>
<br>
<h4>ChangeLog</h4>
2018-11-28 添加了前五个
<br>
<br>

**以上皆为个人所思所得，如有错误欢迎评论区指正。**

**欢迎转载，烦请署名并保留原文链接。**

**联系邮箱：huyanshi2580@gmail.com**

**更多学习笔记见个人博客------><a href="{{ site.baseurl }}/">呼延十</a>**
