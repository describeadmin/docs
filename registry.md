# 插件目录（Registry）

> 方案第八章要求维护的插件清单。目的是让人和 AI Agent 快速判断
> **"这个能力框架有没有现成的，还是需要自己按 SPI 实现"**。
>
> 本文件与 `repos.yml` 的分工：`repos.yml` 登记**仓库**，本文件登记**可用能力**。
> 新增插件时两处都要更新。

---

## 现有插件

每个插件**独立成仓、独立版本线、独立发布**（方案 3.1.1）。
插件版本与框架版本**无对应关系**——引用时必须显式写插件自己的版本号，
`framework-bom` 刻意不仲裁插件版本（理由见准入规范第 4 条）。

| 插件 | 仓库 | 实现的 SPI | 最低框架版本 | 状态 | 说明 |
|---|---|---|---|---|---|
| Redis 缓存与会话 | [`framework-cache-redis-starter`](https://github.com/describeadmin/framework-cache-redis-starter) | `CacheProvider`、`TokenStore` | **0.2.0** | 已发布 v0.2.0 | 解除内存实现的两条局限：重启掉线、不支持多实例。用到 0.2.0 引入的 `TokenStore.listActive()`、`ActiveSession` 与 `SessionMeta`（登录 IP/设备随会话存入 Redis） |
| 邮箱验证码登录 | [`framework-auth-email-starter`](https://github.com/describeadmin/framework-auth-email-starter) | `AuthProvider`（另附可选 `NotifyChannel`） | **0.2.0** | 已发布 v0.2.0 | 无密码邮箱验证码登录，取 userId 走准入规范第 10 条第一种路径（`SysUserService.findByEmail` + `AuthUserLoader.loadByUserId`）。可选提供 `NotifyChannel(channel="email")` 复用同一个 `JavaMailSender` 供其他场景发信。用到 0.2.0 同批交付的 access/refresh 双令牌与 `CacheProvider.keysWithPrefix()` |
| 敏感字段加密入库 | [`framework-crypto-starter`](https://github.com/describeadmin/framework-crypto-starter) | `CryptoProvider` | **0.2.0** | 已发布 v0.2.0 | 面向**业务方自己的实体**（不是核心 `sys_user`）的字段级透明加密：`CryptoProvider`（多实现共存模型，仿 `NotifyChannel`）+ `CryptoDispatcher` + `EncryptedStringTypeHandler`；内置 AES-256-GCM（零依赖默认可用）与 SM4-GCM+HmacSM3（国密，Bouncy Castle 为 optional 依赖）；密文自描述算法前缀支持换算法不迁移存量数据；`@BlindIndex` 支持等值查询字段的索引自动维护；`CryptoTemplate` 覆盖自定义 Mapper/`JdbcTemplate`/批量脚本等 TypeHandler 覆盖不到的场景。盲索引自动填充挂进 `framework-mybatis-starter` 0.2.0 开放的 `ObjectProvider<InnerInterceptor>` 扩展点，**零框架核心改动**（已用字节码反编译验证 `InnerInterceptor.beforeUpdate` 严格早于 `MetaObjectHandler` 填充与 `TypeHandler` 加密的时序）。57 个测试全绿，含 MySQL 5.7/8.4 双版本 Testcontainers 端到端集成测试——过程中发现并验证了一条真实陷阱：`@TableField(typeHandler=...)` 对 INSERT/UPDATE 天然生效，但 SELECT 必须配合实体上的 `@TableName(autoResultMap = true)` 才会生效，缺了不报错，只是查出来的是密文当明文用，已写进插件 README 与 `EncryptedStringTypeHandler` 的 javadoc |
| Excel 导入导出 | [`framework-excel-starter`](https://github.com/describeadmin/framework-excel-starter) | （Web 层扩展点，非核心 SPI） | **0.2.0** | 已发布 v0.2.0 | 第一个 Web 层插件。不实现某个核心 SPI，而是注册框架此前没有的 `ResponseBodyAdvice` + `HandlerMethodArgumentResolver`——**共存式装配**，不用 `before`/`beforeName`，仅用 `afterName` 排在 `FrameworkWebAutoConfiguration` 之后，全部 `@ConditionalOnMissingBean` 绑定到接口（业务方自注册的 `ExcelExporter`/`ExcelImporter` 一定赢）。门面 `ExcelExporter`/`ExcelImporter`（`api/`，零 MVC 依赖可用）+ `@ExcelResponse`（`List<T>`/`PageResult<T>`/`Result<…>` 直接当 xlsx 下载）+ `@ExcelBody`（上传文件绑成 `List<T>`/`ExcelImportResult<T>`，结构化 `RowError` record）。**不碰 `BaseController`、不新增端点/权限动作**——导入导出是少数业务的需求，业务方在自己的 Controller 写端点并自行 `@PreAuthorize`。雪花 `Long` 默认写成文本单元格（同 `CLAUDE.md` 4.8），`@ExcelLongNumber` 逃生舱。导入前自校验文件头（Fesod/POI 对乱码字节不抛异常而是当 CSV 解析出 0 行）。基于 Apache Fesod `fesod-sheet:2.0.2-incubating`（EasyExcel/FastExcel 的 ASF 捐赠版）——⚠️ 孵化中，其 POM 自述 EasyExcel 衍生代码 IP clearance 未完成，下游需自行许可审查（已写进插件 README 兼容性小节）。字典 ⇄ 字面量转换推迟到 v0.3.0，v1 仅在 `api/` 重导出 Fesod `Converter` SPI。42 个测试全绿（含 MockMvc advice/resolver + 真 xlsx 往返），无需 Docker |

> 四个插件均于 **2026-08-31** 随 framework 0.2.0 同批发布到 Maven Central，
> 坐标 `io.github.describeadmin:framework-<能力>-starter:0.2.0`。
> 引用时须显式写版本号（`framework-bom` 刻意不仲裁插件版本，见准入规范第 4 条）。

## 规划中

| 插件 | 实现的 SPI | 说明 |
|---|---|---|
| 浙政钉登录 | `AuthProvider` | 政务场景登录 |
| 钉钉消息推送 | `NotifyChannel` | 工作通知类推送 |
| 企业微信登录/推送 | `AuthProvider` / `NotifyChannel` | 按业务方需求排期 |
| 短信通道 | `NotifyChannel` | 验证码、通知短信 |
| 敏感字段加密：SM2 / 格式保留加密（FPE） | `CryptoProvider` | `framework-crypto-starter` v1（AES-256-GCM + SM4-GCM）未覆盖。SM2 适合信封加密/密钥保护场景，FPE 适合"密文需保持原格式"的存量系统兼容场景，均等真实需求出现再评估，不预先设计接口形状 |
| Excel 字典转换 `@ExcelDict`（DB-backed） | （`framework-excel-starter` 内部） | `framework-excel-starter` v1 只在 `api/` 重导出 Fesod `Converter` SPI，业务方用 `@ExcelProperty(converter = X.class)` 自解。DB 版注解（自动查 `SysDictDataService`）推迟到 v0.3.0——n=1，且照单个用例设计的注解形状大概率装不下第二个真实需求。装配接缝已在 `FrameworkExcelAutoConfiguration.DictConverterConfiguration` 留出（字符串形式 `@ConditionalOnClass`） |

---

## 边界：前端登录方式为什么（目前）不做成插件

本文件登记的是**后端** SPI 插件。邮箱验证码登录落地时曾认真考虑过前端要不要
对称地做一套"登录方式插件"机制——即业务方 `pnpm add` 一个包才拥有对应的登录页
/路由，不装就完全不存在，跟后端插件"不引依赖=这段代码根本不在 classpath 上"
对齐。结论是**目前不做**，原因记在这里，避免以后又把它当成没做完的事翻出来：

1. **后端做插件是为了避开"重依赖/厂商绑定"**（准入规范第 4.6 条的判断标准），
   邮箱登录的前端部分只是一个 Vue 组件 + 一次 `fetch`，没有重依赖也没有厂商 SDK。
   真正"重"的那部分——`third-party-login.vue` 里钉钉的 OAuth 地址、按需
   `loadScript` 的 `ddlogin.js`——本来就已经是独立组件、按需加载，不需要再造一套
   安装机制去隔离它。
2. **正确性已经由运行时开关兜住**：登录页调 `/api/auth/providers`，返回里没有
   `"email"` 时按钮永远不出现。业务方后端不装这个插件，用户在界面上完全感知不到
   这个入口存在——唯一的代价是包里多几 KB 用不上的 JS，成本小到不值得为它建一套
   安装机制。
3. **现在只有邮箱一个真实案例（n=1）**。"规划中"表格里的浙政钉/钉钉是
   **OAuth 跳转式**交互（`dingding-login.vue` 已经是完全不同的形状：图标按钮 +
   弹窗/跳转），跟邮箱这种"表单 + 验证码"模型差异很大。只用一个案例就去设计
   "前端登录方式插件"的接口形状，大概率会照着邮箱这一种交互去设计，等浙政钉真正
   落地时发现装不下——这是过早抽象的典型场景，至少要等第二个真实的前端登录方式
   集成落地，才看得出真正该抽象的边界在哪。
4. **就算做了也不解决更大的问题**：`apps/admin`/`create-app/template`/
   `sample-frontend` 三处手工同步是比"邮箱登录要不要插件化"更根本的既有欠账
   （见本仓 `PROGRESS.md`"已知欠账"一节）。给邮箱登录单做一个前端插件包，
   并不能让这个同步问题消失，只是换了个形式存在。

**什么时候该重新考虑**：出现第二个真实的前端登录方式集成时（大概率是浙政钉或
钉钉登录任一项真正开工时），到那时手上有两个真实案例，再决定要不要抽、抽成
什么形状。在那之前，新的登录方式前端部分继续按邮箱登录的现有做法——直接写进
`apps/admin`/`create-app/template`/`sample-frontend` 各自源码，手工同步三份。

---

## 准入规范

方案第八章只给出了登记表的字段，没有写准入条款。以下是随第一个插件落地时补齐的，
每一条都对应一个已经踩过或已经预见的具体问题。

### 1. 命名与坐标

- artifactId：`framework-<能力>-starter`，能力名用连字符分段（`cache-redis`、`notify-dingtalk`）
- Java 包名：`io.github.describeadmin.<能力>.<细分>`，与 groupId 一致
- 配置前缀：`describeadmin.<能力>.<细分>`，与包名对齐

### 2. 依赖方向（硬性）

- **对框架契约模块用 `compile`**：插件要实现的 SPI 所在模块必须保证运行时存在
- **对"只为判断要不要接管"而引用的模块用 `provided` + `optional`**：
  例如 Redis 插件引用 `framework-security-starter` 只是为了实现 `TokenStore`，
  不该强迫"只想换缓存、不用框架鉴权"的业务方把 Spring Security 拖进依赖树
- **插件不得反向被核心依赖**。核心代码里不允许出现任何具体实现的名字
  （`redis`、`dingtalk`、`zhengwuding` 等字符串只能出现在对应插件内）

### 3. 装配顺序（最容易出错的一条）

核心用 `@ConditionalOnMissingBean` 提供默认实现，**该条件只检查当前已注册的 Bean 定义**。
插件若晚于核心被评估，插件的 Bean 会被自己的条件挡掉——
**引了却没生效，且启动毫无异常**。这是 `VERSION_BASELINE.md` 发现 ⑦ 的同类问题。

因此插件必须显式声明顺序：

```java
@AutoConfiguration(
        before = FrameworkCacheAutoConfiguration.class,          // 硬依赖，直接引用类
        beforeName = "io.github.describeadmin.security."         // optional 依赖，必须用字符串，
                   + "autoconfigure.FrameworkSecurityAutoConfiguration")  // 否则类不在时加载即失败
```

`optional` 依赖一律用 `beforeName` / `afterName` 的**字符串**形式；写成 `before = Xxx.class`
会在该模块缺席时直接抛 `NoClassDefFoundError`。

同理，引用了 optional 模块类型的 Bean 方法必须放进带 `@ConditionalOnClass` 的**嵌套配置类**：
条件标在配置类上时 Spring 用 ASM 读注解、不加载方法签名里的类型；
写在外层则方法返回值的类型解析会先一步失败。

### 4. 版本兼容声明（硬性）

插件以 `provided` 依赖框架，**运行时的框架版本由业务方决定**，不是插件构建时那个。
两个方向的风险极不对称：

| 情况 | 后果 |
|---|---|
| 插件旧、框架新 | 通常没事（只要框架没破坏 `api/`） |
| **插件新、框架旧** | **`NoSuchMethodError` / `NoClassDefFoundError`，且不在启动时暴露** |

因此每个插件版本必须声明**最低框架版本**，并且这个声明要在三个地方保持一致：

1. **本文件的表格**（给人和 AI 看）
2. **插件 POM 里 import 的 `framework-bom` 版本**（构建基线）
3. **代码里的常量 + 启动期自检**（唯一真正生效的一道）：

```java
public static final String REQUIRED_FRAMEWORK_VERSION = "0.2.0";

public FrameworkXxxAutoConfiguration() {
    FrameworkVersion.requireCompatible("framework-xxx-starter", REQUIRED_FRAMEWORK_VERSION);
}
```

`FrameworkVersion`（`framework-common` 的 `api/` 包）的判定策略：

- 框架比要求的**旧** → 抛异常，**启动失败**。这是真正会出事的方向
- **主版本不同** → 抛异常。跨大版本的破坏性变更按 SemVer 是被允许的
- 框架更新、主版本相同 → 只记 WARN。一律拒绝会让每个框架小版本都逼所有插件重发一遍
- 读不到框架版本 → 放行 + WARN。不能因为自检机制本身把应用挡在门外

常量**手工声明，不要从插件自身版本推导**：插件独立成仓后两者不再有对应关系
（插件发 1.3.0 完全可能仍然只要求框架 1.0.0）。用到框架新增的 SPI 时必须同步上调。

> ⚠️ **0.x 期间要格外小心**。SemVer 对 `0.x` 不作任何保证，本项目的 0.2.0 就带过
> Breaking Change。所以 0.x 期间"框架更新"那条 WARN 要当回事，
> 插件应当对每个框架小版本重新验证，而不是假定向后兼容。

### 5. CI 兼容性矩阵（硬性）

上面第 4 条把声明变得**可执行**，这一条把它变得**可信**。

插件仓的 CI 必须对**声明支持的每个框架版本各跑一遍完整测试**。
只声明不验证的话，"最低框架版本 0.2.0"只是一句愿望——
真正的问题（某个 SPI 在 0.3.0 悄悄改了行为）恰恰不会被插件自己的单测发现。

### 6. 两层开关（硬性）

- **编译期**：是否引入 starter，决定能力是否存在
- **运行时**：`@ConditionalOnProperty`，决定已引入的能力是否激活

运行时开关不是可选项。排查"是不是这个插件的问题"时，
改一行配置重启，比改 `pom.xml` 重新打包部署快一个数量级。
关掉后行为必须与"没引这个 jar"完全一致。

### 7. 业务方优先

插件的 Bean 一律带 `@ConditionalOnMissingBean`。业务方自己注册的实现必须赢过插件，
否则业务方将无法覆盖框架行为——那会把"可插拔"变成"被插件锁死"。

### 8. 测试（硬性）

插件必须覆盖**两条路径**，缺一不可：

1. **不引 = 行为不变**：核心的默认实现继续生效
2. **引了 = 能力生效**：插件的实现接管

第二条要用 `ApplicationContextRunner` + `AutoConfigurations.of(...)` 验证，
它会按 `@AutoConfiguration` 的 before/after 真实排序，因此测的确实是装配顺序本身。
只测实现类而不测装配，恰恰漏掉了最隐蔽的那种失败。

此外，与外部中间件对接的插件应当用真实中间件（Testcontainers）而非 mock 验证：
这类插件的价值就在于"与真实语义一致"，mock 掉就等于把要验证的部分假设成立了。

### 9. 契约一致性

插件实现与核心默认实现必须遵守同一份 SPI 语义。建议测试用例与核心实现的用例**一一对应**——
两种实现的行为差异如果存在，应当出现在测试里，而不是出现在生产环境。

### 10. 认证类插件取得 userId 的两种方式

- **凭证已是核心字段**（如手机号、邮箱）：直接注入 `SysUserService`，调
  `findByMobile`/`findByEmail` 拿到 `SysUser`，取 `getId()`。
- **凭证是外部系统的标识**（如第三方 OAuth 的 openId）：插件自建映射表
  （如 `sys_user_oauth_binding(user_id, provider, open_id)`），自己维护换算关系，
  **不碰核心 `sys_user`**。

两种方式殊途同归：拿到 `userId` 后，都调用核心的
`AuthUserLoader.loadByUserId(Long userId)`（`framework-security-starter` 提供的
default 方法，`framework-system-starter` 的 `DbAuthUserLoader` 已实现）拿到角色/
权限/数据权限/首页路径俱全的 `AuthUser`，不要重新查 `sys_role`/`sys_user_role`
之类的表自己拼一遍。

这也是"SPI 新增方法一律写成 `default`、默认给出安全的空实现"这条约定第二次落地
（第一次是 `TokenStore.listActive()`）。以后任何 SPI 新增方法都按这个手法处理。

---

## 仓库归属：独立成仓（已完成）

按方案 3.1.1，**每个插件独立仓库**。`framework-cache-redis-starter` 已于框架 0.2.0
开发期从 framework 仓拆出，是这条拓扑的第一个落地样本。**后续插件直接按独立仓建，
不要再放进 framework 仓当 module** —— 同仓每多一个，迁移成本就翻一倍。

拆仓消除的两个代价：

- **版本线绑定**：框架发 0.3.0，插件即使一行没改也得跟着发；插件要修个 bug，
  也得等框架的发布窗口
- **发布捆绑**：framework 的 `mvn deploy` 会把插件一起推上 Central，
  插件数量上去之后会持续挤占框架的发布节奏

### 新建一个插件仓时照着做

1. 建 `github.com/describeadmin/framework-<能力>-starter`
2. POM **不继承 `framework-parent`**，自带一份精简父配置，并以 `import` 方式引入
   `framework-bom` —— 这正是业务方消费框架的姿势，插件用同一套姿势才能提前暴露
   业务方会遇到的问题；继承 `framework-parent` 反而会把这些问题遮住
3. 自带的构建配置一条都不能少，它们都是硬约束而非偏好：
   `release=17`、surefire 的 UTF-8、enforcer 的 `requireJavaVersion [17,)` + JDBC 驱动 + Jackson 3 三条。
   **不要带 `maven-toolchains-plugin`**（钉死构建 JDK 只会劝退没配 `~/.m2/toolchains.xml` 的人，
   `requireJavaVersion` 兜底即可，见 `develop_plan.md` 2.2.2「第八轮修订」）；
   **也不要带 `enforce-core-thin`** —— 插件的职责就是引入那些重依赖
4. 框架版本写成属性（`<describeadmin.version>`）而不是字面量，CI 的兼容性矩阵靠覆盖它来跑
5. 在 `repos.yml` 登记，group 为 `ext`；在本文件的表格里登记
6. CI 加**框架版本矩阵**（准入规范第 5 条）

> ⚠️ 拆仓最容易漏的是**从父 POM 继承来的隐式依赖**。
> `framework-parent` 的 `<dependencies>` 给每个模块白送了 lombok 与
> `spring-boot-starter-test`，独立成仓后必须自己声明。
> 漏了要到编译测试时才报错，而报错信息指向的是"找不到 JUnit"，不指向拆仓这件事。
