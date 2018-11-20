---
layout: post
category: [开发环境搭建,Spring Boot]
---

好的日志不仅能够方便的自己的编码调试过程，在线上debug过程中也是十分重要的！
今天来学习一下如何在spring boot项目中使用log4j2进来日志的输出。

## 添加依赖

![](http://img.couplecoders.tech/markdown-img-paste-20181101001734348.png)

在pom.xml文件中加入图中的依赖，由于使用yml配置文件，因此需要额外引入第二个，不使用yml的朋友可以不用引入。


## 配置文件

在resources目录下新建`log4j2.yml`文件，其中添加以下内容：

```yml
Configuration:
  status: debug
  Appenders:
    Console: #输出到控制台
      name: Console
      PatternLayout:
        Pattern: "%highlight{[ %p ] [%-d{yyyy-MM-dd HH:mm:ss}] [ LOGID:%X{logid} ] [%l] %m%n}"
      target: SYSTEM_OUT
    RollingFile: # 输出到文件，超过2048MB归档
    - name: RollingFile_Appender
      fileName: /logs/events-csg-adapter/app.log
      filePattern: "/logs/events-csg-adapter/event-csg-adapter-%i.log.%d{yyyy-MM-dd}"
      PatternLayout: #设置日志级别的颜色
        pattern: "%highlight{[ %p ] [%-d{yyyy-MM-dd HH:mm:ss}] [ LOGID:%X{logid} ] [%l] %m%n}"
      Policies:
        SizeBasedTriggeringPolicy:
          size: 2048 M
        DefaultRollOverStrategy:
          max: 10
  Loggers:
    Root:
      AppenderRef:
      - ref: Console
      - ref: RollingFile_Appender
    logger:
    - name: org.springframework
      level: debug
    - name: com.apricotforest.events
      level: debug
```

### 测试用例

![](http://img.couplecoders.tech/markdown-img-paste-20181101002602232.png)


### 运行结果

![](http://img.couplecoders.tech/markdown-img-paste-20181101002650784.png)

可以看到，三个输出语句都输出成功。

同时可以调整log.level来控制日志输出级别。




<br>
完。

<br>
<br>
<br>
<br>
<h4>ChangeLog</h4>
2018-10-31 完成
<br>
<br>

**以上皆为个人所思所得，如有错误欢迎评论区指正。**

**欢迎转载，烦请署名并保留原文链接。**

**联系邮箱：huyanshi2580@gmail.com**

**更多学习笔记见个人博客------><a href="{{ site.baseurl }}/">呼延十</a>**
