# 从零跑起一个管理后台

跟着做完这一篇，你会得到一个**可登录、带完整 RBAC、含审计与操作日志**的管理后台
——后端一条命令生成，前端以应用外壳为起点。

::: tip 版本号
本文命令里出现的 `0.2.1` / `0.2.2` 指当前发布版本。开始前请对照
[兼容性矩阵](/reference/compatibility) 确认后端、前端、codegen、插件之间的版本对应关系
——它们**不总是同号**。
:::

::: warning 本文尚未覆盖的部分
前端目前仍是「以 `apps/admin` 为起点复制」，没有 `npm create` 脚手架；
系统管理页面还在应用外壳里。这两处的现状与后果见
[当前限制与路线图](/about/limitations)。
:::

## 1. 前置环境

| 项 | 要求 | 怎么确认 |
|---|---|---|
| JDK | **17+**（见下方 ⚠️，这一条最容易出事） | `mvn -v` 输出的 `Java version` |
| Maven | 3.9+ | `mvn -v` |
| Node | `^22.18 \|\| ^24.12` | `node -v` |
| pnpm | `>=11` | `pnpm -v` |
| Docker | 任意近期版本（或自备 MySQL 5.7+） | `docker -v` |

::: warning 决定成败的是「Maven 自己跑在哪个 JDK 上」，不是 `java -version`
这里有两个不同的 JDK：

| | 由什么决定 | 要求 |
|---|---|---|
| **编译**用的 JDK | 就是 Maven 自己那个（不配 toolchains） | 17+ 即可 |
| **Maven 进程本身**跑的 JDK | `JAVA_HOME` / `PATH` | **必须 17+** |

第二条常被忽略，但会直接让构建失败。`spring-boot-maven-plugin` 的 `repackage`
是用 Java 17 编译的，Maven 跑在 JDK 11 上加载不了这个插件，报错长这样：

```
Unable to load the mojo 'repackage' ... due to an API incompatibility:
org/springframework/boot/maven/RepackageMojo has been compiled by a more
recent version of the Java Runtime (class file version 61.0), this version
of the Java Runtime only recognizes class file versions up to 55.0
```

报错里提的是 `RepackageMojo`，看起来像 Spring Boot 插件的问题，实际是 `JAVA_HOME` 太旧。

```bash
mvn -v | grep "Java version"        # 必须 >= 17
export JAVA_HOME=/path/to/jdk17     # Windows: $env:JAVA_HOME=...
```

用 `mvn -v` 看 `Java version`，**不要用 `java -version`**——后者看的是 `PATH` 上第一个 java。
:::

## 2. 起数据库

```bash
docker run -d --name da-mysql -p 3307:3306 \
  -e MYSQL_ROOT_PASSWORD=root -e MYSQL_DATABASE=describeadmin \
  -e MYSQL_USER=app -e MYSQL_PASSWORD=app \
  mysql:5.7 --character-set-server=utf8mb4 --collation-server=utf8mb4_general_ci
```

用 3307 而非 3306，是为了不和机器上已有的 MySQL 撞车。

字符集两个参数**必须显式给**，不能依赖服务器默认值：5.7 默认 `utf8mb4_general_ci`，
8.0+ 默认 `utf8mb4_0900_ai_ci`，国产化库各不相同。

MySQL 5.7 首次启动要 20~30 秒才真正就绪。判断就绪要用**带认证的查询**，
不要用 `mysqladmin ping`：5.7 初始化期间会先起一个临时服务器，socket 上的 ping
立刻成功，但此时 root 口令还没设置。

```bash
docker exec da-mysql mysql -uroot -proot -e 'SELECT 1' && echo "就绪"
```

## 3. 后端：一条命令生成工程

```bash
mvn archetype:generate -B \
  -DarchetypeGroupId=io.github.describeadmin \
  -DarchetypeArtifactId=describeadmin-archetype \
  -DarchetypeVersion=0.2.1 \
  -DgroupId=com.acme -DartifactId=my-server -Dpackage=com.acme.myserver

cd my-server
mvn spring-boot:run -Dspring-boot.run.profiles=local
```

不需要安装任何东西——`archetype:generate` 是 Maven 内置插件，模板从 Central 自动下载。
IDEA 里也有现成入口：新建项目 → Maven Archetype，填上面三个坐标即可。

你得到的是一个**没有任何业务模块、但已经可以登录使用的后台**：
用户 / 角色 / 菜单 / 部门管理与登录接口都在 `framework-system-starter` 里，
**没有任何东西需要你事后删除**。

`local` profile 监听 **8090**，每次启动执行建表与种子脚本。框架依赖从 Maven Central
拉取，**不需要你先构建 framework 源码**。

首次启动时 dev-seed 会创建管理员 `admin`，**口令随机生成**——看启动日志里
`dev-seed 生成初始管理员` 那几行，或读项目根目录的 `.passwd` 文件（已被 `.gitignore` 忽略）。

跑起来后确认（`$(cat .passwd)` 从项目根读随机口令）：

```bash
curl -s -X POST http://localhost:8090/api/auth/login \
  -H 'Content-Type: application/json' \
  -d "{\"username\":\"admin\",\"password\":\"$(cat .passwd)\"}"
```

应当返回 `{"code":0,...}`，令牌在 **`data.token`**（不是 `accessToken`），
`data.user` 里带 `nickname` / `roles` / `permissions`。

::: danger local profile 仅供本地开发
`local` 用 dev-seed 建随机口令管理员，每次启动重放种子脚本，绝不能用于任何真实环境。
真实环境不要打开 `describeadmin.system.dev-seed`。管理员给别人建号 / 重置密码后，
对方首次登录会被要求先改密。
:::

### 生成的工程里有什么

只有 6 个文件，全部归你所有：

| 文件 | 作用 |
|---|---|
| `pom.xml` | import BOM + 四个 starter + 驱动；两个接入坑已固化成正确状态，见 §5 |
| `src/main/java/<你的包>/Application.java` | 入口类，`@MapperScan` 已指向你自己的包 |
| `src/main/resources/application.yml` | 框架配置骨架 |
| `src/main/resources/application-local.yml` | 本地库连接、SQL 初始化、`encoding: UTF-8` |
| `.gitattributes` / `.gitignore` | 换行符与忽略规则 |
| `README.md` | 指向框架文档，并记录了那两个坑 |

**没有任何 SQL 文件**——`schema-rbac.sql` / `seed-rbac.sql` 在 `framework-system-starter`
的 jar 里，工程通过 `classpath:` 引用。这正是「空工程也能直接登录」的原因，
也意味着框架修了 RBAC 的 bug，你升个版本就拿到。

### 可覆盖的参数

去掉 `-B` 进入交互模式。有默认值的参数不会提问，需要改就在命令行上给：

| 参数 | 默认值 |
|---|---|
| `-DappClassName=` | `Application` |
| `-DserverPort=` | `8090` |
| `-DdbPort=` / `-DdbName=` | `3307` / `describeadmin` |
| `-DdbUsername=` / `-DdbPassword=` | `app` / `app` |
| `-DdescribeadminVersion=` | 与 archetype 版本相同 |

## 4. 前端：以 apps/admin 为起点

```bash
git clone https://github.com/describeadmin/frontend.git my-web
cd my-web
pnpm install
pnpm dev            # http://localhost:5777
```

浏览器打开 5777，用 `admin` + 后端 `.passwd` 里的随机口令登录。

前端**不带 mock**。用 mock 开发前端，等于把前后端契约不一致的问题全部推迟到联调阶段。
dev server 默认代理到 `http://localhost:8090`，可用 `VITE_PROXY_TARGET` 覆盖。

::: warning 部署前必须替换密钥
`apps/admin/.env` 里的 `VITE_APP_STORE_SECURE_KEY` 是 localStorage 持久化的加密密钥，
仓库里是占位值，部署前务必替换。
:::

「以仓库为起点」的代价与后续升级路径见 [当前限制与路线图](/about/limitations)。

## 5. 脚手架替你挡掉的两个坑

用 §3 的命令生成工程，这一节可以跳过——它们已是默认正确状态。记录在这里，
是因为你迟早要读自己的 `pom.xml`，而这两行看起来都像「可以顺手删掉的冗余配置」。
共同特征是：**报错信息与真实原因相距很远。**

| 坑 | 现象 | 生成的工程里怎么处置 |
|---|---|---|
| BOM 给的驱动版本失效 | 连 MySQL 5.7 直接失败 | 父 POM 继承的 `dependencyManagement` 优先级高于 import 的 BOM，实际解析到 Spring Boot 管理的新版驱动（Connector/J 自 8.3.0 起不再支持 5.7）。`<properties>` 里显式写了 `<mysql.version>8.2.0</mysql.version>` |
| SQL 脚本按平台默认编码读 | 库里中文全乱码，而 `COUNT(*)` 校验完全正常 | `application-local.yml` 里显式写了 `spring.sql.init.encoding=UTF-8` |

::: tip 你照常写自己的 `@MapperScan` 即可，而且必须写
早期业务方写 `@MapperScan("自己的包")` 会把框架的系统管理 Mapper 全排除、登录失败。
框架已在 `FrameworkSystemAutoConfiguration` 上显式声明自己的 `@MapperScan` 解决此事。
你不写自己的 `@MapperScan`，扫不到的是你自己的 Mapper。
:::

## 6. 出了问题看哪里

| 症状 | 多半是 |
|---|---|
| 库里中文全是乱码，但行数对得上 | 少了 `spring.sql.init.encoding=UTF-8` |
| 生成的页面在侧边栏里找不到 | 菜单 SQL 没登记（见[加第一个业务模块](/guide/first-module)） |
| 连 MySQL 5.7 直接失败 | 驱动版本被父 POM 覆盖（§5） |
| 报「不支持发行版本 17」 | 编译用的 JDK 不对（§1） |
| `RepackageMojo ... class file version 61.0 ... up to 55.0` | **Maven 自己**跑在 JDK 11 上（§1 的 ⚠️） |
| 登录后直接落到 404 | `defaultHomePath` 填了菜单表里不存在的路径 |

## 下一步

[加第一个业务模块 →](/guide/first-module)
