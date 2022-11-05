---
layout: post
category: [Effective Java,读书笔记,源码阅读]
tags:
  - 源码阅读
  - 读书笔记
  - Effective Java
---

本文分为两个部分:

1. 对Effective Java书中第二章第二条`遇到多个构造器参数时要考虑使用构建器`进行复盘.
2. lombok正好实现了这个功能,我们顺手学习一下lombok的一些用法.

## 什么是构建器以及为什么要使用构建器

假设某个类,现在有3个必选属性,有5个可选属性.(为了代码简洁,后面都只写一个必选属性,2个可选属性.懂就行).

那么现在想提供完善的`创建该类的机制`,该怎么办呢?

首先是方法1-使用重叠的构造方法.

#### 重叠的构造方法

这是大家都熟悉的方法,重载很多个构造方法,每个的参数都不一样,总有一款适合您!

```java
public class Student {

    // 必选
    String name;
    // 可选
    int age;
    String title;

    public Student(String name) {
        this.name = name;
    }

    public Student(String name, int age) {
        this.name = name;
        this.age = age;
    }

    public Student(String name, int age, String title) {
        this.name = name;
        this.age = age;
        this.title = title;
    }
}
```

三个构造方法是不是已经脑壳疼了,注意,在真正的代码中,30个属性的类也不少见噢,写死人了要.

而且这样还有一个缺点,可读性太差了,在写的时候还好一些,在调用的时候你会看到编译器提醒你有30个构造方法可以调用,并且只显示参数类型不显示参数名字(比如一个8个int参数的构造方法,鬼知道应该按照什么顺序传入啊),你根本不知道该怎么用....

那么还有第二种方法:

#### javabean,即使用setter.

对每个属性都提供set方法,这样客户端可以队医的调用set方法来传入他们想要的参数.

```java
public class Student {

    // 必选
    private String name;
    // 可选
    private int age;
    private String title;

    public void setName(String name) {
        this.name = name;
    }

    public void setAge(int age) {
        this.age = age;
    }

    public void setTitle(String title) {
        this.title = title;
    }
}
```

调用代码:

```java
        Student student = new Student();
        student.setName("huyan");
        student.setAge(1);
        student.setTitle("666");
```

这样子的好处是可读性好,但是不好的地方是不安全,你根本不知道客户端会以什么奇怪的方式使用你的类.

#### 可以使用Builder模式.

```java
public class Student {

    // 必选
    private String name;
    // 可选
    private int age;
    private String title;

    private static class Builder {
        // 必选
        private String name;
        // 可选
        private int age;
        private String title;

        public Builder(String name) {
            this.name = name;
        }

        public Builder age(int age) {
            this.age = age;
            return this;
        }

        public Builder title(String s) {
            this.title = s;
            return this;
        }

        public Student build() {
            return new Student(this);
        }

    }

    private Student(Builder builder) {
        name = builder.name;
        age = builder.age;
        title = builder.title;
    }
```

这里面有几个重要的点:

1. 将Student类的构造方法私有化,所以想要新建Student必须使用Builder.
2. Builder只有一个构造方法,传入必选的参数,这样可以保证每个Student都会有必选参数.
3. 对所有的可选参数提供同名方法,使得可选参数可以被设置,同时返回自身.
4. Builder提供build方法,调用Student私有的构造方法,返回对象.

客户端的调用方法如下:

```java
    public static void main(String[] args) {
        Student s = new Builder("huyan").age(11).title("888").build();
    }
```

使用Builder模式实现了上面其他两种方式的优点:安全且可读性搞.

1. 限制了参数,保证必选参数肯定有.
2. 可读性好,传入每个可选参数单独调用方法,可以明确的知道每个参数的意义.
3. 链式调用看起来好看.

哇,这么牛逼有没有缺点呢!

当然是有的:

1. 在创建的过程中多创建了一个对象,这对性能肯定是有影响的,所以在极限要求性能的场景可以注意一下.
2. 代码比重叠构造器的代码都多...写起来也挺累啊.


等等,老是写Builder类?lombok了解一下?只需要一个注解就可以实现上面这样子的效果噢~.

所以接下来学习一下,lombok是都有哪些使用方式.

## lombok

>Project Lombok is a java library that automatically plugs into your editor and build tools, spicing up your java.
Never write another getter or equals method again, with one annotation your class has a fully featured builder, Automate your logging variables, and much more.

lombok是一套小工具,可以帮助你减少样板式或者实现一些别的功能.

lombok的作用仅在源码起作用,也就是说,lombok会帮你在编译的过程中添加一些东西,使得你不用自己写,而一旦生成了class文件,lombok的作用就已经结束.

#### Builder:

首先看一下上面提到的Builder是怎么实现的.

将Student类的代码清空,仅保留属性,然后在类名上加上`@Builder`注解:

```java
@Builder
public class Student1 {

    // 必选
    private String name;
    // 可选
    private int age;
    private String title;
    
}
```

然后使用IDEA进行编译,然后查看class文件,Idea会自动帮我们反编译拿到源文件.查看源代码,如下:

```java
public class Student1 {
    private String name;
    private int age;
    private String title;

    @ConstructorProperties({"name", "age", "title"})
    Student1(String name, int age, String title) {
        this.name = name;
        this.age = age;
        this.title = title;
    }

    public static Student1.Student1Builder builder() {
        return new Student1.Student1Builder();
    }

    public static class Student1Builder {
        private String name;
        private int age;
        private String title;

        Student1Builder() {
        }

        public Student1.Student1Builder name(String name) {
            this.name = name;
            return this;
        }

        public Student1.Student1Builder age(int age) {
            this.age = age;
            return this;
        }

        public Student1.Student1Builder title(String title) {
            this.title = title;
            return this;
        }

        public Student1 build() {
            return new Student1(this.name, this.age, this.title);
        }

        public String toString() {
            return "Student1.Student1Builder(name=" + this.name + ", age=" + this.age + ", title=" + this.title + ")";
        }
    }
}
```

可以看到,Builder的代码和上面我们自己写的一模一样,整个类的区别就是,`Student1`类提供了`toBuilder()`方法,返回一个`Student1Builder`,可以完全屏蔽用户对`Builder`类的感知.

下面列举一些常用的lombok的注解,并简要解释其作用.

想看完整版可以移步[官网](https://projectlombok.org/features/all).

#### @Getter/@Setter

可以应用在类上,属性上. 自动生成get/set方法.

#### @toString

自动生成`toString`方法.

#### @EqualsAndHashCode

生成`equals`和`hashcode`方法.

#### @RequiredArgsConstructor

生成一个必须参数的构造器.

#### Data

快捷方法,相当于`@Getter`+ `@Setter`+ `toString` + `EqualsAndHashCode` + `RequiredArgsConstructor`.

#### @AllArgsConstructor 和 @NoArgsConstructor

自动生成全部参数和零个参数的构造方法.

#### @Log

包含一系列常用的log系统的注解,比如`@Slf4j`,`@Log4j2`等,自动生成一个全局final的logger供你使用.




## 参考链接

https://projectlombok.org/features/all






完.

<br>
<br>
<br>
<br>
<h4>ChangeLog</h4>
2019-04-21      完成
<br>
<br>


**以上皆为个人所思所得，如有错误欢迎评论区指正。**

**欢迎转载，烦请署名并保留原文链接。**

**联系邮箱：huyanshi2580@gmail.com**

**更多学习笔记见个人博客------><a href="{{ site.baseurl }}/">呼延十</a>**
