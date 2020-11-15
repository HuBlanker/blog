---
layout: post
category: [Java]
tags:
  - Java
---

## 前言

这两天遇到了一个Bug(是的, 我就是bug开发工程师),情景如下:

我们封装了对DB查询的缓存,对于一个查询请求来说, 首先从redis里读取,如果命中缓存,则直接返回结果. 如果未命中缓存,从db中查询数据,返回结果,同时异步将查询到的数据添加到redis中.

在这个过程中, 发生了`ConcurrentModifyException`. 经过查看代码, 确定了问题出在异步填充缓存这里.

当从db中查询到数据, 首先返回给调用方, 之后异步执行序列化及写入redis. 在序列化过程中, 有某个属性是列表,遍历的过程中, 调用方拿到了数据,对列表进行了更改,导致产生异常.

解决方案就是本文的主题, 在异步填充缓存时, 序列化的不应该是原对象, 而是该对象的一个copy. 而Java中的copy, 也是比较讲究的,因此简单学习一下.


## 直接引用

在编码过程中, 我们经常有**获取和目标对象属性值完全一致**的另外一个对象. 最直接的,也就是最常用的就是直接引用.

首先我们定义了一个类:
```java
    public static class Person{
        String name;
        int age;

        public Person(String name, int age) {
            this.name = name;
            this.age = age;
        }

        public String str() {
            return name + "\n" + age;
        }
    }
```

然后对他进行一次引用并打印:

```java 
    public static void main(String [] args){
        Person p1 = new Person("huyanshi", 18);
        System.out.println(p1);
        System.out.println(p1.str());
        Person p2 = p1;
        System.out.println(p2);
        System.out.println(p2.str());
    }
```

打印结果如下:

```text
daily.javacopy.Copy$Person@51cdd8a
huyanshi
18
daily.javacopy.Copy$Person@51cdd8a
huyanshi
18
```

可以看到, 通过 **=** 来进行直接赋值, 我们获得了一个完全一致的对象, 因此他们本质上都是同一个对象, 只是新创建了两个引用,指向了堆上的同一块内存区域.


由于内存地址完全一致, 当对一个引用进行更改, 另一个引用看到的对象必然也会发生变化,不太符合我们的题目要求.

## clone 浅拷贝

众所周知, ~~猫是液体~~, java的万类之爹, `Object`, 是提供了clone方法的, 让我们试试.

```java 
        Person p1 = new Person("huyanshi", 18);
        System.out.println(p1);
        System.out.println(p1.str());
        Person p2 = (Person) p1.clone();
        System.out.println(p2);
        System.out.println(p2.str());

```

打印结果如下:

```text
daily.javacopy.Person@51cdd8a
huyanshi
18
daily.javacopy.Person@d44fc21
huyanshi
18
```

可以看到, 虽然两个对象的属性值完全一样, 但是他们在堆中已经不是同一个对象了, 这个时候对任意一个对象进行改动, 另外一个就不会跟着变了, 那这不是满足需求了吗? 为啥要叫他浅拷贝呢?

因此他只能解决一层对象嵌套, 比如我们的Person类, 如果再引用一个对象, 他就不会进行复制了.

让我们给Person加入一个对象字段.

```java 
public class Edu {

    public String start;
    public String end;
    public String schoolName;

    public Edu(String start, String end, String schoolName) {
        this.start = start;
        this.end = end;
        this.schoolName = schoolName;
    }
}



public class Person implements Cloneable {
    String name;
    int age;
    Edu edu;

    public Person(String name, int age, Edu edu) {
        this.name = name;
        this.age = age;
        this.edu = edu;
    }

    public String str() {
        return name + "\n" + age + edu.toString();
    }

    @Override
    protected Object clone() throws CloneNotSupportedException {
        return super.clone();
    }
}

```

再次运行刚才的程序, 打印如下:

```text
daily.javacopy.Person@d44fc21
daily.javacopy.Edu@23faf8f2
huyanshi
18daily.javacopy.Edu@23faf8f2
==========分割线=============
daily.javacopy.Person@2d6eabae
daily.javacopy.Edu@23faf8f2
huyanshi
18daily.javacopy.Edu@23faf8f2
```

可以发现, 虽然经过clone之后的person对象变成了**真正**的两个对象,但是他们指向的Edu类, 仍然是同一个对象.

这就是浅拷贝的原因, 他只能**拷贝**你调用的对象, 对他的属性中的对象, 是不进行clone的.

## 深拷贝

由于上面的思路, java自带的clone方法, 不会帮你clone属性里面的对象, 那么我们自己实现以下就好了.

给Person类重写clone方法:

```java 
    @Override
    protected Object clone() throws CloneNotSupportedException {
        Person person = (Person) super.clone();
        person.edu = (Edu) this.edu.clone();
        return person;
    }

```

重新执行代码, 可以看到edu也被clone了.

```text
daily.javacopy.Person@d44fc21
daily.javacopy.Edu@23faf8f2
huyanshi
18daily.javacopy.Edu@23faf8f2
==========分割线=============
daily.javacopy.Person@2d6eabae
daily.javacopy.Edu@4e7dc304
huyanshi
18daily.javacopy.Edu@4e7dc304
```

那么我们找到了第一个进行深拷贝的方法, 那就是 **重写clone方法**, 这个方法有个劣势, 就是当你属性里对象很多, 你重写的clone就会非常麻烦, 同时,每次添加/减少字段, 都需要修改clone方法,十分麻烦.

除此之外, 还有一种深拷贝的思路, 那就是将当前的对象完全序列化, 之后再进行反序列化拿到新的对象, 这样也是完整的深拷贝. Apache Commons Lang (自己实现也行,用json什么序列化都行) 提供了序列化工具, 我们可以简单试用一下.


```java
        Edu edu = new Edu("2020-11-11", "2020-11-12", "加里敦大学");
        Person p1 = new Person("huyanshi", 18,edu);
        System.out.println(p1);
        System.out.println(p1.edu);
        Person p2 = SerializationUtils.clone(p1);
        System.out.println("==========分割线=============");
        System.out.println(p2);
        System.out.println(p2.edu);
```

执行代码会发现确实是深拷贝, 让我们看看他是怎么做的.

```java 
    public static <T extends Serializable> T clone(T object) {
        if (object == null) {
            return null;
        } else {
            // 序列化成byte[]
            byte[] objectData = serialize(object);
            ByteArrayInputStream bais = new ByteArrayInputStream(objectData);

            try {
                SerializationUtils.ClassLoaderAwareObjectInputStream in = new SerializationUtils.ClassLoaderAwareObjectInputStream(bais, object.getClass().getClassLoader());

                Serializable var5;
                try {
                    // 反序列化成对象
                    T readObject = (Serializable)in.readObject();
                    var5 = readObject;
                } catch (Throwable var7) {
                    try {
                        in.close();
                    } catch (Throwable var6) {
                        var7.addSuppressed(var6);
                    }

                    throw var7;
                }

                in.close();
                return var5;
            } catch (ClassNotFoundException var8) {
                throw new SerializationException("ClassNotFoundException while reading cloned object data", var8);
            } catch (IOException var9) {
                throw new SerializationException("IOException while reading or closing cloned object data", var9);
            }
        }
    }
```

可以看到, 比较简单, 就是序列化成字节数组,之后再反序列化回来, 也从代码中可以看到, 想要用此方法来进行深拷贝的类,及其所有的属性类, 都必须要实现`Serializable`接口, 否则没有办法使用.

由此我们可以总结下两种深拷贝的优劣势了.

**重写clone方法**
优点:
    - 底层实现较简单
    - 不需要引入第三方包
    - 系统开销小
缺点:
    - 可用性较差，每次新增成员变量可能需要修改clone()方法
    - 拷贝类（包括其成员变量）需要实现Cloneable接口

**Apache序列化**
优点:
    - 可用性强，新增成员变量不需要修改拷贝方法
缺点:
    - 需要引入Apache Commons Lang第三方JAR包
    - 拷贝类（包括其成员变量）需要实现Serializable接口
    - 序列化与反序列化存在一定的系统开销

那么当我们想要选用一种实现方法的时候, 该怎么选呢? 说实话这些方法都挺恶心的...一点都不简单实用, 当你必须需要一个深拷贝的办法时, 首先要考虑的不是你想用哪个, 而是看你的实际情况能用哪个. 比如待拷贝的类是否实现了cloneable,Serializable, 当前系统是要求代码好看点呢还是极致要求性能呢? 根据这些情况, 针对性的选择一种, 如果实在没有办法, 我们还是可以手动全部new一遍的嘛.

## 压测

都说序列化的方式来实现深拷贝性能不好, 那么来进行一个简单的性能对比吧.

测试所用的类, 就用上面简单的Person类吧.

我在1分钟内的时间,反复调用两种序列化,测试结果如下:

拷贝方法| RPS      |  Avg(ms) | Min(ms)  | Max(ms) |   StdDev   |  Total  |    TP50 |      TP90    |   TP95 |     TP99 |   TP999    |  TP9999      
--- |--- |--- |--- |--- |--- |--- |--- |--- |--- |--- |--- | ---| 
重写clone | 13602164.28 |  0.00 |       0      |  94  |     0.05   |  816129857|0 |       0  |      0   |     0  |      0  |      0|
apache序列化 | 383011.93 | 0.02  |   0 |       126  |    0.55  |   22980716 |0 |       0  |      0  |      0 |       10  |     22


大家只看第一列数据,也就是1分钟之内能进行深拷贝的次数, 就知道, 重写clone的方法完全是吊打序列化, 所以基本上选择的时候, 就看, 你愿意用性能换取方便吗?

<br>


完。
<br>
<br>
<br>


## 联系我
最后，欢迎关注我的个人公众号【 呼延十 】，会不定期更新很多后端工程师的学习笔记。
也欢迎直接公众号私信或者邮箱联系我，一定知无不言，言无不尽。
![](http://img.couplecoders.tech/%E6%89%AB%E7%A0%81_%E6%90%9C%E7%B4%A2%E8%81%94%E5%90%88%E4%BC%A0%E6%92%AD%E6%A0%B7%E5%BC%8F-%E6%A0%87%E5%87%86%E8%89%B2%E7%89%88.png)


<br>
<br>




**以上皆为个人所思所得，如有错误欢迎评论区指正。**


**欢迎转载，烦请署名并保留原文链接。**


**联系邮箱：huyanshi2580@gmail.com**


**更多学习笔记见个人博客或关注微信公众号 &lt;呼延十 &gt;------><a href="{{ site.baseurl }}/">呼延十</a>**