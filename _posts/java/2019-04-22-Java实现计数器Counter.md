---
layout: post
category: [Java,轮子]
tags:
  - Java
  - 轮子
---

试着实现一个更好的计数器.可以对输入的`List`进行计数.

最终实现版本使用泛型,使得可以对任意对象进行技术,但是在编写过程中,先以String为例.

那么`计数`这个行为的输入值是`List<String>`,输出值为`Map<String,Integer>`. 这里不是强行要求`Integer`的,只要能够标识数量即可.

## 简单版本

直接随手写一个:

```java
    public static Map<String, Integer> count(List<String> stringList){
        HashMap<String,Integer> c = new HashMap<>();
        stringList.forEach(per->{
            c.put(per, c.getOrDefault(per, 0) + 1);//步骤1
        });
        return c;
    }
```

这里面有几个点:

1. Integer是一个不可变的类,因此,在步骤1中发生了,取到当前数字,对其加一生成新的Integer对象,将这个对象放进map里面.频繁的创建中间对象,浪费.
2. 对于需要计数的每一个值,进行了两次map的操作,第一次获取其当前次数,第二次put加一之后的次数.


## 可变Integer

先解决第一个问题,封装一个可变的Integer类或者使用AtomicInteger.
在没有多线程的要求下,自己封装一个:

```java
    public static final class MutableInteger {
        private int val;

        public MutableInteger(int val) {
            this.val = val;
        }

        public int get() {
            return this.val;
        }

        public void set(int val) {
            this.val = val;
        }

        public String toString() {
            return Integer.toString(val);
        }
    }
```

## 

<br>
完。

<br>
<br>
<br>
<br>
<h4>ChangeLog</h4>
2019-04-22 完成
<br>
<br>

**以上皆为个人所思所得，如有错误欢迎评论区指正。**

**欢迎转载，烦请署名并保留原文链接。**

**联系邮箱：huyanshi2580@gmail.com**

**更多学习笔记见个人博客------><a href="{{ site.baseurl }}/">呼延十</a>**
