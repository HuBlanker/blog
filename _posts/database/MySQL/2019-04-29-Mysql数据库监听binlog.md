---
layout: post
category: [Mysql,轮子]
tags:
  - MySQL
  - 轮子
---

## 前言
我们经常需要根据用户对自己数据的一些操作来做一些事情.

比如如果用户删除了自己的账号,我们就给他~~发短信骂他~~,去发短信求他回来.

类似于这种功能,当然可以在业务逻辑层实现,在收到用户的删除请求之后执行这一操作,但是数据库的binlog为我们提供了另外一种操作方法.

要监听binlog,需要两步,第一步当然是你的mysql需要开启这一个功能,第二个是要写程序来对日志进行读取.

## mysql开启binlog.

首先mysql的binlog日常是不打开的,因此我们需要:

1. 找到mysql的配置文件`my.cnf`,这个因操作系统不一样,位置也不一定一样,可以自己找一下,
2. 在其中加入以下内容:

```

[mysqld]
server_id = 1
log-bin = mysql-bin
binlog-format = ROW


```

3. 之后重启mysql.

```shell
/ ubuntu
service mysql restart
// mac
mysql.server restart
```

4. 监测是否开启成功

进入mysql命令行,执行:

```sql

show variables like '%log_bin%' ;

```

如果结果如下图,则说明成功了:

![2019-04-29-00-31-29](http://img.couplecoders.tech/2019-04-29-00-31-29.png)

5. 查看正在写入的binlog状态:

![2019-04-29-00-32-14](http://img.couplecoders.tech/2019-04-29-00-32-14.png)

## 代码读取binlog

#### 引入依赖

我们使用开源的一些实现,这里因为一些~~奇怪的原因~~,我选用了`mysql-binlog-connector-java`这个包,(官方github仓库)[https://github.com/shyiko/mysql-binlog-connector-java]具体依赖如下:

```xml
<!-- https://mvnrepository.com/artifact/com.github.shyiko/mysql-binlog-connector-java -->
    <dependency>
      <groupId>com.github.shyiko</groupId>
      <artifactId>mysql-binlog-connector-java</artifactId>
      <version>0.17.0</version>
    </dependency>
```

当然,对binlog的处理有很多开源实现,阿里的`cancl`就是一个,也可以使用它.

#### 写个demo

根据官方仓库中readme里面,来简单的写个demo.

```java
    public static void main(String[] args) {
        BinaryLogClient client = new BinaryLogClient("hostname", 3306, "username", "passwd");
        EventDeserializer eventDeserializer = new EventDeserializer();
        eventDeserializer.setCompatibilityMode(
                EventDeserializer.CompatibilityMode.DATE_AND_TIME_AS_LONG,
                EventDeserializer.CompatibilityMode.CHAR_AND_BINARY_AS_BYTE_ARRAY
        );
        client.setEventDeserializer(eventDeserializer);
        client.registerEventListener(new BinaryLogClient.EventListener() {

            @Override
            public void onEvent(Event event) {
                // TODO
                dosomething();
                logger.info(event.toString());
            }
        });
        client.connect();
    }
```

这个完全是根据官方教程里面写的,在onEvent里面可以写自己的业务逻辑,由于我只是测试,所以我在里面将每一个event都打印了出来.

之后我手动登录到mysql,分别进行了增加,修改,删除操作,监听到的log如下:

```
00:23:13.331 [main] INFO util.MysqlBinLog - Event{header=EventHeaderV4{timestamp=0, eventType=ROTATE, serverId=1, headerLength=19, dataLength=28, nextPosition=0, flags=32}, data=RotateEventData{binlogFilename='mysql-bin.000001', binlogPosition=886}}
00:23:13.334 [main] INFO util.MysqlBinLog - Event{header=EventHeaderV4{timestamp=1556468403000, eventType=FORMAT_DESCRIPTION, serverId=1, headerLength=19, dataLength=100, nextPosition=0, flags=0}, data=FormatDescriptionEventData{binlogVersion=4, serverVersion='5.7.23-0ubuntu0.16.04.1-log', headerLength=19, dataLength=95}}
00:23:23.715 [main] INFO util.MysqlBinLog - Event{header=EventHeaderV4{timestamp=1556468603000, eventType=ANONYMOUS_GTID, serverId=1, headerLength=19, dataLength=46, nextPosition=951, flags=0}, data=null}
00:23:23.716 [main] INFO util.MysqlBinLog - Event{header=EventHeaderV4{timestamp=1556468603000, eventType=QUERY, serverId=1, headerLength=19, dataLength=51, nextPosition=1021, flags=8}, data=QueryEventData{threadId=4, executionTime=0, errorCode=0, database='pf', sql='BEGIN'}}
00:23:23.721 [main] INFO util.MysqlBinLog - Event{header=EventHeaderV4{timestamp=1556468603000, eventType=TABLE_MAP, serverId=1, headerLength=19, dataLength=32, nextPosition=1072, flags=0}, data=TableMapEventData{tableId=108, database='pf', table='student', columnTypes=15, 3, columnMetadata=135, 0, columnNullability={}}}
00:23:23.724 [main] INFO util.MysqlBinLog - Event{header=EventHeaderV4{timestamp=1556468603000, eventType=EXT_WRITE_ROWS, serverId=1, headerLength=19, dataLength=23, nextPosition=1114, flags=0}, data=WriteRowsEventData{tableId=108, includedColumns={0, 1}, rows=[
    [[B@546a03af, 2]
]}}
00:23:23.725 [main] INFO util.MysqlBinLog - Event{header=EventHeaderV4{timestamp=1556468603000, eventType=XID, serverId=1, headerLength=19, dataLength=12, nextPosition=1145, flags=0}, data=XidEventData{xid=28}}
00:23:55.872 [main] INFO util.MysqlBinLog - Event{header=EventHeaderV4{timestamp=1556468635000, eventType=ANONYMOUS_GTID, serverId=1, headerLength=19, dataLength=46, nextPosition=1210, flags=0}, data=null}
00:23:55.872 [main] INFO util.MysqlBinLog - Event{header=EventHeaderV4{timestamp=1556468635000, eventType=QUERY, serverId=1, headerLength=19, dataLength=51, nextPosition=1280, flags=8}, data=QueryEventData{threadId=4, executionTime=0, errorCode=0, database='pf', sql='BEGIN'}}
00:23:55.873 [main] INFO util.MysqlBinLog - Event{header=EventHeaderV4{timestamp=1556468635000, eventType=TABLE_MAP, serverId=1, headerLength=19, dataLength=32, nextPosition=1331, flags=0}, data=TableMapEventData{tableId=108, database='pf', table='student', columnTypes=15, 3, columnMetadata=135, 0, columnNullability={}}}
00:23:55.875 [main] INFO util.MysqlBinLog - Event{header=EventHeaderV4{timestamp=1556468635000, eventType=EXT_UPDATE_ROWS, serverId=1, headerLength=19, dataLength=31, nextPosition=1381, flags=0}, data=UpdateRowsEventData{tableId=108, includedColumnsBeforeUpdate={0, 1}, includedColumns={0, 1}, rows=[
    {before=[[B@6833ce2c, 1], after=[[B@725bef66, 3]}
]}}
00:23:55.875 [main] INFO util.MysqlBinLog - Event{header=EventHeaderV4{timestamp=1556468635000, eventType=XID, serverId=1, headerLength=19, dataLength=12, nextPosition=1412, flags=0}, data=XidEventData{xid=41}}
00:24:22.333 [main] INFO util.MysqlBinLog - Event{header=EventHeaderV4{timestamp=1556468662000, eventType=ANONYMOUS_GTID, serverId=1, headerLength=19, dataLength=46, nextPosition=1477, flags=0}, data=null}
00:24:22.334 [main] INFO util.MysqlBinLog - Event{header=EventHeaderV4{timestamp=1556468662000, eventType=QUERY, serverId=1, headerLength=19, dataLength=51, nextPosition=1547, flags=8}, data=QueryEventData{threadId=4, executionTime=0, errorCode=0, database='pf', sql='BEGIN'}}
00:24:22.334 [main] INFO util.MysqlBinLog - Event{header=EventHeaderV4{timestamp=1556468662000, eventType=TABLE_MAP, serverId=1, headerLength=19, dataLength=32, nextPosition=1598, flags=0}, data=TableMapEventData{tableId=108, database='pf', table='student', columnTypes=15, 3, columnMetadata=135, 0, columnNullability={}}}
00:24:22.335 [main] INFO util.MysqlBinLog - Event{header=EventHeaderV4{timestamp=1556468662000, eventType=EXT_DELETE_ROWS, serverId=1, headerLength=19, dataLength=23, nextPosition=1640, flags=0}, data=DeleteRowsEventData{tableId=108, includedColumns={0, 1}, rows=[
    [[B@1888ff2c, 3]
]}}
00:24:22.335 [main] INFO util.MysqlBinLog - Event{header=EventHeaderV4{timestamp=1556468662000, eventType=XID, serverId=1, headerLength=19, dataLength=12, nextPosition=1671, flags=0}, data=XidEventData{xid=42}}


```

## 根据自己的业务,封装一个更好使,更定制的工具类

开始的时候打算贴代码的,,,但是代码越写越多,索性传在github上了,这里只贴部分的实现.[代码传送门](https://github.com/HuBlanker/someprogram/tree/master/javaprogram/src/main/java/util/binlog)

#### 实现思路

1. 支持对单个表的监听,因为我们不想真的对所有数据库中的所有数据表进行监听.
2. 可以多线程消费.
3. 把监听到的内容转换成我们喜闻乐见的形式(文中的数据结构不一定很好,我没想到更加合适的了).

所以实现思路大致如下:

1. 封装个客户端,对外只提供获取方法,屏蔽掉初始化的细节代码.
2. 提供注册监听器(伪)的方法,可以注册对某个表的监听(重新定义一个监听接口,所有注册的监听器实现这个就好).
3. 真正的监听器只有客户端,他将此数据库实例上的所有操作,全部监听到并转换成我们想要的格式`LogItem`放进阻塞队列里面.
4. 启动多个线程,消费阻塞队列,对某一个`LogItem`调用对应的数据表的监听器,做一些业务逻辑.

**初始化代码:**

```java
    public MysqlBinLogListener(Conf conf) {
        BinaryLogClient client = new BinaryLogClient(conf.host, conf.port, conf.username, conf.passwd);
        EventDeserializer eventDeserializer = new EventDeserializer();
        eventDeserializer.setCompatibilityMode(
                EventDeserializer.CompatibilityMode.DATE_AND_TIME_AS_LONG,
                EventDeserializer.CompatibilityMode.CHAR_AND_BINARY_AS_BYTE_ARRAY
        );
        client.setEventDeserializer(eventDeserializer);
        this.parseClient = client;
        this.queue = new ArrayBlockingQueue<>(1024);
        this.conf = conf;
        listeners = new ConcurrentHashMap<>();
        dbTableCols = new ConcurrentHashMap<>();
        this.consumer = Executors.newFixedThreadPool(consumerThreads);
    }
```

**注册代码:**

```java
    public void regListener(String db, String table, BinLogListener listener) throws Exception {
        String dbTable = getdbTable(db, table);
        Class.forName("com.mysql.jdbc.Driver");
        // 保存当前注册的表的colum信息
        Connection connection = DriverManager.getConnection("jdbc:mysql://" + conf.host + ":" + conf.port, conf.username, conf.passwd);
        Map<String, Colum> cols = getColMap(connection, db, table);
        dbTableCols.put(dbTable, cols);

        // 保存当前注册的listener
        List<BinLogListener> list = listeners.getOrDefault(dbTable, new ArrayList<>());
        list.add(listener);
        listeners.put(dbTable, list);
    }
```

在这个步骤中,我们在注册监听者的同时,获得了该表的schema信息,并保存到map里面去,方便后续对数据进行处理.

**监听代码:**

```java
    @Override
    public void onEvent(Event event) {
        EventType eventType = event.getHeader().getEventType();

        if (eventType == EventType.TABLE_MAP) {
            TableMapEventData tableData = event.getData();
            String db = tableData.getDatabase();
            String table = tableData.getTable();
            dbTable = getdbTable(db, table);
        }

        // 只处理添加删除更新三种操作
        if (isWrite(eventType) || isUpdate(eventType) || isDelete(eventType)) {
            if (isWrite(eventType)) {
                WriteRowsEventData data = event.getData();
                for (Serializable[] row : data.getRows()) {
                    if (dbTableCols.containsKey(dbTable)) {
                        LogItem e = LogItem.itemFromInsert(row, dbTableCols.get(dbTable));
                        e.setDbTable(dbTable);
                        queue.add(e);
                    }
                }
            }
        }
    }
```

我偷懒了,,,这里面只实现了对添加操作的处理,其他操作没有写.

**消费代码:**

```java

    public void parse() throws IOException {
        parseClient.registerEventListener(this);

        for (int i = 0; i < consumerThreads; i++) {
            consumer.submit(() -> {
                while (true) {
                    if (queue.size() > 0) {
                        try {
                            LogItem item = queue.take();
                            String dbtable = item.getDbTable();
                            listeners.get(dbtable).forEach(l -> {
                                l.onEvent(item);
                            });

                        } catch (InterruptedException e) {
                            e.printStackTrace();
                        }
                    }
                    Thread.sleep(1000);
                }
            });
        }
        parseClient.connect();
    }
```

消费时,从队列中获取item,之后获取对应的一个或者多个监听者,分别消费这个item.

**测试代码:**

```java
    public static void main(String[] args) throws Exception {
        Conf conf = new Conf();
        conf.host = "hostname";
        conf.port = 3306;
        conf.username = conf.passwd = "hhsgsb";

        MysqlBinLogListener mysqlBinLogListener = new MysqlBinLogListener(conf);
        mysqlBinLogListener.parseArgsAndRun(args);
        mysqlBinLogListener.regListener("pf", "student", item -> {
            System.out.println(new String((byte[])item.getAfter().get("name")));
            logger.info("insert into {}, value = {}", item.getDbTable(), item.getAfter());
        });
        mysqlBinLogListener.regListener("pf", "teacher", item -> System.out.println("teacher ===="));

        mysqlBinLogListener.parse();
    }
```

在这段很少的代码里,注册了两个监听者,分别监听`student`和`teacher`表,并分别进行打印处理,经测试,在`teacher`表插入数据时,可以独立的运行定义的业务逻辑.

注意:这里的工具类并不能直接投入使用,因为里面有许多的异常处理没有做,且功能仅监听了插入语句,可以用来做实现的参考.

## 参考文章
https://github.com/shyiko/mysql-binlog-connector-java

https://cloud.tencent.com/developer/article/1384059

<br>
<br>
<br>
<br>
<h4>ChangeLog</h4>
2019-04-30 完
<br>
<br>

**以上皆为个人所思所得，如有错误欢迎评论区指正。**

**欢迎转载，烦请署名并保留原文链接。**

**联系邮箱：huyanshi2580@gmail.com**

**更多学习笔记见个人博客------><a href="{{ site.baseurl }}/">呼延十</a>**
