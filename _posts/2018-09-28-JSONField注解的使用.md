---
layout: post
category: 实际问题解决
---

1

PS:此文没有远离解读，仅有使用工具解决办法。

日前在工作中，遇到了一个问题，关于java的序列化。  

工作中与前端的数据交换使用的协议是json+protobuf，主要是用protobuf。

现在我需要接收一份较为复杂的数据，数据格式如下：
```json
{
  "result": [
    {
      "String": "string",
      "Int": 123,
      "persions": [
        {
          "person_name": "huyan",
          "person_name_2": "shi"
        }
      ],
      "money": [
        {
          "type": "dollar",
          "num": 100
        }
      ]
    },
    {
      "String": "str",
      "Int": 123,
      "persions": [],
      "money": [
        {
          "type": "软妹币",
          "num": 100
        }
      ]
    }
  ]
}
```

result里面是一个类的列表，我一开始将其定义为proto(这里要尤其注意，这个数据暂不牵涉到数据交换，单纯是懒，定义proto顺手就定义了)，然后在拿到result数组之后，需要将其转化为Java POJO列表。  


由JSONArray转化为对象列表，哎？？ fastJson有现成的呀，直接使用：

```java
  public static <T> List<T> parseArray(String text, Class<T> clazz)
```
方法走你！

后来发现不行，json转java对象使用的是对象的get和set方法，而proto并没有提供传统的get和set方法，提供的是基于builder的set方法，即：set方法的返回值不是void，而是builder。

重点来了，重点来了：

**我选择了自己实现，即：遍历JSONArray，逐个取值，新建对象，存值。**

不要问我为什么，懒！懒得改了。

等我功能完全实现之后，打算review一下自己的代码，重构一下，因为这个需要做了好久，我都忘记自己写的啥玩意了。

看到了这块代码，MMP啊，这代码别说老大给不给过，我自己就过不了啊！！！

然后把这几个类的定义从proto改到普通的POJO，然后提取共性，一番折腾下来重新使用fastjson序列化，成功了，但是好多值莫名其妙的为空。尤其是其中的对象，persion基本都是空。

这个时候我甚至怀疑了一下是不是fastjson不支持这么复杂的数据转化，比如类里面有几个类的列表。

(!!对不起，马爸爸我不该怀疑你的，对不起我知道我狂妄了，我这数据复杂个屁啊)。

在冲动过后，我觉得fastjson不可能这么菜的，怀疑到是不是自己出错了，比如：属性名称不一样。。

检查了一下，是的，，但是呢我的命名问题不大，而且业务都写好了不想改，这时候就用到@JSONField注解了。

在每个名字不一样的属性上打上注解，注解里面备注名字，妥了！

![](http://pem6cy6sv.bkt.clouddn.com/WX20180928-205928.png)


### @JSONField

此注解可以使用在属性上和get/set方法上，具体效果为：

```java
@JSONField(name="Age")
private int age;

@JSONField(name="Age")
private int getAge(){
  return this.age;
}

@JSONField(name="Age")
private void setAge(int age){
  this.age = age;
}

```

注解在属性上，序列化以及反序列化都会使用此名字，通俗点就是：会把json里面key为“Age”的值赋值给 该类的age，会把age的值写入“Age”。

注解在get/set上就是上述操作的一半，一个控制序列化，一个控制反序列化。


<br>
<br>
<br>
<br>
<h4>ChangeLog</h4>
2018-09-28 完成
<br>
<br>

**以上皆为个人所思所得，如有错误欢迎评论区指正。**

**欢迎转载，烦请署名并保留原文链接。**

**联系邮箱：huyanshi2580@gmail.com**

**更多学习笔记见个人博客------><a href="{{ site.baseurl }}/">呼延十</a>**
