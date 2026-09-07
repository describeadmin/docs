# 非代码层优化 —— 迁移决策记录（临时）

> 本文件是「摆脱 sample-app 依赖 + docs 整理 + 删 CLAUDE.md 副本 + README 重写」
> 这轮优化的对照基准与决策记录。立项 2026-09-07。
>
> **状态：Phase 1~4 已全部完成**（2026-09-07/08，各仓已提交 `main`、未推远端）。
> 多条 commit message 与 `repos.yml` 引用本文件，故暂留一个发布周期；`0.2.2` 发版后可删。
>
> 已完成：
> - **Phase 1**：`framework-it` 不发布模块（104 断言，5.7/8.4 双跑绿）；`it-matrix` CI job；
>   `notify-consumers.yml` 删除；`codegen` `e2e-compile` job；插件 IT 比对（crypto 无需迁移、
>   email 记 follow-up）；`frontend` playground 文案；`sample-app`/`sample-frontend` 本地删除，
>   远端 `sample-app` 保留不动（人工决定）
> - **Phase 2**：删 `develop_plan.v0.3.bak.md` / `scripts/toolchains.xml.sample`；
>   全 docs 的 sample-app / toolchains 引用清理；`CLAUDE.md` 母本 §0/头注释/§1/§6 改写；
>   `develop_plan.md` 981→887 行（删附录 A、第十章塌缩、剥离版本标记）；
>   `VERSION_BASELINE.md` 加编号索引 + 剪已完成项；`PROGRESS.md` 1855→138 行
>   （历史切 `PROGRESS.archive.md`）；`LOGIN_MODULE_AUDIT.md` 存档 banner
> - **Phase 3**：8 个子仓 `CLAUDE.md` 副本删除（比对确认仅换行格式差异，无内容漂移）；
>   `docs/CLAUDE.md` 与 `workspace/CLAUDE.md` 保留；工作区根 `CLAUDE.md` 刷新为母本副本
> - **Phase 4**：11 个仓 README 补 framework-it / 「相关文档」指针 / 去陈旧版本号
>
> 未做（记为 follow-up，见 D4）：`framework-auth-email-starter` 的 HTTP 过滤器链整合测试。

## 已定决策

### D1 — sample-app / sample-frontend 彻底删除
- 两个仓当初只为临时测试而建，从未打算作为框架开发的一份子，现已被发版门禁严重依赖。
- 本地目录删除；`describeadmin/sample-app` 远端仓删除（需人工确认后执行）；
  `sample-frontend` 无远端，仅删本地。
- 其承担的验证职责按 D3 / D4 / D5 转移。

### D2 — 各子仓根目录 CLAUDE.md 副本全部删除
- 框架 / 插件开发只需并列检出 `<目标仓> + docs` 两个仓，不需要 clone-all。
- 保留：`docs/CLAUDE.md`（唯一母本）、`workspace/CLAUDE.md`（业务方视角，内容本就不同）。
- 删除前先把 `frontend` / `framework-auth-email-starter` / `framework-crypto-starter`
  三份已漂移副本里「母本没有、仅本仓相关」的条目回收进母本或对应仓 README。
- 母本 §0 改为「clone 目标仓 + docs 并列检出」；删掉「各子仓以副本/软链复用、自动同步脚本待实现」整段。

### D3 — 双版本 MySQL 运行时门禁 → `framework` 仓新增 `framework-it` 不发布模块
- 只在 `-Pit` profile 的 `<modules>` 里挂载，默认 reactor 与 `-Prelease` 均不含它；
  另加 `maven.deploy.skip=true` 兜底。不受 `enforce-core-thin` 约束。
- 从 `sample-app/src/test` 迁入框架核心运行时行为断言（审计填充 / 分页 / 逻辑删除 /
  乐观锁 / 中文往返 / 认证 SPI / 系统模块 CRUD / 权限与数据权限 / 操作日志 / 在线会话 /
  登录锁定 / 口令策略 / 强制改密），Testcontainers 跑 `mysql:5.7` 与 `mysql:8.4`。
- framework CI 新增 `it-matrix` job；保留现有 `archetype-e2e`（它已覆盖「真实业务方姿态 +
  BOM 仲裁 + JDK 17 最低版本构建 + 中文字节核验」，接掉 sample-app 保留 toolchains 的职责）。
- `notify-consumers.yml` 删除对 sample-app 的 repository_dispatch。

### D4 — 插件专属集成测试 → 回到各自插件仓
比对结论（2026-09-07）：

- **`framework-crypto-starter`**：已有自带 `it/` 包（`AbstractMySqlIntegrationTest` +
  Testcontainers + `CryptoTestApplication` + `CryptoEndToEndIntegrationTest` 6 例 +
  `BlindIndexInnerInterceptorTest` 10 例，共 90 个 @Test）。sample 的
  `EmployeeCryptoIT`/`NurseCryptoIT`（密文入库 / 明文读出 / partial update 不清空密文 /
  盲索引等值命中）**已被完全覆盖**，`autoResultMap` 陷阱也已写进该仓 README 与 javadoc。
  → 无需迁移，随 sample-app 一并删除。
- **`framework-auth-email-starter`**：已有 `EmailCodeServiceTest`（GreenMail 真实收发 /
  错误码 / 防枚举，10 例）+ `EmailCodeAuthProviderTest` + `FrameworkAuthEmailAutoConfigurationTest`
  （共 28 个 @Test），登录逻辑层已覆盖。sample 的 `EmailLoginIT` 唯一未被覆盖的是
  **HTTP 过滤器链整合**（发码端点经 framework-security 的 permit-all 贡献免认证可达、
  `/api/auth/providers` 的 HTTP 响应形态）。此项风险低且已在插件 README 明确记载
  「不加 permit-all 会 401」。
  → 本轮不迁移。建议后续在该插件仓补一个 `WebEnvironment.RANDOM_PORT` 整合测试
  （需把 framework-security-starter + framework-system-starter 加入其 test scope），
  作为独立 follow-up，不阻塞 sample-app 删除。

### D5 — codegen 端到端验收 → codegen 仓自带夹具
- 新增 `codegen/e2e/`：自带 spec 夹具（等价于原 `sample-app/codegen-specs/project.yaml`）。
- CI 用 `describeadmin-archetype` 生成一次性后端工程 → 跑 codegen 生成模块 →
  对「上一个已发布 framework」编译通过 + 起服务登录。
- README 删除「sample-app 全量 34/34」「project 模块无手写代码」等表述。

### D6 — frontend/apps/admin 解除对 sample-app 的默认指向
- dev proxy 目标改为读环境变量，默认值仅注释说明；文档改为「起 create-app / archetype 后端」。

## 执行顺序

Phase 1（切 sample-app：D3 → D5 → D4 → D6 → D1 删除）
→ Phase 2（docs 整理，含母本 CLAUDE.md 清理、develop_plan 收窄为设计决策记录、
   删 develop_plan.v0.3.bak.md、PROGRESS/VERSION_BASELINE 瘦身）
→ Phase 3（D2 删各仓 CLAUDE.md 副本）
→ Phase 4（各仓 README 按统一六段结构重写）
→ Phase 5（验证：全工作区无 sample-app 引用；-Pit 绿；-Prelease 不含 framework-it）
