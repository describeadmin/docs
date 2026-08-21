# 当前进度

> **本文件回答一个问题：现在到哪了，下一步做什么。**
>
> 与其他文档的分工——`develop_plan.md` 写「为什么这么设计」，`VERSION_BASELINE.md` 写
> 「已核验的事实」，`registry.md` 写「插件有哪些、怎么写」，本文件写**状态**。
> 状态会过期，所以每次收工前更新它；论证不会过期，所以不要往这里写论证。

**最后更新：2026-08-21**

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
2. **阶段 E：字典 + 参数配置 + 操作日志**。不必等发布，建议等第 1 步落定后再开工，
   避免这条分支越滚越大、和 main 的差距越拉越开。
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
| **E** | 字典 + 参数配置 + 操作日志 | ⬜ **下一个** |
| **F** | `framework-storage-starter` + `framework-notify-starter`（SPI + 零依赖默认实现） | ⬜ |
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

### 验证基线（0.2.0 + D，全绿）

| 线 | 结果 |
|---|---|
| framework 单测 | 67/67 |
| 插件（独立仓） | 31/31 |
| sample-app IT @ MySQL **5.7** | 57/57 |
| sample-app IT @ MySQL **8.4** | 57/57 |

> `AbstractMySqlIntegrationTest` 默认镜像是 **5.7**，跑 8.4 要显式加
> `-Dmysql.image=mysql:8.4`。只跑默认的那次等于只验证了一条线。
>
> `framework 单测`此前记为 81/81——核对后发现那个数字已经与仓库实际测试文件数对不上
> （实测只有 8 个测试类，加总 52），此处改为本次实测的确切值，不再沿用旧数字。

---

## 已知欠账

**前端**（每进核心一个模块就多一页）

- `@describeadmin/system-ui` 包尚未拆出，系统管理四个页面仍在 `apps/admin` 应用层——
  业务方复制走应用外壳后，框架对这些页面的修复到不了他们那里（方案 9.3.1 已诊断过一次）
- **在线用户菜单当前 `visible = 0`**：后端已可用，`system/online/index` 页面还没写。
  前端落地后要把种子数据改回 1
- **角色管理页还没有"数据范围"与"分配数据权限（自定义部门）"的表单**：后端
  `PUT /api/system/role`（`data_scope` 字段）与 `.../{roleId}/depts` 端点已可用，
  权限点 `system:role:assign-dept` 已登记，前端只是还没画出对应的表单控件

**文档**

- `develop_plan.md` 第十章路线图仍是 v0.4 的阶段 -1~6，与 A~G 分期并行存在，尚未合并

**发布链路**

- `codegen` 仓没有 `release.yml`，发布链路未打通（framework 仓已有）
- 前端 `packages/` 仍以源码形式在 workspace 内互引，要真 publish 还缺 tsdown 产物与 `publishConfig`

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
