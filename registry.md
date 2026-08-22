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
| Redis 缓存与会话 | [`framework-cache-redis-starter`](https://github.com/describeadmin/framework-cache-redis-starter) | `CacheProvider`、`TokenStore` | **0.2.0** | 待发布 | 解除内存实现的两条局限：重启掉线、不支持多实例。用到 0.2.0 引入的 `TokenStore.listActive()` 与 `ActiveSession` |

> 「待发布」= 代码与 CI 就绪，但尚未推 Maven Central。
> 插件 `import` 的 `framework-bom` 必须是**已发布**的版本，因此它要等框架 0.2.0 先上 Central。

## 规划中

| 插件 | 实现的 SPI | 说明 |
|---|---|---|
| 浙政钉登录 | `AuthProvider` | 政务场景登录 |
| 钉钉消息推送 | `NotifyChannel` | 工作通知类推送 |
| 企业微信登录/推送 | `AuthProvider` / `NotifyChannel` | 按业务方需求排期 |
| 短信通道 | `NotifyChannel` | 验证码、通知短信 |

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
   toolchains + `release=17`、surefire 的 UTF-8、enforcer 的 JDBC 驱动与 Jackson 3 两条。
   **唯独不要带 `enforce-core-thin`** —— 插件的职责就是引入那些重依赖
4. 框架版本写成属性（`<describeadmin.version>`）而不是字面量，CI 的兼容性矩阵靠覆盖它来跑
5. 在 `repos.yml` 登记，group 为 `ext`；在本文件的表格里登记
6. CI 加**框架版本矩阵**（准入规范第 5 条）

> ⚠️ 拆仓最容易漏的是**从父 POM 继承来的隐式依赖**。
> `framework-parent` 的 `<dependencies>` 给每个模块白送了 lombok 与
> `spring-boot-starter-test`，独立成仓后必须自己声明。
> 漏了要到编译测试时才报错，而报错信息指向的是"找不到 JUnit"，不指向拆仓这件事。
