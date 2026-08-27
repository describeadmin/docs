# 快速开始

> 目标：从零得到一个**可登录、带完整 RBAC、含一个自建业务模块**的管理后台。
>
> 适用版本：后端 `0.1.1`（新增脚手架）、前端 `0.1.0`（无变化）。
> 本文每一条命令都在 Windows 11 + Docker 上实测过，
> 实测记录见文末「本文的验证状态」一节——**没实测过的步骤会明确标出**，
> 不会混在实测过的步骤里让你分不清。

---

## 0. 你会得到什么，以及现在还得不到什么

先把话说在前面，免得你按着做到一半才发现方向不对。

**当前版本能给你的**：

- 后端：**一条命令生成可直接登录的空工程**（§3）。工程 `import` 一个 BOM + 四个 starter，
  得到统一响应结构、traceId、令牌认证、MyBatis-Plus 基类，
  以及**开箱可用的用户/角色/菜单/部门管理**
- 前端：27 个 `@describeadmin/*` npm 包，含布局、表单、弹窗、权限指令、请求封装
- 生成器：写一份 YAML，一条命令同时产出后端四件套 + 建表 SQL + 菜单 SQL
  + 前端页面 + API 封装 + 验收用例

**还给不了你的**（诚实记录，避免你踩空）：

| 缺什么 | 后果 | 当前的替代做法 |
|---|---|---|
| 前端脚手架 `npm create @describeadmin/app` | 没有生成应用外壳的命令 | **以 `frontend/apps/admin` 为起点复制** |
| `@describeadmin/system-ui` | 系统管理四个页面还在应用外壳里，你会永久拥有这 1376 行，框架后续对它们的修复到不了你那里 | 暂时接受；升级路径见 §7 |
| codegen 的 Maven 插件形态 | 只能 `java -jar`，写不进 `pom.xml` | 用 fat jar |

也就是说：**后端已经是「一条命令生成空工程」，前端仍然是「以样例仓库为起点」。**
两边不对称是当前的真实状态，不是本文的简化写法。

---

## 1. 前置环境

| 项 | 要求 | 怎么确认 |
|---|---|---|
| JDK | **17+**（见下方⚠️，这一条最容易出事） | `mvn -v` 输出的 `Java version` |
| Maven | 3.9+ | `mvn -v` |
| Node | `^22.18 \|\| ^24.12` | `node -v` |
| pnpm | `>=11` | `pnpm -v` |
| Docker | 任意近期版本（或你自备 MySQL 5.7+） | `docker -v` |

> ⚠️ **决定成败的是「Maven 自己跑在哪个 JDK 上」，不是 `java -version`。**
>
> 这里有两个不同的 JDK，很容易混为一谈：
>
> | | 由什么决定 | 要求 |
> |---|---|---|
> | **编译**用的 JDK | 就是 Maven 自己那个（框架源码与业务工程都不再配 toolchains） | **17+ 即可**，见 §3 |
> | **Maven 进程本身**跑的 JDK | `JAVA_HOME` / `PATH` | **必须 17+** |
>
> 第二条常被忽略，但它会直接让构建失败：`spring-boot-maven-plugin` 的
> `repackage` 是用 Java 17 编译的，Maven 跑在 JDK 11 上**加载不了这个插件**，
> 报错长这样——
>
> ```
> Unable to load the mojo 'repackage' ... due to an API incompatibility:
> org/springframework/boot/maven/RepackageMojo has been compiled by a more
> recent version of the Java Runtime (class file version 61.0), this version
> of the Java Runtime only recognizes class file versions up to 55.0
> ```
>
> 报错里提的是 `RepackageMojo`，看起来像 Spring Boot 插件的问题，
> 实际是你的 `JAVA_HOME` 太旧。**本文作者实测撞过这一条。**
>
> 确认方法用 `mvn -v` 看 `Java version`，**不要用 `java -version`**——
> 后者看的是 `PATH` 上第一个 java，未必是 Maven 用的那个。
>
> ```bash
> mvn -v | grep "Java version"        # 必须 >= 17
> export JAVA_HOME=/path/to/jdk17     # 不满足时这样改（Windows: $env:JAVA_HOME=...）
> ```
>
> 框架源码、插件仓、`codegen`、业务工程都**不再用 `maven-toolchains-plugin`**——
> 只要 Maven 跑在 JDK 17+ 上就能构建，`release=17` 保证产物在 Java 17 上可运行。
> （唯一例外是 `sample-app`，它刻意用 toolchains 钉 JDK 17 做最低版本验证。）

---

## 2. 起数据库

```bash
docker run -d --name da-mysql -p 3307:3306 \
  -e MYSQL_ROOT_PASSWORD=root -e MYSQL_DATABASE=describeadmin \
  -e MYSQL_USER=app -e MYSQL_PASSWORD=app \
  mysql:5.7 --character-set-server=utf8mb4 --collation-server=utf8mb4_general_ci
```

用 3307 而不是 3306，是为了不和你机器上已有的 MySQL 撞车。

字符集两个参数**必须显式给**，不能依赖服务器默认值：5.7 默认
`utf8mb4_general_ci`，8.0+ 默认 `utf8mb4_0900_ai_ci`，国产化库各不相同。

MySQL 5.7 首次启动要 20~30 秒才真正就绪。判断是否就绪要用**带认证的查询**，
不要用 `mysqladmin ping`：5.7 初始化期间会先起一个临时服务器，socket 上的
ping 立刻就成功了，但此时 root 口令还没设置。

```bash
docker exec da-mysql mysql -uroot -proot -e 'SELECT 1' && echo "就绪"
```

---

## 3. 后端：一条命令生成工程

```bash
mvn archetype:generate -B \
  -DarchetypeGroupId=io.github.describeadmin \
  -DarchetypeArtifactId=describeadmin-archetype \
  -DarchetypeVersion=0.1.1 \
  -DgroupId=com.acme -DartifactId=my-server -Dpackage=com.acme.myserver

cd my-server
mvn spring-boot:run -Dspring-boot.run.profiles=local
```

不需要安装任何东西——`archetype:generate` 是 Maven 内置插件，模板从 Central 自动下载。
IDEA 里也有现成入口：新建项目 → Maven Archetype，填上面三个 archetype 坐标即可。

你得到的是一个**没有任何业务模块、但已经可以登录使用的后台**：
用户 / 角色 / 菜单 / 部门管理与登录接口都在 `framework-system-starter` 里，
**没有任何东西需要你事后删除**。

`local` profile 监听 **8090**，每次启动执行建表与种子脚本。
框架依赖从 Maven Central 拉取，**不需要你先构建 framework 源码**。

首次启动时 dev-seed 会创建管理员 `admin`，**口令随机生成**——看启动日志里
`dev-seed 生成初始管理员` 那几行，或读项目根目录的 `.passwd` 文件（已被 `.gitignore` 忽略）。

跑起来之后确认一下（`$(cat .passwd)` 从项目根读那个随机口令）：

```bash
curl -s -X POST http://localhost:8090/api/auth/login \
  -H 'Content-Type: application/json' \
  -d "{\"username\":\"admin\",\"password\":\"$(cat .passwd)\"}"
```

应当返回 `{"code":0,...}`，令牌在 **`data.token`**（不是 `accessToken`），
同时 `data.user` 里带 `nickname` / `roles` / `permissions`。

> **`local` profile 用 dev-seed 建随机口令的管理员，仅供本地开发。**
> 每次启动都会重放种子脚本，绝不能用于任何真实环境；真实环境不要打开
> `describeadmin.system.dev-seed`。管理员为别人建号 / 重置密码后，对方首次登录会被要求先改密。

### 生成的工程里有什么

只有 6 个文件，全部归你所有：

| 文件 | 作用 |
|---|---|
| `pom.xml` | import BOM + 四个 starter + 驱动；两个接入坑已固化成正确状态，见 §5 |
| `src/main/java/<你的包>/Application.java` | 入口类，`@MapperScan` 已指向你自己的包 |
| `src/main/resources/application.yml` | 框架配置骨架 |
| `src/main/resources/application-local.yml` | 本地库连接、SQL 初始化、`encoding: UTF-8` |
| `.gitattributes` / `.gitignore` | 换行符与忽略规则 |
| `README.md` | 指向框架文档，并记录了上面那两个坑 |

**没有任何 SQL 文件**——`schema-rbac.sql` / `seed-rbac.sql` 在
`framework-system-starter` 的 jar 里，工程通过 `classpath:` 引用。
这正是"空工程也能直接登录"的原因，也意味着框架修了 RBAC 的 bug，你升个版本就拿到。

### 可覆盖的参数

去掉 `-B` 进入交互模式。有默认值的参数不会提问，需要改就在命令行上给：

| 参数 | 默认值 |
|---|---|
| `-DappClassName=` | `Application` |
| `-DserverPort=` | `8090` |
| `-DdbPort=` / `-DdbName=` | `3307` / `describeadmin` |
| `-DdbUsername=` / `-DdbPassword=` | `app` / `app` |
| `-DdescribeadminVersion=` | 与 archetype 版本相同 |

### 对 JDK 的要求只有一条

**Maven 进程自身跑在 JDK 17+**（`mvn -v` 看 `Java version`，不要用 `java -version`）。

生成的工程**刻意不带** `maven-toolchains-plugin`：用哪个发行版、哪个大版本构建是你的自由。
产物侧由 `pom.xml` 的 `<java.version>17</java.version>`（即 `release=17`）钉死——
无论用多新的 JDK 构建，字节码都落在 Java 17。

（`sample-app` 的 POM 里有 toolchains 配置，那是为了让框架团队用最低支持版本验证兼容性，
不是业务工程该抄的东西。业务方机器上大多没有 `~/.m2/toolchains.xml`，
抄过去只会以 `Cannot find matching toolchain` 直接打死构建。）

---

## 4. 前端：以 apps/admin 为起点

```bash
git clone https://github.com/describeadmin/frontend.git my-web
cd my-web
pnpm install
pnpm dev            # http://localhost:5777
```

浏览器打开 5777，用 `admin` + 后端 `.passwd` 里的随机口令登录（见上文）。

前端**不带 mock**。用 mock 开发前端，等于把前后端契约不一致的问题
全部推迟到联调阶段才暴露。dev server 默认代理到 `http://localhost:8090`，
可用 `VITE_PROXY_TARGET` 覆盖。

> ⚠️ **部署前必须替换 `apps/admin/.env` 里的 `VITE_APP_STORE_SECURE_KEY`。**
> 它是 localStorage 持久化的加密密钥，仓库里是占位值。

### 关于「以仓库为起点」的代价

克隆整个 `frontend` 会同时得到 `packages/`（框架，34485 行）和
`apps/admin`（应用外壳）。你**真正需要拥有的只有 `apps/admin`**。

目前没有把外壳单独取出来的命令（`npm create @describeadmin/app` 未交付），
因此当前的建议是：克隆后删掉 `packages/`、`internal/`，把
`apps/admin/package.json` 里的 `workspace:*` 依赖改成 `^0.1.0`，
让它从 npm 拉包。**这一步本文尚未实测**，见文末验证状态。

---

## 5. 脚手架替你挡掉的两个坑（手写 POM 时必踩）

用 §3 的命令生成工程，这一节你可以跳过——它们已经是默认正确的状态。
下面记录它们是什么，是因为你迟早要读自己的 `pom.xml`，
而这两行看起来都像"可以顺手删掉的冗余配置"。

它们的共同特征是：**报错信息与真实原因相距很远。**

| 坑 | 现象 | 生成的工程里怎么处置的 |
|---|---|---|
| BOM 给的驱动版本失效 | 连 MySQL 5.7 直接失败 | 父 POM 继承的 `dependencyManagement` **优先级高于** import 的 BOM，实际解析到 Spring Boot 管理的新版驱动（Connector/J 自 8.3.0 起不再支持 5.7）。`<properties>` 里显式写了 `<mysql.version>8.2.0</mysql.version>` |
| SQL 脚本按平台默认编码读 | 库里中文全乱码，而 `COUNT(*)` 校验完全正常 | `application-local.yml` 里显式写了 `spring.sql.init.encoding=UTF-8` |

这正是「接入不能靠文档，必须靠模板」的由来——两条都不是靠读文档能想起来的。

> **"多 JDK 共存报『不支持发行版本 17』"不在这张表里**，因为它对业务工程不成立：
> 生成的工程不配 `maven-toolchains-plugin`，编译用的就是 Maven 自己那个 JDK，
> 而 Maven 本来就必须跑在 17+（§1）。给业务工程配 toolchains 反而会因为
> 开发机上没有 `~/.m2/toolchains.xml` 而直接打死构建。

> **曾经的第三个坑已经不存在了**：早期业务方写 `@MapperScan("自己的包")`
> 会把框架的系统管理 Mapper 全部排除、登录直接失败。框架已在
> `FrameworkSystemAutoConfiguration` 上显式声明自己的 `@MapperScan` 解决此事。
> 你照常写自己的 `@MapperScan` 即可，**而且必须写**，否则扫不到的是你自己的 Mapper。

---

## 6. 加一个业务模块

### 6.1 写 spec

在 `my-server/codegen-specs/` 下新建 `order.yaml`，可参照
[`sample-app/codegen-specs/project.yaml`](https://github.com/describeadmin/sample-app/blob/main/codegen-specs/project.yaml)。

### 6.2 跑生成器

从 [codegen 的 Release 页](https://github.com/describeadmin/codegen/releases)
下载 `codegen.jar`：

```bash
java -jar codegen.jar codegen-specs/order.yaml --out .
```

一次产出两侧的东西：

| 产物 | 落点 |
|---|---|
| Entity / Mapper / Service / Controller | `src/main/java/.../order/` |
| `schema-biz_order.sql` | `src/main/resources/db/` |
| `menu-biz_order.sql` | `src/main/resources/db/` |
| 列表页 `.vue` + API 封装 `.ts` | 前端工程（用 `--frontend-out` 指定） |
| 验收用例 spec | `test-specs/order.yaml` |

### 6.3 登记 SQL —— **最容易漏的一步**

生成的两个 SQL **不会自动生效**，必须登记进 `application-local.yml`：

```yaml
spring:
  sql:
    init:
      schema-locations: classpath:db/schema-rbac.sql,classpath:db/schema-biz_order.sql
      data-locations: classpath:db/seed-rbac.sql,classpath:db/menu-biz_order.sql
      encoding: UTF-8          # ⚠️ 不能省，见下
```

**漏掉 `menu-biz_order.sql` 的症状极具欺骗性**：代码全在、编译通过、
接口能调通，但页面在侧边栏里根本不出现——因为菜单是后端 `sys_menu` 表下发的。

**`encoding: UTF-8` 同样不能省**：不写的话 Spring 用**平台默认编码**读脚本，
中文 Windows 上是 GBK，会把 UTF-8 脚本读坏，库里中文全是乱码，
而 `COUNT(*)` 校验完全正常，环境看起来非常健康。

重启后端，页面就出现在侧边栏了。

---

## 7. 升级

| 层 | 动作 |
|---|---|
| 后端框架 | 改 `<describeadmin.version>` 一行 |
| 前端包 | `pnpm up "@describeadmin/*"` |
| 生成的业务代码 | **不动**——通用逻辑在框架基类里，生成的是「薄」代码 |
| 应用外壳 | **不会自动升级**，由 CHANGELOG 提示手工跟进 |

最后一行是这套体系里唯一没有自动化兜底的部分。这也是为什么
「外壳尽可能薄」不是洁癖，而是升级机制能否成立的前提。

---

## 8. 出了问题看哪里

| 症状 | 多半是 |
|---|---|
| 库里中文全是乱码，但行数对得上 | 少了 `spring.sql.init.encoding=UTF-8`（§6.3） |
| 生成的页面在侧边栏里找不到 | 菜单 SQL 没登记（§6.3） |
| 连 MySQL 5.7 直接失败 | 驱动版本被父 POM 覆盖（§5） |
| 报「不支持发行版本 17」 | 编译用的 JDK 不对（§5） |
| `RepackageMojo ... class file version 61.0 ... up to 55.0` | **Maven 自己**跑在 JDK 11 上，与 §5 不是同一回事，见 §1 的 ⚠️ |
| 登录后直接落到 404 | `defaultHomePath` 填了菜单表里不存在的路径 |

更多已核验的事实与已知的错误信息源，见
[`VERSION_BASELINE.md`](./VERSION_BASELINE.md)。

---

## 本文的验证状态

把这一节单独列出来，是因为「文档说能跑」和「真的跑过」是两回事。

| 步骤 | 状态 |
|---|---|
| §2 起数据库 | ✅ 实测 |
| §3 用 archetype 生成工程 → 构建 → 登录 | ✅ **用 Maven Central 上的 0.1.1 实测**（空本地仓库），详见下方 |
| §3 后端起服务、登录 | ✅ **用 Maven Central 上的 0.1.0 实测**，详见下方 |
| §4 前端起服务、登录 | ✅ 实测（29/29 端到端用例，真实浏览器 → Spring Boot → MySQL 5.7） |
| §6 生成模块并接入 | ✅ 实测（用 GitHub Release 上发布的 `codegen.jar`） |
| §4「删掉 packages/ 改用 npm 包」 | ⬜ **未实测** |

> `describeadmin-archetype` 随 **0.1.1** 首次发布（2026-08-20）。
> 上表两行分属两次实测：§3 的 archetype 行用的是 Central 上的 0.1.1，
> "后端起服务、登录"行是 0.1.0 首发时的记录，两者的结论互不依赖。

### 从 Maven Central 消费这条链路是怎么验的

「能构建」不等于「能用」，所以这条按下面的顺序验，每一步都不靠推断：

1. **全新克隆** `sample-app`，**空的本地 Maven 仓库**（`-Dmaven.repo.local` 指向空目录）
   ——本机 `~/.m2` 里若有同版本缓存，Maven 根本不会碰 Central，跑绿了也证明不了任何事
2. 来源核验：`_remote.repositories` 记录为 `central=`，
   且本地解析到的 jar 与 `repo1.maven.org` 上的 **SHA256 完全一致**
3. 构建 → 启动 → 登录：`code: 0`，令牌 43 字符
4. 中文按**字节**核验：`nickname` 为 `e8b685e7baa7e7aea1e79086e59198`，
   与 `超级管理员` 的 UTF-8 编码逐字节相同
   ——不看控制台渲染，Windows 代码页会把好数据显示成乱码
5. RBAC：角色 `ADMIN`，24 个权限点；菜单树 dashboard / system（4 个子项）/ biz 结构正确，
   `系统管理`、`用户管理` 的字节同样逐一核对

**这一轮实测改掉了本文两处会让人卡住的错误**：登录响应的令牌字段是 `data.token`
而非 `accessToken`；以及 §1 那条关于 Maven 自身 JDK 的 ⚠️——作者自己就撞了，
报错指向 `RepackageMojo`，与真实原因（`JAVA_HOME` 太旧）相距很远。

用 `repo1.maven.org` 核验，**不要用 `search.maven.org`**——那个索引已陈旧，
会对真实存在的制品返回假阴性。

### 脚手架这条链路是怎么验的

同样不靠推断，每一步都落到可核对的事实上。**用空的本地仓库跑**
（`-Dmaven.repo.local` 指向空目录）——本机 `~/.m2` 里有同版本的 `install` 产物的话，
Maven 根本不会碰 Central，跑绿了也证明不了任何事：

0. 来源核验：`_remote.repositories` 记录为 `central=`，本地解析到的 archetype jar 与
   repo1 上的 **SHA256 完全一致**（`1c7cabae…b837d12`）
1. `mvn archetype:generate` 生成工程 → 6 个文件齐全，**`.gitignore` 与 `.gitattributes` 都在**
   （这两个文件是分开验的：Maven 的默认排除规则只吃掉前者，且不报任何错）
2. 生成物里**没有未替换的变量**，`README.md` 的二级标题一个不少
   （Velocity 把行首 `##` 当行注释，标题会整行消失且不报错）
3. **用 JDK 17 构建**（不是 21）：`mvn package` 通过，证明业务工程不需要 toolchains
4. 起服务 → 登录：`code: 0`，令牌 43 字符，`roles: [ADMIN]`，20 个权限点
5. 中文按**字节**核验：`nickname` 为 `e8b685e7baa7e7aea1e79086e59198`，
   与 `超级管理员` 的 UTF-8 编码逐字节相同——不看控制台渲染。
   库里的菜单名同样逐字节核对：`工作台` / `概览` / `系统管理` 三条无误

第 1、2 条已固化为 `framework` 仓库 CI 的 `archetype-e2e` job，
第 3~5 条同样在那个 job 里跑，用的是真实的 MySQL 5.7 容器。
