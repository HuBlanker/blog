---
layout: post
tags:
  - Java
  - Java集合
---

其实我现在觉得关系不是很大...但是在今天及以前我也一直很迷惑,所以还是将自己的一些理解写出来备忘.

## Comparable

`Comparable`定义在`java.lang`包里,意味着可以被比较的能力,因此某个类想要可以被排序,被比较大小,需要实现这个接口.

```java
public int compareTo(T o);
```

接口里只定义了这一个方法,代表了:传入一个对象,将对象和元素自身进行比较,如果元素自身大,返回1,相等返回0,元素自身小于参数则返回-1.

例如:

```java
    private static class Student implements Comparable {
        int id;
        String name;
        int age;

        @Override
        public int compareTo(Object o) {
            return this.id - ((Student) o).id;
        }
    }

```

代码中定义了`Student`类,以及实现了`Comparable`,即只比较他们的id的大小即可.

## Comparator

`Comparator`定义与`java.util`包中,代表着一个角色,这个角色的功能是对传入的两个元素进行大小的比较,并且返回结果.

```java
int compare(T o1, T o2);
```

这是最主要的一个方法,我们需要传入两个同一类型的元素.

使用示例:

```java
    private static class StudentCom1 implements Comparator<Student>{

        @Override
        public int compare(Student o1, Student o2) {
            return o1.id - o2.id;
        }
    }

```

代码中定义了一个Student的比较器,实现了`Comparator`.


## 他们的区别及联系

那么问题来了,都有`Comparable`了,还要`Comparator`干什么?

设想一个场景,我们定义了一个学生类,如上面代码所示,那么学生可以按着id的大小进行排序.

然后现在有两个使用的地方,第一个是考试,需要学生按照id排序.第二个是学生统计,需要学生按照年龄进行排序.

怎么实现两种完全不同的排序方式呢?或者更极端一点,一会需要按照id增序,一会需要按照id降序呢?改源代码肯定是不科学的.

这个时候就可以采用以下方案:

1. 学生实现自然排序,即最通用的那种排序方式,比如按照id增序.
2. 实现几个不同的比较器,比如`运动会比较器`,`吃饭比较器`等等.
3. 在需要默认排序的情况下,直接调用学生的`comparTo`即可.
4. 在特定情景下,调用集合类的排序方法,传入一个想要的比较器即可.


## 总结

他们的区别是角色不同,想要实现的目的也不同.一个是内部自然排序,只能有一种定义.一个是外部的比较器,可以定义多个不同的比较器,按需取用.

唯一的联系可能就是他们最终都是对两个元素定义一个孰大孰小?





<br>
<br>
<br>
<br>
<h4>ChangeLog</h4>
2019-05-02 完成
<br>
<br>


**以上皆为个人所思所得，如有错误欢迎评论区指正。**

**欢迎转载，烦请署名并保留原文链接。**

**联系邮箱：huyanshi2580@gmail.com**

**更多学习笔记见个人博客------><a href="{{ site.baseurl }}/">呼延十</a>**
