---
layout: post
category: [开发者工具,效率编程]
tags:
  - 开发者工具
  - 效率编程
---

## 背景介绍

我一直自诩干活效率高,但是最近见识了一些大佬,在编码过程中,基本不使用鼠标,效率高的飞起.

工欲善其事必先利其器,不仅要用好的工具,也要用好工具.Intelij想要使用的好,没那么简单.

比如查找文件,修改,删除,移动代码等等操作,用鼠标是一种比较简单的方式,但是也是一种较慢的方式,因此我决定学习且熟悉IDEA的一些常用的快捷键,相信在长期使用下,一定能提高效率.

PS:其实各种快捷键的使用,难的不在于了解和记忆,而在于`常用`.就好像我初学习双拼,记忆键盘位置也就1个小时,但是不能熟练使用. 之后我强行将自己的输入法改成了双拼,在之后的几天里面,确实是打字很慢,甚至出现忘记位置去重新查的情况,但是坚持了下来,现在的打字速度就不是原来的水平啦~.(当然,现在打出奇奇怪怪的错别字的概率也大了一些.)

本文应该会分为几个小部分.
1. 快捷键部分,会长期补充在第二小节`快捷键`中.
2. 一些配置内容,会在后面逐渐添加小节

## 快捷键

快捷键 | 作用 | 备注
---   | --- | ---
ctrl + s | 将当前文件放到水平分屏的右侧 | 
alt + s | 将当前文件放回左侧的区域 | 
shift + f6 | 重命名当前变量/方法等 | 会同步到使用它的地方
shift + alt + ⬆️/⬇️ | 向上/向下移动一行代码  |
shift + enter | 无论你的光标是否在行尾,开始下一行. | 建议将下一个的快捷键改为此快捷键,可以较为方便的室自动补全当前语句和下一行.
shift + command + enter | 自动补全当前行的分号 | 当当前行有分号,开始下一行
command + o | 实现方法 | 
双击 shift | 全局查找任何东西 | 可以使用`tab`切换要查找的类型
shift + command + alt + n | 全局查找symbols | 主要用来查找方法
command + n | 查找Java类 |
shift + f9 | debug 启动 |
shift + f10 | run 启动 | 
ctrl + shift + f9 | debug 启动当前类|
ctrl + shift + f10 | run 启动当前类 | 
shift + command + a | find action,然后输入你想做的动作,很多常用功能都有 |  比如输入`opt`,提醒你优化import
command + w | 选中光标所在的单词
command + y | 删除光标所在行
command + x | 剪切光标所在行
command + shift + r | 全局查找和替换
alt + F7 | 查询类,变量等的引用
ctrl + n | 自动生成代码 | get/set,construct之类
command + alt + l | 自动格式化代码 |
command + alt + o | 自动优化import | 
F8 | 单步跳过 | 
F9 | 跳过当前断点
command + 7 | 打开structure视图,可以查看类的属性和方法
command + 9 | 打开版本控制
alt + F12 / command + 8 | 在idea中打开终端 | 第二个快捷键为自己配置
command + F7 | 寻找使用者 
command + F12 | 以弹窗的形式查看类的属性和方法
ctrl + h | 查看类的继承关系


## 分屏快捷键的配置

为了实现类似效果:

![2019-03-28-14-45-51](http://img.couplecoders.tech/2019-03-28-14-45-51.png)

当你的屏幕比较大并且你想要左右同时对照着修改两个文件的时候,可能会用到左右分屏.

配置方式:在文件栏上右键,然后可以选择点击`Split Vertically`,`Split Horizontally`,`Move Right`,`Move Down`,`Move To Opposite Griup`等选项. 我个人只喜欢使用左右分屏,因此在`keymap`中配置`Move Rigth` = `ctrl+S`,`Move To Opposite Griup` = `alt + s`.

功能很好使,快捷键仍有待测试.

## mac 本身的光标移动速度

这个不属于IDEA的配置,但是也写在这里吧.

去设置中,keyboard,将按键重复和重复前延迟拉满.

## 自定义代码段及创建类注释

#### 类注释

就是类的上面那个标识谁在哪一天写的.

在`setting-> File And Code Templates - >class` 中加入:

```java
/**
 * Created by huyanshi on ${YEAR}/${MONTH}/${DAY}.
 */
```

#### 自定义代码段

常用的代码片段可以由某个关键字触发.

比如我经常写一些小的测试类,不喜欢老是写main方法.所以在`setting-> live Templates` 中加入:
![2019-03-28-15-42-58](http://img.couplecoders.tech/2019-03-28-15-42-58.png)

以后需要直接在代码中`main`就会自动生成了.

#### 2018 版本自动提示忽略大小写

网上的忽略大小写基本都是以前的版本.

在2018中,在`Setting->Editor->General->Code Complete`中取消勾选 `match case`.

![2019-04-16-11-02-10](http://img.couplecoders.tech/2019-04-16-11-02-10.png)


<br>
<br>
<br>
<br>
<h4>ChangeLog</h4>
2019-03-28      完成
<br>
<br>


**以上皆为个人所思所得，如有错误欢迎评论区指正。**

**欢迎转载，烦请署名并保留原文链接。**

**联系邮箱：huyanshi2580@gmail.com**

**更多学习笔记见个人博客------><a href="{{ site.baseurl }}/">呼延十</a>**
