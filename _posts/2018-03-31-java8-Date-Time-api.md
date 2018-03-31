java8里面新增了一套处理时间和日期的API，为什么要搞一套全新的API呢，因为原来的java.util.Date以及Calendar实在是太难用了。   
如果你有过在程序中处理时间的经验你就会知道，在java8以前，处理时间是多么让人痛苦。  

举个简单的小栗子：  

如果你需要查询当前周的订单，那么你需要先获取本地时间，然后根据本地时间获取一个Calendar，然后对Calendar进行一些时间上的加减操作，然后获取Calendar中的时间。   

而在java8中，你只需要这样：  

```java
    LocalDate date = LocalDate.now();
    //当前时间减去今天是周几
    LocalDate start = date.minusDays(date.getDayOfWeek().getValue());
    //当前时间加上（8-今天周几）
    LocalDate end = date.plusDays(8 -date.getDayOfWeek().getValue());
```
是不是很简单呢，接下来就将看一下java8的时间api具体怎么使用吧。  

java8中提供里真正的日期，时间分割开来的操作，LocalDate是日期相关操作，LocalTime是时间(即每天24个小时)的操作。   
想要获取时间及日期的话请使用LocalDateTime.
<h3>LocalDate</h3>  
首先，获取日期：  

```java
// 取当前日期：
LocalDate today = LocalDate.now(); // -> 2014-12-24
// 根据年月日取日期，12月就是12：
LocalDate crischristmas = LocalDate.of(2014, 12, 25); // -> 2014-12-25
// 根据字符串取：
LocalDate endOfFeb = LocalDate.parse("2014-02-28"); // 严格按照ISO yyyy-MM-dd验证，02写成2都不行，当然也有一个重载方法允许自己定义格式
LocalDate.parse("2014-02-29"); // 无效日期无法通过：DateTimeParseException: Invalid date
```
日期转换：  

```java  
// 取本月第1天：
LocalDate firstDayOfThisMonth = today.with(TemporalAdjusters.firstDayOfMonth()); // 2014-12-01
// 取本月第2天：
LocalDate secondDayOfThisMonth = today.withDayOfMonth(2); // 2014-12-02
// 取本月最后一天，再也不用计算是28，29，30还是31：
LocalDate lastDayOfThisMonth = today.with(TemporalAdjusters.lastDayOfMonth()); // 2014-12-31
// 取下一天：
LocalDate firstDayOf2015 = lastDayOfThisMonth.plusDays(1); // 变成了2015-01-01
// 取2015年1月第一个周一，这个计算用Calendar要死掉很多脑细胞：
LocalDate firstMondayOf2015 = LocalDate.parse("2015-01-01").with(TemporalAdjusters.firstInMonth(DayOfWeek.MONDAY)); // 2015-01-05
```
<h3>LocalTime</h3>    
获取时间：  

```java
//包含毫秒
LocalTime now = LocalTime.now(); // 11:09:09.240
//不包含毫秒  
LocalTime now = LocalTime.now().withNano(0)); // 11:09:09
//构造时间  
LocalTime zero = LocalTime.of(0, 0, 0); // 00:00:00
LocalTime mid = LocalTime.parse("12:00:00"); // 12:00:00
```

LocalDateTime的很多操作都和LocalDate差不多，具体的请查看一下源码就秒懂了。  

####提醒一下朋友们：千万不要觉得学习LocalDate及相关操作很麻烦，而继续使用java.util.date,因为当你认真的看一下，你会发现用不了半个小时你就可以基本掌握LocalDate的使用。而这半个小时带来的效率提升，代码质量的提升是很大的。  

我就是很早就知道了LocalDate但是懒得学习，总觉得java.util.Date可以凑活使用及时他很渣，但是当我终于静下心来学了一下之后，后悔莫及！！！！我为什么没有早点认真学习呢！我为什么要使用愚蠢的java.util.Date那么久呢！！！  

<br>
<br>
<br>
<br>
<h4>ChangeLog</h4>
2018-03-31      完成
<br>

**以上皆为个人所思所得，如有错误欢迎评论区指正。**

**欢迎转载，烦请署名并保留原文链接。**

**联系邮箱：huyanshi2580@gmail.com**

**更多学习笔记见个人博客------><a href="https://hublanker.github.io/blog/">呼延十</a>**




