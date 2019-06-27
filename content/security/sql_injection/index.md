---
title: SQL注入漏洞
date: 2018-03-05
categories: ["security"]
---

SQL注入是最高危的漏洞之一,它和命令执行漏洞一样是直接危害应用本身,可能导致数据库内容直接泄露或者被删除等.

<!--more-->


### 如何出现

以Java和MySQL为例子,假设用户输入账号和密码进行登录,调用执行SQL的方法如下.


```
public boolean login(String name,String passwd){
	String sql = "select count(1) from t_user where name = '"+name+"' and passwd = '"+passwd+"'";
		
	try{
		ResultSet resultSet = connection.createStatement().executeQuery(sql);
		if(resultSet.next()){
			int i = resultSet.getInt(1);
			if(i > 0){
				return true;
			}
		}
	}
	catch (Exception e) {
		e.printStackTrace();
	}
		
	return false;
}
```

实际上所执行的SQL是代入2个值之后直接拼接出来.那么就有了如下场景


```

// 正常场景
name = GrayMan]
password = 123456

select count(1) from t_user 
where name = 'GrayMan' and password = '123456' ;

// 注入场景
name = GrayMan' or 1=1 -- 
password = [123456]

select count(1) from t_user 
where name = 'GrayMan' or 1=1 --' and password = '123456' ;

```

注入场景中所执行的是 select count(1) from t_user 
where name = 'GrayMan' or 1=1;那么它是永远成立的.那么就是在知道用户名的情况下是可以登入到任何一个账户的.倘若是其他场景下,是一些其他SQL


```

// SQL模板
select * from t_user where name = '' and password = '';


//查询出所有的用户名称

name = GrayMan' union select * from t_user;-- '

select * from t_user where name = 'GrayMan' union select * from t_user;-- ' and password = '' ;

// 执行删除库表语句

name = GrayMan' ; drop table t_profile;-- '

select * from t_user where name = 'GrayMan' ; drop table t_profile;-- ' and password = '' ;


// 查询操作系统文件

name= GrayMan' union select load_file('/etc/passwd');-- 

select * from t_user where name = 'GrayMan' union select  1,load_file('/etc/passwd');-- ' and password = '' ;

```

上面一个例子即能查询出系统中所有的用户,也能删除应用库,甚至如果有权限的话,直接把整个数据库删除掉也是很容易的.最后一个能读出系统的用户密码文件,当然是需要经过处理的.

### 如何防范

- 不要使用SQL拼接然后再去执行,尽量使用预编译语句,且进行参数绑定. 文章开头的例子可修改为

```
public boolean login(String name,String password){
	String sql = "select count(1) from t_user where name = ? and password = ?";
	
	try{
		PreparedStatement ps = connection.prepareStatement(sql);
		ps.setString(1, name);
		ps.setString(2, password);
		ResultSet resultSet = ps.executeQuery();
		if(resultSet.next()){
			int i = resultSet.getInt(1);
			if(i > 0){
				return true;
			}
		}
	}
	catch (Exception e) {
		e.printStackTrace();
	}
	
	return false;
}
```

- 如果非不得已需要使用到拼接,一定要做SQL拼接的地方对用户输入的参数进行敏感字符的转义.

- 使用框架的时候一定要确认什么样的情况下是参数绑定,什么情况下是直接拼接SQL ,例如MyBatis 中是用 【$】 和 【#】 来引用变量的区别.

- 应用所使用的数据库账号与数据库管理相关的账号独立,限制好对该账号的权限,比如DDL权限,防止应用存在SQL注入漏洞后带来灾难性的后果.

- 存储的重要数据要脱敏,加密,防篡改等.比如账户的金额流水虽然金额是明文存储,但是要有token可以反推数据是否被篡改.