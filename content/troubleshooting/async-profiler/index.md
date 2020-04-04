---
title: async-profiler查找CPU热点
date: 2019-08-10
categories: ["troubleshooting"]
---

算法新上线的接口，平均耗时增加了20ms。使用jstack一类的脚本出来的堆栈基本上比较平均。很难定位到确切的位置。这种微小耗时监测场景。典型的方式是直接进行CPU热点采样，通常是linux的perf加上perf-map-agent来映射出java的堆栈。这个组合略复杂。我使用的是 async-profiler 。

<!--more-->

```
wegt https://github.com/jvm-profiling-tools/async-profiler/releases/download/v1.5/async-profiler-1.5-linux-x64.tar.gz
```

直接下载到服务器然后进行解压。找出要采样的进程号。

```
sh profiler.sh -d 5 -e cpu 130822 > /tmp/130822.cpu.trace
```

执行上述脚本， 得到一个cpu采样的文件。

```
tarted [cpu] profiling
--- Execution profile ---
Total samples:         468
Non-Java:              3 (0.64%)

Frame buffer usage:    0.321%

--- 680387991 ns (14.53%), 68 samples
  [ 0] java.nio.HeapByteBuffer._get
  [ 1] java.nio.Bits.getIntB
  [ 2] java.nio.Bits.getFloatB
  [ 3] java.nio.Bits.getFloat
  [ 4] java.nio.HeapByteBuffer.getFloat
  [ 5] com.mayabot.blas.MutableByteBufferVector.plusAssign
  [ 6] com.mayabot.mynlp.fasttext.FastText.addInputVector
  [ 7] com.mayabot.mynlp.fasttext.FastText.getWordVector
  [ 8] com.mayabot.mynlp.fasttext.FastText.getWordVector
  [ 9] (project package).search.rank.CandidateSelect.selectAdvanceRankCandidatesFromRtAd
  [10] (project package).search.rank.CandidateSelect.candidateSelect
  [11] (project package).search.rank.SearchRanking.candidateSelect
  [12] (project package).search.recall.SearchRecallHelper.adRecallWork
  [13] (project package).search.recall.SearchRecallHelper.adRecall
  [14] (project package).search.service.SearchRecallSvcImpl.adRecall
  ....
  [44] java.lang.Thread.run

--- 490290559 ns (10.47%), 49 samples
  [ 0] java.util.Arrays.copyOf
  [ 1] java.lang.AbstractStringBuilder.expandCapacity
  [ 2] java.lang.AbstractStringBuilder.ensureCapacityInternal
  [ 3] java.lang.AbstractStringBuilder.append
  [ 4] java.lang.StringBuilder.append
  [ 5] (project package).search.rank.CandidateSelect.selectAdvanceRankCandidatesFromRtAd
  [ 6] (project package).search.rank.CandidateSelect.candidateSelect
  [ 7] (project package).search.rank.SearchRanking.candidateSelect
  [ 8] (project package).search.recall.SearchRecallHelper.adRecallWork
  [ 9] (project package).search.recall.SearchRecallHelper.adRecall
  [10] (project package).search.service.SearchRecallSvcImpl.adRecall
  ....
  [44] java.lang.Thread.run
  
  ....
  //中间省略
  
            ns  percent  samples  top
  ----------  -------  -------  ---
  1220574844   26.07%      122  jshort_disjoint_arraycopy
  1170635197   25.00%      117  java.nio.HeapByteBuffer._get
   490290559   10.47%       49  java.util.Arrays.copyOf
   490237824   10.47%       49  (project package).search.rank.CandidateSelect.selectAdvanceRankCandidatesFromRtAd
```

文件内容头部如上所述，CPU热点主要集中在selectAdvanceRankCandidatesFromRtAd 方法，其中最高的是jshort_disjoint_arraycopy的使用，引起它的主要是StringBuilder.append后需要扩容字符数组导致的array copy。于是找到对应的代码，果不其然，发现在未开启debug级别日志的情况下有很多debug相关的字符串拼接动作。修改后重新采样结果如下，问题解决。

```
          ns  percent  samples  top
  ----------  -------  -------  ---
  1573048239   12.74%      157  Monitor::TrySpin(Thread*)
  1251599098   10.14%      125  [unknown]
  1222266324    9.90%      122  OtherRegionsTable::add_reference(void*, int)
   830435668    6.73%       83  java.nio.HeapByteBuffer._get
   590272841    4.78%       59  HeapRegionRemSetIterator::fine_has_next(unsigned long&)
   430869401    3.49%       43  Monitor::ILock(Thread*)
   410395759    3.32%       41  G1BlockOffsetArrayContigSpace::block_start_unsafe(void const*)
   409558334    3.32%       41  GenericTaskQueueSet<OverflowTaskQueue<StarTask, (MemoryType)5, 131072u>, (MemoryType)5>::steal_best_of_2(unsigned int, int*, StarTask&)
   390784596    3.17%       39  Monitor::unlock()
   360671281    2.92%       36  G1RemSet::refine_card(signed char*, unsigned int, bool)
   360092908    2.92%       36  G1ParScanThreadState::trim_queue()
   310183234    2.51%       31  FilterIntoCSClosure::do_oop(oopDesc**)
   300118751    2.43%       30  G1ParScanThreadState::copy_to_survivor_space(oopDesc*)
   280537975    2.27%       28  SpinPause
```

#### 其它用途

async-profiler还有很多其他的用处，对于性能要求比较高的应用可以使用它来进行分析。

> - CPU cycles
> - Hardware and Software performance counters like cache misses, branch misses, page faults, context switches etc.
> - Allocations in Java Heap
> - Contented lock attempts, including both Java object monitors and ReentrantLocks

本文只是简单介绍了CPU热点的查看，它监测cache miss，堆分配事件，锁事件等功能，并生成火焰图。后续再通过真实的操作案例来分享。



参考

https://github.com/jvm-profiling-tools/async-profiler



