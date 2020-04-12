---
title: 微基准测试框架JMH
date: 2020-04-12
categories: ["common","java"]
---

JMH（Java Microbenchmark Harness），是一个针对Java或者JVM上语言的基准测试工具。它可以比较轻松地创建基准测试。<!--more-->

最典型的场景就是你想知道两个功能相同的操作到底哪个性能比较好，通常会自己手撸一段代码，前后增加时间，然后对比多次执行的时间。这种做法比较原始，还要自己处理预热等问题。JMH提供了比较丰富的操作。且看如何使用。

#### 使用示例

这个工具是中JDK9 加入的，但是也可以直接使用Maven添加对应的依赖。

```
<dependency>
    <groupId>org.openjdk.jmh</groupId>
    <artifactId>jmh-core</artifactId>
    <version>${jmh.version}</version>
</dependency>
<dependency>
    <groupId>org.openjdk.jmh</groupId>
    <artifactId>jmh-generator-annprocess</artifactId>
    <version>${jmh.version}</version>
    <scope>provided</scope>
</dependency>
```

依赖添加完成以后即可编写性能测试程序

```
@BenchmarkMode(Mode.Throughput)
@OutputTimeUnit(TimeUnit.MICROSECONDS)
@State(Scope.Benchmark)
public class JmhApplication {

    public static void main(String[] args) throws RunnerException {
        Options opt = new OptionsBuilder()
                .include(JmhApplication.class.getSimpleName())
                .forks(1)
                .warmupIterations(2)
                .measurementIterations(5)
                .build();

        new Runner(opt).run();
    }

    @Benchmark
    public void stringAdd(){
        String a = "";
        for (int i = 0; i < 10; i++) {
            a += i;
        }
    }

    @Benchmark
    public void stringBuilderAdd(){
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < 10; i++) {
            sb.append(i);
        }
    }
}
```

如上述代码只需要在要进行基准测试的方法上增加Benchmark注解，即可进行基准测试。而类上的注解直接定义了基准测试的一些全局设置，如测试类型，时间单位等。

main方法里面使用Options类定义的预热运行测试方法的次数，以及运行基准测试运行方法的次数。接着构建Runner类运行基准测试。

```
// .... 省略其他输出
# Run progress: 50.00% complete, ETA 00:01:11
# Fork: 1 of 1
# Warmup Iteration   1: 23.463 ops/us
# Warmup Iteration   2: 19.687 ops/us
Iteration   1: 18.304 ops/us
Iteration   2: 20.687 ops/us
Iteration   3: 20.641 ops/us
Iteration   4: 20.194 ops/us
Iteration   5: 20.112 ops/us
// .... 省略其他输出
Benchmark                         Mode  Cnt   Score   Error   Units
JmhApplication.stringAdd         thrpt    5   5.711 ± 1.784  ops/us
JmhApplication.stringBuilderAdd  thrpt    5  19.988 ± 3.757  ops/us
```

结果如上，可以看出进行了2次的预热，执行5次迭代，来计算结果。最终输出了Benchmark的结果。关注点是Score和对应的单位Units，表示每个时间单位执行的操作次数。即第一个方法每微秒执行5.711 ± 1.784次，第二个方法是每微秒执行19.988 ± 3.757 次。

#### 基准测试类型

基准测试类型，由注解Benchmark来指定，主要由五种选型，实际是4中模式。

**Throughput** 整体吞吐量，结果是单位时间的执行次数。

```
Benchmark                         Mode  Cnt   Score   Error   Units
JmhApplication.stringAdd         thrpt    5   5.711 ± 1.784  ops/us
JmhApplication.stringBuilderAdd  thrpt    5  19.988 ± 3.757  ops/us
```

**AverageTime**  调用的平均时间，结果是执行一次所需要的时间。

```
Benchmark                        Mode  Cnt  Score   Error  Units
JmhApplication.stringAdd         avgt    5  0.150 ± 0.002  us/op
JmhApplication.stringBuilderAdd  avgt    5  0.049 ± 0.005  us/op
```

**SampleTime**  随机取样，最后输出取样结果的分布

```
Benchmark                                  Mode      Cnt     Score   Error  Units
stringAdd                                  sample  1264158     0.202 ± 0.019  us/op
stringAdd:stringAdd·p0.00                  sample              0.100          us/op
stringAdd:stringAdd·p0.50                  sample              0.200          us/op
stringAdd:stringAdd·p0.90                  sample              0.200          us/op
stringAdd:stringAdd·p0.95                  sample              0.200          us/op
stringAdd:stringAdd·p0.99                  sample              0.300          us/op
stringAdd:stringAdd·p0.999                 sample              2.200          us/op
stringAdd:stringAdd·p0.9999                sample             31.907          us/op
stringAdd:stringAdd·p1.00                  sample           3895.296          us/op
stringBuilderAdd                           sample  1968851     0.082 ± 0.008  us/op
stringBuilderAdd:stringBuilderAdd·p0.00    sample                ≈ 0          us/op
stringBuilderAdd:stringBuilderAdd·p0.50    sample              0.100          us/op
stringBuilderAdd:stringBuilderAdd·p0.90    sample              0.100          us/op
stringBuilderAdd:stringBuilderAdd·p0.95    sample              0.100          us/op
stringBuilderAdd:stringBuilderAdd·p0.99    sample              0.100          us/op
stringBuilderAdd:stringBuilderAdd·p0.999   sample              0.300          us/op
stringBuilderAdd:stringBuilderAdd·p0.9999  sample             10.896          us/op
stringBuilderAdd:stringBuilderAdd·p1.00    sample           3563.520          us/op
```

**SingleShotTime**  以上模式都是默认一次 iteration 是 1秒，唯有 SingleShotTime 是只运行一次。往往同时把 warmup 次数设为0，用于测试冷启动时的性能。

```
// 预热修改为0，执行的次数修改为1
Options opt = new OptionsBuilder()
                .include(JmhApplication.class.getSimpleName())
                .forks(1)
                .warmupIterations(0)
                .measurementIterations(1)
                .build();
// 结果如下
Benchmark                        Mode  Cnt      Score   Error  Units
JmhApplication.stringAdd           ss       32612.100          us/op
JmhApplication.stringBuilderAdd    ss          18.500          us/op
```

**All** 运行全部以上的基准测试模式

其中最常用的是Throughput和AverageTime模式，其他的在正常场景基本上可以略过。

#### 后续

工具使用起来比较方便，功能也是挺多，此处不逐个介绍。一个很大的缺点是文档比较少，官方有完整的[示例代码](https://hg.openjdk.java.net/code-tools/jmh/file/tip/jmh-samples/src/main/java/org/openjdk/jmh/samples/)，可以直接阅读和执行来学习如何使用 。