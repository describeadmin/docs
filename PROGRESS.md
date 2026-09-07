# 当前进度

> **本文件回答一个问题：现在到哪了，下一步做什么。**
>
> 与其他文档的分工——`develop_plan.md` 写「为什么这么设计」，`VERSION_BASELINE.md` 写
> 「已核验的事实」，`registry.md` 写「插件有哪些、怎么写」，本文件写**状态**。
> 状态会过期，所以每次收工前更新它；论证不会过期，所以不要往这里写论证。

**最后更新：2026-09-07。当前工作：非代码层优化（Phase 1 完成、Phase 2 收窄 develop_plan /
VERSION_BASELINE 待办、Phase 3/4 已完成 CLAUDE.md 副本移除 + README 补指针）。
更早的逐条开发日志（0.2.2 锁能力、0.2.1、0.2.0、A~G 分期等）已移到 `PROGRESS.archive.md`。**

***

## 2026-09-07：非代码层优化（Phase 1 完成，Phase 2 进行中）

方案与决策见 `docs/MIGRATION_NOTES.md`。全部改动**已提交各仓 `main`、未推远端**。

**Phase 1 — 切断 sample-app 依赖（完成）**

- `framework`：新增不发布的 `framework-it` 模块（只在 `-Pit` profile 挂载），
  从 sample-app 迁入 104 条运行时行为断言（审计填充 / 分页 / 逻辑删除 / 乐观锁 /
  中文往返 / 认证 SPI / 系统模块 / 权限 / 数据权限 / 操作日志 / 在线会话 /
  登录锁定 / 口令策略 / 强制改密）。本地 `mysql:5.7` 与 `mysql:8.4` 各跑绿 104/104。
  CI 新增 `it-matrix` job；删除 `notify-consumers.yml`（原向 sample-app 派发门禁）。
- `codegen`：CI 新增 `e2e-compile` job（checkout framework → archetype 现生成工程 →
  注入 project 模块 → `mvn test-compile`），取代「sample-app 全量编译」的验证。
  ⚠️ CI-only，待首次 CI 跑通确认。
- `framework-crypto-starter`：自带 `it/` 包已完全覆盖 sample 的加密 IT，无需迁移。
- `framework-auth-email-starter`：逻辑层已覆盖；HTTP 过滤器链整合测试作为独立
  follow-up（未做）。
- `frontend`：`apps/admin` 联调后端文案改为「archetype 生成的工程」。
- `sample-app` / `sample-frontend`：本地目录已删；`describeadmin/sample-app` 远端仓
  **保留不动**（人工决定）；`repos.yml` 已移除两条登记。

**Phase 2 — docs 整理（进行中）**

- 已完成：删 `develop_plan.v0.3.bak.md`、`scripts/toolchains.xml.sample`；
  `CLAUDE.md` 母本头注释 + §0 + §1 toolchains + §6 改写；`README.md` / `QUICKSTART.md` /
  `develop_plan.md` 的 sample-app 引用清理。
- 待办：`develop_plan.md` 收窄为设计决策记录（删附录 A 修订史、第十章路线图塌缩、
  剥离 `(v0.4 新增)` 内联标记）；`VERSION_BASELINE.md` 逐轮实测 → 现行事实清单归并；
  本文件（PROGRESS）历史日志切出 `PROGRESS.archive.md`；`LOGIN_MODULE_AUDIT.md` 存档。

**Phase 3/4 — 待办**：删各子仓 CLAUDE.md 副本（回收 frontend / auth-email / crypto
的漂移条目）；各仓 README 按统一六段结构重写。

***

## 下一步

1. **`framework` / `frontend` 统一发版 `0.2.2`**（含锁能力 + 本轮非代码层优化）。
   发布前先把 Phase 2 深整理做完（见上）。`codegen` 已单独发 `0.2.2`。
2. **阶段 H：厂商插件**（浙政钉登录用 `AuthProvider`、钉钉推送用 `NotifyChannel`）。
   新开插件仓，按 `docs/registry.md` 六步流程，独立成仓、不进 framework reactor。
3. **Phase 3/4 收尾**：各子仓 `CLAUDE.md` 副本已删；README 已补 docs 指针。
   剩 `develop_plan.md` 收窄、`VERSION_BASELINE.md` 归并（见「非代码层优化」节的待办）。
4. **`framework-auth-email-starter` HTTP 整合测试**（`WebEnvironment.RANDOM_PORT`，
   见 `docs/MIGRATION_NOTES.md` D4）——独立 follow-up。

***

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

**文档**

- `develop_plan.md` 第十章路线图仍是 v0.4 的阶段 -1~6，与 A~G 分期并行存在——
  待 Phase 2 深整理时塌缩为「已完成 + 未来方向」。

**发布链路**

- 前端 `packages/` 结构上已 publish-ready，但**从未真正执行过** `changeset publish`，
  npm registry 上还没有 `@describeadmin/*`。0.1.0/0.2.x 的"已发布"指的是 Maven Central
  一侧；npm 一侧待首次 `changeset publish`。

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
10. **判断一个前端页面该不该进** **`system-ui`，看它是否围着** **`framework-system-starter`**
    **的实体转**，不是看它"看起来像不像系统管理页面"。工作台首页最初因为展示四个实体的
    统计数字而放进 system-ui，后来改成不请求接口的纯静态欢迎页后就应该挪出去——这类
    "通用但归属具体应用"的页面（同 `views/_core/profile`/`views/_core/about`）该待在
    应用外壳里，业务方能直接改。三处 `access.ts` 合并 `pageMap` 时，`systemPageMap`
    必须展开在业务本地 `import.meta.glob('../views/**/*.vue')` **之前**，让本地同名
    页面覆盖框架默认，反过来会被静默吃掉且没有报错。


