---
title: TiDB和Splice Machine的初步对比
date: 2019-07-16 14:37:28
author: Francis
tags:
  - Database
  - PPT
---

[Splice Machine](https://github.com/splicemachine/spliceengine) 和 
[TiDB](https://github.com/pingcap/tidb) 都是优秀的开源 HTAP 数据库，
一个针对大数据技术栈更加友好，完全不脱离大数据组件，比如 Hadoop/HBase/Spark 。
另一个脱离了大数据技术栈，走自主研发(TiKV)。相比 TiDB 而言，Splice Machine 
具有更加完整的关系型数据库功能。奈何 Splice Machine 在国内的用户比较少，
导致了其知名度不如 TiDB 。TiDB 在国内拥有活跃的社区，版本更新迭代相当的快，
目前 TiDB 的客户主要在互联网行业，其中银行、金融行业的超大型客户比较少，
因此其稳定性需要时间来验证。Splice Machine 在国外已经有很大规模的应用场景了，
比如国外知名的信用卡商 Visa 等超大型用户。两款产品各有优缺点，因此我们不做评价，
用户总会选择适合自己的来用。目前在 HTAP 领域也有其他的产品，我个人也有试用过一些，
以后会整理出来进行分享。目前仅对这两款产品做一个简单的分析，仅供参考。

{{< zohoshow f9a26dec6f5c59a70462a95a19bc9ab75f343 >}}