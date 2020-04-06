---
title: 后端大量数据导出场景的处理
date: 2020-04-04
categories: ["design"]
---

统计类报表除了提供界面查询还提供导出的功能，一般量也不是很大，不容易遇到瓶颈。日志明细类的，比如一个全民APP的下载数据，可能一天的量就是百万级别的。在这种场景下，如果客户需要导出这类数据的明细那么就会遇到一些挑战。<!--more-->

客户导出明细数据，需要在界面进行操作。这时候很多后端开发由于比较熟悉 MySQL，自然而然是经过处理的数据推送到MySQL，然后通过服务查询继而通过服务端的输出流写出到HTTP Response，这里面有几个坑点。

- **多次进行总数的计算**

一次性查询不是很现实，因为后端数据库连接池如果长时间被占用，多来几个这种查询，那么连接池一下子就到达了上限。所以必然也是使用分页，而很多分页插件默认使用count功能。每次查询一页的数据，进行一次总数的计算。这时候数据总量是比较大，自然每次查询的耗时会比较长。进而直接影响到整体的时间。

```
Paginator paginator = new Paginator(offset,limit);
paginator.setContainTotal(true);
long total = 0
do{
	// set  parrameter 
	pagination = svc.queryData(param,paginator);
	if( total == 0){
		total = pagination.getTotal();
		// 第一次执行后，直接把是否查询总数的参数设置为否
		paginator.setContainTotal(false);
	} 
	
	offset+= limit;
	
	//其他逻辑
}while(offset <= total)
```

使用上述的代码结构进行处理，在第一次查询完总数以后存储中临时变量中，无需每次进行总数的查询。

- **OFFSET过大影响性能**

同样是上述的代码结构 ，随着offset的增加。性能会变的越来越差。这时候可以使用查询条件来优化一下，然而需要数据格式和表结构符合一定的要求。

```
select * from table_name where( user = xxx ) limit 10000,10

select * from table_name inner join ( select id from table_name where (user = xxx) limit 10000,10) b using (id)
```

如上语句 ，第一个语句没有任何优化，上来就直接捞数据。第二个语句进行了优化**用子查询先查询出索引列**的内容，然后再去进行**关联**，查出索引列所对应的数据内容。

- **流式导出**

经常还是会看到如下错误写法

```
List<..> data = new ArrayList();
Paginator paginator = new Paginator(offset,limit);
paginator.setContainTotal(true);
long total = 0
do{
	// set  parrameter 
	pagination = svc.queryData(param,paginator);
	if( total == 0){
		total = pagination.getTotal();
		// 第一次执行后，直接把是否查询总数的参数设置为否
		paginator.setContainTotal(false);
	} 
	// 内存中保存数据
	data.addAll(pagenation.getData());
	
	offset+= limit;
	
	//其他逻辑
}while(offset <= total);

// 一次性写入
this.writeExcel(data)
```

因为一些错误封装的原因， 导致了所有数据都先存储在内存，然后一次性写入Excel格式的流。数据量较小的时候没什么问题。数据量一大，**内存瓶颈**和**HTTP超时**都会突显出来。直接导致数据导出的功能不可用。

这个时候需要改造为流式导出 。每查询完一次数据则进行一次输出流的写入。这样每次查询的数据用完即可回收，且HTTP会开始数据传输，而不是一直停留在等待服务器响应的阶段最后直到超时。用户也能看到浏览器是在工作的。

以Excel来说，Apache POI 提供了几种API ，大部分时候我们使用的是XSSF的usermodel模式。从图中可以看出它的实现就是DOM的方式。自然也是整个文件都是要全部load到内存中才能处理。

![](ss-features.png)

SXSSF是一种流式的方式，不支持读，但是支持写，跟这里的场景比较契合。如果觉得Apache POI的流式API比较不好用，而且存在读写不统一的问题。那么可以尝试alibaba开源的easyexcel。

#### 异步化

即使优化了上面所有的坑，交互时间比较长的问题是无法避免的。而且在一个事务型的系统里面做大批量的数据导出并不可取。在产品交互上做一个优化，采用异步化导出的方式能够直接避免上述的问题。

首先，用户在系统里面提交一个提取数据的任务，然后就可以去做其他事情，等任务执行结束以后，便可以多次进行文件的下载。这是一个产品交互的优化点，长时间的等待会让用户对系统的能力产生一种不信任感。

其次，不再需要实时响应以后，即可使用离线的方式。比如这种明细数据存储都是在HDFS，可以直接使用MR任务或者DataX等组件组件进行导出。