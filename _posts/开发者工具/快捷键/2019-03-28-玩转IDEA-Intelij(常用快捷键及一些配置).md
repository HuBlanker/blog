---
layout: post
category: [开发者工具，效率编程]
tags:
  - 开发者工具
  - 效率编程
---

## 目录

- [目录](# 目录)
- [背景介绍](# 背景介绍)
- [快捷键](# 快捷键)
- [配置项](# 配置项)
    - [分屏快捷键的配置](# 分屏快捷键的配置)
    - [mac 本身的光标移动速度](#mac - 本身的光标移动速度)
    - [自定义代码段及创建类注释](# 自定义代码段及创建类注释)
        - [类注释](# 类注释)
        - [自定义代码段](# 自定义代码段)
        - [2018 版本自动提示忽略大小写](#2018 - 版本自动提示忽略大小写)
        - [配置同步](# 配置同步)

## 背景介绍

工欲善其事必先利其器，不仅要用好的工具，要用好工具。Intelij 要使用的好，那么简单。

比如查找文件，修改，删除，移动代码等等操作，用鼠标是一种比较简单的方式，但是也是一种较慢的方式，因此我决定学习且熟悉 IDEA 的一些常用的快捷键，相信在长期使用下，一定能提高效率。

PS: 其实各种快捷键的使用，难的不在于了解和记忆，而在于 ` 常用 `. 就好像我初学习双拼，记忆键盘位置也就 1 个小时，但是不能熟练使用。之后我强行将自己的输入法改成了双拼，在之后的几天里面，确实是打字很慢，甚至出现忘记位置去重新查的情况，但是坚持了下来，现在的打字速度就不是原来的水平啦~.（当然，现在打出奇奇怪怪的错别字的概率也大了一些。)

本文应该会分为几个小部分。
1. 快捷键部分，会长期补充在第二小节 ` 快捷键 ` 中。
2. 一些配置内容或者小技巧，会在后面逐渐添加小节

## 快捷键

快捷键部分没有直接翻译官方文档，而是按照自己的使用习惯一个一个添加，基本都是自己工作中经常使用的。

快捷键 | 作用 | 备注
---   | --- | ---
ctrl + s | 将当前文件放到水平分屏的右侧 |
alt + s | 将当前文件放到相反的区域 | 主要用来左右切换，开两个窗口
shift + f6 | 重命名当前变量 / 方法等 | 会同步到使用它的地方
shift + alt + ⬆️/⬇️ | 向上 / 向下移动一行代码  |
shift + enter | 无论你的光标是否在行尾，开始下一行。| 建议将下一个的快捷键改为此快捷键，可以较为方便的室自动补全当前语句和下一行。
shift + command + enter | 自动补全当前行的分号 | 当当前行有分号，开始下一行
command + o | 实现方法 |
双击 shift | 全局查找任何东西 | 可以使用 `tab` 切换要查找的类型
command + n | 全局查找类
command + shift + n | 全局查找文件 | 这几个是一系列，都可以通过双击 shift 之后使用 tab 来切换，也可以直接按快捷键。
shift + command + alt + n | 全局查找 symbols | 主要用来查找方法
command + n | 查找 Java 类 |
shift + f9 | debug 启动 |
shift + f10 | run 启动 |
ctrl + shift + f9 | debug 启动当前类 |
ctrl + shift + f10 | run 启动当前类 |
shift + command + a | find action, 然后输入你想做的动作，很多常用功能都有 |  比如输入 `opt`, 提醒你优化 import
command + w | 选中光标所在的单词 | 改为 Extend Selection, 多次按键，可以向高层逐渐选中。
command + y | 删除光标所在行
command + x | 剪切光标所在行
command + shift + r | 全局查找和替换
alt + F7 | 查询类，变量等的引用
ctrl + n | 自动生成代码 | get/set,construct 之类
command + alt + l | 自动格式化代码 |
command + alt + o | 自动优化 import |
F8 | 单步跳过 |
F9 | 跳过当前断点
command + 7 | 打开 structure 视图，可以查看类的属性和方法
command + 9 | 打开版本控制
alt + F12 / command + 8 | 在 idea 中打开终端 | 第二个快捷键为自己配置
command + F7 | 寻找使用者 
command + F12 | 以弹窗的形式查看类的属性和方法
ctrl + h | 查看类的继承关系
ctrl + shift + n | 新建一个临时的文件
command +  g | 跳转到某一行
command + b | 进入方法等，等价于 command + 鼠标左键
command + e | 最近打开的文件列表
command + j | 插入模板代码
shift + ctrl + n | 新建 scratches 文件
command + , | 打开设置面板
alt + f1 | select in , 经常用来在 project 中选中文件。
command + - | 折叠代码
command + + | 打开折叠代码
comand + shift + 8 | 进入列选择模式，直接按住滚轮移动鼠标也可以按列选中。
command + shift + i | 悬浮窗口显示方法的具体代码

## 配置项

### 分屏快捷键的配置

为了实现类似效果：

![2019-03-28-14-45-51](http://img.couplecoders.tech/2019-03-28-14-45-51.png)

当你的屏幕比较大并且你想要左右同时对照着修改两个文件的时候，可能会用到左右分屏。

配置方式：在文件栏上右键，然后可以选择点击 `Split Vertically`,`Split Horizontally`,`Move Right`,`Move Down`,`Move To Opposite Griup` 等选项。我个人只喜欢使用左右分屏，因此在 `keymap` 中配置 `Move Rigth` = `ctrl+S`,`Move To Opposite Griup` = `alt + s`.

功能很好使，快捷键仍有待测试。

### 自定义代码段及创建类注释

#### 类注释

就是类的上面那个标识谁在哪一天写的。

在 `setting-> File And Code Templates - >class` 中加入：

```java
/**
 * Created by huyanshi on ${YEAR}/${MONTH}/${DAY}.
 */
```

#### 自定义代码段

**main 方法 **

常用的代码片段可以由某个关键字触发。

比如我经常写一些小的测试类，不喜欢老是写 main 方法。所以在 `setting-> live Templates` 中加入：
![2019-03-28-15-42-58](http://img.couplecoders.tech/2019-03-28-15-42-58.png)

以后需要直接在代码中 `main` 就会自动生成了。

如果想控制自动生成代码之后的光标位置，可以在该位置加上 `$END$`.

更多的自定义代码段，见我的配置仓库。[IDEA 配置仓库](https://github.com/HuBlanker/Intellij/blob/master/templates/huyanshi.xml).

#### 2018 版本自动提示忽略大小写

网上的忽略大小写基本都是以前的版本。

在 2018 中，在 `Setting->Editor->General->Code Complete` 中取消勾选 `match case`.

![2019-04-16-11-02-10](http://img.couplecoders.tech/2019-04-16-11-02-10.png)

#### 配置同步 （手动导出导入文件）

配置的越多，换电脑越难受，幸好 idea 提供了导出导入配置，使用 `File->Import Settings` 和 `File->Export Settings` 即可。

#### 配置同步 （使用 github 仓库）

此外还可以使用 github 仓库来进行同步，这种方法也比较适合一个团队使用相同的 DIEA 配置。

首先打开 IDEA,`File -> Settings Repository`, 然后链接输入自己 github 的一个空仓库。

![2019-09-22-23-01-59](http://img.couplecoders.tech/2019-09-22-23-01-59.png)

之后，可以快吃根据需要进行配置的上传，下载以及合并。

注意：在使用过程中，需要填写 github 的 Token. 具体生成方法见 [github 的 Token 使用](https://www.jetbrains.com/help/idea/sharing-your-ide-settings.html#settings-repository).

#### 双引号，括号等自动包括

在 idea 的默认设置中，当我们选中一个单词，之后输入双引号，那么该单词会被替换为双引号，而很多时候我们是需要使用引号包含内容的。可以选中 `Setting -> Editor ->Smart Keys -> Surround a selection with a quote or brace` 来实现。

#### 引号和括号自动跳出

当我们在引号中输入完成，还需要按一下方向右键，来跳出括号，而右键又比较远，我们可以选中，`Setting -> Editor ->Smart Keys -> Jump outside the closing bracket or quote with Tab` 来达到这个目的。

** 对于上面两点，[此链接](https://studyidea.cn/articles/2019/06/02/1559465646386.html) 讲解的十分好且有丰富的截图，大家没有明白的可以去看一下。**

#### 流调试器

Java 8 引入的流（Stream）可谓是一个大杀器，极大的提高了对数据的处理效率。但是也有很多人吐槽，Stream 降低了代码的可读性以及难以 debug, 作为最专业的的 Java IDE, Intellij 已经集成了流调试器。一起来看看。

对以下代码，进行调试后点击 debug 栏中：

![2019-09-22-23-32-46](http://img.couplecoders.tech/2019-09-22-23-32-46.png), 就会进入下面的页面，可以清晰的看到自己是哪一步出错了。

![2019-09-22-23-33-31](http://img.couplecoders.tech/2019-09-22-23-33-31.png).

这个功能十分强大，但是个人不建议严重依赖于它，首先单步调试本来就是一个效率比较低的操作，其次，我们还是应该去了解 Stream 的代码，来理解他的功能，而不要仅仅停留在 "看图看懂" 的阶段 （个人建议）.

<br>
<h4>ChangeLog</h4>
2019-03-28      完成
<br>

** 以上皆为个人所思所得，如有错误欢迎评论区指正。**

** 欢迎转载，烦请署名并保留原文链接。**

** 联系邮箱：huyanshi2580@gmail.com**

** 更多学习笔记见个人博客 ------><a href="{{ site.baseurl}}/"> 呼延十 </a>**
