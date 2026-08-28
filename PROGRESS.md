# 当前进度

> **本文件回答一个问题：现在到哪了，下一步做什么。**
>
> 与其他文档的分工——`develop_plan.md` 写「为什么这么设计」，`VERSION_BASELINE.md` 写
> 「已核验的事实」，`registry.md` 写「插件有哪些、怎么写」，本文件写**状态**。
> 状态会过期，所以每次收工前更新它；论证不会过期，所以不要往这里写论证。

**最后更新：2026-08-28（`workspace` 仓新增 `codegen` skill：管生成器 jar 的下载/校验/缓存 + spec 要点 + 生成后隐坑，见下方新增章节）**

***

## 2026-08-28 追加：`workspace` 仓新增 `codegen` skill（生成器 jar 的获取与使用）

**背景问题（用户走查发现）**：`init-workspace.sh` / `archetype:generate` / `npm create @describeadmin/app`
都不下载 `codegen`，而 `describe` skill 的 A6 又直接说「优先走 codegen」，全流程里**没有任何一步负责把
`codegen.jar` 弄到手**——隐含假设「执行者自己会去 GitHub Release 页下载」。codegen 刻意不发 Maven Central、
不进 `pom.xml`（`develop_plan.md` §9.4），所以这个缺口只能在使用侧补。

**讨论收敛过程**（几轮否掉的方案都记下，避免重提）：
- 先考虑塞进 `describe/SKILL.md` A6 → 否：不是每次开发都走 `describe`，用户可能直接让 AI 加模块。
- 再考虑只写进 `workspace/CLAUDE.md` §6（每次会话都加载）+ 一个 `codegen.sh` 辅助脚本 → 否：
  用户认为「下载+校验+缓存」这套步骤 AI 自己就能做，不值得为它单开脚本；但散在 CLAUDE.md 一节里又不够显眼。
- **最终：单独做成 `codegen` skill，无配套 `.sh`**。步骤写在 SKILL.md 里由 AI 执行，`describe` A6 与
  `CLAUDE.md` §6 都改为指向它。

**交付（`workspace` 仓，未 push）**：

- 新增 `.claude/skills/codegen/SKILL.md`：①备 jar——版本取 `workspace.env` 的 `CODEGEN_VERSION`，
  没有则查 GitHub `releases/latest`；缓存 `~/.describeadmin/codegen/<版本>/codegen.jar`（**per-user、
  跨项目/worktree 共用，刻意不放工作空间**，`describe.sh clean` 不动它），`.sha256` 比对通过才用；
  下不通又无缓存则停下让用户手动放。②spec 要点：字段 `type` 白名单 + 常见校验拦截。
  ③`java -jar ... --out <BACKEND_DIR> --frontend-out <FRONTEND_DIR>`，默认不覆盖、`--force`/`--dry-run`。
  ④生成后三个隐坑：SQL 登记进 `spring.sql.init`、下划线模块名导致权限点 403、别自写 `list` 重载。
  ⑤编译不过＝codegen 版本比框架新，钉早一点的 `CODEGEN_VERSION`。⑥被 `describe` 调用时的路径差异。
- 改 `describe/SKILL.md` A6：「写 spec → 跑生成」→「调 `codegen` skill」。
- 改 `workspace/CLAUDE.md`：§4「三个 skill」→「四个」+ 加 `codegen` 条目；§6 改为指向 skill。
- 改 `init-workspace.sh`：`workspace.env` heredoc 加注释掉的 `# CODEGEN_VERSION=0.1.1`；
  头部注释树 + 结尾提示同步「四个 skill」。
- 改 `workspace/README.md`：结构树加 `codegen/`；维护须知加一条「codegen skill 无配套脚本」的说明。
- 改本文件；`develop_plan.md` §9.4 加「9.4.3 fat jar 的获取与缓存」。

**未做 / 已知**：
- `codegen` 的「适配哪个框架版本」仍无正式声明（`registry.md` 没有 codegen 兼容表）。当前策略是
  「默认最新 + 编译兜底 + 不行就钉 `CODEGEN_VERSION`」。等框架有多个大版本在用时应补一张对照表。
- `develop_plan.md` §9.4.1 仍写「Maven 插件（主）+ fat jar（辅）」，而现实是 fat-jar-only（插件形态
  未实现，见 QUICKSTART §1 表）。本次未动这个「主/辅」结论，只在 §9.4.3 记录 fat jar 路径的获取机制。
- SKILL.md 里的 `.sha256` 资产名、Release tag 形态（`0.1.1` vs `v0.1.1`）按「从 `releases/latest`
  响应里读 `browser_download_url` / `tag_name`」处理，未硬编码；真实 Release 上线后需实跑一次确认。
- 改动未提交、未 push。

***

## 2026-08-28 追加：`workspace` 仓新增 `describe` skill（端到端开发编排）

用户要一条「完全独立自主的开发 + 集成流程」：用户给需求 + 参考材料（PRD/参考代码/图/文档），
AI 先建 worktree → 出开发计划（可二次确认）→ 确认后自主开发 → 跑完整测试 → 含前端则跑可视化测试 →
停在「待合并」→ 用户验证无误后一句话触发合并 + 清理。判定可行——三个能力已就位，`describe` 是编排剧本不是新运行时。

**探索发现的硬约束**：`mvn archetype:generate` / `npm create @describeadmin/app` / `init-workspace.sh`
三者**都不 `git init`** 子项目，而 `workspace/CLAUDE.md` 已声称「两个项目各自是独立仓库」、
`git worktree` 也以此为前提 → 必须补这个缺口。

**交付（`workspace` 仓 + 本文件/`develop_plan.md` 在 `docs` 仓，已 commit 到各自 `0.2.0-dev`，未 push）**：

- 新增 `.claude/skills/describe/SKILL.md`：三入口剧本（A 新需求开发 / B 集成 / C 放弃）。
  唯一人工闸是「计划确认」，确认后一路自主跑到「待合并 + REPORT.md」。不 push、不 merge。
- 新增 `.claude/skills/describe/describe.sh`：只做机械活。子命令
  `new <slug> [--base <branch>] [--init-repos]` / `list` / `land <slug>` / `clean <slug> [--force]`。
  `new` == 「`init-workspace.sh` 的 worktree 版」：对两个子仓各 `git worktree add` 到
  `<workspace>/.worktrees/<slug>/`，拷 `.claude/` + `CLAUDE.md`，写 `.describe/meta.env`。
  base 默认按仓探测 `origin/HEAD` → 本地 `main` → `master` → 当前分支。
  `land` 两仓各自 `checkout <base>` + `merge --no-ff`，冲突即停可重跑，成功则自动 `clean`。
- 改 `init-workspace.sh`：生成后端/前端后，对两个子项目各 `git init -b main` + 首次提交（已是仓库则跳过）。
- 改 `.claude/skills/dev-env/dev.sh`：(1) 新增 `dev wait [back|front|all] [--timeout N]`（阻塞到端口可连接 +
  后端盯日志的启动完成/失败行），给 `describe` / `visual-test` 用，不再 `sleep` 猜时间；(2) MySQL 镜像从写死
  `mysql:5.7` 改为读 `DEV_MYSQL_IMAGE`（`workspace.env` 或环境变量），默认仍 `mysql:5.7`——业务方线上是 8.x
  可自行对齐；只在首次建共享容器时生效（容器项目级共享）。均为纯新增/替换，不动既有子命令语义。
- 改 `.claude/skills/visual-test/SKILL.md`：加「被 `describe` 调用时」一节。
- 改 `init-workspace.sh`：生成的 `workspace.env` 带一行注释掉的 `# DEV_MYSQL_IMAGE=mysql:8.0` 提示。
- 改 `workspace/CLAUDE.md` §0/§4、`workspace/README.md`（结构树 + 维护须知）、本文件、`develop_plan.md` §9.5.1 + §9.7。

**复审修正（用户 review 时抓出来的）**：
- `describe/SKILL.md` 原先引用「框架团队那份 `CLAUDE.md`」的 §3/§3.6/§4.9——业务方工作空间里只有
  `init-workspace.sh` 生成的**业务版** `CLAUDE.md`（无这些章节），三处死链已改为自包含表述。
- 其中「数据库改动」一条原写「SQL 落在 MySQL 5.7 安全子集」——那是**框架**的兼容负担（框架 DDL 要能跑在
  业主可能用的 5.7 上），不是业务方的。业务方的库版本自己定，已删除该约束，改为「登记进 `spring.sql.init` +
  语法按自己的库版本写」。

**已验证**：`describe.sh` / 改动后的 `dev.sh` `bash -n` 通过；在 scratch 双 git 仓里实跑过
`new` / `list` / `land`（顺利 + 冲突路径）/ `clean`（含已跟踪改动守卫 + `--force`）/ 嵌套 `new` 守卫 /
`--init-repos` / `dev wait` 快速超时——全过。

**未做 / 待确认**：
- 尚未在 `sample-app` + `sample-frontend` 上跑**真实**端到端（`mvn test` + `pnpm build` + chrome-devtools
  可视化那一整条，计划文件 `skill-skill-velvety-graham.md` 的「验证方式」7 步）。
- `dev wait` 的 Windows 端口探测分支未在 Windows 上实测。
- 改动已提交到 `workspace` / `docs` 两仓的 `0.2.0-dev`，未 push。

***

## 2026-08-27 追加：移除 `maven-toolchains-plugin`，构建 JDK 只要求 ≥ 17

用户走查：`framework/pom.xml` 与 `codegen/pom.xml` 仍用 toolchains 把构建 JDK 钉在 21，
而唯一真实要求是 Java ≥ 17。`release=17` 已锁定产物字节码，钉具体版本只会让没配
`~/.m2/toolchains.xml` 的协作者 / AI 以 `Cannot find matching toolchain` 直接构建失败。
三个插件仓此前已改，这次把父 POM 与 codegen 也一并统一。

- `framework/pom.xml`：删 `maven-toolchains-plugin` + `java.build.version` + 版本属性；
  enforcer `enforce-rules` 加 `requireJavaVersion [17,)`。
- `codegen/pom.xml`：删 toolchains；新增 `maven-enforcer-plugin`（原本没有），只挂 `requireJavaVersion [17,)`。
- 文档同步：`CLAUDE.md` §1 + §4.6（7 份副本）、`develop_plan.md` 2.2.2 新增「第八轮修订」小节 +
  附录 B、`VERSION_BASELINE.md` 发现 ⑥ 追加 2026-08-27 补充、`registry.md` 新建插件清单、
  `QUICKSTART.md` §1、`RELEASE.md` 排障表、`framework/README.md`、archetype `README.md`。
- 未动：`sample-app`（刻意保留 toolchains 钉 JDK 17 做最低版本验证）、各仓 CI（`setup-java` 固定 21）。
- 已验证：`mvn -f framework/pom.xml clean install` 与 `mvn -f codegen/pom.xml clean package`
  在 JDK 21、无 `toolchains.xml` 下 BUILD SUCCESS，enforcer `RequireJavaVersion passed`。

***

## 2026-08-27 追加：账号密码安全升级（去掉固定 `admin123` + 强制改密 + 定期过期/历史）

用户走查：`seed-rbac.sql` 写死 `admin/admin123`（预计算 BCrypt，绕过 `PasswordPolicy`），
且散落在 7 个 IT + 3 个 e2e + CI + archetype + 文档。风险是拷 local 库上生产带上弱口令。
分三部分交付，详见 `docs/LOGIN_MODULE_AUDIT.md` G 项：

**Part 1 — 随机种子口令 + `.passwd`**（`framework-system-starter` / `framework-security-starter`）
- 新增 `DevAdminSeeder`（`ApplicationRunner`，`@ConditionalOnProperty(describeadmin.system.dev-seed.enabled=true)`，
  默认关）：库中无用户时创建 `admin`，口令用 `RandomPasswordGenerator` 随机生成（`PasswordPolicy` 复核），
  BCrypt 入库，明文写 `${user.dir}/.passwd` + 打印启动日志。配置类
  `FrameworkSystemProperties.DevSeed`。
- `seed-rbac.sql` 移出 admin 用户 + user_role 两条 INSERT（只留结构数据），文件头注释改写。
- `UsernamePasswordAuthProvider` 的 `DUMMY_HASH` 常量（原本正好是 `admin123` 的哈希）→
  构造期用注入 encoder 现算随机串的 `dummyHash` 字段。
- `.gitignore` 三处（根 / sample-app / archetype `__dot__gitignore`）加 `.passwd`；
  `application-local.yml`（sample-app + archetype）加 `describeadmin.system.dev-seed.enabled: true`。

**Part 2 — 强制首次改密**
- `sys_user` 加 `pwd_reset_required TINYINT NOT NULL DEFAULT 0`；`SysUser` 实体加字段。
- `SysUserService.createUser`/`resetPassword` 置 1；`changeOwnPassword`（`SysUserMapper.updateSelfPassword`
  的手写 `@Update`）清 0 并刷 `pwd_update_time`。
- `AuthUser`/`LoginUser`（`api/`）各加 `pwdResetRequired` 字段 + 新构造重载（不改既有签名，
  既有 `new LoginUser(...)` 调用点零改动）。`DbAuthUserLoader` 传入。
- `framework-common` `ResultCode` 加 `PASSWORD_RESET_REQUIRED(40105)`。
- 新增 `PasswordResetRequiredFilter`（`OncePerRequestFilter`，排 `TokenAuthenticationFilter` 之后），
  白名单 `PUT /api/auth/password` `GET /api/auth/me` `POST /api/auth/logout` `/error`，其余
  被标记用户请求 → `403 + 40105`。`FrameworkSecurityAutoConfiguration` 装配 + `addFilterAfter`。
- 前端：`BackendLoginUser` 加 `pwdResetRequired?`；`store/auth.ts` 加 `pwdResetRequired` ref
  （`authLogin`/`fetchUserInfo` 刷新，`logout`/`$reset` 清）；`router/guard.ts` 把被标记用户
  钉在新页 `_core/authentication/password-reset-required.vue`（`routes/core.ts` 注册
  `PasswordResetRequired`）。`apps/admin` 与 `packages/create-app/template` 五个文件逐字一致。

**Part 3 — 定期过期 + 历史不可重用**（`sys_config` 参数驱动，默认 0＝关）
- `seed-rbac.sql` 加两个内置参数 `sys.password.max-age-days` / `sys.password.history-count`。
- `sys_user` 加 `pwd_update_time DATETIME`；新表 `sys_user_password_history`（只追加，仿 `sys_oper_log`）+
  `SysUserPasswordHistoryMapper`（`selectRecentHashes` / `pruneToRecent`，5.7-safe）。
- `SysUserService` 三处设密码路径：`assertNotRecentlyUsed` + `recordPasswordHistory`（注入 `SysConfigService`）。
- `DbAuthUserLoader` 注入 `SysConfigService`，登录时按 `pwd_update_time + max-age-days` 现算过期
  （不落库），并入 `pwdResetRequired` → 复用 Part 2 门禁。

**验证**：`framework` 全模块 `mvn install` 全绿（新增 `PasswordResetRequiredFilterTest` 4 例、
`RandomPasswordGeneratorTest` 51 例）；`sample-app` 108 例在 `mysql:5.7` + `mysql:8.4` 两轮全绿
（新增 `PasswordResetRequiredIT` 2 例、`PasswordPolicyRuntimeIT` 2 例；7 个既有 IT 登录 helper
改从 `.passwd` 读，"建号后以该用户调接口"的用例加 `clearPwdResetRequired`）；`apps/admin`
`typecheck` 通过。CI workflow 的登录核验步骤改 `cat /tmp/gen/ci-app/.passwd`，并加两条
生成物校验（`dev-seed` 段存在、`.gitignore` 含 `.passwd`）。

**未做 / 待确认**：未做 chrome-devtools 前端强制改密页的人工走查；`docs/` 母本改动
（QUICKSTART / LOGIN_MODULE_AUDIT / 本文件）尚未同步到各子仓副本；四仓 `0.2.0-dev`
本地已改、尚未提交推送。

***

## 2026-08-27 追加：邮箱登录前端接线下沉进框架包（修"倒反天罡"）

用户走查：sample-app 的 `/api/auth/providers` 已返回 `["password","email"]`，但登录页
不显示邮箱登录入口。定位到根因**不是插件问题**，而是前端分层错位：邮箱登录的
app 级接线（`showEmailLogin` 跟 providers 联动、`email-login.vue`、`/auth/email-login`
路由、`sendEmailCodeApi`）当时只做进了 `sample-frontend`，`apps/admin` 与
`packages/create-app/template` 都没有——于是 `create-app` 脚手架生成的新前端即使后端
装了 `framework-auth-email-starter` 也不显示邮箱登录。`sample-frontend` 只是消费方
验证仓，却跑在了框架前面。

**按方案 2 处理：把「按 providers 渲染登录入口 + 邮箱验证码登录表单」整体下沉进
`@describeadmin/ui`，三个 app 只留注入 store/api 的薄接线，且这次三处同时改、起点一致。**

`@describeadmin/ui`（`packages/effects/common-ui`）：

- `AuthenticationProps` 新增 `providers?: string[]`；`AuthenticationLogin` 据此推导
  邮箱入口显隐（`showEmailLogin` 显式传时优先，否则看 `providers` 是否含 `email`）。
  只认 `email` 这一项——框架内也只有邮箱插件是真实存在的第二种能力。
- 新增 `AuthenticationEmailLogin`（`email-login.vue`）：包裹 `AuthenticationCodeLogin`，
  内建邮箱 + 验证码表单 schema / 校验 / 发码节流；`sendCodeApi` 由业务方注入
  （框架包不持有 requestClient），`@submit` 抛 `{email,code}` 给业务方补 `type`。
- `@describeadmin/locales` 新增 `authentication.emailLoginSubtitle`（zh/en），
  邮箱登录页标题用 📧 覆盖 CodeLogin 默认的 📲（短信语义）。

三个 app（`apps/admin` / `packages/create-app/template` / `sample-frontend`，三份文件逐字一致）：

- `login.vue`：`:providers="providers"` 透传给 `<AuthenticationLogin>`；`handleSubmit`
  的 `type` 由脆弱的 `providers.value[0]` 统一改为硬编码 `'password'`（这张表单固定是
  用户名密码）。app 内不再有 `showEmailLogin` computed。
- `views/_core/authentication/email-login.vue`：~20 行薄包装，注入
  `sendEmailCodeApi` + `authStore.authLogin({...values, type:'email'})`。
- `router/routes/core.ts`：始终注册 `EmailLogin` 路由——让"装了邮箱插件就能用"成立、
  业务方不改前端；未装插件时直达该 URL 会渲染提交必失败的表单，是可接受取舍
  （背后有真实后端信号门控，不同于 A 项删掉的 CodeLogin/QrCodeLogin 纯死壳）。
- `api/core/auth.ts`：`sendEmailCodeApi`（对应插件的 `POST /api/auth/email/code`）。
- `locales/langs/{zh,en}/page.json`：`auth.emailLogin`。

**验证**：`apps/admin` `vue-tsc --noEmit` 干净；`@describeadmin/ui` + `@describeadmin/locales`
tsdown 构建通过；`sample-frontend` 重跑 `pack-local-deps.sh` + `pnpm install` +
`vite build` 通过（`vue-tsc` 仅剩既有的 `router/guard.ts:108` 无关报错）。
chrome-devtools 端到端走查 `sample-frontend`：登录页出现邮箱入口 → 点击进
`/auth/email-login` → 框架组件链 `EmailLogin → AuthenticationEmailLogin →
AuthenticationCodeLogin` 正常 → 填邮箱点「获取验证码」→ `POST /api/auth/email/code`
返回 200、倒计时启动。`componentProps` 的 `[Vue warn]` 是 `@core/form-ui` 既有告警
（`/auth/login` 上也有），非本轮引入。

**约束（记进 memory）**：`sample-frontend` 只能跟随框架，不能领先——功能先落
`@describeadmin/*` 包 + `apps/admin` + `create-app/template`，再让 sample-frontend 拉平。

**追加：切换登录方式的过渡中间态**（用户反馈）。`AuthenticationFormView`
（`@describeadmin/layouts` 的 `authentication/form.vue`）去掉 `mode="out-in"` 后，
Login ↔ EmailLogin 切换时离场/进场两张表单同时留在文档流里上下堆叠，露出
"两张表单都可见"的中间态。`form.vue` 加 scoped 样式让离场元素在过渡期间
`position:absolute; left:0; right:0` 覆盖在进场元素之上——等价 out-in 的观感，
但不触发 form.vue 注释里记录的 out-in + KeepAlive 卡死。chrome-devtools 实测
过渡期间两 `.side-content` 的包围盒重叠而非纵向排列。

**踩坑**：本轮用 `pkill -f "vite --mode development"` 关临时 server 时误杀了用户
`apps/admin` 的 dev server（它随后被父进程自动拉起、换了 PID）。以后关进程按
具体 PID，不要按命令行模糊匹配。

**未做**：`apps/admin` / `sample-frontend` 未启新 dev server 长期验证（走查用的临时
5173 端口 server 已关）；四个仓 `0.2.0-dev` 本地已改，尚未提交推送时见下方 git 状态。
另注意 `apps/admin` 与 `sample-frontend` 的 `.env.development` 都写死 `VITE_PORT=5777`，
谁先起谁占端口，容易看错 app——本轮未改，可考虑给 `apps/admin` 换个端口。

***

## 2026-08-27 追加：在线用户模块升级（登录 IP/设备 + 分页）

用户反馈两点：在线用户列表没有登录 IP / 登录设备；且怀疑没做分页，在线用户多时
一页全展示有问题。核实：确实两处都没有分页（后端 `list()` 返回全量 `List`，前端
裸 `ElTable` 无 `ElPagination`）。均已在 `0.2.0-dev` 上做完，**四个仓库本地已提交**
（`framework` / `framework-cache-redis-starter` / `frontend` / `sample-app`），
`sample-frontend` 只是消费方无源码改动。

**新增能力**

1. **登录 IP + 登录设备**。新增 `SessionMeta`（`api/`，IP + 设备）；`TokenStore`
   加 `issue(user, meta)` / `issueWithRefresh(user, meta)` 两个 `default` 重载
   （默认忽略 `meta`，延续 `listActive` 那套加法）；`ActiveSession` 加 `ip` / `device`
   两个字段。`AuthController.login` 注入 `HttpServletRequest`，用新增的
   `RequestClientInfo`（`framework-system-starter` 内部，非 `api/`）提取：IP 走
   `X-Forwarded-For` 首段 → `X-Real-IP` → `remoteAddr`；设备对 `User-Agent` 做
   **轻量启发式**（`Chrome · Windows` 这种粒度，不引 UA 解析库），识别不出为 `null`。
   `OperLogAspect` 一并改用 `RequestClientInfo.clientIp`（顺带让操作日志也认
   `X-Real-IP`）。刷新令牌时来源随会话延续（内存实现存进 `Entry`/`RefreshEntry`，
   Redis 实现存进 `StoredSession` 的两个扁平字段）。
2. **后端分页**。`GET /api/system/online` 改为接受 `PageQuery`、返回
   `PageResult<ActiveSession>`。分页在 `SysOnlineController` 应用层对
   `tokenStore.listActive()` 的全量快照切片——`TokenStore` 没有分页入参，翻页会重复
   一次全量枚举，但这是低频管理页、在线会话数天然有界，换来的是与其余列表页一致的
   `PageResult` 契约。前端 `views/online/index.vue` 照抄 `oper-log` 的分页写法加
   `ElPagination` + 「登录IP」「登录设备」两列（`data-testid="online-pagination"`）。

**Breaking（0.2.0 未发布，不留兼容）**

- `ActiveSession` 构造函数新增 `ip` / `device` 两个参数，不保留旧重载。
- `GET /api/system/online` 返回体 `List<ActiveSession>` → `PageResult<ActiveSession>`。

**测试**：`InMemoryTokenStoreTest` / `RedisTokenStoreTest` 各 +3（来源写入、可选、
刷新延续）；新增 `RequestClientInfoTest`（IP 头优先级 + UA 启发式，10 例）；
`sample-app` `OnlineSessionIT` +3（分页信封、`X-Forwarded-For`+UA 端到端、`size` 生效）。
`framework` 两模块单测全绿；`framework-cache-redis-starter` `RedisTokenStoreTest` 23 全绿
（Testcontainers）；`sample-app` `OnlineSessionIT`(7) / `AuthFlowIT` / `RefreshTokenIT`
/ `FrameworkRuntimeIT` 全绿；前端 `apps/admin` `vue-tsc --noEmit` 干净。
CHANGELOG：`framework`、`framework-cache-redis-starter` 均已补。

**未做**：`sample-frontend` 按"已发布依赖"方式消费 `@describeadmin/system-ui`，
其 `dist` 是旧的；要在 sample-frontend 里看到新页面需先 `pnpm build` 共享包
+ `pack-local-deps.sh` + `pnpm install`，本轮未跑（与前一章节同一情况）。

***

## 2026-08-27 追加：token 过期不跳转登录页 + 登录失效提示重复/文案不一致

用户反馈的三个连续问题，根因各不相同，均已在 `0.2.0-dev` 上修完（尚未提交/推送）：

1. **token 过期后页面不跳转登录页**。根因：`refreshTokenApi`/`logoutApi` 此前用
   挂了 `authenticateResponseInterceptor` 的 `requestClient`，导致这两个"重新认证
   流程自己要调用的接口"在 `isRefreshing=true` 临界区内被同一套拦截器递归重入，
   `logout()` 里 `await logoutApi()` 永久挂起。修复：新增 `authLifecycleRequestClient`
   （拦截器栈去掉 `authenticateResponseInterceptor`），`refreshTokenApi`/`logoutApi`
   改用它。
2. **修复①之后出现一条"内部服务器错误"误报**。根因：`authenticateResponseInterceptor`
   刷新令牌失败的 `catch` 块里 `throw refreshError`（刷新请求自己的错误，已被
   `RequestClient.request()` 剥掉 `.response` 只剩后端返回体）而不是 `throw error`
   （原始请求的错误，带 `.response.status`），导致下一层按状态码分类时读到
   `undefined`，落进 `default` 分支。修复：改成 `throw error`，与旁边
   `!enableRefreshToken || config.__isRetryRequest` 分支保持一致。
3. **登录失效时并发弹出多条提示，且文案不统一**（一条是标准 401 的
   "未认证或登录已过期"，一条是 `/auth/refresh` 业务失败自定义的
   "刷新令牌无效或已过期，请重新登录"）。两个独立问题：
   - **文案统一**：`errorMessageResponseInterceptor` 新增 `unauthorizedCode` 选项，
     把"HTTP 401"和"业务码 40100（`ResultCode.UNAUTHORIZED`）"这两种登录失效的
     出场形式统一识别为 `isAuthExpired`，命中时不再用 `responseData.message`，
     固定展示 i18n `ui.fallback.http.unauthorized` 文案。新增
     `@describeadmin/constants` 的 `RESULT_CODE_UNAUTHORIZED` 常量。
   - **只弹一次**：新增模块级标记 `authExpiredNotified`（三个 app 各一份
     `src/api/auth-expired-notify.ts`），同一次登录失效事件只让第一个命中的
     请求弹提示。**踩坑记录**：这个标记最初放进了 Pinia 的 `accessStore`，
     实测从 3 条只降到 2 条——`logout()` 内部的 `resetAllStores()` 会在
     "最先触发这一切的原始请求"自己走到判断点之前就把标记提前清零，导致它
     绕过了去重。改成完全独立于 Pinia 生命周期的模块级变量（只在下次登录
     成功后复位）才稳定收敛到 1 条。用 chrome-devtools 全新标签页反复复现
     验证：真实浏览器登录 + 内存里破坏 token + 触发页面请求，稳定只弹 1 条。
   - 顺带清理：`@describeadmin/system-ui` 的 8 个列表页（user/dept/role/menu/
     dict/config/online/oper-log）`onMounted` 里的数据拉取此前没有 catch，
     登录失效时会在控制台产生一条
     `[Vue warn]: Unhandled error during execution of mounted hook`——功能上
     无害（全局拦截器已经处理了提示和跳转），但控制台噪音容易误导排查，
     统一包了一层 try/catch（空 catch，注释说明原因）。

涉及文件：共享包 `preset-interceptors.ts`/`types.ts`（`@describeadmin/request`）、
`RESULT_CODE_UNAUTHORIZED`（`@describeadmin/constants`）、8 个 system-ui 视图；
三份各自的 `src/api/request.ts`、新增 `src/api/auth-expired-notify.ts`、
`src/store/auth.ts`（`apps/admin`、`packages/create-app/template`、
`sample-frontend`）。`vue-tsc --noEmit`/`eslint` 均干净（sample-frontend 需要先
`pnpm build` 改动到的共享包再跑 `pack-local-deps.sh` + `pnpm install`，
它是按"已发布依赖"的方式消费这些包的，不会自动感知源码改动）。

***

## 2026-08-26 追加：个人中心移动端适配 + 在线用户时间格式/时区修复

两个前端可用性问题，均已在 `0.2.0-dev` 上修完，`framework`/`frontend` 已推送，
`sample-frontend`（无远端）已本地提交：

1. **个人中心页面不兼容移动端，修改密码表单在不同 PC 尺寸下也挤压**。
   根因是 `packages/effects/common-ui/src/ui/profile/profile.vue` 的侧边栏+内容区
   用固定 `w-1/6`/`w-5/6` 两栏布局，窄屏下直接被压垮；`password-setting.vue` 的
   `VbenForm` 又是 `layout: 'horizontal'` + 固定 `labelWidth: 130`，与页面级
   `password-setting.vue` 外层写死的 `w-1/3`（相对内容区的比例，容器变窄时
   输入框同比例挤窄）叠加，PC 窗口稍窄就不好用。
   修复：`profile.vue` 在 `lg` 断点以下纵向堆叠（配合 `useBreakpoints` 同步切换
   `Tabs` 的 `orientation`）；`base-setting.vue`/`password-setting.vue`（common-ui）
   用同一个 `md` 断点把 `VbenForm.layout` 动态切到 `vertical`；三份页面级
   `password-setting.vue`（`apps/admin`、`packages/create-app/template`、
   `sample-frontend`）外层宽度从 `w-1/3` 改成 `w-full max-w-lg`。
   frontend commit `b3689e2`，sample-frontend commit `2e1edb7`。
2. **在线用户列表的登录/过期时间格式、时区都不对**。根因是
   `ActiveSession.issuedAt`/`expiresAt` 是 `Instant`，`FrameworkJsonModule`
   （4.8 节）此前只处理了 `LocalDateTime`/`LocalDate`/`LocalTime`，`Instant` 走
   Jackson 默认序列化——UTC 的 ISO-8601（带 `T`/`Z`），既跟框架统一的
   `yyyy-MM-dd HH:mm:ss` 格式不一致，也没按服务器时区换算。
   修复：新增 `LocalizedInstantSerializer`，复用同一个 `dateTimeFormat`，
   按 `ZoneId.systemDefault()` 换算后输出同款字符串；只做序列化，不做反序列化
   （目前没有 `@RequestBody` 需要把 `Instant` 当输入接收）。前端 `online/index.vue`
   不需要改——后端格式一致后，跟其余 `createTime` 之类的列一样直接展示原始字符串
   即可。framework commit `158840a`，已补测试 `FrameworkJsonModuleTest`。

***

## ⚠️ 分支模型（2026-08-26 起生效，覆盖下面「五个 PR 待合并」一节）

- **主分支统一是 `main`**。此前 `framework-auth-email-starter`/`framework-crypto-starter`
  用的是 `master`，`sample-frontend`（无远端）也是 `master`，三者都已改名为 `main`；
  前两者的 GitHub 默认分支也已切到 `main`。
- **`main` 保持不动**，仍指向已发布的 0.1.0/0.1.1——0.1.0 只是用来跑通 Maven Central/npm
  发布流程的，不是正式版本，**不需要为它保留任何向后兼容代码或走 PR 合并**。
- **`0.2.0-dev` 是唯一的开发分支**，已从 `main` 建出并把当时各仓库存在的开发分支合并了
  进去（全部是 fast-forward 或干净合并，无冲突）。**后续所有开发都在 `0.2.0-dev` 上做**，
  不要再新建长期存在的功能分支。
- 下面「五个 PR 待合并」一节里提到的 5 个 PR（framework/docs/codegen/frontend/sample-app
  各 #1）**内容已经在 `0.2.0-dev` 里了**，PR 本身还开着但已经不是推进 0.2.0 的路径——
  是否关闭这些 PR 待用户决定，AI 未擅自处理。
- 顺带做了一次历史兼容代码清理（用户要求"0.1.0 不算数，不用保留兼容代码"）：删掉了
  `framework` 里 `system.core.TreeBuilder`（纯转发的 `@Deprecated(forRemoval=true)`
  过渡类）和 `LoginResult` 的 3 参数向后兼容构造函数，两者当时都已无调用方；
  其余仓库排查后未发现类似的历史兼容 cruft（`frontend` 里几处"向后兼容"字样是从
  vue-vben-admin 5.7.0 取材带进来的第三方代码自身的 API 设计，不是 describeadmin
  自己的历史包袱，未动）。

***

## 五个 PR 待合并（旧记录，已被上面「分支模型」一节取代——仅保留历史信息）

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
  ⚠️ **`dashboard/index` 这部分结论已于 2026-08-26 撤销，见下方新记录。**
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

***

### 纠偏：worktree/可视化测试工具改到新仓库 `workspace`（2026-08-26）

上两条被 revert 的记录（`scripts/dev.sh`、`testing/VISUAL_TESTING.md`）是本轮对
"面向 AI 编程 / 全自动可视化测试 / worktree 友好"三个设计初衷的第一次落地尝试，
**放错了受众**：`docs/` 是框架团队自己的元仓库（`repos.yml`/`clone-all.sh` 拉的是
`framework`/`codegen`/`sample-app`/`sample-frontend`/`docs` 这一族框架自己的仓库），
业务方从不 clone 它。业务方的真实工作空间只有 `mvn archetype:generate` 生成的
`<业务>-server`、`npm create @describeadmin/app` 生成的 `<业务>-web`，放进 `docs/`
的东西业务方永远看不到。

用户拍板方向：新建独立的 **`workspace`** 仓库（`describeadmin/workspace`），承载：

- `init-workspace.sh`：唯一入口脚本，首选分发方式
  `curl -fsSL .../init-workspace.sh | bash -s -- <name>`，一条命令生成
  `<name>-server`（archetype）+ `<name>-web`（create-app）+ `.claude/skills/`
  + 业务方视角的 `CLAUDE.md`（新写的，不是框架团队那份的摘抄——不涉及插件作者规范、
  发布治理这些业务方用不上的内容）
- `.claude/skills/dev-env/`：本轮 `docs/scripts/dev.sh` 的通用化版本——目录名/项目名
  从 `init-workspace.sh` 写的 `.claude/workspace.env` 读，不再硬编码
  `sample-app`/`sample-frontend`；共享 MySQL/Redis 容器名按项目派生，避免同一台机器上
  跑多个业务方项目时撞名。slug/端口偏移算法本轮已验证正确，原样带过去
- `.claude/skills/visual-test/`：本轮 `VISUAL_TESTING.md` 的通用化版本，含
  `click`/`fill` 走 `take_snapshot` 的 `uid`（不接受 CSS 选择器）这条真实跑通时才
  发现的关键修正。`dept-create.yaml` 场景保留——`@describeadmin/system-ui` 的部门页面
  随每个业务方项目分发，不是 sample-app 专属，这个示例场景对任何业务方项目都成立

`docs` 仓的两条 revert 是干净的（Windows 文件锁导致 `.gitignore` 那部分手工补了一刀，
效果一致，见 revert 提交信息）。完整设计方案见批准的 plan（本会话）。

#### `workspace` 仓库已在本地写完并做过真实端到端验证（2026-08-26）

本地 `c:\...\describe-admin\workspace\` 已建成 git 仓库（尚未推远端，见文末待办），内容：
`README.md`（框架团队视角）、`CLAUDE.md`（业务方视角，新写）、`init-workspace.sh`、
`.claude/skills/dev-env/{SKILL.md,dev.sh}`、`.claude/skills/visual-test/{SKILL.md,
scenarios/dept-create.yaml}`。`docs/repos.yml` 新增 `enablement` 分组登记这个仓库
（`status: planned`，建仓后改 `active`）；`develop_plan.md` 新增 9.5.1 节记录这个机制。

**真实端到端跑通一次**（不是只读代码判断，见 CLAUDE.md 3.6 一贯的验证纪律）：

1. `describeadmin-archetype` 确认已发布 Central（`0.1.1`），`init-workspace.sh` 用真实的
   `mvn archetype:generate` 生成后端工程，`groupId`/`artifactId`/`package` 派生正确
2. `@describeadmin/create-app` **确认尚未发布 npm**（`404`）——这是已知状态
   （`repos.yml` 早就记着"尚未发布到 npm registry"），本轮验证时用一个 stub
   （`mkdir` 代替 `npm create`）绕过这一步，只为了继续验证脚本后续逻辑，
   不代表这一步本身跑通了；`workspace` 建仓推送后，真正的首次端到端验证要等
   `create-app` 发布 npm 才能补全
3. "拉取 `.claude`/`CLAUDE.md`"（本地 clone 场景）+ 写 `.claude/workspace.env` 两步
   验证通过，生成物目录结构与 `README.md` 描述的 1:1 对应关系一致
4. `dev-env` 的 `dev.sh slug`/`dev status` 在生成出的新工作空间里正确读到
   `workspace.env`，且用两个不同 slug（模拟两个 worktree）验证了"共享的 MySQL/Redis
   容器名与端口只随项目名变化、后端/前端端口与 DB schema 只随 worktree 变化"这条
   设计在真实脚本里成立
5. `dev.sh dev up` 真实拉起了一套新的共享容器（`describeadmin-dev-mysql-testapp`/
   `describeadmin-dev-redis-testapp`，与框架团队自己用的 `da-mysql` 完全独立）+
   真实的 `mvn spring-boot:run`，`curl /api/auth/login` 拿到了正确的 token 与
   RBAC 权限列表，中文昵称"超级管理员"正常（再次确认没有 3.6 那类字符集坑）

**验证过程中发现并当场修复的两个真实问题**（不是理论推演）：

- **`dev down` 杀不干净 Windows 上的 java 子进程**：`taskkill //T` 杀的是记录下来的
  那个 pid 自己的进程树，但 `mvn spring-boot:run` 派生出的真正 java 进程往往已经
  脱离那棵树——`dev down` 报告"已停止"，java 却还占着端口。原脚本头部注释把这个写成
  "极端情况下可能需要手动确认"，实测是**必现**。已改为按端口杀
  （Windows 用 `Get-NetTCPConnection | Stop-Process`），验证过对真实残留进程有效
- **并发 `dev up` 会撞 `docker run` 的 name 冲突**：`ensure_dev_mysql`/`ensure_dev_redis`
  的"先查是否存在再创建"没有加锁，本轮测试时手滑对同一个 worktree 并发跑了两次
  `dev up`，第二次在 Redis 容器创建那步撞上"name already in use"。已记录进头部注释的
  已知限制（不加锁，避免过度设计——单次调用本身幂等，问题只在并发调用这个边缘场景）

**已解决（2026-08-26）**：`workspace` 仓库已人工确认后建仓并推送：
[github.com/describeadmin/workspace](https://github.com/describeadmin/workspace)
（`main` 分支）。`docs/repos.yml` 已同步改回 `active`。

**待办（下次开工先看这里）**：
1. `visual-test` 的 `dept-create.yaml` 在这个新仓库的文件布局下**没有重新跑一遍**——
   跑之前用的核心机制（`click`/`fill` 走 `uid`、DB 断言用 `mysql` CLI）本轮之前已经
   验证过，本次只是文件挪了地方 + 措辞通用化，判断风险低所以没重复跑，但这仍然是一个
   没有闭环验证的点，不要当成"已验证"
2. `@describeadmin/create-app` 发布 npm 之后，应该补一次不加 stub 的完整端到端跑通

***

### 账号密码登录接入渐进式图形验证码（2026-08-26）

用户提出"给账号密码登录加验证码"，讨论定型为：核心内置图形字符验证码（零依赖），
预留 `CaptchaProvider` 契约供以后接入滑块/Cloudflare Turnstile/阿里云等第三方插件
（本轮不做任何具体第三方插件）；触发策略用渐进式——正常登录不要求，同一用户名连续
失败达到阈值（默认 3，严格小于 `lockout.max-failures` 默认 5）后才要求，复用
`LoginAttemptGuard` 已有的失败计数。四仓均已提交并推送到各自现有分支
（`framework`/`sample-app`/`frontend` 续在本文件顶部表格登记的那几条分支上，
`sample-frontend` 本地仓库无远端）。

**`framework`**（续在 `feat/0.2.0-permission-cache-plugin` 分支）：

- 新增 `CaptchaProvider`/`CaptchaChallenge`（`framework-security-starter` 的 `api`
  包）：`generate()`/`verify()` 两个动作，`verify` 一次性（无论对错立即失效，防重放）；
  渲染数据放在 `payload: Map<String,Object>` 里而不是加签名字段，与 `AuthRequest`
  解决"不同登录方式入参形状不同"是同一手法，保证以后接第三方插件不用改这两个类
- 新增 `ImageCaptchaProvider`（`core` 包）：`BufferedImage`/`Graphics2D` 离屏渲染，
  `CACHE_KEY_PREFIX` 刻意声明为 `public`——图形验证码是给人眼看的，自动化测试没法
  "识图"，只能通过注入的 `CacheProvider` 直接读出正确答案，这是刻意的可测试性设计
- 新增 `CaptchaGuard`（`core` 包）：渐进式触发编排，`LoginAttemptGuard` 新增只读
  `failureCount()` 供其判断阈值，不新起一套计数；验证码答错/缺失**不计入**登录失败
  计数（避免两套计数联动放大锁定）；`attemptGuard` 为 `null`
  （`lockout.enabled=false`）时 fail-open，不因为一个开关被关就意外生效或失效
- `ResultCode` 新增 `CAPTCHA_REQUIRED(40103)`/`CAPTCHA_INVALID(40104)`；
  `FrameworkSecurityProperties` 新增 `captcha.*` 配置项，`trigger-threshold` 必须
  严格小于 `lockout.max-failures`，装配时校验，配置错误直接拒绝启动而不是运行到一半
  才发现验证码没生效；`AuthController` 新增 `GET /api/auth/captcha`（免认证），
  `login()` 在 `registry.authenticate()` 之前挂 `CaptchaGuard`
- 新增测试：`ImageCaptchaProviderTest`（含一次性防重放的核心断言）、
  `CaptchaGuardTest`（阈值/放行/fail-open 各分支）、
  `FrameworkSecurityCaptchaAutoConfigurationTest`（装配行为，含启动期拒绝非法阈值）；
  `LoginAttemptGuardTest` 补 `failureCount` 用例。均通过（`framework` 单测新增
  30 例，全绿）

**`sample-app`**（续在 `test/0.2.0-permission-online-lockout` 分支）：

- `AuthFlowIT` 新增验证码分区，走完整 HTTP 链路验证渐进式触发、一次性防重放、
  两层校验独立
- **发现并修复一个真实的跨功能交互**：`LoginLockoutIT` 原本裸发用户名密码，默认
  `trigger-threshold(3)` 小于 `lockout.max-failures(5)`，第 3 次失败起会被
  `CaptchaGuard` 拦在锁定判断之前（返回"需要验证码"而不是"用户名或密码错误"），
  锁定计数因此卡在 3 不再前进——4/6 用例直接跑挂。这不是回归，是验证码这道新防线
  与既有锁定测试的真实交互：`LoginLockoutIT` 要单独验证"锁定"这一层，改法是让它的
  `login()` 每次都顺带解出一个真实验证码一并提交，绕开这层拦截；已在类注释里写明
  这条交互，避免以后有人以为是巧合
- **顺带发现两个与本轮无关的既有问题，未修复**（记在这里免得下次又当新 bug 排查）：
  ① `AuthFlowIT.loginReturnsRefreshToken` 报 `ClassCast String→Number`——阶段 G 把
  `LoginResult.expiresIn`/`refreshExpiresIn`（原始类型 `long`）也纳入了"`Long`/`long`
  → 字符串"的序列化约定，但该测试断言仍按数字类型读，阶段 G 验证基线表里明确写过
  "本批没有重跑 sample-app 集成测试"，这次是第一次真正跑到这条路径；
  ② `PermissionEnforcementIT.noRoleUserIsDeniedOnPreAuthorizeEndpoint` 偶发失败，
  比对的是含 `timestamp` 字段的完整 JSON 字符串，天然对时间敏感，是断言方式的问题
  不是功能问题

**`frontend`**（续在 `feat/email-login-and-refresh-token` 分支）与 **`sample-frontend`**
（本地仓库，`feat/email-login` 分支）：

- 不改 `@describeadmin/ui` 发布包——图形验证码只是"一张图 + 一个输入框"，在业务方
  自己拥有的 `login.vue` 里加一个表单字段即可；验证码图片用 `VbenFormSchema.suffix`
  （支持函数返回 VNode，由 `form-field.vue` 的 `VbenRenderContent` 渲染）贴在输入框
  旁，不需要新增插槽
- `auth.ts` 加 `captchaId?`/`captchaCode?`/`CaptchaChallenge`/`getCaptchaApi()`；
  `login.vue` 正常登录不显示验证码字段，登录失败时按错误码判断是否需要显示
- **真实浏览器验证时发现一个关键点**：最初按 `error.response.data.code` 读错误码
  完全不生效，验证码字段永远不出现。根因是 `RequestClient.request()`
  （`packages/effects/request/src/request-client/request-client.ts`）在 axios
  拦截器链跑完之后又做了一层展开——`throw error.response ? error.response.data :
  error`——到应用层 `catch` 到的 `error` 已经是后端 `Result` 原始 JSON 本身，不再
  嵌套 `response.data`。这条只在真实点击链路里才会暴露，`vue-tsc` 类型检查测不出来
  （`error: any`），单元测试也测不出来（没有真的走一遍 axios 拦截器链）。已改用
  `error.code` 读取，并用 chrome-devtools 在 `apps/admin` 上完整点了一遍
  "多次输错密码 → 出现验证码图片 → 输错验证码密码仍分别报错 → 验证码+密码都对，
  登录成功、验证码字段消失"，网络面板确认每一步的响应码（40102/40103/40104/0）
  与预期一致
- locales 补 `authentication.captcha`/`captchaTip`/`captchaRefreshTip`
  （`zh-CN`、`en-US`）

**已知遗留**：三方验证码插件（Cloudflare Turnstile、阿里云/腾讯云等）本轮只留了
契约扩展点，未实现；讨论过程中确认这类插件即使做，前端也要为每一家单独写适配组件
（各家 JS SDK 初始化方式不同，没有统一协议），不是"后端装插件、前端零代码"，这条
结论供以后接具体厂商时参考。

### 工作台首页从 system-ui 移出（2026-08-26，纯前端，仅 `frontend`/`sample-frontend`）

用户先反馈"工作台/用户管理页面把 `framework-system-starter` 之类的实现说明当成
`Page` 的 `description` 展示给了最终用户"，改成注释后引出一个更根本的问题：
工作台首页原本靠并发请求 `/api/system/{user,role,menu/tree,dept/tree}` 四个接口算
统计数字，而这四个接口分别要求对应模块的 `xxx:list` 权限——只分配了"工作台→概览"
菜单的用户登录后这四个请求全部 403，还会触发全局错误提示。讨论后决定：**工作台首页
不再请求任何接口**，改成纯静态欢迎页（问候语按时段计算、用户名/角色来自登录时已有的
`userStore`、四张卡片换成静态能力介绍文案）。

改完之后用户追问了一个更深的问题：这个页面既然已经不依赖任何 `framework-system-starter`
实体，还应不应该继续放在 `@describeadmin/system-ui`（随框架版本发布）？结论是**不应该**，
理由与上面 2026-08-21 记录里"进 system-ui"的判据（是否围着框架实体转）正好相反，
已按此把它挪出：

- `frontend/packages/effects/system-ui/src/views/dashboard/` 整个删除，
  `src/index.ts` 的 `systemPageMap` 去掉 `/dashboard/index.vue` 这一条
- 迁到三处应用外壳各自的 `views/dashboard/index.vue`（`apps/admin`、
  `packages/create-app/template`、`sample-frontend`），定位对齐既有先例
  `views/_core/profile`/`views/_core/about`——这类"通用但归属具体应用、不是框架能力"
  的页面本来就该在外壳里，业务方生成项目后可以直接改问候语/文案/快捷入口
- 顺带修了一个在排查这个问题时发现的合并顺序缺陷：三处 `access.ts` 原来是
  `{ ...import.meta.glob('../views/**/*.vue'), ...systemPageMap }`，`systemPageMap`
  展开在后——同 key 时框架默认页面会**静默覆盖**业务方本地同名页面，且没有任何报错。
  已调整为 `systemPageMap` 展开在前，业务本地 `views` 覆盖框架默认，这才是符合直觉
  的语义（本条同时补进了下面"容易忘的约束"第 10 条）
- `packages/create-app/README.md` 关于"哪些目录不该出现在 template 里"的说明同步更新：
  `views/dashboard` 从"不应该出现"改成"应该出现"（例外说明写在原地）
- `seed-rbac.sql` 的 `component = 'dashboard/index'` 不用改，它只是个 key，
  不关心物理文件在哪个包
- 本轮改动只涉及前端（`frontend` + `sample-frontend`），未提交/推送，本地验证用
  chrome-devtools 打开 `/dashboard/workbench`，确认控制台无告警、网络面板不再出现
  那四个接口、页面正常渲染问候语与角色标签

### 个人中心：自助改资料/改密码 + 密码复杂度策略（2026-08-26）

用户反馈"个人中心"是个从 Vben 脚手架继承下来、从没接后端的静态页面（`基本设置`
能读不能写、`修改密码`点提交只弹一条假成功提示，`安全设置`/`新消息提醒`全是硬编码
假数据）——`docs/PROGRESS.md` 此前从未把这个页面列为已知欠账，`develop_plan.md`
也没有针对它的设计章节，是个纯粹被遗漏的空白点。已按以下范围补齐，
四仓 `feat/profile-self-service` 分支：

- **基本设置**：允许自助改姓名/手机号/邮箱，用户名只读、角色字段（此前是假数据）
  整体删除。后端新增 `GET/PUT /api/auth/profile`（`AuthController`），
  `SysUserService.updateOwnProfile`
- **修改密码**：接通此前已经存在但前端从未调用过的 `PUT /api/auth/password`
  （2026-08-22 那批登录模块修复里就做完了后端，只是没接前端），并补上一套此前完全
  没有的密码复杂度策略——新增 `PasswordPolicy` SPI（`framework-security-starter`，
  与 `TokenStore`/`CacheProvider` 同一"契约 + 零依赖默认实现"模式），默认口径
  8 位 + 大写/小写/数字/特殊字符至少 3 类，套用到自助改密/管理员重置密码/创建用户
  设初始密码三处入口（用户明确要求"三处全部统一生效"）
- **安全设置**：无对应功能，直接删除（含 `security-setting.vue`）
- **新消息提醒**：功能尚未实现，从 tabs 里摘掉但保留 `notification-setting.vue`，
  等消息通知能力上线后再接回来

**过程中意外发现并修复了两个数据权限相关的既有 bug**——本次新增的 HTTP 层集成测试
（`AuthFlowIT`）第一次让"无角色的普通用户"以真实登录态跑通自助端点全链路时暴露，
此前的测试要么用 admin（`dataScope=ALL`，天然绕过这条过滤），要么直接调 Service
方法（不经过 `SecurityContextHolder`，数据权限过滤同样不生效），从未真正测到：

1. 无角色用户默认 `dataScope=SELF`，`DeptDataPermissionHandler` 对 `sys_user`
   表的过滤条件是 `create_by = 当前用户id`——但用户自己的账号几乎总是管理员创建的，
   结果是"自己查自己都查不到"，`GET /api/auth/profile` 返回 `data: null`，
   改资料/改密码的 `updateById` 也会因为同一个过滤条件静默影响 0 行。
   新增 `SysUserMapper.selectSelfById`/`updateSelfPassword`/`updateSelfProfile`
   （`@InterceptorIgnore(dataPermission = "true")`）绕开过滤，只供确认是当前
   登录用户自己时使用
2. `findByMobile`/`findByEmail` 用于全局唯一性校验，同样受这条过滤影响——
   SELF/DEPT 档的操作者会把"已被别人占用但自己看不到"的手机号/邮箱误判为可用。
   同样改为忽略数据权限的查询

验证：`sample-app` 102 个集成测试全绿（含新增的密码策略正/反例、自助资料 HTTP 层
测试、手机号冲突检测）；`framework-security-starter` 新增 `DefaultPasswordPolicyTest`
7 例全绿；三处前端（`apps/admin`/`create-app/template`/`sample-frontend`）
`typecheck`/`build` 均干净；用 chrome-devtools 以真实无角色用户账号走完整链路
（改资料成功、手机号冲突正确拒绝、弱密码被前后端双重拒绝、改密成功后正确跳转登录页、
新密码可登录）。过程中还顺带修了一个前端自己的 bug：改密成功后原先直接调
`authStore.logout()`，会跟框架内置的 401 自动重新认证拦截器抢着处理同一个已失效
令牌，两边并发 `resetAllStores`+跳转互相打断，实测卡在原地不跳转；改为改密成功后
直接清本地登录态并跳转，不再触发这条竞态。

四个仓库均已提交到 `feat/profile-self-service` 分支；`framework`/`sample-app`/
`frontend` 已推送到远端（尚未开 PR），`sample-frontend` 是本地仓库无远端。

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
10. **判断一个前端页面该不该进** **`system-ui`，看它是否围着** **`framework-system-starter`**
    **的实体转**，不是看它"看起来像不像系统管理页面"。工作台首页最初因为展示四个实体的
    统计数字而放进 system-ui，后来改成不请求接口的纯静态欢迎页后就应该挪出去——这类
    "通用但归属具体应用"的页面（同 `views/_core/profile`/`views/_core/about`）该待在
    应用外壳里，业务方能直接改。三处 `access.ts` 合并 `pageMap` 时，`systemPageMap`
    必须展开在业务本地 `import.meta.glob('../views/**/*.vue')` **之前**，让本地同名
    页面覆盖框架默认，反过来会被静默吃掉且没有报错。

