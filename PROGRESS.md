# 当前进度

> **本文件回答一个问题：现在到哪了，下一步做什么。**
>
> 与其他文档的分工——`develop_plan.md` 写「为什么这么设计」，`VERSION_BASELINE.md` 写
> 「已核验的事实」，`registry.md` 写「插件有哪些、怎么写」，本文件写**状态**。
> 状态会过期，所以每次收工前更新它；论证不会过期，所以不要往这里写论证。

**最后更新：2026-08-21（阶段 E 完成）**

---

## ⚠️ 先看这个：五个 PR 待合并

**0.2.0 的全部工作已提交并推送，但都还在分支上没合进 main。**
框架的 `main` 因此仍是 **0.1.1**，下次开工前先确认这一点。

| 仓库 | PR | CI | 说明 |
|---|---|---|---|
| `framework` | [#1](https://github.com/describeadmin/framework/pull/1) | ✅ 全绿 | **先合这个**，其余两个仓的 CI 依赖它 |
| `docs` | [#1](https://github.com/describeadmin/docs/pull/1) | 无 CI | 本文件 + `registry.md` |
| `codegen` | [#1](https://github.com/describeadmin/codegen/pull/1) | ✅ 通过 | 不依赖 framework，可随时合 |
| `frontend` | [#1](https://github.com/describeadmin/frontend/pull/1) | — | 仅 `CLAUDE.md` 同步 |
| `sample-app` | [#1](https://github.com/describeadmin/sample-app/pull/1) | ❌ 见下 | **合完 framework 后重跑即绿** |

**`sample-app` 与插件仓的 CI 现在都是红的，原因相同**——两者的 CI 都会去拿
`describeadmin/framework` 的 `main`，而那里还是 0.1.1：

```
Could not find artifact io.github.describeadmin:framework-bom:pom:0.2.0-SNAPSHOT
##[error]框架仓 main 当前是 0.1.1，矩阵要的是 0.2.0-SNAPSHOT。
```

插件仓那条是**守卫步骤主动报的**，设计如此——静默用错版本比直接失败更糟。
合并 framework#1 后重跑这两个仓的 CI 即可转绿。

| 仓库 | Central / npm | GitHub main |
|---|---|---|
| `framework` | **0.1.1** | 0.1.1（0.2.0 在 PR #1 里） |
| `framework-cache-redis-starter` | 未发布 | `0.2.0-SNAPSHOT` ✅ 已在 main |
| `frontend` | 未发布 | `0.1.0` |
| `codegen` | 未发布 | — |

---

## 下一步（按依赖顺序）

1. **合并 framework#1**，然后重跑 `sample-app` 与插件仓的 CI。
   它是两件事的共同前提：那两个仓的 CI 转绿、插件能发 Central。
   其余四个 PR 合并顺序不限。阶段 D 已经在同一条分支
   （`feat/0.2.0-permission-cache-plugin`）上跟着做完并验证过，不必单独等这一步——
   合并后 D 的改动自然一起进 main。
2. **阶段 F：`framework-storage-starter` + `framework-notify-starter`**。E 已经和
   D 一样在同一条分支上做完并验证过，不必单独等第 1 步——但分支已经积了 A~E 五个阶段，
   建议合并 framework#1 后尽快切一次，别让差距继续拉大。
3. **framework 0.2.0 发 Maven Central** → 之后插件才能跟着发。
   顺序不可颠倒：插件 `import` 的 `framework-bom` 必须是 Central 上**真实存在**的已发布版本。

---

## 阶段进度

分期定义见已批准的能力规划（核心/插件判据 + A~G 分期）。

| 阶段 | 内容 | 状态 |
|---|---|---|
| **A** | 接口权限校验 + framework 单测底座 | ✅ 完成 |
| **B** | `CacheProvider` SPI + 内存实现；拦截器链扩展缝；`TokenStore` default 方法 + 在线用户端点 | ✅ 完成 |
| **C** | `framework-cache-redis-starter`（第一个真实插件）+ 独立成仓 | ✅ 完成（未发布） |
| **D** | 数据权限 + `sys_dept.ancestors` | ✅ 完成（未合并） |
| **E** | 字典 + 参数配置 + 操作日志 | ✅ 完成（未合并） |
| **F** | `framework-storage-starter` + `framework-notify-starter`（SPI + 零依赖默认实现） | ⬜ **下一个** |
| **G** | 厂商插件（浙政钉登录、钉钉推送） | ⬜ |

### A~C 实际产出

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

同一条分支（`feat/0.2.0-permission-cache-plugin`）上跟着 A~C 一起做，未单独开分支：

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

### 验证基线（0.2.0 + D + E，全绿）

| 线 | 结果 |
|---|---|
| framework 单测 | 71/71 |
| 插件（独立仓） | 31/31 |
| sample-app IT @ MySQL **5.7** | 64/64 |
| sample-app IT @ MySQL **8.4** | 64/64 |
| framework `clean verify -Prelease -Dgpg.skip=true` | 通过（含 `enforce-core-thin`） |

> `AbstractMySqlIntegrationTest` 默认镜像是 **5.7**，跑 8.4 要显式加
> `-Dmysql.image=mysql:8.4`。只跑默认的那次等于只验证了一条线。

### 前端：system-ui + create-app 落地（2026-08-21）

对齐 develop_plan.md §9.3.1/§9.3.2、`repos.yml` 里早先登记的 `planned` 交付物，
本轮把两者都做完并做了真实的外部消费验证（不是只看编译）：

- **新增 `@describeadmin/system-ui`**（`frontend/packages/effects/system-ui`）：收纳
  系统管理四页面（dept/menu/role/user）+ 首页统计卡片（`dashboard/index`，随它一起搬走——
  它展示的是 `framework-system-starter` 四个实体的统计数，且 `component` 值被
  `seed-rbac.sql` 硬编码为登录后必须存在的首页路由，本质是框架基础设施不是业务内容）。
  接口层不内置 `requestClient`：导出 `provideSystemApiClient(client)`，认证头/过期重登
  策略仍由消费方决定（这层策略天然是应用可自定义的东西）。`apps/admin` 现在反过来
  依赖本包（`workspace:*`），`router/access.ts` 的 `pageMap` 与包导出的 `systemPageMap`
  合并——`ComponentRecordType` 本来就支持这种显式 key→组件 的合并方式，不需要改
  `generateRoutesByBackend`。
- **`apps/admin` 改为框架自己的联调 playground**，不再是业务方起点（措辞对齐
  `sample-app` README 的等价表述）。同时删掉了 `views/project`/`api/project.ts`
  （codegen 产出的业务示例，不属于框架仓）与上游遗留的 `locales/langs/*/demos.json`。
- **新增 `@describeadmin/create-app`**（`frontend/packages/create-app`）：
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
- **新建 `sample-frontend`**（工作区根目录同级，`describe-admin/sample-frontend/`，
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

---

## 已知欠账

**前端**（每进核心一个模块就多一页）

- **在线用户菜单当前 `visible = 0`**：后端已可用，`system/online/index` 页面还没写。
  这个页面按今天的结论也该进 `@describeadmin/system-ui`（和 dept/menu/role/user 同类），
  不要加回 `apps/admin`。前端落地后要把种子数据改回 1
- **角色管理页还没有"数据范围"与"分配数据权限（自定义部门）"的表单**：后端
  `PUT /api/system/role`（`data_scope` 字段）与 `.../{roleId}/depts` 端点已可用，
  权限点 `system:role:assign-dept` 已登记，前端只是还没画出对应的表单控件
  （改动位置是 `system-ui` 包里的 `views/role/index.vue`，不是 `apps/admin`）
- **`@describeadmin/create-app` 的 `template/` 与 `apps/admin` 靠手工同步**，没有
  自动化机制——`apps/admin` 的 router/layouts/adapter 等外壳代码变了，容易忘记同步
  `template/`，包内 README 写了这条维护责任但没有 CI 校验兜底
- **`internal/tailwind-config` 只是拿掉了 `private: true`，没有搬出 `internal/`**：
  它的 `/theme` 导出是运行时会被消费的 CSS，分类上更应该在 `packages/` 而非
  `internal/`（后者语义是"框架自身构建工具，从不发给业务方"）。目录搬迁涉及改
  `pnpm-workspace.yaml`、`repos.yml` 与全部引用，本轮为了不放大改动范围没做，
  先解决了"能不能被外部消费"这一个具体问题

**codegen**

- `codegen` 仓的 Controller 模板大概率还生成 `protected String permPrefix()`——阶段 E
  把 `BaseController.permPrefix()` 放宽成了 `public`（操作日志切面需要跨包读取），
  `sample-app` 手写的 `ProjectController` 已经因为这条踩过一次编译错误并修复。
  `codegen` 仓当前未拉取到本地，没有核实/修改，下次碰 `codegen` 时先查这一条，
  不确认的话新生成的业务模块会在运行期抛
  `Error: Unresolved compilation problem`（而不是构建期报错，容易被忽略）。

**文档**

- `develop_plan.md` 第十章路线图仍是 v0.4 的阶段 -1~6，与 A~G 分期并行存在，尚未合并

**发布链路**

- `codegen` 仓没有 `release.yml`，发布链路未打通（framework 仓已有）
- 前端 `packages/` 结构上已经 publish-ready（`publishConfig`/`files`/`exports`/tsdown
  构建产物齐全，`system-ui`/`create-app`/`tailwind-config` 本轮补齐），但**从未真正
  执行过 `changeset publish`**，npm registry 上没有任何 `@describeadmin/*`——本地验证
  改用 `pnpm pack` + `file:` 依赖（见 `sample-frontend/scripts/pack-local-deps.sh`），
  这条路径已验证可行，但终究是发布链路的替代品，不是发布链路本身

---

## 本轮定下的、容易忘的约束

1. **插件一律独立成仓**，不再进 framework 仓当 module。新建插件仓照 `registry.md`
   末节的六步做。
2. **`framework-bom` 刻意不仲裁插件版本**。写进去会让业务方拿到一个与框架同号、
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
7. **`packages/effects/system-ui` 导出的 `systemPageMap`，key 必须与后端
   `sys_menu.component` 规范化后的值逐字对上**（`/system/dept/index.vue` 这种形式，
   规则见 `generateRoutesByBackend` 的 `normalizeViewPath`）。写错的症状是静默 404，
   不会报错——新增页面时对照 `seed-rbac.sql`/`menu-*.sql` 核实，别凭记忆写。
8. **子类覆写 `BaseController` 的 create/update/delete 不需要额外标 `@OperLog`**。
   Spring AOP 的 `execution(BaseController+.create(..))` 按方法签名匹配整个类型层级，
   覆写不影响命中；额外标注反而会让同一次调用被记两条日志。`@OperLog` 只用于
   方法名不是 create/update/delete 的自定义端点。
9. **操作日志切面必须捕获 `Throwable` 而不是只捕获业务失败**。`GlobalExceptionHandler`
   把 `BizException` 转成 HTTP 200 + 错误码，发生在 Spring MVC 的异常解析阶段，
   晚于 AOP 环绕通知——`OperLogAspect` 的 `catch` 块看到的是原始异常，
   这也是"失败的操作也要落日志"这条能成立的前提，改动异常处理链路时留意别破坏这个时序。
