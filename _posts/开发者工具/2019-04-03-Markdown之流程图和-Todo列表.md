---
layout: post
category: [开发者手册,开发者工具,效率编程]
tags:
  - 开发者手册
  - 开发者工具
---

## 背景介绍
顺手记录一下Markdown的两个小操作.

## Todo列表

我日常有一个记录`已做`和`待做`的表格,每次手动标记完成还是有点烦的.偶然间看到这个操作记录一下.

- [x] 已经完成
- [ ] 未完成的

写法如下:

```markdown
- [x] 已经完成
- [ ] 未完成的
```

支持层级列表,并且可以点击取消和点击完成哦.

同时,由于markdown的各种解释器的不兼容的原因,经我实际测试,这个语法在`Jekyll`博客系统,也就是`kramdown`解释器下以及在有道云比较的解释器下都是可以正常工作的.

## 流程图

实现效果如下:

<div class="mermaid">
graph LR;
A[aa bb]-->B(wo);
A-->C((我是C));
B-->D>我是D];
C-->D;
D-->E{我是E};
C-->E;
2-->E;
_-->E;
</div>

在有道云笔记中的写法:

```markdown
_```
graph LR;
A[aa bb]-->B(wo);
A-->C((我是C));
B-->D>我是D];
C-->D;
D-->E{我是E};
C-->E;
2-->E;
-->E;
_```
```

没有前面的下划线,是我为了不让markdown解释加的.

在Jekyll中的写法:

```html
<div class="mermaid">
graph LR;
A[aa bb]-->B(wo);
A-->C((我是C));
B-->D>我是D];
C-->D;
D-->E{我是E};
C-->E;
2-->E;
_-->E;
</div>
```

同时,需要在自己使用到的页面中加入以下语句,用来引入相关的js文件:

```html
<script src="https://unpkg.com/mermaid@8.0.0/dist/mermaid.min.js"></script>
<script>mermaid.initialize({startOnLoad:true});</script>
```

天知道我为了让有道云笔记和Jekyll支持同一种语法(让我不必要去学两种语法,来完成同一件事情),付出了多少时间.

最后的结果如上面的效果图所示,完成了流程图的功能,但是有点丑陋.我不想搞了,太耽误时间了,我用的不是很多,先这样子吧.


## 一些常用的markdown语法记录

语法 | 作用 | 备注
--- | --- | ---
`> + 内容` | 引用内容 | 
`==x==` | 标记内容 | ==哈==
`~~x~~` | 删除线 | ~~哈~~

<br>
<br>
<br>
<h4>ChangeLog</h4>
2019-04-03      完成
<br>
<br>


**以上皆为个人所思所得，如有错误欢迎评论区指正。**

**欢迎转载，烦请署名并保留原文链接。**

**联系邮箱：huyanshi2580@gmail.com**

**更多学习笔记见个人博客------><a href="{{ site.baseurl }}/">呼延十</a>**
