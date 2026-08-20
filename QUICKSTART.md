# 快速开始

> 目标：从零得到一个**可登录、带完整 RBAC、含一个自建业务模块**的管理后台。
>
> 适用版本：`0.1.0`。本文每一条命令都在 Windows 11 + Docker 上实测过，
> 实测记录见文末「本文的验证状态」一节——**没实测过的步骤会明确标出**，
> 不会混在实测过的步骤里让你分不清。

---

## 0. 你会得到什么，以及现在还得不到什么

先把话说在前面，免得你按着做到一半才发现方向不对。

**0.1.0 能给你的**：

- 后端：`import` 一个 BOM + 五个 starter，得到统一响应结构、traceId、
  令牌认证、MyBatis-Plus 基类，以及**开箱可用的用户/角色/菜单/部门管理**
- 前端：27 个 `@describeadmin/*` npm 包，含布局、表单、弹窗、权限指令、请求封装
- 生成器：写一份 YAML，一条命令同时产出后端四件套 + 建表 SQL + 菜单 SQL
  + 前端页面 + API 封装 + 验收用例

**0.1.0 还给不了你的**（诚实记录，避免你踩空）：

| 缺什么 | 后果 | 当前的替代做法 |
|---|---|---|
| 后端工程模板 `describeadmin-archetype` | 从空工程手写 POM 会踩两个坑，见 §5 | **以 `sample-app` 为起点复制**，不要手写 |
| 前端脚手架 `npm create @describeadmin/app` | 没有生成应用外壳的命令 | **以 `frontend/apps/admin` 为起点复制** |
| `@describeadmin/system-ui` | 系统管理四个页面还在应用外壳里，你会永久拥有这 1376 行，框架后续对它们的修复到不了你那里 | 暂时接受；升级路径见 §7 |
| codegen 的 Maven 插件形态 | 只能 `java -jar`，写不进 `pom.xml` | 用 fat jar |

也就是说：**0.1.0 的接入方式是「以样例仓库为起点」，不是「一条命令生成工程」。**
这是当前的真实状态，不是本文的简化写法。

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
> | **编译**用的 JDK | `maven-toolchains-plugin` | 框架源码构建需 21；业务工程需 17 |
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
> 只有你要**自己构建框架源码**时才需要额外配 toolchains；
> 只是**使用**已发布的 0.1.0 制品的话不需要。

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

## 3. 后端：以 sample-app 为起点

```bash
git clone https://github.com/describeadmin/sample-app.git my-server
cd my-server
mvn spring-boot:run -Dspring-boot.run.profiles=local
```

`local` profile 监听 **8090**，并在每次启动时执行建表与种子脚本。
框架依赖从 Maven Central 拉取，**不需要你先构建 framework 源码**。

跑起来之后确认一下：

```bash
curl -s -X POST http://localhost:8090/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"admin123"}'
```

应当返回 `{"code":0,...}`，令牌在 **`data.token`**（不是 `accessToken`），
同时 `data.user` 里带 `nickname` / `roles` / `permissions`。

> **默认账号 `admin` / `admin123` 仅供本地开发。**
> `local` profile 每次启动都会重放种子脚本，绝不能用于任何真实环境。

### 把它变成你自己的工程

`sample-app` 是**活样本**，不是要你原样跑的 demo。改造成你的工程：

1. 改 `pom.xml` 的 `groupId` / `artifactId` / `<name>`
2. 把 `io.github.describeadmin.sample` 改成你自己的包名
3. 删掉 `project` 这个示例模块（`src/main/java/.../project/`、
   `src/main/resources/db/schema-biz_project.sql`、`menu-biz_project.sql`，
   以及 `application-local.yml` 里对这两个 SQL 的引用）
4. 新建 `application-dev.yml` / `application-prod.yml` 指向你的真实数据库

**第 3 步不要跳过**：留着示例模块，你的菜单里会一直挂着一个「项目管理」。

---

## 4. 前端：以 apps/admin 为起点

```bash
git clone https://github.com/describeadmin/frontend.git my-web
cd my-web
pnpm install
pnpm dev            # http://localhost:5777
```

浏览器打开 5777，用 `admin` / `admin123` 登录。

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

## 5. 两个已实测的坑（手写 POM 时必踩）

如果你不以 `sample-app` 为起点，而是从空的 Spring Boot 工程手写 POM，
会踩到下面两个问题。它们的共同特征是：**报错信息与真实原因相距很远。**

| 坑 | 现象 | 处置 |
|---|---|---|
| BOM 给的驱动版本失效 | 连 MySQL 5.7 直接失败 | 父 POM 继承的 `dependencyManagement` **优先级高于** import 的 BOM，实际解析到 Spring Boot 管理的新版驱动。必须在自己的 `<properties>` 里显式写 `<mysql.version>8.2.0</mysql.version>` |
| 多 JDK 共存 | 报「不支持发行版本 17」 | 用了 `PATH` 上恰好存在的 JDK。配 `maven-toolchains-plugin` |

`sample-app` 的 POM 已经把这两条固化成默认正确的状态——这正是
「接入不能靠文档，必须靠模板」的由来。

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
| §3 后端起服务、登录 | ✅ **用 Maven Central 上的 0.1.0 实测**，详见下方 |
| §4 前端起服务、登录 | ✅ 实测（29/29 端到端用例，真实浏览器 → Spring Boot → MySQL 5.7） |
| §6 生成模块并接入 | ✅ 实测（用 GitHub Release 上发布的 `codegen.jar`） |
| §4「删掉 packages/ 改用 npm 包」 | ⬜ **未实测** |

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
