# 当前进度

> **本文件回答一个问题：现在到哪了，下一步做什么。**
>
> 与其他文档的分工——`develop_plan.md` 写「为什么这么设计」，`VERSION_BASELINE.md` 写
> 「已核验的事实」，`registry.md` 写「插件有哪些、怎么写」，本文件写**状态**。
> 状态会过期，所以每次收工前更新它；论证不会过期，所以不要往这里写论证。

**最后更新：2026-09-08。新增「隐藏菜单」能力（见下节，含一处 schema 变更与语义变更），
`framework` / `frontend` / `docs` 均已提交 `main`、未推远端；非代码层优化 Phase 1~4 已全部完成；
另起了面向使用者的文档站骨架 `docs/site/`（VitePress，见下节）。
下一步是把 `framework` / `frontend` 统一发版 `0.2.2`。更早的逐条开发日志
（0.2.2 锁能力、0.2.1、0.2.0、A~G 分期等）已移到 `PROGRESS.archive.md`。**

***

## 2026-09-08：隐藏菜单（独立的新增/编辑页）+ /profile 刷新丢菜单修复

起因是一个提问：框架自带的增删改都是弹窗表单，业务复杂时需要独立的新增/编辑页，
菜单管理是否撑不住这种「页面必须存在但不能进侧边栏」的场景。答案是撑不住，
而且是前后端语义打架：前端 `toRouteRecords` 早就写了 `hideInMenu: visible === 0`，
但后端 `SysMenuService.treeOf()` 用 `.eq("visible", 1)` 在 SQL 层就把记录滤掉了，
`visible = 0` 的实际语义是「停用」，那行 `hideInMenu` 是死代码。

**已完成（三个仓）**

- `framework`：`treeOf()` 去掉 `visible` 过滤（显隐与授权解耦）；`sys_menu` 新增
  `active_path` 列 + `SysMenu.activePath`；`normalizeBlankToNull` 覆盖 `activePath`；
  seed 的「登录锁定」占位行改为 `path`/`component` 留 `NULL`（它靠 `visible=0`
  来「藏起来」的写法在新语义下会生成指向不存在组件的路由）；`AuthFlowIT` +1 条断言。
- `frontend`：透传 `activePath` 到 `meta.activePath`；菜单管理表单加「高亮菜单」项、
  表格加「显示」列、树默认收起 + 展开/收起全部按钮；`coreRouteNames` 收窄为
  「Root 自身 + /auth 子树」修掉 `/profile` 刷新丢菜单。`apps/admin` 与
  `create-app/template` 两份同步。
- `docs`：`CLAUDE.md` 新增 §4.5.1；`framework/CHANGELOG.md` 0.2.2 记 Breaking Changes。

**验证**：`framework-it` 105/105 绿（mysql:5.7）；前端跑真实链路
（Chrome → vite → 代理 → ItApplication → MySQL 5.7）14/14 绿，覆盖
隐藏菜单不进侧边栏 / 路由仍可达 / activePath 高亮 / 取消授权后不下发 /
菜单树默认收起与展开收起 / `/profile` 刷新菜单仍在 / 未登录跳登录页。

**⚠️ 0.2.2 发版必须带上的两条**（已写进 `framework/CHANGELOG.md` 的 Breaking Changes）：

1. `sys_menu.visible = 0` 语义从「停用」变「隐藏」，存量库里既有的 `visible = 0`
   记录会变成可访问（仍需授权），升级前应检查并按需取消授权；
2. 存量库需手动加列：
   `ALTER TABLE sys_menu ADD COLUMN active_path VARCHAR(191) NULL COMMENT '侧边栏高亮路径' AFTER visible;`

***

## 2026-09-08：面向使用者的文档站骨架（`docs/site/`）

此前 `docs/` 全是维护者视角（方案 / 版本基线 / 编码规范 / 进度），唯一偏用户的
`QUICKSTART.md` 也混进了「验证状态」这类维护者记录。新起一套**对外文档**，与现有
内部文档并存、分工明确：怎么用 → `site/`；为什么这么设计 → `develop_plan.md`（对外文档只链接）。

- **技术选型**：VitePress `1.6.4`（稳定线，与「有意选上一代」一致）。纯静态产物，
  `npm run build` → `site/.vitepress/dist` 可直接塞进内网 nginx，契合「无公网出口」目标。
- **信息架构**：Diátaxis 四分法 —— `guide/`（教程）/ `how-to/`（操作指南）/
  `reference/`（参考）/ `explanation/`（解释）/ `about/`（限制与贡献）。
- **已写实内容**：两篇教程 `guide/getting-started.md`（由 `QUICKSTART.md` §1~§6 迁入，
  剥掉验证状态）、`guide/first-module.md`（codegen 加模块）；`index.md` 首页。
- **占位页**：其余 20 页是带「本页将覆盖 + 素材来源」的 stub，逐页补。
- **构建产物**：本地 `npm ci && npm run build` 跑通（24 页，无死链）。
  ⚠️ **本机 pnpm 装不了**（node_modules junction 报 "untrusted mount point"），
  故此站单独用 npm、提交 `package-lock.json`；CI 走 `.github/workflows/docs.yml`（npm + Pages）。
- **版本号纪律**：全站唯一事实来源是 `reference/compatibility.md`，其余页面链过去不硬编码。
  教程里暂写的 `0.2.1` / `0.2.2` 待 `0.2.2` 统一发版后核对。
- 尚未推远端；GitHub Pages 首次生效需在仓库 Settings 开启 Pages（source: GitHub Actions）。

## 2026-09-07/08：非代码层优化（Phase 1~4 完成）

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

**Phase 2 — docs 整理（完成）**

- 删 `develop_plan.v0.3.bak.md`、`scripts/toolchains.xml.sample`
- 全 docs 的 sample-app / toolchains 引用清理；`CLAUDE.md` 母本头注释 + §0 + §1 + §6 改写
- `develop_plan.md` 981→887 行：删附录 A（修订史）、第十章路线图塌缩、剥离版本标记
- `VERSION_BASELINE.md`：新增「踩过的坑：编号索引」，剪除已完成的「待实测」清单。
  逐轮实测记录保留（是发现 ①~⑳ 的详情载体、被跨文档引用）
- 本文件历史日志切出 `PROGRESS.archive.md`（1855→138 行）
- `LOGIN_MODULE_AUDIT.md` 加存档 banner

**Phase 3 — 删 CLAUDE.md 副本（完成）**

- 8 个子仓（framework / codegen / frontend / 5 个插件）的 `CLAUDE.md` 删除。
  比对确认各副本与母本仅换行/表格分隔符格式差异，无内容漂移，无需回收
- 保留 `docs/CLAUDE.md`（母本）与 `workspace/CLAUDE.md`（业务方视角）；
  工作区根 `CLAUDE.md`（非 git）刷新为母本副本

**Phase 4 — README（完成）**

- 11 个仓 README：补 `framework-it` 说明 / 「相关文档」指向 docs 仓 / 去陈旧版本号；
  frontend 去掉「脚手架未交付」的过时段落；plugin 仓「本仓为副本」措辞改为指向 docs 仓

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


