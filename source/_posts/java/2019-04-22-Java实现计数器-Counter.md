---
layout: post
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

## 对map的操作减少

对于每一个字符串,都需要get确认,然后put新值,这明显是不科学的.

`HashMap`的`put`方法,其实是有返回值的,会返回旧值.

这就意味着我们可以通过一次map操作来达到目的.

经过这样两次的优化,现在的方法为:

```java
    public static Map<String, MutableInteger> count2(List<String> strings) {
        HashMap<String, MutableInteger> c = new HashMap<>();
        strings.forEach(per -> {
            MutableInteger init = new MutableInteger(1);
            MutableInteger last = c.put(per, init);
            if (last != null) {
                init.set(last.get() + 1);
            }
        });
        return c;
    }
```

## 简单测试一下:

```java
    public static void main(String[] args) {
        List<String> list = new ArrayList<>();

        String[] ss = {"my", "aa", "cc", "aa", "cc", "b", "w", "sssssa", "10", "10"};

        for (int i = 0; i < 100000000; i++) {
            list.add(ss[i % 10]);
        }
        long s = System.currentTimeMillis();
        System.out.println(count1(list));
        System.out.println(System.currentTimeMillis() - s);

        long s1 = System.currentTimeMillis();
        System.out.println(count2(list));
        System.out.println(System.currentTimeMillis() - s1);

    }
```

测试结果如下:

```
{aa=20000000, cc=20000000, b=10000000, w=10000000, sssssa=10000000, my=10000000, 10=20000000}
4234
{aa=20000000, cc=20000000, b=10000000, w=10000000, sssssa=10000000, my=10000000, 10=20000000}
951
```


可以看到结果非常明显,效率提高了4倍.

<font color="red">NOTE:</font>
这个测试明显是有偏向的,因为我这个1亿条数据,只有几种,所以数据重复率非常高.但是日常使用中数据重复率不会有这么夸张.
但是构建1亿条重复率不高的测试数据,太麻烦了.

## 分析

其实起作用比较大的是可变的Integer类.

而map的操作我们知道,取和放到时O(1)的.所以这个的提升不是特别的大.`经测试,修改为两次操作,仅增加80ms.`

## 最终代码(使用泛型实现通用类)

实现了以下几个API:

* add(T): 向计数器添加一个值.
* addAll(List<T>): 一次性添加多个值.以`List`的形式.
* get(T): 返回该值目前的数量.
* getALl(): 返回该计数器目前所有的计数信息.形式为,`Map<T,Integer>`

```java
package daily.counter;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Created by pfliu on 2019/04/21.
 */
public class Counter<T extends Object> {

    private HashMap<T, MutableInteger> c = new HashMap<>();
    
    public void add(T t) {
        MutableInteger init = new MutableInteger(1);
        MutableInteger last = c.put(t, init);
        if (last != null) {
            init.set(last.get() + 1);
        }
    }

    public void addAll(List<T> list) {
        list.forEach(this::add);
    }

    public int get(T t) {
        return c.get(t).val;
    }

    public Map<T, Integer> getAll() {
        Map<T, Integer> ret = new HashMap<>();
        c.forEach((key, value) -> ret.put(key, value.val));
        return ret;
    }

    public static final class MutableInteger {

        private int val;

        MutableInteger(int val) {
            this.val = val;
        }

        public int get() {
            return this.val;
        }

        void set(int i) {
            this.val = i;
        }
    }
}
```

当然你完全不用自己实现,网上一大把已经实现的.

但是自己思考一下为什么要这样实现,还是有很多的好处的.

## 联系我
最后，欢迎关注我的个人公众号【 呼延十 】，会不定期更新很多后端工程师的学习笔记。
也欢迎直接公众号私信或者邮箱联系我，一定知无不言，言无不尽。
![](http://img.couplecoders.tech/%E6%89%AB%E7%A0%81_%E6%90%9C%E7%B4%A2%E8%81%94%E5%90%88%E4%BC%A0%E6%92%AD%E6%A0%B7%E5%BC%8F-%E6%A0%87%E5%87%86%E8%89%B2%E7%89%88.png)

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
