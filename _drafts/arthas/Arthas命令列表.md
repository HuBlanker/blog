---
layout: post
category: [Java]
tags:
  - Java
---

**本文仅学习记录使用，内容基本来自官网,可以直接前往查看**

Arthas 是 Alibaba 开源的 Java 诊断工具，零星的用了一些，功能很不错，直击痛点，因此进行一个系统的学习.


当你遇到以下类似问题而束手无策时，Arthas可以帮助你解决：

> 0. 这个类从哪个 jar 包加载的？为什么会报各种类相关的 Exception？
> 1. 我改的代码为什么没有执行到？难道是我没 commit？分支搞错了？
> 2. 遇到问题无法在线上 debug，难道只能通过加日志再重新发布吗？
> 3. 线上遇到某个用户的数据处理有问题，但线上同样无法 debug，线下无法重现！
> 4. 是否有一个全局视角来查看系统的运行状况？
> 5. 有什么办法可以监控到 JVM 的实时运行状态？
> 6. 怎么快速定位应用的热点，生成火焰图？
> 7. 怎样直接从 JVM 内查找某个类的实例？

希望我学习完后，可以回答上面的8个问题.


安装下载等就跳过了，官网有详细的解释. [arthas](https://arthas.aliyun.com/doc/), 直接开始学习命令列表.




# dashboard

查看当前进程的面板，包含线程，内存，GC, 和运行时参数. 

比较有用的是，可以查看线程(包括JVM内部线程)的CPU占用率，可以比较清晰的看到，当前Load较高，是哪些线程造成的.

# getstatic 

```getstatic 类名 属性名 "ognl表达式"```

可以查看类的静态属性，支持ognl表达式，支持指定classLoader. 

官方更推荐直接使用`ognl`命令，更加灵活一些.

# heapdump 

类似jmap的dump功能. 我选择jmap.

# jvm 

查看jvm 的一些信息. 

* 运行时参数
* classLoader信息
* 编译信息
* gc 
* 内存
* 线程
      *COUNT: JVM 当前活跃的线程数
      *DAEMON-COUNT: JVM 当前活跃的守护线程数
      *PEAK-COUNT: 从 JVM 启动开始曾经活着的最大线程数
      *STARTED-COUNT: 从 JVM 启动开始总共启动过的线程次数
      *DEADLOCK-COUNT: JVM 当前死锁的线程数
* 操作系统
* 文件描述符
      * MAX-FILE-DESCRIPTOR-COUNT：JVM 进程最大可以打开的文件描述符数
      * OPEN-FILE-DESCRIPTOR-COUNT：JVM 当前打开的文件描述符数


其他的有很多信息展示和统计. 可以方便查看.

# logger 

查看logger相关的信息，比如日志级别等. 可以使用`logger --name root --level debug`来更新日志级别.

# mbean 

不了解. 跳过先.

# memory 

查看JVM内存区域，堆，堆外，元空间等. 　`direct`是堆外内存.

# ognl 

执行ognl表达式.  可以方便的替换`getstatic`命令. 

ognl表达式，语法很好理解. (ognl表达式官网)[https://commons.apache.org/proper/commons-ognl/language-guide.html]

* 调用静态函数
* 获取静态类的静态字段


# perfcounter

未知，跳过.

# sysenv 

查看系统环境变量

# sysprop 

查看JVM的系统属性

# thread

查看线程相关信息

* thread -n 3 展示当前最忙的3个线程，并打印其堆栈
* thread 1  打印ID为1的线程堆栈，一般是主线程
* thread --all 显示所有匹配的线程
* thread -b 找出阻塞其他线程的线程,可以用来排查死锁
* thread --state 查看指定状态的线程


# vmoption

查看JVM的参数 

* vmoption 查看所有的参数
* vmoption PrintGC 查看指定的参数
* vmoption PrintGC true 更新指定的参数 

# vmtool 

vmtool 利用JVMTI接口，实现查询内存对象，强制 GC 等功能。


* 获取对象  `vmtool --action getInstance --className java.lang.String --limit 10 `. 获取指定类的实例，最好指定limit. 否则会对JVM造成压力.
* `-x`可以指定结果展开层数
*  getInstances action 返回结果绑定到instances变量上，它是数组。可以通过--express参数执行指定的表达式。 


**结合以上三点，如果项目中有实例很容易标识的类，比如`Resources`资源类，可以直接全局搜索该类的唯一实例，然后对其进行表达式求值. 观察一些资源的加载情况.**

这点其实是我学习arhtas的初衷，项目中，经常会怀疑数据加载错了，每次打日志总是很麻烦，而该类在项目中也不是单例存在，不能使用`getstatic`或者`ognl`获取，因此，一直想找**在JVM中搜索某个类的实例，并查看详细信息**的方法.


# classloader

查看classloder的继承树, urls,  类加载信息.

* classloader 查看统计信息
* classloder -t 查看继承树 


# dump 

dump 已加载类的 bytecode 到特定目录

支持指定类，包的通配符,以及指定文件或者类加载器.


# jad 

反编译.

* jad class  反编译类
* jad class method 反编译方法

# mc 

Memory Compiler/内存编译器，编译.java文件生成.class。

* mc /tmp/Test.java   编译该Java文件
* mc -d /tmp/out  /tmp/Test.java  指定输出目录. 

可以和热更新相关命令进行配合.

# redefine

官方推荐使用: retransform命令.

* redefine /tmp/Test.class 重新加载该class.
* 结合 jad/mc 使用. 
      * jad --source-only com.example.demo.arthas.user.UserController > /tmp/UserController.java   反编译类
      * mc /tmp/UserController.java -d /tmp    修改源码
      *  redefine /tmp/com/example/demo/arthas/user/UserController.class   重新加载该类


**上传class文件到服务的技巧**

> 在本地先转换.class文件为 base64，再保存为 result.txt    `base64 < Test.class > result.txt`
> 到服务器上，新建并编辑result.txt，复制本地的内容，粘贴再保存
> 把服务器上的 result.txt还原为.class  `base64 -d < result.txt > Test.class`
> md5校验文件是否一致



# retransform

加载外部的.class文件，retransform jvm 已加载的类。


* retransform  a.class 

加载指定的类.

* 查看 retransform entry 

查看当前有哪些类进行了 retransform. `retransform -l`


* 删除指定的 retransform entry 

`retransform -d ID` 

* 删除所有的 retransform entry 

`retransform --deleteAll`.

* 显示的触发一次 retransform

`retransform --classPattern demo.MathGame`

* 消除影响

  1. 删除这个类对应的 retransform entry 
  2. 重新触发 retransform . 加载回最原始的类.


* 结合 jad/mc使用

和redefine一样，反编译->修改->重新加载.


* 限制
  1. 不允许新增field/method.
  2. 正在跑的函数，没有退出不能生效.

# sc (class-search)

查看 JVM 已加载的类信息


* 通配符搜索  `sc com.xxx.*`
* 打印类的详细信息, 名字，父类，子类，类加载器等. `sc -d class`.
* 打印类的filed信息. `sc -d -f class`.

# sm  (method-search)


查看已加载类的方法信息

* 查看类的全部方法 `sm class`
* 查看类的全部方法的详细信息. 入参，出参，异常，类加载器等. `sm -d class`.

# monitor 

方法调用监控.

* 监控某个方法5次 `monitor -c 5 class method`
* 计算条件表达式过滤 `monitor -c 5 class method "params[0] <= 2"`
* -b可以在方法调用之前统计.


输出信息含义:

调用时间戳，类名，方法名，总数，成功数，失败数，平均时间，失败比例.


# stack 

输出当前方法被调用的调用路径

* 查看方法堆栈 `stack class method`.
* 根据条件表达式过滤 `stack class method 'params[0]<0' -n 2`
* 根据执行时间过滤 `stack class method '#cost<3' -n 2`



# trace 

方法内部调用路径，并输出方法路径上的每个节点上耗时.

这是排查方法调用性能问题的一把利剑.

* trace函数  `trace class method`.
* 次数限制  `-n 10`
* 是否包含JDK的函数 `--skipJDKMethod false`.
* 根据调用耗时过滤. `#cost > 20`
* 排除指定的类
* 动态trace  通过使用listenerId,来不断深入进行trace.
* -v打印更多参数




# tt 

方法执行数据的时空隧道，记录下指定方法每次调用的入参和返回信息，并能对这些不同的时间下调用进行观测 

记录并分析，回溯请求.


* 记录方法调用 `tt -t class method`
* 检索调用  `tt -s 'method.name=="xxxxx"'`
* 查看某次调用的详细信息 `tt -i index` index 是 tt结果的编号.
* 重放一次调用 `tt -i index -p`.
* 观察表达式. 观察某次调用的详细信息值. `tt -w "ognl表达式" -x 1 -i index`


结合以上参数，可以实现.**记录某方法的N次调用，搜索到自己想查看的那次，通过观察表达式，观察调用的上下文信息，进行修改，然后重放一次请求，观察修改是否符合预期.**


# watch 

 函数执行数据观测,另一个分析利器.  经常我们在灰度测试，结果不对，此时不能确认是别人调用我们数据错误，还是程序内部逻辑错误,因此需要观察调用链路上的所有数据.

 * 观察入参，出参, this对象. `watch class method -x 2`
 * 观察入参，出参 `watch class method "{params,returnObj}" -x 2 -b`, -b指的是在函数调用前观察.因此返回值全部是空.
 * 同时观察函数调用前和函数返回后 , 分两个节点观察. `watch class method "{params,target,returnObj}" -x 2 -b -s -n 2`
 * `-x 3`，指定参数的展开层次
 * 条件表达式. `watch class method "{params[0],target}" "params[0]<0"` 可以指定参数过滤，指定耗时过滤('#cost>100').
 * 观察异常信息 `watch class method "{params[0],throwExp}" -e -x 2`
 * 观察表达式，支持ognl表达式. 因此可以观察任何你想观察的数据，只要是合法的ognl表达式即可.
 比如`this.xxxx`,观察当前对象的某个属性. `@class@static_field`，观察某个静态类的静态字段，或者调用静态方法等等.具体的可以学习ognl.


 # profiler 

 生成火焰图

 * 启动   `profiler start`
 * 获取采集到的sample数量. `profiler getSamples`.
 * 查看状态 `profiler status`.
 * 停止 `profiler stop`. 默认会生成html格式的火焰图，dump到本地，用浏览器打开即可.
 * 支持的事件类型. `profiler list` ,可以列出支持的类型. 在linux下，支持`cpu,alloc,lock,wall,itimer`.
 * 支持的动作类型. `profiler actions`
 * 指定执行时间自动结束. `profiler --duration 300`. 秒.


 # jfr 

 jfr可以收集JVM的数据，然后进行分析.

 * 启动记录 `jfr start`
 * 指定目录等. `jfr start -n myRecording --duration 60s -f /tmp/myRecording.jfr`
 * 停止记录. `jfr stop -r 1`

 生成的jfr文件，可以用支持jfr格式的工具查看，比如`JDM Mission Control`.

 jfr里面具体包含什么，我还不清楚，跳过. 学习了再来补充.


# options

查看全局的开关,查看Arthas一些开关，并修改对应的值.

* unsafe 开关
* 保存日志 save-result.
* 关闭Strict模式.
* 输出为json格式的开关.

# reset 

重置所有的增强类

重置增强类，将被 Arthas 增强过的类全部还原，Arthas 服务端stop时会重置所有增强过的类


# session 

查看当前会话，为啥放在重要命令呢? 因为他和`Arthas Tunnel`有关.


 # 一些不重要的命令


* auth 验证当前会话

* base64   同linux.
* cat  同linux.
* cls 清空屏幕
* echo 同linux.
* grep 同linux
* help 打印帮助信息
* history 历史命令，所有的历史命令，而不是当前会话中的指令
* keymap 快捷键配置
* pwd 同linux.
* quit 只是退出当前 Arthas 客户端，Arthas 的服务器端并没有关闭，所做的修改也不会被重置。
* stop 关闭服务端，所有客户端关闭，重置所有的增强类.
* tee 同linux.
* version 打印版本
















## 参考文章

https://arthas.aliyun.com/

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