# 当前进度

> **本文件回答一个问题：现在到哪了，下一步做什么。**
>
> 与其他文档的分工——`develop_plan.md` 写「为什么这么设计」，`VERSION_BASELINE.md` 写
> 「已核验的事实」，`registry.md` 写「插件有哪些、怎么写」，本文件写**状态**。
> 状态会过期，所以每次收工前更新它；论证不会过期，所以不要往这里写论证。

**最后更新：2026-08-24（阶段 G 完成：JSON 序列化约定 + 可注入 `Clock` + `TreeBuilder` 上提，
跨 framework / codegen / frontend / sample-frontend 四仓，本地已改完待提交）**

***

## ⚠️ 先看这个：五个 PR 待合并

**0.2.0 的全部工作已提交并推送，但都还在分支上没合进 main。**
框架的 `main` 因此仍是 **0.1.1**，下次开工前先确认这一点。

| 仓库           | PR                                                       | CI   | 说明                     |
| ------------ | -------------------------------------------------------- | ---- | ---------------------- |
| `framework`  | [#1](https://github.com/describeadmin/framework/pull/1)  | ✅ 全绿 | **先合这个**，其余两个仓的 CI 依赖它 |
| `docs`       | [#1](https://github.com/describeadmin/docs/pull/1)       | 无 CI | 本文件 + `registry.md`    |
| `codegen`    | [#1](https://github.com/describeadmin/codegen/pull/1)    | ✅ 通过 | 不依赖 framework，可随时合     |
| `frontend`   | [#1](https://github.com/describeadmin/frontend/pull/1)   | —    | 仅 `CLAUDE.md` 同步       |
| `sample-app` | [#1](https://github.com/describeadmin/sample-app/pull/1) | ❌ 见下 | **合完 framework 后重跑即绿** |

> **2026-08-22 追加**：登录模块 A/B/C/D/E 项修复 + 邮箱验证码登录插件（见下方新增章节）
> 又在四个仓各开了一条分支，**都还没开 PR**，只是推了分支：
> `framework`（`feat/0.2.0-permission-cache-plugin`，本轮三个提交直接续在这条分支上，
> 与本表格里的 `framework` PR #1 是同一条分支）、`framework-cache-redis-starter`
> （新分支 `feat/token-refresh-and-keys-with-prefix`）、`sample-app`（本轮提交续在
> 已有的 `test/0.2.0-permission-online-lockout` 分支上）、`frontend`（新分支
> `feat/email-login-and-refresh-token`，注意它是从 `chore/sync-claude-md` 切出的——
> 那条分支本身还有 6 个提交没推到远端，见该仓 `git log main..chore/sync-claude-md`）。
> 新插件 `framework-auth-email-starter` 代码已写好并测试通过，**远端仓库已于
> 2026-08-22 建好并推送**（`master` 分支，人工确认后由 AI 建仓）——
> 见 `docs/repos.yml`/`registry.md` 对应条目，状态已改回「待发布」。

**`sample-app`** **与插件仓的 CI 现在都是红的，原因相同**——两者的 CI 都会去拿
`describeadmin/framework` 的 `main`，而那里还是 0.1.1：

```
Could not find artifact io.github.describeadmin:framework-bom:pom:0.2.0-SNAPSHOT
##[error]框架仓 main 当前是 0.1.1，矩阵要的是 0.2.0-SNAPSHOT。
```

插件仓那条是**守卫步骤主动报的**，设计如此——静默用错版本比直接失败更糟。
合并 framework#1 后重跑这两个仓的 CI 即可转绿。

| 仓库                              | Central / npm | GitHub main                |
| ------------------------------- | ------------- | -------------------------- |
| `framework`                     | **0.1.1**     | 0.1.1（0.2.0 在 PR #1 里）     |
| `framework-cache-redis-starter` | 未发布           | `0.2.0-SNAPSHOT` ✅ 已在 main |
| `frontend`                      | 未发布           | `0.1.0`                    |
| `codegen`                       | 未发布           | —                          |

***

## 下一步（按依赖顺序）

1. **合并 framework#1**，然后重跑 `sample-app` 与插件仓的 CI。
   它是两件事的共同前提：那两个仓的 CI 转绿、插件能发 Central。
   其余四个 PR 合并顺序不限。阶段 D\~F 已经在同一条分支
   （`feat/0.2.0-permission-cache-plugin`）上跟着做完并验证过，不必单独等这一步——
   合并后 D\~F 的改动自然一起进 main。**分支目前已积了 A\~F 六个阶段，别再让差距继续拉大，
   合并 framework#1 后尽快切一次。**
2. **阶段 H：厂商插件（浙政钉登录、钉钉推送）**。是当前分支尚未做的第一个阶段（原编号 G，
   因 JSON 序列化那批插队而顺延），
   需要新开插件仓（浙政钉登录用 `AuthProvider`、钉钉推送用阶段 F 刚交付的
   `NotifyChannel`），按 `docs/registry.md` 的六步流程走，独立成仓、不进 framework reactor。
3. **framework 0.2.0 发 Maven Central** → 之后插件才能跟着发。
   顺序不可颠倒：插件 `import` 的 `framework-bom` 必须是 Central 上**真实存在**的已发布版本。

***

## 阶段进度

分期定义见已批准的能力规划（核心/插件判据 + A\~G 分期）。

| 阶段    | 内容                                                                      | 状态        |
| ----- | ----------------------------------------------------------------------- | --------- |
| **A** | 接口权限校验 + framework 单测底座                                                 | ✅ 完成      |
| **B** | `CacheProvider` SPI + 内存实现；拦截器链扩展缝；`TokenStore` default 方法 + 在线用户端点     | ✅ 完成      |
| **C** | `framework-cache-redis-starter`（第一个真实插件）+ 独立成仓                          | ✅ 完成（未发布） |
| **D** | 数据权限 + `sys_dept.ancestors`                                             | ✅ 完成（未合并） |
| **E** | 字典 + 参数配置 + 操作日志                                                        | ✅ 完成（未合并） |
| **F** | `framework-storage-starter` + `framework-notify-starter`（SPI + 零依赖默认实现） | ✅ 完成（未合并） |
| **G** | JSON 序列化约定 + 可注入 `Clock` + `TreeBuilder` 上提                              | ✅ 完成（未合并） |
| **H** | 厂商插件（浙政钉登录、钉钉推送）                                                        | ⬜         |

### A\~C 实际产出

**framework 侧（未提交）**

- 新模块 `framework-cache-starter`：`CacheProvider` + `InMemoryCacheProvider`
- `framework-common`：`PermissionChecker`、`FrameworkVersion`（插件版本自检）
- `framework-security-starter`：`SecurityContextPermissionChecker`、`SecurityExceptionHandler`、
  `LoginAttemptGuard`、`ActiveSession`、`TokenStore.listActive()`
- `framework-mybatis-starter`：`BaseController.permPrefix()` / `requirePermission()`、
  `MybatisPlusInterceptor` 收集 `InnerInterceptor`
- `framework-system-starter`：`SysOnlineController`（在线用户 / 强制下线）
- 四个模块的首批单测；surefire 补上 `-Dfile.encoding=UTF-8`
- 父 POM enforcer 拆成 `enforce-rules` + `enforce-core-thin` 两个 execution

**插件仓（已推）**：见该仓 `CHANGELOG.md`。

### D 实际产出

同一条分支（`feat/0.2.0-permission-cache-plugin`）上跟着 A\~C 一起做，未单独开分支：

- `framework-common`：`DataScopeType`、`DataScopeContext`、`DataScopeProvider`（新 SPI，
  与 `CurrentUserProvider` 同一范式）
- `framework-mybatis-starter`：`DataScopeTableCustomizer`（表登记 SPI）、
  `DeptDataPermissionHandler`（`MultiDataPermissionHandler` 实现，复用 MP 自带的
  `DataPermissionInterceptor`，未新增依赖）；`FrameworkMybatisAutoConfiguration` 新增
  拦截器 Bean——完全靠 0.2.0 已有的 `ObjectProvider<InnerInterceptor>` 收集点接入，
  没有改动那个方法本身
- `framework-security-starter`：`AuthUser`/`LoginUser` 新增 `deptId`/`dataScope`/
  `customDeptIds` 三个字段（保留旧构造函数重载）、`SecurityContextDataScopeProvider`
- `framework-system-starter`：`sys_dept.ancestors` 物化路径维护（`SysDeptService`
  的 `createDept`/`updateDept`，含移动部门的级联更新与成环校验）、
  `sys_role.data_scope` + `sys_role_dept`、`DataScopeResolver`（多角色合并，纯函数）、
  `DbAuthUserLoader` 登录时解析数据权限、`SysRoleController` 新增
  `.../{roleId}/depts` 端点
- `schema-rbac.sql`/`seed-rbac.sql` 相应更新：**这是一次破坏性 schema 变更**，
  升级前已建库的开发/测试环境需要重建（`CREATE TABLE IF NOT EXISTS` 不会给已存在的表加列）

### E 实际产出

同一条分支上继续做，未单独开分支：

- `framework-mybatis-starter`：`BaseController.permPrefix()` 从 `protected` 放宽为
  `public`，供操作日志切面跨包读取——业务方若自己覆写过这个方法要同步放宽可见性
  （`sample-app` 的 `ProjectController` 已同步，且因为踩了这个坑补充确认：
  Maven 增量编译在"依赖 jar 的方法可见性变了但本模块源码没变"这种情况下
  **不会**触发重新编译，本地/CI 都得留意，遇到运行期"Unresolved compilation
  problem"这类怪异报错先想到这条）
- `framework-system-starter`：新增 `sys_dict_type`/`sys_dict_data`/`sys_config`/
  `sys_oper_log` 四张表；`SysDictTypeController`/`SysDictDataController`/
  `SysConfigController`（标准 CRUD，字典与参数配置读穿 `CacheProvider`）；
  `SysOperLogController`（不继承 `BaseController`，只读 + 清空）；
  `OperLogAspect` + `@OperLog` 注解（两条切入路径：`BaseController+` 的
  create/update/delete 自动记录，自定义端点显式标注）；新增对
  `framework-cache-starter`、`spring-boot-starter-aop` 的依赖
- `schema-rbac.sql`/`seed-rbac.sql` 相应更新：同样是破坏性 schema 变更，
  与阶段 D 那次一起重建库即可，不必分两次

### F 实际产出

同一条分支上继续做，未单独开分支。与 B（`CacheProvider`）不同的是，本阶段**没有**
新增数据库表——F 的定义就是"契约 + 零依赖默认实现"，持久化与端点都留给后续消费方
（业务代码或阶段 G 的厂商插件）：

- 新模块 `framework-storage-starter`：`StorageProvider`（`put`/`get`/`exists`/
  `remove`/`url` 五个方法，另加 `default String presignedUrl(key, expiry)`）+
  `LocalFileStorageProvider`（零依赖本地磁盘实现，防路径穿越、覆盖开关可配）。
  不依赖 `spring-boot-starter-web`，`url()` 只返回拼接出的虚拟路径字符串，
  能否真正提供 HTTP 下载由业务方或未来的 OSS 插件负责——与
  `InMemoryCacheProvider`"单机可用，生产换 Redis 插件"是同一组取舍。
  `presignedUrl` 是设计评审时补的扩展点：S3 兼容存储的真实部署几乎总是私有桶，
  `url()` 返回的地址通常不可访问，业务方应改用 `presignedUrl` 取限时签名地址；
  本地实现没有"签名"概念，`default` 方法退化为 `url()` 即可，不需要重写
- 新模块 `framework-notify-starter`：`NotifyChannel`（`channel()`/`send()`）+
  `NotifyDispatcher`（按 `channel()` 键收集、路由，构造期发现重复标识/空标识立即
  抛异常，`send()` 遇到未注册渠道也抛异常而非静默丢弃）+ `LogNotifyChannel`
  （零依赖日志渠道，标识固定为 `"log"`，与任何插件渠道永久共存，不是"占位后被替换"）。
  **这是本阶段与** **`CacheProvider`/`TokenStore`** **模式的唯一实质分歧**：通知天然多实现
  共存，不是"单一默认实现 + `@ConditionalOnMissingBean` 整体替换"的形状——未来的
  通知插件（钉钉/企业微信/短信）**不能**照抄 `framework-cache-redis-starter` 那种
  `@ConditionalOnMissingBean(NotifyChannel.class)` 写法，否则会被核心已注册的
  `LogNotifyChannel` 静默挡掉；插件渠道应无条件注册（只受自身
  `@ConditionalOnProperty` 控制），真正的冲突检测交给 `NotifyDispatcher` 构造函数
  ——两个类的 javadoc 都已把这条陷阱写清楚
- `framework/pom.xml` 的 `enforce-core-thin` 顺带补上了此前缺失的排除坐标
  （阿里云 OSS/腾讯云 COS/AWS S3/MinIO 等对象存储 SDK，钉钉/企业微信/短信等厂商
  推送 SDK）——此前这条约束只是 pom 头部注释里的君子协定，没有构建期强制力
- 两个模块的单测均对齐 `InMemoryCacheProviderTest` 的风格（`@Nested`/`@DisplayName`
  分组 + AssertJ 断言），含并发正确性测试（`LocalFileStorageProviderTest` 并发写入
  不同 key、`NotifyDispatcherTest` 并发 send 调用不丢失）；`LogNotifyChannelTest` 用
  Logback `ListAppender` 断言日志的**具体内容**而非"有没有打印一行日志"，直接对应
  CLAUDE.md 3.6 的测试规范

### G 实际产出

同一条分支上继续做，未单独开分支。**这批是跨仓的**——framework 改了序列化行为，
codegen 与三份前端 `auth.ts` 必须同批跟上，否则生成的前端类型与实际返回值对不上。

**framework**

- `framework-web-starter`：`FrameworkJsonModule`（`Long`/`long` → 字符串、
  时间格式出严进宽）+ `LongToStringSerializer`（实现 `ContextualSerializer`
  以尊重 `@JsonFormat(shape = NUMBER)`）+ `describeadmin.web.json.*` 配置项。
  **本模块此前一个测试都没有**，本批建立测试底座：24 个用例
- `framework-common`：`PageResult` 的四个分页元信息 getter 加
  `@JsonFormat(shape = NUMBER)`；`TreeBuilder` 从 framework-system-starter 上提到 `api/` 包
- `framework-mybatis-starter`：`Clock` Bean（`@ConditionalOnMissingBean`）+
  `AuditMetaObjectHandler` 改从 `Clock` 取时间（保留原两个构造函数为重载）
- `framework-system-starter`：原 `core/TreeBuilder` 改为
  `@Deprecated(forRemoval = true, since = "0.2.0")` 转发类，0.3.0 移除

**codegen**：`tsType(LONG)` → `string`、`controlOf(LONG)` → `ElInput`、
`initialValue(LONG)` → `''`，审计接口的 `id`/`createBy`/`updateBy` 与
`update*Api`/`delete*Api` 的形参、`editingId`/`deletingId` 全部改为 `string`。
`FrontendGeneratorTest` 补 5 个用例把这些契约钉住——**改之前这些类型没有任何断言覆盖**，
所以改完测试仍然全绿，这本身就是个信号。

**frontend / sample-frontend**：三份 `auth.ts`（`apps/admin`、
`packages/create-app/template`、`sample-frontend`）的 `userId` 与 `BackendMenu.id`
改为 `string`。

#### 这批必须知道的三件事

1. **不要自己声明 `@Bean ObjectMapper`**。会顶掉 Boot 全部默认配置并让业务方的
   `spring.jackson.*` 失效。改约定一律加 `Module` Bean。
2. **`long`（原始类型）与 `Long`（包装类型）在 Jackson 里是分别查找序列化器的。**
   本批两者都注册了。曾考虑"只注册包装类型"作为分页元信息的天然分界线，
   但那依赖"id 恰好写成 `Long`、分页字段恰好写成 `long`"的巧合，
   业务方随手写 `private long id` 就会漏且毫无提示——改用 `@JsonFormat(shape = NUMBER)`
   显式排除。
3. **`strictInsertFill` 依赖 `TableInfo`**（字节码实测，见 VERSION_BASELINE 发现 ㉑）。
   拿普通 POJO 的 `MetaObject` 调它什么都不会填充，**也不报错**。
   测审计填充必须先 `TableInfoHelper.initTableInfo(...)`。

### 验证基线（阶段 G，全绿，2026-08-24）

| 线 | 结果 |
| --- | --- |
| framework 单测 | **151/151**（本批新增 32：web-starter 24、mybatis 4、common 4） |
| codegen 单测 | **45/45**（本批新增 5，钉住 `long` → `string` 的生成契约） |
| framework `clean verify -Prelease -Dgpg.skip=true` | 通过（含 `enforce-core-thin`；本批零新增依赖） |
| `frontend/apps/admin` 类型检查 | 通过 |
| `sample-frontend` 类型检查 | 1 个**既有**错误（`router/guard.ts:107`），stash 后同样复现，与本批无关 |
| codegen 生成物目视核对 | `examples/project.yaml` 生成的 `.ts`/`.vue` 已逐项确认（`ownerDeptId` 为 string + ElInput、分页元信息仍为 number、`ElInputNumber` 仍被 `budget` 用到所以 import 未失效） |

> **下面这张表是阶段 F 时的快照，`98/98` 的数字已过期**（F 之后的登录模块修复与
> 邮箱登录插件又加过用例），保留是为了对照当时的 IT 覆盖情况。
> 本批**没有**重跑 MySQL 5.7/8.4 的 sample-app 集成测试——那需要 Docker 环境，
> 且本批改动是序列化层，未触及 SQL。合并前应补跑一次，重点看带 `datetime`
> 字段的模块（当前 sample-app 里没有这样的字段，需要先加一个）。

### 验证基线（0.2.0 + D + E + F，全绿）

| 线                                                  | 结果                                      |
| -------------------------------------------------- | --------------------------------------- |
| framework 单测                                       | 98/98（新增 storage 15、notify 12）          |
| 插件（独立仓）                                            | 31/31                                   |
| sample-app IT @ MySQL **5.7**                      | 64/64                                   |
| sample-app IT @ MySQL **8.4**                      | 64/64                                   |
| framework `clean verify -Prelease -Dgpg.skip=true` | 通过（含 `enforce-core-thin`，新增排除坐标未误伤现有模块） |

> `AbstractMySqlIntegrationTest` 默认镜像是 **5.7**，跑 8.4 要显式加
> `-Dmysql.image=mysql:8.4`。只跑默认的那次等于只验证了一条线。

### 前端：system-ui + create-app 落地（2026-08-21）

对齐 develop\_plan.md §9.3.1/§9.3.2、`repos.yml` 里早先登记的 `planned` 交付物，
本轮把两者都做完并做了真实的外部消费验证（不是只看编译）：

- **新增** **`@describeadmin/system-ui`**（`frontend/packages/effects/system-ui`）：收纳
  系统管理四页面（dept/menu/role/user）+ 首页统计卡片（`dashboard/index`，随它一起搬走——
  它展示的是 `framework-system-starter` 四个实体的统计数，且 `component` 值被
  `seed-rbac.sql` 硬编码为登录后必须存在的首页路由，本质是框架基础设施不是业务内容）。
  接口层不内置 `requestClient`：导出 `provideSystemApiClient(client)`，认证头/过期重登
  策略仍由消费方决定（这层策略天然是应用可自定义的东西）。`apps/admin` 现在反过来
  依赖本包（`workspace:*`），`router/access.ts` 的 `pageMap` 与包导出的 `systemPageMap`
  合并——`ComponentRecordType` 本来就支持这种显式 key→组件 的合并方式，不需要改
  `generateRoutesByBackend`。
- **`apps/admin`** **改为框架自己的联调 playground**，不再是业务方起点（措辞对齐
  `sample-app` README 的等价表述）。同时删掉了 `views/project`/`api/project.ts`
  （codegen 产出的业务示例，不属于框架仓）与上游遗留的 `locales/langs/*/demos.json`。
- **新增** **`@describeadmin/create-app`**（`frontend/packages/create-app`）：
  `npm create @describeadmin/app <项目名>` 的实现包。`template/` 是收走 system-ui 后
  `apps/admin` 外壳的裁剪副本，`vite.config.ts`/`tsconfig*.json` 改为不依赖
  `internal/vite-config`、`internal/tsconfig`（那两个是框架自身构建工具，从未打算发给
  业务方）的自包含写法。`@describeadmin/*` 版本号来自 `src/versions.ts` 手工维护的清单
  （fixed 分组，全包共用一个版本号）——发布链路打通后应改为查询 registry，切换点已留成
  单一函数。三者（template、versions.ts、vite-config 写法）都需要手工同步，维护责任写在
  包内 README。
- **顺带修的一个真实 bug**：`@describeadmin/core-design` 的 CSS 通过裸 `@import`
  引用 `@describeadmin/tailwind-config/theme`，但从未把它声明为 `dependencies`——在
  monorepo 里靠隐式 hoisting 蒙混过去，真正外部安装时直接解析不到。已补上依赖声明，
  并把 `tailwind-config` 从 `internal/`（`private: true`）改为可发布（这个包的
  `/theme` 导出是运行时会被消费的 CSS，不是构建期工具，分类本来就不该在 `internal/`，
  只是暂时没精力挪目录，先解决"能不能被外部消费"）。`theme.css` 的 `@source` 新增一条
  `../../`，在原有四条 monorepo 专用路径之外，让业务方安装的 `node_modules/@describeadmin/`
  也能被 Tailwind 扫描到。
- **新建** **`sample-frontend`**（工作区根目录同级，`describe-admin/sample-frontend/`，
  与 `sample-app` 对称）：本地跑 `create-app` 生成骨架，`@describeadmin/*` 依赖用
  `pnpm pack` 出的本地 tarball + `pnpm-workspace.yaml` 的 `overrides` 模拟外部安装
  （脚本 `sample-frontend/scripts/pack-local-deps.sh`，效果等价于真实 npm 安装，
  省了真正发布这一步）。**已验证登录 → 菜单树 → system-ui 提供的用户/角色/菜单/部门
  管理 CRUD 全链路可用**，且全程只通过 `node_modules` 消费框架代码，未触达 `frontend/`
  任何源文件路径。
- **验证过程中发现一个纯环境问题，顺手修复**：本地 `da-mysql`（3307）建库早于阶段 D
  的 `data_scope`/`ancestors` schema 变更，`sample-app` 用旧库启动会在登录时报
  `NoClassDefFoundError`/`Unknown column 'data_scope'`——`framework/CHANGELOG.md` 已经
  写明这种情况需要重建库，本轮重建了一次（`DROP DATABASE` + 重启触发
  `spring.sql.init` 重新建表种子）。这不是本轮改动引入的问题，只是恰好在验证时撞上。

回归验证：`pnpm -F @describeadmin/admin run typecheck` / `build` 均通过，
`pnpm run check:circular` 未新增循环依赖（既有的三条循环与本次改动无关，在
`@core/ui-kit/form-ui` 和 `effects/plugins/vxe-table` 里，本轮未触碰）。

### 前端追平：dict/config/oper-log/online + 角色数据权限表单（2026-08-21）

上一轮"前端：system-ui + create-app 落地"记录的两条前端欠账（在线用户页面未写、
角色数据权限表单未画），加上本轮探查时发现的一个更紧急的问题——字典/参数配置/
操作日志三个菜单在 `seed-rbac.sql` 里是 `visible=1`，但 `@describeadmin/system-ui`
的 `src/views/` 下完全没有对应目录、`systemPageMap` 也没注册这几个 key，**三个入口
点开就是静默 404**，不是"部分实现"——本轮一并解决：

- **新增四个页面**（均进 `@describeadmin/system-ui`，不进 `apps/admin`，理由同
  dept/menu/role/user）：`views/dict/index.vue`（字典类型 + 字典数据左右两栏，
  字典数据没有服务端按 `dictType` 过滤——`SysDictDataController` 未覆写
  `buildListWrapper`——前端整批拉取 `size=500` 后客户端过滤，量级上可接受，
  后续如果字典数据规模变大需要回头给后端加真正的服务端过滤）、
  `views/config/index.vue`（标准单表 CRUD）、`views/oper-log/index.vue`
  （只读列表 + 模块/操作人/状态/时间范围筛选栏——这是四个新页面里唯一带筛选栏的，
  因为后端 `SysOperLogController.list` 本就支持这些查询参数——+ 单条删除 + 清空）、
  `views/online/index.vue`（只读列表，无分页，强制下线）
- **角色页补数据权限**：`views/role/index.vue` 表单加 `dataScope` 下拉
  （`DATA_SCOPE_OPTIONS`，新增在 `api/types.ts`），表格操作列加"分配数据权限"
  按钮——仅当 `dataScope === CUSTOM(2)` 时可点击，非 CUSTOM 时 disabled 并提示，
  对照后端 `SysRoleService.assignDataScopeDepts` 的 javadoc（非 CUSTOM 角色调用不报错
  但写入的部门列表不会被数据权限拦截器读取）在 UI 层提前拦截而不是让用户点了发现没生效。
  分配对话框结构照抄"分配菜单"（`ElTree` + `show-checkbox`），半选父节点同样要
  一并提交
- **`api/types.ts`/`api/index.ts`** 新增五个实体接口（`SysDictType`/`SysDictData`/
  `SysConfig`/`SysOperLog`/`ActiveSession`）与对应接口封装，`SysRole` 加 `dataScope`
  字段；`api/index.ts` 新增 `getRoleDeptsApi`/`assignRoleDeptsApi`
- **`seed-rbac.sql`**：在线用户菜单的 `visible` 从 0 改回 1（该行注释此前明确写了
  "前端页面落地后把这里改成 1"），这是本轮唯一改动 `framework` 仓的地方——纯种子数据，
  不是框架代码
- 字典/字典数据表单用了本地的 `DictTypeForm`/`DictDataForm` 接口而不是直接
  `reactive<SysDictType>`——`status` 字段在实体上可空，`ElSwitch` 的 v-model 不接受
  null，与 `dept/index.vue` 的 `DeptForm` 是同一处理方式

### 角色级自定义首页 home_path（2026-08-21）

用户发现"首页只有一个全局 `defaultHomePath`，业务方没有入口自定义"，且 Vben 内核
其实早留了 `userInfo.homePath` 这个优先级更高的覆盖位，只是后端从没填过。本轮把这条
腿接上，做**角色级**（不做用户级覆盖，用户已明确选择）：

- **`framework`**（`framework-security-starter` + `framework-system-starter`，
  同样在 `feat/0.2.0-permission-cache-plugin` 分支上，依赖阶段 D 加的
  `sort`/`data_scope`/`RoleScope` 这套基础设施）：
  - `sys_role` 新增 `home_path VARCHAR(191) NULL` 列（`schema-rbac.sql`）——**已建库
    的开发/测试环境需要重建或手动** **`ALTER TABLE`**，`CREATE TABLE IF NOT EXISTS`
    不会给存量表加列，这是阶段 D 的 `ancestors` 就踩过的同一个坑，本轮在本地
    `da-mysql` 上手动 `ALTER TABLE` 了一次
  - 新增 `HomePathResolver`（纯函数，风格对齐 `DataScopeResolver`）：多角色按
    `sort` 升序取第一个非空 `home_path`，全部为空则返回 `null`
  - `SysRelationMapper.selectDataScopesByUserId` 顺带查出 `home_path` 并加
    `ORDER BY r.sort`（首页合并需要确定性顺序，之前这条查询没排序）
  - `AuthUser`/`LoginUser`（均在 `api` 包，兼容性承诺范围）新增 `homePath` 字段，
    走新增构造函数重载而非改签名，不是 Breaking Change——手法与阶段 D 加
    `deptId`/`dataScope`/`customDeptIds` 时完全一致
  - `AuthController` 零改动：`/auth/login`、`/auth/me` 都是直接序列化整个
    `LoginUser`，加字段自动生效
  - 新增 `HomePathResolverTest`（5 例）+ `FrameworkRuntimeIT` 补两个用例
    （角色未设置首页时 `homePath` 为 `null`；设置后登录携带该路径），均用真实
    MySQL 5.7 Testcontainers 跑过
- **`frontend`**（`@describeadmin/system-ui`）：`api/types.ts` 的 `SysRole` 加
  `homePath` 字段；`views/role/index.vue` 编辑弹窗新增"首页"字段，`ElTreeSelect`
  数据源复用已有的 `getMenuTreeApi()`，只允许选中 `menuType === 'MENU'` 且有
  `path` 的真实页面节点，目录/按钮节点用 `disabled` 函数标灰仅做分组展示——避免
  选到假路径复现 `defaultHomePath` 那个已知的 404 坑
- **三处外壳文件同步改**（`sample-frontend`、`frontend/apps/admin`、
  `frontend/packages/create-app/template` 各自的 `src/api/core/auth.ts`）：
  `BackendLoginUser` 加 `homePath` 字段，`toUserInfo()` 从硬编码 `''` 改成
  `user.homePath ?? ''`。`router/guard.ts`/`store/auth.ts` **零改动**——
  `userInfo.homePath || preferences.app.defaultHomePath` 这条兜底逻辑本来就在等这个字段
- **chrome-devtools 端到端验证时发现一个真实的、值得记住的交互坑**：角色的
  "首页"和"分配菜单"是两个独立操作——只设置了 `home_path` 但没给该角色勾选对应菜单时，
  登录会直接落到该路径的 404（因为 backend 模式下前端的动态路由表是按
  `menuService.treeOf(userId)`——即该用户角色被授权的菜单——生成的，`home_path`
  指向的页面哪怕在 `sys_menu` 里真实存在，没被授权照样进不去）。这不是本轮实现的
  bug，是与既有 RBAC 路由生成机制的必然交互，但目前没有任何 UI 提示——授予
  `分配菜单` 之后重新登录验证通过（真实落到 `/system/dict`，无控制台报错）。
  **待办**：要不要在"首页"选择器或保存时提示"请确认已给该角色分配对应菜单"，
  还没做，下次碰这块时补上

回归验证：`mvn -f framework/pom.xml test -pl framework-security-starter,framework-system-starter -am`
全绿（含新增 5 例）；`sample-app` 的 `FrameworkRuntimeIT` 15 例全绿（含新增 2 例）；
`pnpm --filter @describeadmin/system-ui build` 通过；chrome-devtools 走完
"新建角色设首页 → 分配菜单 → 建用户 → 分配角色 → 登录验证落地路径"全链路。

回归验证：`pnpm -F @describeadmin/system-ui run build`、
`pnpm -F @describeadmin/admin run typecheck` / `build`、`pnpm run lint`、
`pnpm run check:circular`（未新增循环依赖）均通过。**未做**：起真实后端点一遍五个
页面的完整交互——后端 schema 已是 D~F 阶段的 `data_scope`/`ancestors`/`sys_dict_*`/
`sys_config`/`sys_oper_log`，本地 `sample-app` 数据库若还没按这套 schema 重建，
启动会在登录时报错（上一轮已踩过一次同类问题），下次有本地环境时应补这一步再收工。

### 登录模块 A/B/C/D/E 项修复 + 邮箱验证码登录插件（2026-08-22）

对照 `docs/LOGIN_MODULE_AUDIT.md`（2026-08-22 盘点）逐项修复，并交付插件把
F 项打下的地基（`sys_user.mobile`/`email` + `AuthUserLoader.loadByUserId`）用起来。

**`framework`**（`framework-security-starter`/`framework-system-starter`/
`framework-cache-starter`，续在 `feat/0.2.0-permission-cache-plugin` 分支）：

- **B 项**：`SysUserService.resetPassword()` 与 `SysUserController.update()`
  （检测 `status` 显式改为 0）末尾都补了 `tokenStore.revokeAllOf(userId)`
- **C 项**：新增 `SysUserService.changeOwnPassword()` + `PUT /api/auth/password`
  （`AuthController`），当前登录用户自助改密，不挂具体权限点（只需已登录）
- **D 项**（用户加码：不只查询，还要能手动解锁）：`CacheProvider` 新增
  `default Set<String> keysWithPrefix(String prefix)`；`LoginAttemptGuard` 新增
  `listLockedUsernames()`/`unlock()`；新增 `SysSecurityController`
  （`GET/DELETE /api/system/security/locked-accounts[/{username}]`，权限点
  `system:security:list`/`system:security:unlock`）——**必须用
  `ObjectProvider<LoginAttemptGuard>`** 而非直接注入，因为
  `FrameworkSystemAutoConfiguration` 声明了 `before = FrameworkSecurityAutoConfiguration`，
  `LoginAttemptGuard` 这个 Bean 在 system 侧装配时还不存在——这是 registry.md 准入
  规范第 3 条"引了却没生效"同款陷阱在核心内部两个 starter 之间的复现
- **E 项**（完整方案：access/refresh 双令牌）：新增 `api` 类 `IssuedTokens`；
  `TokenStore` 新增三个 `default` 方法 `issueWithRefresh`/`refresh`/
  `revokeRefreshToken`（`issue(LoginUser)` 签名不变，现有/新增 `AuthProvider`
  零改动）；`revokeAllOf` 的 javadoc 补充"必须同时吊销 refresh token"这条约束；
  `InMemoryTokenStore` 实现（`refresh()` 做轮换）；`FrameworkSecurityProperties`
  新增 `refresh-token.enabled`/`.ttl`；`AuthController` 新增
  `POST /api/auth/refresh`（免认证，加入 permit-all）；`LoginResult` 新增
  `refreshToken`/`refreshExpiresIn`（旧 3 参构造函数保留向后兼容）

**`framework-cache-redis-starter`**（新分支 `feat/token-refresh-and-keys-with-prefix`）：
`RedisCacheProvider.keysWithPrefix()` 用 `SCAN`（不用 `KEYS`，同
`RedisTokenStore.listActive()` 已确立的铁律）；`RedisTokenStore` 新增对称的
`refresh:`/`refresh-index:` 两组 key，`revokeAllOf` 同步吊销两组索引。

**新插件 `framework-auth-email-starter`**（已建仓并推送到
[GitHub](https://github.com/describeadmin/framework-auth-email-starter)，`master` 分支）：
邮箱验证码（无密码）登录，实现 `AuthProvider`
（`type()="email"`，`order()` 默认 0，排在内置 `password` 之后）+ 可选
`NotifyChannel(channel="email")`。取 userId 走 registry.md 准入规范第 10 条
第一种路径（`SysUserService.findByEmail` + `AuthUserLoader.loadByUserId`），
不新建任何映射表。`EmailCodeAuthProvider`/`NotifyChannel` **都无条件注册**
（不照抄 `CacheProvider` 那种 `@ConditionalOnMissingBean` 整体替换写法——两者都是
多实现共存模型），只受自身 `@ConditionalOnProperty` 与
`@ConditionalOnBean(JavaMailSender.class)` 控制，且该类**必须**声明
`after = MailSenderAutoConfiguration.class`（唯一必须的顺序约束，因为
`@ConditionalOnBean(JavaMailSender.class)` 是时序敏感判断）。发码接口
`POST /api/auth/email/code` 不区分邮箱是否已注册（防账号枚举，验证码仍会生成写入
`CacheProvider` 但不真正发信）。28 个测试全绿，含 GreenMail（纯 JVM 假 SMTP，
无需 Docker）真实收发验证，覆盖 registry.md 准入规范第 8 条"不引=行为不变"/
"引了=能力生效"两条路径。

**`sample-app`**（续在 `test/0.2.0-permission-online-lockout` 分支）：显式版本号
引入插件（`framework-bom` 不仲裁插件版本）+ `spring-boot-starter-mail`；
`application-local.yml` 追加 SMTP（本地默认 MailHog）+ `permit-all` 追加
`/api/auth/email/code`；新增 `AbstractGreenMailIntegrationTest`/`EmailLoginIT`
（真实 GreenMail 走一遍注册邮箱→发码→登录成功全链路）；`FrameworkRuntimeIT`/
`AuthFlowIT`/`LoginLockoutIT` 补齐 B/C/D/E 四项集成测试。**踩坑记录**：
`GlobalExceptionHandler` 把全部 `BizException`（含 `ResultCode.UNAUTHORIZED`）统一
映射成 HTTP 200 + 错误码，只有 Spring Security 过滤器链自身的拒绝才是真实 401/403——
第一版 `refresh` 相关测试按"业务异常≈HTTP 401"的错误假设写，实际跑起来才发现，
已改为断言响应体里的 `code` 字段。全部 90 个测试通过。

**`frontend`**（新分支 `feat/email-login-and-refresh-token`）：
- **A 项**：`apps/admin` 与 `packages/create-app/template` 的 `login.vue` 显式关闭
  `showCodeLogin`/`showQrcodeLogin`/`showRegister`/`showThirdPartyLogin`/
  `showForgetPassword`，删除对应四个死壳页面与路由，`page.json` 清理未用 key；
  共享组件 `third-party-login.vue` 删除微信/QQ/GitHub/Google 四个无 `@click`
  的纯装饰按钮（`DingdingLogin` 保留，前端 UI 组件不受 CLAUDE.md §4.6 约束，
  且已靠环境变量门控恒为空渲染）；登录提交按钮补 `data-testid`
- **邮箱登录 UI 地基**：`AuthenticationLogin` 新增 `showEmailLogin`（默认 `false`）/
  `emailLoginPath`，locales 新增 `authentication.emailLogin`
- **E 项前端接入**：`api/request.ts` 的 `doRefreshToken` 从"确定抛错的桩实现"换成
  真实调用 `refreshTokenApi`；`preferences.ts` 的 `enableRefreshToken` 由 `false`
  改 `true`；`store/auth.ts` 登录成功时存 `refreshToken`。
  **`authenticateResponseInterceptor` 的排队重放逻辑本来就是现成的**，只是被桩实现
  挡住了，这次不是新写而是接上
- **发现分支基点问题**：最初从 `main` 切的功能分支，导致 `request.ts` 缺了
  `@describeadmin/system-ui` 的 `provideSystemApiClient` 接入（`main` 落后于本地未推送的
  `chore/sync-claude-md` 6 个提交）——改从 `chore/sync-claude-md` 重新切分支，
  这正是 CLAUDE.md §7 反复强调的"本地已完成但未推上 GitHub 是常态"在实操中的复现

**`sample-frontend`**（无 GitHub 远端，纯本地仓库，新分支 `feat/email-login`）：
新增 `views/_core/authentication/email-login.vue`（复用共享
`AuthenticationCodeLogin` 组件）+ `sendEmailCodeApi` + `/auth/email-login` 路由；
`login.vue` 的 `showEmailLogin` 改为跟 `/api/auth/providers` 联动（修掉 A 项审计
指出的"开关不跟 providers 联动"缺口），`handleSubmit` 的 `type` 由脆弱的
`providers.value[0]` 改为硬编码 `'password'`；同步了 A/E 项在 apps/admin 侧的
其余改动。顺带修了 `scripts/pack-local-deps.sh`——它重新生成 `pnpm-workspace.yaml`
时会连带丢掉之前对 `allowBuilds`（`@parcel/watcher`/`vue-demi`）的手工修复，
现在脚本自己会把这两行也写出来。

**已知遗留**（下次开工前看一眼）：

- ~~`framework-auth-email-starter` 只完成到本地仓库，远端 GitHub 仓库还没建~~
  **已解决（2026-08-22）**：人工确认后已建仓并推送，见上方与 `registry.md`/`repos.yml`
- **追加发现并修复（2026-08-22，chrome-devtools 走查邮箱登录时撞见）**：
  `packages/effects/layouts` 的 `AuthenticationFormView`（`RouterView` 外层包
  `Transition`+`KeepAlive` 的布局壳）存在一个此前从未被撞见的既有缺陷——
  `<Transition mode="out-in"><KeepAlive :include="['Login']">` 这个组合下，
  "离开的是被 KeepAlive 缓存的组件（Login）、进入的是首次挂载的新组件"这条路径
  会卡死渲染成一个空注释节点，且没有任何报错/警告。症状是：直接访问
  `/auth/email-login` 完全正常，但从登录页点击"邮箱登录"按钮（前端路由内跳转）
  会跳出空白页。这个缺陷一直潜伏是因为 EmailLogin 之前 `/auth` 下从没真的存在过
  第二个有内容的跳转目的地。修复：去掉 `mode="out-in"`，退回同时过渡，已用真实
  点击链路验证。提交见 `frontend` 仓 `feat/email-login-and-refresh-token` 分支的
  `c014a91`，详见 `LOGIN_MODULE_AUDIT.md` A 项追加发现
- `sample-frontend` 的 `vue-tsc --noEmit` 会在 `@describeadmin/ui` 打出的
  `dist/components/api-component/api-component.vue.d.ts` 里报一个**与本轮改动无关的
  预置 bug**：`AnyPromiseFunction` 类型跨包解析失败，`rolldown-plugin-dts` 把它
  错误替换成字面量 `undefined`，产出 `beforeFetch: undefined<any, any>;` 这种不合法
  语法，导致 `.d.ts` 文件本身无法解析（`--skipLibCheck` 对语法错误不生效）。
  `apps/admin` 用 workspace 源码链接（不经过打包的 `dist`）跑 `vue-tsc` 完全正常，
  `sample-frontend` 的 `vite build`（生产构建）也完全正常，只有"消费打包后的
  `.d.ts` 再跑 `vue-tsc`"这条路径会撞上——本轮没有修，因为这是
  `@core/base/typings` 与 `common-ui` 之间类型重导出在 tsdown 构建链路上的一个更深的
  预置问题，超出本轮范围
- 四个仓库的新分支都还没开 PR，也没有合并进各自 main/master

***

### 敏感字段加密插件 framework-crypto-starter（2026-08-24）

用户提出"给业务方自己的实体做字段级敏感数据加密（身份证、手机号等）"需求，讨论定型为
独立插件（不进 framework 仓、不碰 `sys_user.mobile`/`email`），设计与实现均已完成：

- **`CryptoProvider` SPI**：多实现共存模型（仿 `NotifyChannel`/`NotifyDispatcher`，不是
  `CacheProvider` 那种单一默认实现整体替换模型）+ `CryptoDispatcher`（按 `algorithm()` 路由，
  构造期查重复标识直接失败；密文格式 `<算法>:<Base64(IV||密文+Tag)>` 自描述算法前缀，
  使换算法不需要迁移存量数据，同列新旧算法密文可共存）
- **内置两个算法**：`AesCryptoProvider`（AES-256-GCM，JDK 原生零依赖，默认可用）、
  `Sm4CryptoProvider`（SM4-GCM + HmacSM3，国密，面向政务/信创场景；Bouncy Castle 声明为
  `optional` 依赖，只用 AES 的业务方不受影响）。DES/3DES/ChaCha20 明确不做；SM2/格式保留
  加密（FPE）记入 registry.md"规划中"，不预先设计接口形状
- **`EncryptedStringTypeHandler`**（+ Aes/Sm4 两个子类）：MyBatis-Plus 字段级透明加解密，
  静态持有者模式桥接 Spring（TypeHandler 由 MyBatis 反射创建，不受 DI 管理）
- **`CryptoTemplate`**：手动加解密门面，覆盖自定义 Mapper 返回 Map/DTO、`JdbcTemplate`、
  批量脚本等 TypeHandler 覆盖不到、且不会报错的场景
- **`@BlindIndex` + `BlindIndexInnerInterceptor`**：盲索引自动填充，支持按明文精确查询加密
  字段（不支持模糊/范围查询）。**零框架核心改动**是本轮设计上最花时间验证的一点——
  MyBatis-Plus 全局只允许一个 `MetaObjectHandler`（核心 `AuditMetaObjectHandler` 已占用），
  改用 `framework-mybatis-starter` 已开放、面向外部模块的
  `ObjectProvider<InnerInterceptor>` 扩展点（`FrameworkMybatisAutoConfiguration` 的
  javadoc 早已写明这条扩展方式，只是此前没有真实案例用过），已用 `javap` 反编译
  MyBatis-Plus 3.5.17 字节码核实 `InnerInterceptor.beforeUpdate` 严格早于
  `MetaObjectHandler` 填充与 `TypeHandler` 加密的时序，不是凭印象判断
- **落地过程中发现并验证的一条真实陷阱**：`@TableField(typeHandler = ...)` 对
  INSERT/UPDATE 天然生效（typeHandler 内联在生成 SQL 的参数占位符里），但 **SELECT 必须
  配合实体上的 `@TableName(autoResultMap = true)`** 才会生效——缺了不报错，`selectById`
  正常跑完，只是拿到的是密文当明文用。这条是在 MySQL Testcontainers 集成测试第一轮跑
  失败后定位到的（单元测试测不出来，因为单元测试直接调 Provider，不经过 MyBatis-Plus 的
  ResultMap 生成逻辑），已写进插件 README 与 `EncryptedStringTypeHandler`/`BlindIndex`
  的 javadoc，示例代码全部带上这个属性
- **测试**：57 个全绿，含 `ApplicationContextRunner` 装配测试（多算法共存、独立开关、
  `default-algorithm` 误配启动即失败）+ 单元测试（GCM 篡改检测、盲索引确定性、
  `CryptoDispatcher` 构造期查重、`BlindIndexInnerInterceptor` 反射层）+ MySQL 5.7/8.4
  双版本 Testcontainers 端到端集成测试（绕开 ORM 直接查裸列确认存的是密文、AES/SM4
  同列密文共存且互相能正确解密、篡改密文触发异常、盲索引精确查询、partial update
  不覆盖已有密文/索引列）
- `mvn clean verify -Prelease -Dgpg.skip=true` 验证通过，能产出 Central 要求的三件套

**已解决（2026-08-24）**：`gh repo create` 最初被 Claude Code 的权限分类器拦下（创建公开
仓库属于对外操作），用户显式确认后已建仓并推送：
[github.com/describeadmin/framework-crypto-starter](https://github.com/describeadmin/framework-crypto-starter)
（`master` 分支）。`docs/registry.md`/`repos.yml` 已同步改回"待发布"/`active`，与
`framework-auth-email-starter` 一样等 framework 0.2.0 先发 Central 才能跟着发。

## 已知欠账

**前端**（每进核心一个模块就多一页）

- **`@describeadmin/create-app`** **的** **`template/`** **与** **`apps/admin`** **靠手工同步**，没有
  自动化机制——`apps/admin` 的 router/layouts/adapter 等外壳代码变了，容易忘记同步
  `template/`，包内 README 写了这条维护责任但没有 CI 校验兜底
- **`internal/tailwind-config`** **只是拿掉了** **`private: true`，没有搬出** **`internal/`**：
  它的 `/theme` 导出是运行时会被消费的 CSS，分类上更应该在 `packages/` 而非
  `internal/`（后者语义是"框架自身构建工具，从不发给业务方"）。目录搬迁涉及改
  `pnpm-workspace.yaml`、`repos.yml` 与全部引用，本轮为了不放大改动范围没做，
  先解决了"能不能被外部消费"这一个具体问题

**登录模块**

- 完整清单见 **`docs/LOGIN_MODULE_AUDIT.md`**（2026-08-22 梳理，同日已更新各项进展）。
  A/B/C/D/E 五项已修复（见上方新增章节），F 项的地基（`mobile`/`email` 核心字段 +
  `loadByUserId`）与"邮箱验证码登录"这一半能力也已交付（`framework-auth-email-starter`）。
  **仍未立项**：手机验证码登录本身（`MobileCodeAuthProvider` 一类的实现，需要短信
  通道，`docs/registry.md`"规划中"表里的"短信通道"尚未开工）；阶段 G 的厂商登录
  （浙政钉/企业微信）。

**codegen**

- `codegen` 仓的 Controller 模板大概率还生成 `protected String permPrefix()`——阶段 E
  把 `BaseController.permPrefix()` 放宽成了 `public`（操作日志切面需要跨包读取），
  `sample-app` 手写的 `ProjectController` 已经因为这条踩过一次编译错误并修复。
  `codegen` 仓当前未拉取到本地，没有核实/修改，下次碰 `codegen` 时先查这一条，
  不确认的话新生成的业务模块会在运行期抛
  `Error: Unresolved compilation problem`（而不是构建期报错，容易被忽略）。

**文档**

- `develop_plan.md` 第十章路线图仍是 v0.4 的阶段 -1\~6，与 A\~G 分期并行存在，尚未合并

**发布链路**

- `codegen` 仓没有 `release.yml`，发布链路未打通（framework 仓已有）
- 前端 `packages/` 结构上已经 publish-ready（`publishConfig`/`files`/`exports`/tsdown
  构建产物齐全，`system-ui`/`create-app`/`tailwind-config` 本轮补齐），但**从未真正
  执行过** **`changeset publish`**，npm registry 上没有任何 `@describeadmin/*`——本地验证
  改用 `pnpm pack` + `file:` 依赖（见 `sample-frontend/scripts/pack-local-deps.sh`），
  这条路径已验证可行，但终究是发布链路的替代品，不是发布链路本身

***

## 本轮定下的、容易忘的约束

1. **插件一律独立成仓**，不再进 framework 仓当 module。新建插件仓照 `registry.md`
   末节的六步做。
2. **`framework-bom`** **刻意不仲裁插件版本**。写进去会让业务方拿到一个与框架同号、
   根本不存在的制品，而报错只说"找不到"。
3. **插件必须声明最低框架版本**，三处保持一致：`registry.md` 表格、POM 里 import 的
   `framework-bom` 版本、代码常量 + `FrameworkVersion.requireCompatible()` 启动期自检。
   **只有第三处真正生效**。
4. **0.x 期间不要相信小版本兼容**。SemVer 对 `0.x` 不作保证，本项目 0.2.0 就带过
   Breaking Change；插件对每个框架小版本都要重新验证。
5. **数据权限的多角色合并规则是"取最宽松的单一档位"，不是按角色把条件 OR 起来**。
   这是阶段 D 明确权衡过的简化：OR 拼接在"本部门及以下"与"自定义部门"混用时条件会
   变复杂，V1 用简单规则换低风险。改这条规则要同时改
   `framework-system-starter` 的 `DataScopeResolver` 与它的单测，别只改一处。
6. **前端"框架包 + 消费方注入 requestClient"是刻意的分层，不是漏做**。
   `@describeadmin/system-ui` 不内置认证/token 过期/错误提示这些策略（那是应用层的事，
   不同业务方可能要不同处理），改用 `provideSystemApiClient(client)` 由消费方在
   `requestClient` 建好之后注入一次。以后新增类似"框架包需要网络请求"的场景，
   照这个模式做，不要在包里自建一个新的 axios 实例。
7. **`packages/effects/system-ui`** **导出的** **`systemPageMap`，key 必须与后端
   `sys_menu.component`** **规范化后的值逐字对上**（`/system/dept/index.vue` 这种形式，
   规则见 `generateRoutesByBackend` 的 `normalizeViewPath`）。写错的症状是静默 404，
   不会报错——新增页面时对照 `seed-rbac.sql`/`menu-*.sql` 核实，别凭记忆写。
8. **子类覆写** **`BaseController`** **的 create/update/delete 不需要额外标** **`@OperLog`**。
   Spring AOP 的 `execution(BaseController+.create(..))` 按方法签名匹配整个类型层级，
   覆写不影响命中；额外标注反而会让同一次调用被记两条日志。`@OperLog` 只用于
   方法名不是 create/update/delete 的自定义端点。
9. **操作日志切面必须捕获** **`Throwable`** **而不是只捕获业务失败**。`GlobalExceptionHandler`
   把 `BizException` 转成 HTTP 200 + 错误码，发生在 Spring MVC 的异常解析阶段，
   晚于 AOP 环绕通知——`OperLogAspect` 的 `catch` 块看到的是原始异常，
   这也是"失败的操作也要落日志"这条能成立的前提，改动异常处理链路时留意别破坏这个时序。

