---
title: 前端页面内容监控
date: 2018-07-04
categories: ["design"]
---

最近有个事件抖音在搜狗的搜索引擎上面投放了侮辱先烈的广告，导致公司被相关部门约谈,还涉及了多家广告代理商。他们纷纷表示完善广告审查机制,将广告审查纳入总编辑负责制；切实落实公共信息巡查，应急处置等网络安全主体责任制度。

一般这种投放广告是推广一个落地页链接,广告主可以自己做这个页面,然后创建广告的时候落地链接填入到广告中。广告平台对其进行审核。到这个步骤是没有问题的，只要平台方严格执行。但是总是有那么一些状况。比如广告主在审核通过后对页面进行了修改没有重新提交审核。猪队友总是有的。求生欲望强一些总要做点什么来监控这种情况。

<!--more-->

### 页面监控

那么我如何进行页面监控呢？

常规方案是抓包，分析HTTP包体，做文本差异性分析。但是这个方案要处理各种跳转，JavaScript执行，还要应对图片的更换，单独下载下来进行差异对比。极其复杂。

浏览器上都是自然不过的事情，而爬虫的工作量巨大。那么换个思路。是不是有一个程序可以使用的浏览器呢。在自动化测试领域是见过类似原理的，于是找到了PhantomJS这个无界面浏览器。能够直接把一整个网页的最终显示截图并保存下来。

### 如何使用

```
// hello.js
var page = require('webpage').create();
page.open('http://www.google.com', function() {
    setTimeout(function() {
        page.render('google.png');
        phantom.exit();
    }, 200);
});
```

机器安装了相关的包以后就可以使用 phantomjs hello.js来启动，这会进行一个截图，完全后台操作。除此之外就是伪装一下ua等其他HTTP报文头信息。

通常要监控的落地页链接是成千上万的。每次都是使用phantomjs xxx.js这样的shell命令来执行页面访问截图。都是新启动一个进程，幸运的是它有webserver模块。可以先启动phantomjs作为一个http server。监控程序来调用此服务进行截图的保存。性能瞬间提升好几倍。


```
"use strict";
var page = require('webpage').create();
var server = require('webserver').create();
var system = require('system');
var host, port;

if (system.args.length !== 2) {
    console.log('Usage: server.js <some port>');
    phantom.exit(1);
} else {
    port = system.args[1];
    var listening = server.listen(port, function (request, response) {
        console.log("GOT HTTP REQUEST");
        console.log(JSON.stringify(request, null, 4));

        // we set the headers here
        response.statusCode = 200;
        response.headers = {"Cache": "no-cache", "Content-Type": "text/html"};
        response.close();
    });
    if (!listening) {
        console.log("could not create web server listening on port " + port);
        phantom.exit();
    }
}
```
如上面代码，启动了一个http server，请求了便返回一个空白页面，直接添加一下访问页面并截图的逻辑就好了。服务器端js基本上都是单线程的，如果一个http server的吞吐量不够可以尝试启用多个服务。

落地页面的截图已经有了，监控它是否篡改了就需要比对实时的截图是否与审核的时候是否是一致的。如下两张图片如何从计算机角度来判断它们是否是一致的。

![image](demo_img_01.jpg)

![image](demo_img_02.jpg)

### 图片指纹

在图片搜索领域一直流传着一种算法叫“感知哈希算法”(Perceptual Hash Algorithm)。为图片生成一个指纹(字符串格式), 两张图片的指纹越相似, 说明两张图片就越相似。操作分6个步骤。

1. 缩小图片尺寸  
  将图片缩小到8x8的尺寸, 总共64个像素. 这一步的作用是去除各种图片尺寸和图片比例的差异, 只保留结构、明暗等基本信息.  

2. 转为灰度图片  
  将缩小后的图片, 转为64级灰度图片.  

3. 计算灰度平均值  
  计算图片中所有像素的灰度平均值  

4. 比较像素的灰度  
  将每个像素的灰度与平均值进行比较, 如果大于或等于平均值记为1, 小于平均值记为0.  

5. 计算哈希值  
  将上一步的比较结果, 组合在一起, 就构成了一个64位的二进制整数, 这就是这张图片的指纹.  

6. 对比图片指纹  
  得到图片的指纹后, 就可以对比不同的图片的指纹, 计算出64位中有多少位是不一样的. 如果不相同的数据位数不超过5, 就说明两张图片很相似, 如果大于10, 说明它们是两张不同的图片



```
public class PerceptualHash {

	private static final int WIDTH = 8;
	private static final int HEIGHT = 8;
	
	public static void main(String[] args) throws Exception {
		BufferedImage img1 = ImageIO.read(new File("1.png"));
		BufferedImage img2 = ImageIO.read(new File("2.png"));
		
		String fingerPrint1 = fingerPrint(img1);
		String fingerPrint2 = fingerPrint(img2);
		
		System.out.println(fingerPrint1);
		System.out.println(fingerPrint2);
		System.out.println(hammingDistance(fingerPrint1, fingerPrint2));
		
	}
	
	public static int hammingDistance(String hashCode1, String hashCode2) {
        int difference = 0;
        int len = hashCode1.length();

        for (int i = 0; i < len; i++) {
            if (hashCode1.charAt(i) != hashCode2.charAt(i)) {
                difference++;
            }
        }
        return difference;
    }
	
	public static String fingerPrint(BufferedImage source){
		
		// 第一步，缩小尺寸。
		BufferedImage thumb = thumb(source, WIDTH, HEIGHT);
		
		// 第二步，简化色彩。
        int[] pixels = grayPixels(thumb);
        
        // 第三步，计算平均值。
        int avgPixel = average(pixels);
        
        // 第四步，比较像素的灰度。。
        int[] comps = new int[WIDTH * HEIGHT];
        for (int i = 0; i < comps.length; i++) {
            if (pixels[i] >= avgPixel) {
                comps[i] = 1;
            } else {
                comps[i] = 0;
            }
        }
        //第五部，计算哈希值。
        StringBuffer hashCode = new StringBuffer();
        for (int i = 0; i < comps.length; i += 4) {
            int result = comps[i] * (int) Math.pow(2, 3) + comps[i + 1] * (int) Math.pow(2, 2) + comps[i + 2] * (int) Math.pow(2, 1) + comps[i + 2];
            hashCode.append(Integer.toHexString(result));
        }
        
        return hashCode.toString();
	}
	
	private static BufferedImage thumb(BufferedImage source, int width, int height) {
		int type = source.getType();
		BufferedImage target = null;
		double sx = (double) width / source.getWidth();
		double sy = (double) height / source.getHeight();

		if (type == BufferedImage.TYPE_CUSTOM) {
			ColorModel cm = source.getColorModel();
			WritableRaster raster = cm.createCompatibleWritableRaster(width, height);
			boolean alphaPremultiplied = cm.isAlphaPremultiplied();
			target = new BufferedImage(cm, raster, alphaPremultiplied, null);
		} else
			target = new BufferedImage(width, height, type);
		
		Graphics2D g = target.createGraphics();
		g.setRenderingHint(RenderingHints.KEY_RENDERING, RenderingHints.VALUE_RENDER_QUALITY);
		g.drawRenderedImage(source, AffineTransform.getScaleInstance(sx, sy));
		g.dispose();
	
		return target;
	}

	private static int[] grayPixels(BufferedImage thumb){
		int[] pixels = new int[WIDTH * HEIGHT];
        for (int i = 0; i < WIDTH; i++) {
            for (int j = 0; j < HEIGHT; j++) {
                pixels[i * HEIGHT + j] = rgbToGray(thumb.getRGB(i, j));
            }
        }
        
        return pixels;
	}
	

	private static int rgbToGray(int pixels) {
        int _red = (pixels >> 16) & 0xFF;
        int _green = (pixels >> 8) & 0xFF;
        int _blue = (pixels) & 0xFF;
        return (int) (0.3 * _red + 0.59 * _green + 0.11 * _blue);
    }
    
    private static int average(int[] pixels) {
        float m = 0;
        for (int i = 0; i < pixels.length; ++i) {
            m += pixels[i];
        }
        m = m / pixels.length;
        return (int) m;
    }
}
```

第一张图和第二张图如上，计算出来的汉明距离是13

### 延伸使用

> PhantomJS is an optimal solution for:
>
> Page automation
> Access webpages and extract information using the standard DOM API, or with usual libraries like jQuery.
>
> Screen capture
> Programmatically capture web contents, including SVG and Canvas. Create web site screenshots with thumbnail preview.
>
> Headless website testing
> Run functional tests with frameworks such as Jasmine, QUnit, Mocha, WebDriver, etc.
>
> Network monitoring
> Monitor page loading and export as standard HAR files. Automate performance analysis using YSlow and Jenkins.

上面这段为官网原文