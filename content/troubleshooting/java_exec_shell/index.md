---
title: Java执行shell避坑指南
date: 2018-07-16
categories: ["troubleshooting"]

---

后端一些任务场景中经常需要去执行shell,使用可能踩坑.

<!--more-->


假设在Java任务中有一个脚本需要执行,创建2个文件夹并在中间输出一些日志.
```
mkdir d:\testdir_start
for /l %%i in (1,1,10000) do echo 6666666666666666666666666666666666666;
mkdir d:\testdir_end
```

如果执行代码如下,程序是不会结束的.只会创建第一个文件夹.process.waitFor()一直并没有返回

```
Process process = Runtime.getRuntime().exec("d:/test.bat");
int existCode = process.waitFor();
System.out.println("existCode "+existCode);
System.out.println("done ");
```

查询一下类注释有一段关于输入输出流相关的内容.

> By default, the created subprocess does not have its own terminal or console. All its standard I/O (i.e. stdin, stdout, stderr) operations will be redirected to the parent process, where they can be accessed via the streams obtained using the methods getOutputStream(), getInputStream(), and getErrorStream(). The parent process uses these streams to feed input to and get output from the subprocess. Because some native platforms only provide limited buffer size for standard input and output streams, failure to promptly write the input stream or read the output stream of the subprocess may cause the subprocess to block, or even deadlock.


大意是,执行脚本的子线程输入和输出均通过主线程.可以从Process的输入输出流中拿到.但是一些操作系统只提供了比较小的标准输入输出缓冲区,缓冲区满的话则会造成子线程阻塞或者死锁.而我们执行的脚本里面有一段输出日志的内容.而父线程没有去清除其中的内容,所以执行脚本的子线程就被阻塞了.

```
public static void execCommand(String command, int waitSeconds) {
	LOGGER.info("start exec Command {}.", command);
	Process currentProcess = null;
	try {
		final Process process = Runtime.getRuntime().exec(command);
		currentProcess = process;
		
		Future<Integer> processFuture = ES.submit(new Callable<Integer>() {
			@Override
			public Integer call() throws Exception {
				BufferedReader stdInput = new BufferedReader(new InputStreamReader(process.getInputStream()));
				BufferedReader errInput = new BufferedReader(new InputStreamReader(process.getErrorStream()));

				String s = null;
				while ((s = stdInput.readLine()) != null) {
					LOGGER.info(s);
				}
				while ((s = errInput.readLine()) != null) {
					LOGGER.info(s);
				}

				return process.waitFor();
			}
		});
		
		int existCode = processFuture.get(waitSeconds, TimeUnit.SECONDS);
		currentProcess = null;
		LOGGER.info("execCommand {} exit code {}", command, existCode);
	} catch (Exception ex) {
		LOGGER.error("execCommand {} error", command, ex);
	} finally {
		if (null == currentProcess) {
			return;
		}
		
		currentProcess.destroy();
	}
}
```
上面是一个避坑工具类.不过这jdk8已经做了改进 waitFor可设置等待的时间,但是并不保证子线程不会因为缓冲区的问题而阻塞.