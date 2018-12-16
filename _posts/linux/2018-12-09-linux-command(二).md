---
layout: post
category: Linux
tags:
  - Linux
---

## 1.ls

列出当前目录下的清单.

命令格式:
`ls [选项] [目录名]`

常用命令:
```shell
#列出当前目录所有文件,包括.开头的隐藏文件
ls -a       
#列出当前文件的权限文件大小等信息
ls -l
```

## 2.du
显示目录或文件的大小

命令格式:
`du [选项][文件]`

常用命令:

```shell
# 以K，M，G为单位，提高信息的可读性。
du -h
# 输出当前目录下各个子目录所使用的空间,可以修改深度设置查看几级目录
du -h  --max-depth=1
```

## 3.df
检查linux服务器的文件系统的磁盘空间占用情况

命令格式:
`df [选项] [文件]`

常用命令:
```shell
# 以可读方式显示信息
df -h
```

## 4.touch
创建一个文件

命令格式:
`touch [选项]... 文件名...`

常用命令:

```shell
# 创建一个名为haha.log的文件
touch haha.log
```

## 5.cat
连接文件或标准输入并打印

命令格式:
`cat [选项] [文件]...`

cat主要有三大功能：

1. 一次显示整个文件:cat filename

2. 从键盘创建一个文件:cat > filename 只能创建新文件,不能编辑已有文件.

3. 将几个文件合并为一个文件:cat file1 file2 > file

常用命令:
```shell
# 在命令行输出一个文件并带有行号
cat -n ha.log
# 在命令行新建一个文件输入
cat > my.log
# 在命令行输出某个文件中的搜索内容,查看log时经常使用
cat -n ha.log | grep test

```

tac 可以反向排列显示文件内容哦,致敬vdog.

## 6.rm
删除文件及目录

命令格式:
`rm [选项] 文件… `

常用命令:
```shell
# 删除某个文件
rm ha.log
# 删除某个目录及其所有子目录,并且不会再次询问
rm -rf xi
# 删除某个文件不必询问
rm -f ha.log
```

rm -rf 命令记住不要手抖啊...

## 7.mv

移动文件或者将文件改名

命令格式:
` mv [选项] 源文件或目录 目标文件或目录`

常用命令:

```shell
# 将当前目录的ha文件移至子目录t1中
mv ha t1/
# 将当前目录的ha文件改名为he
mv ha he
## 将多个文件移至父目录
mv ha he ../
```

## 8.cp

复制文件或者目录

命令格式:
`cp [选项]... [-T] 源 目的`

常用命令:
```shell
# 复制单个文件到子目录,文件存在时会询问是否覆盖
cp -i ha t1/
## 复制多个文件到子目录,文件存在时会询问是否覆盖
cp -i ha he wo /t2
```

操作复制或者移动时,最好随时带上`-i` 参数,这样在覆盖前会询问,防止出错.

## 9.more

更加方便的阅读文件

命令格式:
`more [-dlfpcsu ] [-num ] [+/ pattern] [+ linenum] [file ... ] `

常用命令:
```shell
#从第几行开始显示
more +3 ha
# 分页显示,每页几行(enter向下一行,q键退出)
more -2 ha
# 搜寻字符串第一次出现,并在其上两行开始显示
more +/pp ha
```

## 10.less

可以向后翻页的阅读文件

命令格式:
`less [参数]  文件 `

常用命令:

```shell
# 查看文件
less ha.log
# 查看进程并通过less分页
ps -ef | less

```

## 11.head

显示某个文件开头一些数量的区域

命令格式:
`head [参数]... [文件]...  `

常用命令:

```shell
# 显示文件前10行
head -n 5 ha.log
```

## 12.tail

显示某个文件尾部一些数量的区域

命令格式:
`tail[必要参数][选择参数][文件]  `


常用命令:
```shell
# 显示文件最后6行
tail -n 6 ha.log
# 使用-f可以循环读取一个文件,常用来查看不断更新的日志文件
tail -f  ha.log
```

## 13.locate

查找文件

命令格式:
`Locate [选择参数] [样式]`

常用命令:

```shell
# 查找和XXX有关的所有文件
locate he
# 查找/home/huyan目录下的所有文件
locate /home/huyan
```

## 14.find

功能更加丰富的查找文件.

命令格式:
`find pathname -options [-print -exec -ok ...]`

常用命令:

```shell
# 根据关键字查找文件
find . -name "*.log"
# 根据权限查找文件
find . -perm 777
```

find 命令的功能十分强大,这里不多做介绍,具体使用时可以详细的学习.

## 15.ps

查看进程

命令格式:
`ps[参数]`

常用命令:

```shell
# 查看所有进程
ps -A
# 查看此次登录后的相关进程
ps -l
# 与grep组合使用,查看特定的进程
ps -ef | grep tomcat
```

## 16.kill

杀死进程

命令格式:

`kill[参数][进程号]`

常用命令:
```shell
# 杀死某个进程
kill 2334
# 彻底杀死某个进程
kill  -9 2334
```

## 17.top

性能监测

命令格式:
`top [参数]`

常用命令:
```shell
# 显示当前的进程,内存占用率,cpu占用率等信息
top
```

## 18.grep

用于过滤/搜索的特定字符。可使用正则表达式能多种命令配合使用，使用上十分灵活。
命令格式:
`grep [option] pattern file`


常用命令:

```shell
# 查找指定进程
ps -ef | grep tomcat
# 查找文本中特定字符串
cat ha.log | grep xixi
cat ha.log | grep xix
# 显示查找到的字符串之前5行的内容,B-之前,A-之后,C-之前之后都显示
cat ha.log | grep -B 5 xixi
```

<br>
完。

<br>
<br>
<br>
<br>
<h4>ChangeLog</h4>
2018-12-09 完成
<br>
<br>

**以上皆为个人所思所得，如有错误欢迎评论区指正。**

**欢迎转载，烦请署名并保留原文链接。**

**联系邮箱：huyanshi2580@gmail.com**

**更多学习笔记见个人博客------><a href="{{ site.baseurl }}/">呼延十</a>**
