# 当前进度

> **本文件回答一个问题：现在到哪了，下一步做什么。**
>
> 与其他文档的分工——`develop_plan.md` 写「为什么这么设计」，`VERSION_BASELINE.md` 写
> 「已核验的事实」，`registry.md` 写「插件有哪些、怎么写」，本文件写**状态**。
> 状态会过期，所以每次收工前更新它；论证不会过期，所以不要往这里写论证。

**最后更新：2026-09-18。对 `framework` 仓 `v0.2.1..HEAD`（0.2.2 全部未发布的功能改动）
做了一轮代码审查，7 条 finding 中落地 6 条（第 7 条「登录锁定菜单存量库迁移」经决定不做，
本阶段不考虑历史兼容），另附带修了 2 处同形缺陷。改动集中在 `framework-system-starter`，
`api/` 包签名不变，全部折进未发布的 0.2.2（见下节与 `framework/CHANGELOG.md`）。
2026-09-15：排查并修复了 qujiang-hrms-web（业务方消费框架）字典管理页面分栏失效
问题，根因是 turbo 构建缓存看不见 `@core/base/design` 对其他包源码的隐式依赖（Tailwind
`@source` 跨包扫描），导致 `pnpm build` 静默产出过期的 `core-design.css`（见下节）。
2026-09-14：用户/角色/部门/在线用户/字典/参数配置六个系统管理列表页新增搜索栏，
操作日志的手拼搜索栏改用同一套封装（前后端均有改动，尚未提交）。此前的菜单图标
选择器、「隐藏菜单」能力、非代码层优化 Phase 1~4、面向使用者的文档站骨架 `docs/site/`
（VitePress）均已完成（见下）；`framework` / `frontend` / `docs` 的既有提交均在 `main`、
未推远端。
下一步是把 `framework` / `frontend` 统一发版 `0.2.2`。更早的逐条开发日志
（0.2.2 锁能力、0.2.1、0.2.0、A~G 分期等）已移到 `PROGRESS.archive.md`。**

***

## 2026-09-18：framework 0.2.2 发版前代码审查 —— 6 条缺陷修复

审查范围 `v0.2.1..HEAD` 的 `*/src/main/*` 与 `pom.xml`（约 1850 行 diff），
覆盖 0.2.2 的全部未发布改动：锁能力（`LockOperations` / `@DistributedLock` / `UniqueGuard`）、
系统模块并发唯一性接入、隐藏菜单 + `active_path`、空权限标识崩溃修复、列表筛选条件。

**这批缺陷的共同特征是症状不指向真因**，逐条的完整描述见 `framework/CHANGELOG.md`
的 0.2.2 Bug Fixes，这里只记状态：

| # | 缺陷 | 落点 |
|---|---|---|
| 1 | 逻辑删除的角色仍下发权限点与菜单路由（`hasRole` 失效而 `hasAuthority` 照过） | `SysRelationMapper` 两条 `@Select` 补 `JOIN sys_role` + `r.deleted = 0` |
| 2 | `getIfAvailable()` 多候选时抛异常，恰好击穿它要保护的多数据源场景 | `SysUserService` 改 `getIfUnique()` |
| 3 | `path` / `component` 永远清不回 `NULL`（漏在 `normalizeBlankToNull` 之外） | `SysMenuService` 补两列 |
| 4 | `set(col, null)` 绑参数而非字面量 NULL，达梦 / 金仓报「无效的列类型」 | `SysMenuService` 改 `setSql`，并记入 `CLAUDE.md` §3.8 |
| 5 | 唯一标识为空时校验静默通过，最终以 500 收场（应为 400） | `SysUser`(username) / `SysRole` / `SysDictType` / `SysConfig` 四处 `save` 补非空校验；三处 `updateById` 的空白非 null 一律 400 |
| 6 | `LockStartupValidator` 的 `MetadataLookup` 入选条件注释说反 | 只改注释（代码本身正确，照注释"修正"会让门禁失守） |

其中 #5 的 username 与 `updateById` 空串两处是审查之外发现的同形缺陷，一并修了。

**决定不做**：`seed-rbac.sql` 的「登录锁定」菜单在 0.2.1 里把 `path` / `component` 写成了
`'/system/security'` / `'system/security/index'`，HEAD 改成 `NULL` 但被同句的 `NOT EXISTS`
幂等守卫挡住，只对全新库生效。本阶段不考虑历史兼容，不加迁移语句。

**门禁**：新增 `framework-it/SystemModuleFixesIT`（逻辑删除角色 / 菜单可空列清空 /
空标识 400 三组）与 `framework-system-starter/SysUserServiceTransactionFallbackTest`
（0、1、2 个 `TransactionTemplate` 候选三种形态）。`mvn -Pit -pl framework-it verify`
在 `mysql:5.7` 与 `mysql:8.4` 两条线各 112 个断言全绿。

改动已提交 `framework` 仓 `main`，未推远端。

***

## 2026-09-15：qujiang-hrms-web 字典管理页面分栏失效 —— 根因是 turbo 缓存看不见 Tailwind 跨包扫描依赖

起因：业务方（qujiang-hrms-web，以 npm 依赖消费框架）反馈字典管理页面左右分栏
（`grid-cols-1 lg:grid-cols-5` + `lg:col-span-2`/`lg:col-span-3`）失效，右侧「字典数据」
面板要么溢出、要么退化成上下堆叠。此前已有一版排查报告，怀疑是 `@tailwindcss/vite` 在
Rolldown 驱动的 `vite@8` 下对同一 CSS 入口重复编译、第二次空结果覆盖第一次——本轮实测
**未能复现这个结论**（见下），实际根因在更上游。

**排查过程**：

- 在 `@core/base/design` 包插桩 `@tailwindcss/vite` 并反复重建 5 次（用 `diff`/`grep -F`
  严格核对，避免 shell 里 `lg\\:col-span-2` 这类双反斜杠转义导致的假阴性——第一轮自己也踩了
  一次这个坑），当前源码在本机稳定产出正确的 `lg:col-span-2` 等规则，未见候选类被清零覆盖的
  情况。4 个 CSS 入口（global/nprogress/transition/ui）确系并发独立编译，但最终被正确拼接，
  不存在互相覆盖——原报告"重复调用覆盖"的结论不成立。
- 真正问题在更上游：`qujiang-hrms/.describeadmin-local/describeadmin-core-design-0.2.2.tgz`
  （业务方消费的本地 tarball）文件时间戳虽是当天，但内容和 8 月底的产物字节完全相同——
  打包时用的是没有重新构建的旧 `dist/`。
- "没有重新构建"还有更深一层原因：`pnpm build`（`turbo build`）对 `@core/base/design` 是
  **FULL TURBO 全缓存命中**——turbo 的任务依赖图只看 `package.json` 的 `dependencies`
  （这个包只依赖 `@describeadmin/tailwind-config`），看不到 `theme.css` 里
  `@source '../../../packages/'` 等 4 条指令带来的"CSS 编译内容实际依赖全仓库任意包源码"
  这层隐式依赖。于是只要改动发生在 `system-ui`/`apps` 等**其他**包，`core-design` 自己的
  输入哈希不变，turbo 就会放心回放旧缓存——**跑了 `pnpm build`、显示成功、产物却是错的**，
  没有任何报错信号，这也是它比原来怀疑的"Rolldown 重复编译"更隐蔽的地方。

**已修复**：

- 手动 `turbo build --filter=@describeadmin/core-design --force` 重建 + `pnpm pack` 重新
  打包 + 业务方侧 `pnpm install --update-checksums`（踩坑记录：tarball 内容真变化后，
  普通 `pnpm install` 甚至 `--force` 都不会重新校验 `file:` 依赖的 hash，会继续吃 store 里的
  旧内容；只有整个删掉 `node_modules` 重装才会触发 pnpm 的完整性校验，报
  `ERR_PNPM_TARBALL_INTEGRITY`，这时候用 `--update-checksums` 确认是本地合法重建而不是
  供应链问题）。已核实 `qujiang-hrms-web` 的
  `node_modules/@describeadmin/core-design/dist/core-design.css` 现含 `lg:col-span-2` 等
  目标规则。
- 新增 `frontend/packages/@core/base/design/turbo.json`：给 `build` 任务的 `inputs` 补上
  `$TURBO_ROOT$/packages/**`、`apps/**`、`docs/**`、`playground/**`（镜像 `theme.css` 自己的
  4 条 monorepo `@source`），让 turbo 的缓存 key 能感知到这层隐式依赖。
  ⚠️ 代价：这个 glob 范围较大，实测下 turbo 对这个任务的**重复缓存命中变得不稳定**
  （连续两次不改任何东西也经常 miss；缩小到单个子包目录时缓存能正常命中）——具体是 turbo
  在这个规模下哈希计算的哪个环节不稳定未查。但"每次都老实重新跑一遍 vite build（~1-3s）"
  换来的是"内容永远正确"，优先级上可以接受，没有为了缓存命中率继续深挖。
- 未动 workspace 根目录 `.local-tarballs/`（Aug 28、`0.1.0` 版本）——更早的历史遗留产物，
  与本次问题无关。

**下一步 / 待办**：

- 其余 28 个 `@describeadmin/*` 包目前没发现类似"产物内容依赖其他包源码但 turbo 看不到"的
  情况（只有 `core-design` 做 Tailwind 编译），但以后若有别的包出现同类模式（编译期扫描/聚合
  其他包内容），照这次 `turbo.json` 的写法处理。
- `qujiang-hrms-web` 的 `pnpm-lock.yaml` 改动（integrity 刷新）尚未提交——那是业务方自己的
  仓库，且里面还有一条无关的 `src/composables/useSearchForm.ts` 在途改动，本轮未动它，
  留给业务方自己处理/提交。

***

## 2026-09-14：系统管理列表页统一加搜索栏

起因：`frontend` 之前给 `@describeadmin/create-app` 模板加了一个 `useSearchForm` 组合式
函数（折叠检索栏 + 搜索/清空按钮 + 卡片背景的统一封装），但一直没有落地页面用它——
本轮把它铺到系统管理的六个列表页，并顺带把操作日志页原本手拼的筛选行换成同一套封装。

**已完成（`frontend`）**

- `packages/effects/system-ui/src/composables/useSearchForm.ts`：`create-app` 模板同名文件
  在本包的对应实现，两者不能合并——本包不知道消费方 app 声明的 `ComponentType`，
  只能退回 `@describeadmin/ui` 默认导出的 `VbenFormSchema`（其 `component` 字段类型底层是
  `BaseFormComponentType`，本就带 `string` 转义），字段用 `'Input'`/`'Select'`/`'DatePicker'`
  等 adapter 别名——这些组件由消费方 app 的 `initComponentAdapter()` 注册进同一个全局
  `COMPONENT_MAP` 单例，本包运行时不需要重新声明。
- 用户 / 角色 / 参数配置：搜索栏走后端分页查询（新增 `UserQuery`/`RoleQuery`/`ConfigQuery`），
  对应后端 `buildListWrapper` 覆写（见下）。
- 字典管理：字典类型面板走后端分页查询（`DictTypeQuery`）；字典数据面板本来就是整批拉取
  + 客户端按类型过滤（见 `getDictDataListApi` 的既有注释），本轮只是在客户端过滤链上加一个
  按标签关键词的条件，未改后端。
- 部门管理：部门是整棵树一次性拉取、没有分页（`getDeptTreeApi`），搜索因此是纯客户端过滤——
  按名称/状态过滤时保留命中节点的祖先链，不让匹配到的子部门因父节点被过滤掉而"消失"。
- 在线用户：新增 `username` 子串过滤，应用层做（数据源是 `TokenStore.listActive()` 的内存
  快照，没有表可下推 SQL）。
- 操作日志：原本手拼的 `ElInput`/`ElSelect`/`ElDatePicker` + 查询/重置按钮行改用
  `SearchFormBar`；时间范围拆成开始/结束两个独立 `DatePicker` 字段而不是一个 `daterange`
  型字段——后者要靠 adapter 把单个 fieldName 拆成 `[name, name_end]` 两个值，这条路径在本仓
  还没有别的页面验证过，拆成两个平级字段直接对应 `OperLogQuery.start`/`.end`，是更少假设的写法。

**已完成（`framework`，`framework-system-starter`）**

- `SysUserController`/`SysRoleController`/`SysDictTypeController`/`SysConfigController`
  新增 `buildListWrapper` 覆写，写法与 `codegen` 生成物的既有约定一致（`likeRight` 右模糊、
  `eq` 精确匹配、空值不参与筛选）。此前这四个 Controller 都没覆写这个钩子，前端传筛选参数
  也是静默无效——「搜索框能点、后端不接」比没有搜索框更容易误导。
- `SysOnlineController#list` 新增可选 `username` 查询参数，在 `TokenStore.listActive()` 的
  内存快照上过滤后再切片分页。
- 部门（`SysDeptController`）、字典数据（`SysDictDataController`）未改——理由见上，前端侧
  就地过滤已经够用。

**验证**：`framework-system-starter` 单模块 `mvn compile` 通过；`apps/admin` 的
`vue-tsc --noEmit`（含 system-ui/common-ui 源码）通过；改动文件 ESLint 干净。
未跑 `-Pit` 行为门禁（需要 Testcontainers 拉真实 MySQL）、未做浏览器真实链路验证——
下次接手先补这两项，尤其是 `buildListWrapper` 的筛选条件要对着真实数据核实一遍。

***

## 2026-09-11：菜单管理「图标」字段改为可视化选择器

起因是一个提问：菜单管理里的图标是纯文本框，placeholder 只举了一个 `lucide:users`，
使用者不知道该填什么、填错也没有任何反馈，只能保存后回侧边栏看效果。

**已完成（`frontend`）**

- 复用已有的 `IconPicker`（`@describeadmin/ui` 导出）当选择器：6 列图标网格 +
  关键词搜索 + 分页 + 悬浮显示图标名，图标集锁定 `lucide`（与 `seed-rbac.sql`
  里既有数据一致；清单仍走 iconify 公共 API，内网/离线空白是现状、本次未改变）。
- `IconPicker`（`packages/effects/common-ui/src/components/icon-picker/`）的
  **向后兼容增强**，四个可选 prop 默认行为与原来一致：
  `contentClass` / `zIndex`（面板层级，内联样式下发）、`clearable`（面板内「清空」入口）。
  另外：加载中 / 加载失败（带重试）/ 无匹配 三态区分；当前值不在图标集内时面板顶部提示；
  修正分页 `:items-per-page` 写死 36（传别的 `pageSize` 时分页器会算错）；修掉触发器上
  写成字面量的 `aria-expanded="visible"`。
- `fetchIconsData` **失败改为向上抛**，并把失败的 Promise 从在途表里摘掉——此前失败被吞成
  空数组，界面只能显示「暂无数据」（与「图标集里真没有」无法区分），且「重试」永远命中
  已 reject 的旧 Promise，点了没反应。顺带把在途表换成 `Map`。
- 菜单页（`packages/effects/system-ui/src/views/menu/index.vue`）：图标项换成只读选择器
  （挡住手输），`zIndex=3000` 抬到 ElDialog（弹层层级 2000 起自增）之上；列表新增
  「图标」列，用侧边栏同一个 `VbenIcon` 渲染；`@describeadmin/ui` 白名单补导出
  `VbenIcon`，不给 system-ui 新增依赖。`data-testid="menu-icon-input"` 锚点保持不变。
  「图标 / 类型 / 显示」三列的表头与内容统一居中——图标必须带 `inline-block`：
  Tailwind preflight 把 `svg` 设成 `display: block`，块级元素不吃单元格的
  `text-align: center`，否则表现为「表头居中、图标贴在格子左边」。
- 数据形态不变：仍只存 iconify 名称（`sys_menu.icon` 依旧是 `VARCHAR(64)`），
  后端与表结构零改动。
- 新增 `icon-picker/__tests__/icons.test.ts` 3 条：成功合并 + 缓存命中、失败抛出且
  「重试」真的重新发请求、并发调用共享同一次请求。

**验证**：`pnpm check:type`（admin 的 vue-tsc 会把 system-ui / common-ui 源码一并检查）、
`pnpm test:unit` 312 通过（唯一失败是 `@core/preferences` 的既有快照，与本次无关）、
改动文件 ESLint 与 cspell 干净。浏览器真实链路（Chrome → vite dev server → 代理 →
真实后端 → MySQL）实测：面板 z-index 3000 > 弹窗遮罩 2003/2004 且位于最上层可点选；
搜索 `users` 过滤到 2 项并点选回填；「清空」置空并关闭面板；保存后列表图标列与侧边栏
同步为新图标，改回 `lucide:gauge` 后再次同步（业务数据已复原）。控制台无新增报错/警告。

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


