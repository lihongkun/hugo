---
title: Java虚拟机监控工具 - jps和jstat
date: 2018-05-28
categories: ["jvm"]
---

简单介绍下两个JVM监控工具 , jps 和 jstat

<!--more-->

### jps

查找当前用户的Java进程,通常当你不知道服务器上有哪些java进行的时候,直接输入jps或者带命令选项,就能直接查询出来了.

```
-l：输出完全的包名,应用主类名,jar的完全路径名； 
-v：输出jvm参数
```

JVM启动的时候都是使用jdk来启动,使用系统命令如ps -ef|grep java,这种场景下使用jps确实是鸡肋.但是很多情况下,启动的进程比较多,不会直接使用jdk来启动,而是创建一些比较有语义性的软链,使用这个有语义的软链来启动应用.


```
${JAVA_HOME}/java xxx.jar

// 变为软链启动


ln -s ${JAVA_HOME}/java my_process_name

./my_process_name xxx.jar

```
例如上面的方式,使用系统的命令ps -ef|grep java 是查找不出java进行的,此时jps能够准确找到.

### jstat

全称是Java Virtual Machine Statistics Monitoring Tool,通常使用他来查看类加载和卸载情况JVM各个分代的容量已经使用容量,GC原因和时间.


```
Usage: jstat -help|-options
       jstat -<option> [-t] [-h<lines>] <vmid> [<interval> [<count>]]
       
// 使用方式

jstat -gcutil 25477 1000 500

```
jstat -help 可以看到看到命令行的使用方式.上面示例gcutil 就是options,即要使用的功能;25477是进程号,也就是vmid;1000是频率,即1000,每1000ms输出一次监控结果;500为执行次数,即count

这个选项比较多

#### class

类加载情况的统计

```
jstat -class 2600

Loaded  Bytes  Unloaded  Bytes     Time
   400   830.9        0     0.0       0.11
```
- Loaded 加载的类数量.
- Bytes 加载类所耗费的空间,单位KB.
- Unloaded 卸载的类数控.
- Bytes 卸载类释放的空间,单位KB
- Time 加载和卸载所花的时间.

#### compiler

即时编译器编译情况的统计

```
jstat -compiler  2600

Compiled Failed Invalid   Time   FailedType FailedMethod
      19      0       0     0.01          0
```

- Compiled	编译执行次数
- Failed 编译任务失败词素
- Invalid 无效编译任务次数
- Time 编译任务花费的时间
- FailedType 最后一次编译失败的编译类型
- FailedMethod 最后一次编译失败的类名及方法名

#### gc


JVM中堆的垃圾收集情况的统计,主要是当前的容量和GC的情况
```
S0C    S1C    S0U    S1U      EC       EU        OC         OU       MC     MU    CCSC   CCSU   YGC     YGCT    FGC    FGCT     GCT
5120.0 5120.0  0.0    0.0   33280.0   5325.4   87552.0      0.0     4480.0 776.9  384.0   75.8       0    0.000   0      0.000    0.000
```

- S0C 新生代中Survivor space中S0当前容量的大小（KB）
- S1C 新生代中Survivor space中S1当前容量的大小（KB）
- S0U 新生代中Survivor space中S0容量使用的大小（KB）
- S1U 新生代中Survivor space中S1容量使用的大小（KB）
- EC Eden space当前容量的大小（KB）
- EU Eden space容量使用的大小（KB）
- OC Old space当前容量的大小（KB）
- OU Old space使用容量的大小（KB）
- PC Permanent space当前容量的大小（KB）
- PU Permanent space使用容量的大小（KB）
- YGC 从应用程序启动到采样时发生 Young GC 的次数
- YGCT 从应用程序启动到采样时 Young GC 所用的时间(秒)
- FGC 从应用程序启动到采样时发生 Full GC 的次数
- FGCT 从应用程序启动到采样时 Full GC 所用的时间(秒)
- GCT 从应用程序启动到采样时用于垃圾回收的总时间(单位秒)，它的值等于YGC+FGC


#### gccause


```
jstat -gccause 8524 1000 1000
  S0     S1     E      O      M     CCS    YGC     YGCT    FGC    FGCT     GCT    LGCC                 GCC              
  0.00   0.00  22.00   0.62  53.34  53.68    392    0.134     0    0.000    0.134 Allocation Failure   No GC            
  0.00   0.00   0.00   0.62  53.34  53.68    418    0.142     0    0.000    0.142 Allocation Failure   No GC 
```

- LGCC 最后一次垃圾收集原因,上述示例为分配失败
- GCC 当前垃圾收集原因

#### gc其他

其他的gc options 还包括  gccapacity , gccause ,gcnew ,gcnewcapacity ,gcold ,gcoldcapacity,gcpermcapacity ,gcutil 基本上都是gc的分代情况和耗费时间,具体不赘述可以查看手册


https://docs.oracle.com/javase/7/docs/technotes/tools/share/jstat.html