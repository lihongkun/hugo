---
title: Spring MVC 你必须关注点
date: 2020-07-19
categories: ["springframework"]
---

Spring MVC配置简单，特别是在SpringBoot出现后基本都是开箱即用。在实际项目中通常是需要单独去处理一些特殊的情况，比如统一的异常处理，校验器以及国际化。<!--more-->

### 基础使用

为了简化相关的配置和包的引入，例子基于SpringBoot。首先引入相关的依赖包。

```
<parent>
	<groupId>org.springframework.boot</groupId>
	<artifactId>spring-boot-starter-parent</artifactId>
	<version>2.3.1.RELEASE</version>
</parent>

<dependencies>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-web</artifactId>
    </dependency>
</dependencies>
```

然后可以直接创建Controller类，即可实现一个基于SpringMVC的HTTP服务

```
@RestController
public class ExampleController {

    @RequestMapping("/")
    String home() {
        return "Hello World!";
    }
}


@SpringBootApplication
public class Application {

    public static void main(String[] args) {
        SpringApplication.run(Application.class, args);
    }

}
```

`@RequestMapping` 表示当前方法所对应的 Contextpath

`@RestController` 表示当前类，为Controller类，并且每个方法的ViewResolver都是采用JSON的方式来渲染。

### 异常处理

Controller中发生了异常，该如何处理。直接抛出异常，这是一种不可取得行为，对前端不友好，而且也可能暴露服务端的一些细节，给网络攻击提供一些便利的信息。每个Controller的方法都使用try ... catch 包裹住，这样的话代码的冗余度非常的高。这很容易让人想到了面向切面编程，SpringMVC提供了一个`ControllerAdvice` 机制来处理这种情况。这个注解的意义是拦截所有你在里面定义的异常。

```
@ControllerAdvice
public class CustomErrorController {

	private static final Logger LOGGER = LoggerFactory.getLogger(CustomErrorController.class);

	@ExceptionHandler({ RuntimeException.class })
	@ResponseStatus(HttpStatus.OK)
	public @ResponseBody HttpResponse<Void> processException(RuntimeException ex) {
		LOGGER.error(this.getClass().getName(), ex);
		HttpResponse<Void> response = new HttpResponse<>();
		response.fail().setMsg(ex.getMessage());
		return response;
	}

	@ExceptionHandler({ Exception.class })
	@ResponseStatus(HttpStatus.OK)
	public @ResponseBody HttpResponse<Void> processException(Exception ex) {
		LOGGER.error(this.getClass().getName(), ex);
		HttpResponse<Void> response = new HttpResponse<>();
		response.fail().setMsg(ex.getMessage());
		return response;
	}

	@ExceptionHandler({ BindException.class })
	@ResponseStatus(HttpStatus.OK)
	public @ResponseBody HttpResponse<Void> processException(BindException ex) {

		LOGGER.error(this.getClass().getName(), ex.getMessage());

		HttpResponse<Void> response = new HttpResponse<>();
		response.fail();

		response.setMsg(getErrorMessage(ex));
		return response;
	}

}
```

如上述代码 `ExceptionHandler` 注解在某个方法上表示的是该方法处理该注解所标识的异常。这里面是统一对异常进行处理返回了自定义的HttpResponse对象。

通过ControllerAdvice能解决请求到达了Controller后的所有的异常，但是如果还未到达业务逻辑后所产生的异常同样是会直接抛到前端去，正好SpringMVC框架在处理路由的时候如果没有找到路由是会产生这样的异常。

```
/**
 * 未处理错误页面 
 * 
 * 由于Spring MVC 的 DispatchServlet.throwExceptionIfNoHandler 直接返回了 404错误
 *   
 * 404错误还没到Controller,无法被 ControllerAdvice捕获 
 * 需要单独的错误处理
 */
@RestController
public class NotFoundController implements ErrorController{

	private static final String PATH = "/error";
	
	public String getErrorPath() {
		return PATH;
	}
	
	@RequestMapping(PATH)
	public HttpResponse<Void> handler(HttpServletRequest request){
		HttpResponse<Void> response = new HttpResponse<>();
		
		Integer statusCode = (Integer) request.getAttribute("javax.servlet.error.status_code");
		if(Objects.equal(statusCode, org.apache.http.HttpStatus.SC_NOT_FOUND)){
			response.setCode(statusCode);
		}
		else{
			response.fail().setMsg("unknown error");
		}
		
		return response;
	}

}
```

上述代码定义了一个通用error处理的页面，当框架抛出异常，会转到 /error地址，我们对其进行了定制。

### 数据校验

web环境的输入比较复杂，后端需要对输入做好保底的业务正确性校验。Spring MVC 提供了两种方法来对用户的输入数据进行校验，一种是 Spring 自带的 Validation 校验框架，另一种是利用 JRS-303 验证框架进行验证。通常使用 JRS-303 ，代表性的框架为 Hibernate-Validator，它所包含的功能如下表。

| 注解 | 功能 |
| ---- | ---- |
|@Null|验证对象是否为null|
|@NotNull|验证对象是否不为null|
|@AssertTrue|验证Boolean对象是否为true|
|@AssertTrue|验证Boolean对象是否为false|
|@Max(value)|验证Number和String对象是否小于等于指定值|
|@Min(value)|验证Number和String对象是否大于等于指定值|
|@DecimalMax(value)|验证注解的元素值小于等于@DecimalMax指定的value值|
|@DecimalMin(value)|验证注解的元素值大于等于@DecimalMin指定的value值|
|@Digits(integer,fraction)|验证字符串是否符合指定格式的数字，integer指定整数精度，fraction指定小数精度|
|@Size(min,max)|验证对象长度是否在给定的范围内|
|@Past|验证Date和Calendar对象是否在当前时间之前|
|@Future|验证Date和Calendar对象是否在当前时间之后|
|@Pattern|验证String对象是否符合正则表达式的规则|
|@NotBlank|检查字符串是不是Null，被Trim的长度是否大于0，只对字符串，且会去掉前后空格|
|@URL|验证是否是合法的url|
|@Email|验证是否是合法的邮箱|
|@CreditCardNumber|验证是否是合法的信用卡号|
|@Length(min,max)|验证字符串的长度必须在指定范围内|
|@NotEmpty|检查元素是否为Null或Empty|

使用这些注解来标注接收参数的表单对象，然后在需要校验的时候使用`@Validated`注解进行标注

```
@Data
public class User {

    @NotBlank(message = "用户名不能为空")
    private String username;
    
	@NotBlank(message = "密码不能为空")
    @Length(min = 6, max = 16, message = "密码的长度必须在6~16位之间")
	private String password;
    
	@Range(min = 18, max = 60, message = "年龄必须在18岁到60岁之间")
    private Integer age;
    
	@Pattern(regexp = "^1[3|4|5|7|8][0-9]{9}$", message = "请输入正确格式的手机号")
    private String phone;
    
	@Email(message = "请输入合法的邮箱地址")
    private String email;
}

@RestController
public class UserController {

	@RequestMapping("/register")
    public HttpResponse register(@Validated User user) {
        // logic
    }
}
```

当然以上注解在实际项目中远远不够，有一些业务的校验本身就比较复杂。在参数解析的时候进行校验的话，还需要做很多更业务相关的逻辑，但是如果把校验逻辑放到Controller或者Service里面又显得很服务非常复杂，并且校验逻辑无法复用。SpringMVC支持我们进行校验器的自定义。

```
@Documented
@Constraint(validatedBy = UserValidaror.class)
@Target({ElementType.TYPE})
@Retention(RetentionPolicy.RUNTIME)
public @interface UserConstraint {

	String message() default "";
	
	Class<?>[] groups() default {};
	
	Class<? extends Payload>[] payload() default {};
	
}

@Conpement
public class UserValidaror implements ConstraintValidator<UserConstraint, User>  {
	
	public void initialize(UserConstraint constraintAnnotation) {
		
	}

	public boolean isValid(User value, ConstraintValidatorContext context) {
		// 比如校验邮箱或者电话的唯一性,或者其他需要通过服务调用
    }
}

@Data
@UserConstraint
public class User {

    @NotBlank(message = "用户名不能为空")
    private String username;
    
	@NotBlank(message = "密码不能为空")
    @Length(min = 6, max = 16, message = "密码的长度必须在6~16位之间")
	private String password;
    
	@Range(min = 18, max = 60, message = "年龄必须在18岁到60岁之间")
    private Integer age;
    
	@Pattern(regexp = "^1[3|4|5|7|8][0-9]{9}$", message = "请输入正确格式的手机号")
    private String phone;
    
	@Email(message = "请输入合法的邮箱地址")
    private String email;
}
```

如上述代码，我们需要定义一个UserConstraint 注解，它将使用在表单接收模型User类上面，同时UserConstraint定义的时候即指定其对应的校验器类UserValidaror。UserValidaror实现了ConstraintValidator接口，使用isValid方法进行校验逻辑的业务实现。在使用的时候UserValidaror需要托管到Spring进行实例化。

#### 分组校验

 Constraint 注解都有一个group属性，用来指定校验的分组。因为并不是每一个操作需要校验所有的属性，比如新增和更新 校验的参数不一样。那么我们就可以定义两个分组。

```
@UserConstraint(groups={Create.class,Update.class})
public class User {

    @NotBlank(message = "用户名不能为空",groups={Create.class})
    private String username;
    
    ...
}

@RestController
public class UserController {

	@RequestMapping("/register")
    public HttpResponse register(@Validated(Create.class) User user) {
        // logic
    }
    
    @RequestMapping("/update")
    public HttpResponse register(@Validated(Update.class) User user) {
        // logic
    }
}
```

在使用校验注解的时候指定了该注解的生效分组，如果没有指定的话则全部分组生效。在用@Validated 指定校验的分组，则可以实现不同类型的操作，校验不同的内容。

### 国际化

在校验环节，我们直接把message放到了代码中。除了调整不方便，每次都需要重新编译和发布版本。还不能支持多语言。Spring Core 本身就有一个MessageSource 接口，用来实现各种消息的翻译。

```
@Configuration
public class WebMvcConfs extends WebMvcConfigurerAdapter {
		
	@Bean
	public MessageSource messageSource(){
		ResourceBundleMessageSource  messageSource = new ResourceBundleMessageSource ();
		
		messageSource.setBasename("i18n/message");
		messageSource.setCacheSeconds(300);
		messageSource.setDefaultEncoding("UTF-8");
		
		return messageSource;
	}
	
	// Validator 注入i18n 信息
	public Validator getValidator() {
		LocalValidatorFactoryBean factory = new LocalValidatorFactoryBean();
        factory.setValidationMessageSource(messageSource());
        return factory;
	}
}
```

上述代码配置了SpringMVC的 MessageSource实现和对Validator注入 翻译的MessageSource。它会根据Http Header中的Locale 来决定取哪个文件的配置来解析消息。比如locale 是zh_CN那么会取classpath下的i18n/message_zh_CN.properties来查找消息的对应翻译，如果查找不到则使用i18n/message.properties，兜底的文件没有的话则会发生异常，走入异常逻辑处理的环节。

那么要实现一个多语言的网站就比较简单了，只需要在界面上设置一个选择语言的交互界面。选择后设置对应的Locale，后续的请求和返回的内容则可以根据Locale来定制。

Validator 在引入了国际化的内容后，配置会有一些差别。首先我们不需要在配置注解里面写message，而是配置到对应的MessageSource文件里。

```
public class User {

    @NotBlank
    private String username;
    
    @Range(min = 18, max = 60)
    private Integer age;
}


// i18n/message.properties
NotBlank.user.username=username can not be blank
Range.user.age=age must between {min} in {max} 

// i18n/message_zh_CN.properties
NotBlank.user.username=用户名不能为空
Range.user.age=年龄必须在{min}岁到{max}岁之间
```

在定义i18n文件的时候可以使用变量，比如上述的Range注解对应Validate把min和max作为变量传入到校验后的结果中。那么配合国际化的时候我们的自定义注解也是可以做到。

```
@Conpement
public class UserValidaror implements ConstraintValidator<UserConstraint, User>  {
	
	public void initialize(UserConstraint constraintAnnotation) {
		
	}

	public boolean isValid(User value, ConstraintValidatorContext context) {
		// 比如校验邮箱或者电话的唯一性,或者其他需要通过服务调用
		
		if (/* some condition */) {
            HibernateConstraintValidatorContext hibernateValidatorContext = constraintValidatorContext.unwrap(HibernateConstraintValidatorContext.class);
            hibernateValidatorContext.disableDefaultConstraintViolation();
            hibernateValidatorContext.addMessageParameter("age", "some value...").buildConstraintViolationWithTemplate("{Range.user.age}")
                .addPropertyNode("age").addConstraintViolation();
            return false;
        }
    }
}
```

#### 整合使用

除了校验的异常需要进行国际化，服务端使用返回码来提示的业务错误也需要进行国际化消息提醒。那么异常处理可以定义一个ServiceException 统一包装来处理。那么`ControllerAdvice` 可以增加以下两个处理方法

```
@ExceptionHandler({ BindException.class })
@ResponseStatus(HttpStatus.OK)
public @ResponseBody HttpResponse<Void> processException(BindException ex) {
	HttpResponse<Void> response = new HttpResponse<>();
    response.fail();
    response.setMsg(getErrorMessage(ex));
	return response;
}

@ExceptionHandler({ ServiceException.class })
@ResponseStatus(HttpStatus.OK)
public @ResponseBody HttpResponse<Void> processException(ServiceException ex) {
	HttpResponse<Void> response = new HttpResponse<>();
    response.fail();
    response.setMsg(getErrorMsg(ex));
	return response;
}

/**
 * 获取参数错误信息
 * @param ex
 * @return
 */
private String getErrorMsg(BindException ex){
	String message = null;
	
	List<FieldError> fieldErrors = ex.getBindingResult().getFieldErrors();
	
	if(CollectionUtils.isEmpty(fieldErrors)){
		return messageSource.getMessage("Param.Error", new Object[]{},"参数错误",RequestContextUtils.getLocale(request));
	}
	
	FieldError fieldError = fieldErrors.get(0);
	String[] codes = fieldError.getCodes();
	
	for(String code:codes){
		message = messageSource.getMessage(code, fieldError.getArguments(), RequestContextUtils.getLocale(request));
		//最明细的消息有的话就直接返回
		if(StringUtils.isNotEmpty(message)){
			break;
		}
	}
	
	//如果没有定义i18n 信息 ,则取默认的
	if(StringUtils.isEmpty(message)){
		message = fieldError.getField() + fieldError.getDefaultMessage();
	}
	
	return message;
}

private String getErrorMsg(ServiceException ex){
	String message = message = messageSource.getMessage(ex.getCode(), ex.getArguments(), RequestContextUtils.getLocale(request));
	
	if(StringUtils.isEmpty(message)){
		messageSource.getMessage(/**unknow exception code*/, new Obejct[]{}, RequestContextUtils.getLocale(request));
	}
	
	return message;
}
```

BindException 为 校验器默认的异常，ServiceException为自定义异常。分别对他们的以及内容进行i18n信息的翻译。





