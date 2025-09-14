---
title: "Wiki Graph"
date: 2021-01-16T04:40:36+08:00
url: /blog/wiki-graph/
description: "Wikipida Graph"
tag:
- Rust
- Wikipedia
images: []
---

项目以 MIT LICENSE 托管在 GitHub[1]，
Web 服务[2]使用 Heroku 部署， 在线文档[3]使用 GitHub Pages 服务托管。
该项目源于一次远程面试，以下内容摘自面试邮件。 [详情](https://gist.github.com/defclass/8c4f6da71629d861f9a554ad7580c1ef)

![img](https://wiki-graph.francis.run/images/index.png)

### 面试题：

>在你提供的 web app 上（请确保可以正常访问），用户搜索某个主题，比如 Knowledge base，
>可以显示 Wikipedia 上相关的页面以及页面之间的关系。具体展示和交互形式不限，语言和技术栈也不限。

- 实现思路：
1. 首先使用 Wikipedia 的 API 获取搜索结果，但是后来发现如果是中文或者其他语言返回的结果任然是英文，
   后来发现默认请求是的英文版的 API。
2. 然后通过自然语言的库先处理搜索关键字，将关键字解析为不同语言的缩写，例如:‘en’,'zh'等，然后去不同语言的 
   Wikipedia搜索，这样返回的结果就是对应搜索关键字的语言。目前支持英文、中文、西班牙语、意大利语和法语。
3. 然后将搜索结果进行处理，生成一棵树，以搜索关键字为父节点，然后遍历所有搜索结果作为子节点，同时获取相对应的内容摘要，
   目前默认取 Top 10，然后将这十个页面所有的链接的标题作为每个子节点的子节点，由于有的页面关键字很多，
   会导致可视化展示的时候渲染页面非常慢，目前每个页面之取了20个。
5. 由于 Wikipedia 查询会有限制，目前没有通过子链接来递归查询子链接的页面。
6. 最后将生成的树结构以 Json 返回，提供查询参数，供前端页面查询。
7. 前端页面中当用户输入查询关键字并点击 Search 按钮或者回车的时候，会请求 Web Service 返回的树结构数据，然后用 
   Amcharts 将数据渲染成一个 Graph。

![](https://wiki-graph.francis.run/images/graph.png)
 
### 回答问题：

>请谈一谈你为什么对 Logseq 感兴趣，以及你对知识管理或其它笔记软件的理解。

1. 首先我觉得 Logseq 的招聘方式非常棒，这种社区招聘我第一次见，这让我为之兴奋，
   可以激发我的兴趣，让我花两天的时间来完整的解决一个问题，从设想到实现，从实现到用作品应聘。 
2.对于知识管理软件，市面上已经有了很多工具了，旧的总是瞧不上新的，经常会有新的工具被开发，有多人协作的，
   最早的比如印象笔记，Notion 之类，个人的比如 Effie 等。我个人也是在不断的试用更好的更适合我的工具。
   当我试用了 Logseq 之后，我就觉得是我想要的。Logseq 离社区非常近，近的就隔着一个 GitHub Oauth，
   在线写文档和自动 Commit 记录到 GitHub，这非常适合一个经常活跃在开源社区但是不是开发者的群体-技术作者，或者开源社区运营。
3. 因为我身边有很多 Technical Writer 和社区运营，他们的烦恼就是使用 Git 来提交文档，大多数都使用 GUI 来做，
   做的久一点的 Git 命令行才会。这块我觉得 Logseq 降低了这类人群的使用难度，将会非常受这类人群的欢迎。
   
[1].[源码地址: https://github.com/francis-du/wiki-graph](https://github.com/francis-du/wiki-graph)

[2].[在线体验地址：https://wiki-graphs.herokuapp.com](https://wiki-graphs.herokuapp.com) 

[3].[在线文档地址：https://wiki-graph.francis.run](https://wiki-graph.francis.run)