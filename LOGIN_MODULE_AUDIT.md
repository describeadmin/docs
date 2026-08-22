# 登录模块待完善事项梳理

> 本文件回答"登录模块现在有哪些没做完/没接上的地方"。产出方式：用 codegraph_explore
> 通读了后端认证链路（`framework-security-starter`/`framework-system-starter`）的全部相关源码，
> 并 Read 了前端登录相关的全部 `.vue` 文件确认实际渲染逻辑，不是凭 grep 猜测。
>
> 这是一次**盘点**，不是已批准的实现计划——具体修哪几项、修到什么程度，
> 待讨论后再定。修的时候记得回来更新这份文件，别让它跟 `docs/PROGRESS.md` 一样过期了没人管。

**梳理日期：2026-08-22**

---

## 发现的问题（按影响面排序）

### A. 前端登录页遗留大量 Vben 上游演示脚手架，功能不完整且已扩散到脚手架模板

`packages/effects/common-ui/src/ui/authentication/login.vue` 的 `AuthenticationLogin` 组件默认 `showCodeLogin`/`showQrcodeLogin`/`showRegister`/`showThirdPartyLogin` 全部为 `true`。`apps/admin`（以及由它复制出的 `create-app/template`、`sample-frontend`）的 `login.vue` 没有显式关闭这些开关，而后端目前**只有 `password` 一种 `AuthProvider`**（浙政钉/钉钉登录是尚未开工的阶段 G）。实测结果：

- `code-login.vue`：`handleSendCode` 直接 `throw new Error('手机号校验失败')`；`handleLogin` 是空函数（`void values`）；后端没有对应的手机验证码 `AuthProvider`。
- `qrcode-login.vue`：二维码内容硬编码指向上游示例地址 `https://vben.vvbin.cn`，没有任何轮询/登录逻辑。
- `register.vue`：`handleSubmit` 是空函数；后端没有注册接口，SPI 层面也未设计过"自助注册"这个概念。
- `forget-password.vue`：`handleSubmit` 是空函数；后端没有"忘记密码"接口。
- `third-party-login.vue`：微信/QQ/GitHub/Google 四个图标按钮**完全没有点击事件**，纯装饰；`DingdingLogin` 组件硬编码了钉钉 SDK 地址与 OAuth 端点，且与项目自己在 CLAUDE.md §4.6 定下的"厂商登录必须做插件、核心不出现具体厂商名字"的架构相悖——阶段 G（浙政钉/钉钉插件）还没做，壳子里却已经内置了钉钉专属组件。

按项目自己在 CLAUDE.md §4.4 定的标准（"没有 data-testid 的交互元素视为未完成"），上述按钮既没有 `data-testid` 也没有真实行为，是明确的未完成状态。因为 `create-app/template` 是 `apps/admin` 外壳的裁剪副本，**这些死链接会随 `npm create @describeadmin/app` 扩散到每一个新建的业务项目**，属于影响面最大的一项。

此外，`login.vue` 里 `providers` 数组注释写着"应该按 providers 动态渲染登录方式"，但实现上只取了 `providers[0]` 决定提交时的 `type`，并没有真正驱动上面四个开关的显示/隐藏——即便以后浙政钉插件上线，这四个开关也不会自动跟着 `providers` 变化，注释里的设计意图和实现之间有缺口。

**建议**：短期直接在 `apps/admin`（连带 `create-app/template`、`sample-frontend`）的 `login.vue` 上把 `showCodeLogin`/`showQrcodeLogin`/`showRegister`/`showThirdPartyLogin` 显式设为 `false`，与当前只有 password 一种登录方式的事实对齐；同时决定"手机验证码登录/二维码登录/注册/忘记密码"这几个能力是否要真的做，若不打算做就一并去掉入口而不是留着空壳。`third-party-login.vue` 里没有点击事件的四个图标按钮建议直接删除（不是本项目场景需要的社交登录）。

> **进展（2026-08-22）**：按建议原样落地，`apps/admin`/`create-app/template`/`sample-frontend`
> 三处 `login.vue` 均显式关闭上述五个开关（`showForgetPassword` 一并关掉——`forget-password.vue`
> 同样是空函数）；对应四个 app 级包装页与路由**已删除**，不是只隐藏入口；
> `third-party-login.vue` 的四个无 `@click` 图标按钮已删除，`DingdingLogin` 予以保留
> （前端 UI 组件不受 CLAUDE.md §4.6"核心不能出现厂商名字"约束，且今天靠环境变量门控
> 恒为空渲染）；登录提交按钮补了 `data-testid`。`providers[0]` 决定提交类型这条脆弱耦合
> 也在 `sample-frontend` 侧修正为硬编码 `'password'`（这张表单固定是密码登录，第二种登录
> 方式邮箱验证码走独立页面），`showEmailLogin` 开关改为跟 `/api/auth/providers` 联动——
> 一并解决了本节提到的"开关不跟 providers 联动"的设计缺口，但仅对 email 这一项做
> （其余四项本来就没有对应能力）。**`create-app/template` 与 `apps/admin` 目前需要手工
> 保持同步**，本轮已同步一次。

### B. 改密码 / 禁用账号后，未撤销已签发的令牌

`TokenStore.revokeAllOf(userId)` 的 javadoc 明确写了三个应当调用的场景——"禁用账号、改密码、强制下线"——但代码里只有 `SysOnlineController` 的强制下线端点真正调用了它。

- `SysUserService.resetPassword()`（管理员重置他人密码）没有调用 `revokeAllOf`。
- 禁用账号走的是 `BaseController.update()` 通用端点（改 `SysUser.status`），同样没有调用。

结果：管理员重置某用户密码或禁用某账号后，该用户已经登录的会话**仍然有效**，要等令牌自然过期（默认 8 小时）才会失效——不满足"改密码/禁用立即失效"这个符合直觉的预期，也和 `TokenStore` 接口自己的设计意图不一致。

**建议**：`SysUserService.resetPassword()` 末尾补一次 `tokenStore.revokeAllOf(userId)`；禁用账号这条路径需要先决定要不要让 `SysUserController` 覆写 `update()`（当前完全走的是 `BaseController` 通用端点，没有介入点），如果要做，同样是收口到 `revokeAllOf`。

> **进展（2026-08-22）**：`resetPassword()` 已补 `revokeAllOf`；`SysUserController.update()`
> 已确认本来就是覆写而非走通用端点（前一次审计发现的钩子问题已不存在，该方法本已存在，
> 只是没做吊销），补了"`status` 显式改为 0 时吊销全部令牌"这一段，改其他字段不触发。
> `sample-app` 的 `FrameworkRuntimeIT` 新增 `resetPasswordRevokesExistingTokens`/
> `disablingAccountRevokesExistingTokens`/`editingOtherFieldsDoesNotRevokeTokens` 三例验证。

### C. 缺少"用户自助改密"入口

现有的唯一改密端点是 `PUT /api/system/user/{userId}/password`，需要 `system:user:edit` 权限，是管理员改别人密码用的。**没有**"当前登录用户修改自己密码"的端点（不需要 `system:user:edit`，只需要已登录）。配合 A 项里提到的空壳 `forget-password.vue`，目前一个普通用户没有任何自助改密码的路径。

**建议**：`SysUserController` 或新端点补一个 `PUT /api/auth/password`（取当前登录用户 ID，校验旧密码后改密），前端在个人信息页（如有）挂一个入口；改密后按 B 项一并调用 `revokeAllOf` 强制重新登录。

> **进展（2026-08-22）**：新增 `SysUserService.changeOwnPassword(userId, oldPassword,
> newPassword)`（校验旧密码、改密、`revokeAllOf` 收在同一个事务方法里，避免调用方
> 漏掉吊销这一步）+ `PUT /api/auth/password`（放在 `AuthController`，不新建 Controller，
> 不挂具体权限点，只需已登录）。**前端个人信息页的改密入口本轮未做**——
> 后端端点已就绪，前端页面待后续需要时再接。

### D. 登录失败锁定缺少管理侧的可观测性

`LoginAttemptGuard` 实现了锁定机制（默认 5 次/15 分钟），设计上"到点自动解锁，不需要管理员介入"，这是有意的取舍（类注释写明了）。但目前：

- 没有端点可以查询"当前有哪些账号处于锁定状态"；
- 锁定发生的事件不会写操作日志（`OperLogAspect` 只覆盖 `BaseController` 的 CRUD 与显式标注的自定义端点，`UsernamePasswordAuthProvider.authenticate()` 不在覆盖范围内）。

真实用户被误锁时，管理员除了等 15 分钟没有别的手段，且事后也查不到"谁、什么时候被锁过"。

**建议**：视运维需求决定是否需要补一个只读的"当前锁定账号"查询端点（读 `CacheProvider` 里 `describeadmin:login:fail:*` 前缀的 key）；是否要给锁定事件补审计，看优先级，不是阻塞项。

> **进展（2026-08-22）**：用户加码要求"不只查询，还要能手动解锁"，按此交付。
> `CacheProvider` 新增 `default Set<String> keysWithPrefix(String prefix)`
> （`InMemoryCacheProvider` 直接扫内存 Map；`RedisCacheProvider` 用 `SCAN` 而非
> `KEYS`，同 `RedisTokenStore.listActive()` 已确立的铁律）；`LoginAttemptGuard` 新增
> `listLockedUsernames()`/`unlock()`；新增 `SysSecurityController`
> （`GET/DELETE /api/system/security/locked-accounts[/{username}]`，权限点
> `system:security:list`/`system:security:unlock`，`seed-rbac.sql` 已登记，
> `visible=0`——暂无前端管理页面，先例是 `system:online` 当年同样的过渡状态）。
> **必须用 `ObjectProvider<LoginAttemptGuard>`**，不能直接注入或
> `@ConditionalOnBean`：`FrameworkSystemAutoConfiguration` 先于
> `FrameworkSecurityAutoConfiguration` 装配，`LoginAttemptGuard` 这个 Bean 在
> system 侧还不存在，直接依赖会导致本控制器被静默挡掉。**锁定事件的操作日志本轮未做**
> （审计原文标注"不是阻塞项"，仍待后续按优先级排期）。

### E. 没有刷新令牌，且是固定过期而非滑动过期——长时间操作会被强制退出

`TokenStore` 只有 `issue`/`resolve`/`revoke`/`revokeAllOf`/`listActive` 五个方法，没有任何"续期"语义；`AuthController` 也只有 `login`/`logout`/`me`/`menus`，没有 refresh 端点。

更关键的是：`InMemoryTokenStore.issue()` 在签发时一次性算好 `expiresAt = now + ttl`（默认 8 小时），`resolve()` 只读不写——**用户即使一直在操作，8 小时后 token 照样准时失效**，不是"空闲 8 小时才失效"的滑动过期。`RedisTokenStore` 是同一模式。

`LoginResult.expiresIn` 字段的 javadoc 写着"供前端决定何时提示续期"，但检索 `apps/admin` 全部前端代码，`expiresIn` 只在类型定义（`api/core/auth.ts` 的 `BackendLoginResult`）里出现过一次，`store/auth.ts` 完全没有读取它——没有到期提醒，也没有静默续期，token 一过期，下一次请求直接 401，前端只能弹回登录页重新输密码。这是一个**后端已经预留、前端从未接上的半成品字段**。

**结论**：只要一个管理员连续操作超过 8 小时（默认值，可通过 `describeadmin.security.token-ttl` 调），必然被强制退出，且没有任何提前预警。

**建议**（二选一，取舍点不同）：
- **轻量**：`resolve()` 命中时顺带把 `expiresAt` 往后推（滑动过期）。改动集中在 `InMemoryTokenStore`/`RedisTokenStore`，`TokenStore` 接口不用变，前端不用改。缺点是"完全不操作也不会掉线"和"用户主动登出"之间的边界变模糊。
- **完整**：加一对 access/refresh token，`AuthController` 新增 `/api/auth/refresh`，前端请求拦截器在收到 401 时用 refresh token 换新 token 并重放原请求。工作量明显更大，且要重新考虑"不透明令牌"这个既有设计决策——`TokenStore.java` 类注释解释过选择不透明令牌而非 JWT 的理由（禁用用户能立即失效），引入 refresh token 不冲突，但要想清楚 refresh token 本身要不要单独存、能不能也被 `revokeAllOf` 吊销。

如果两者都不打算近期做，建议在 `docs/PROGRESS.md` 的"已知欠账"里补一条说明现状（`expiresIn` 字段已预留但未使用），避免以后有人以为它已经生效。

> **进展（2026-08-22）**：拍板选择"完整方案"（access/refresh 双令牌），不是轻量滑动过期。
> 新增 `api` 类 `IssuedTokens(accessToken, refreshToken)`；`TokenStore` 新增三个
> `default` 方法 `issueWithRefresh`/`refresh`/`revokeRefreshToken`——`issue(LoginUser)`
> 签名不变，现有/未来任何 `AuthProvider` 实现零改动，唯一要改的调用方是
> `AuthController`。`revokeAllOf` 的 javadoc 补了一句硬约束：支持刷新令牌的实现
> **必须**同时吊销该用户名下的全部 refresh token，否则 B 项刚补上的"改密立即失效"
> 会被一个仍然有效的 refresh token 绕过——`InMemoryTokenStore`/`RedisTokenStore`
> 都已照此实现并有专门测试覆盖这条断言。`FrameworkSecurityProperties` 新增
> `refresh-token.enabled`（默认 true）/`.ttl`（默认 7 天）；`AuthController` 新增
> `POST /api/auth/refresh`（**不挂权限校验**，加入 permit-all，校验完全下沉到
> `TokenStore.refresh()` 内部）；`LoginResult` 新增 `refreshToken`/`refreshExpiresIn`
> （旧 3 参构造函数保留向后兼容）。前端 `authenticateResponseInterceptor` 的排队重放
> 逻辑本来就是现成的（`doRefreshToken` 此前是故意抛错的桩实现），这次换成真实调用即可，
> `enableRefreshToken` 偏好项同步打开。**踩坑记录**：`GlobalExceptionHandler` 把全部
> `BizException` 统一映射成 HTTP 200 + 错误码，只有 Spring Security 过滤器链自身的
> 拒绝才是真实 401/403——refresh 相关的集成测试第一版按"业务异常≈HTTP 401"的错误假设
> 写，跑起来才发现，已改为断言响应体的 `code` 字段。

### F. 手机号登录需要新增字段/接口，且有两种可行的插件化程度（已决定：mobile/email 进核心表，登录方式仍插件化）

当前 `SysUser` 实体（`framework-system-starter`）只有 `username`/`password`/`nickname`/`deptId`/`status` 五个字段，`sys_user` 表没有 `mobile`/`phone`/`email` 任何一列。要支持手机号登录，核心症结不是"发短信"（`NotifyChannel` SPI 现成能用），而是**认证通过后要把角色/权限/数据权限/首页拼成完整 `LoginUser`**——这部分逻辑全部写死在 `DbAuthUserLoader.loadByUsername()` 里，只能按 username 查，任何新登录方式最终都要走到这一步。有两种可行方案：

**方案一：核心加 mobile 概念，插件只做"发短信"**
- `sys_user` 加 `mobile` 列（破坏性 schema 变更，存量库要手动 `ALTER TABLE`，同类先例见阶段 D 的 `ancestors`、`home_path`）；`AuthUserLoader` 加 `loadByMobile()`；`DbAuthUserLoader` 实现它；核心新增内置的 `MobileCodeAuthProvider`。
- 插件只负责把验证码"发出去"（接具体短信厂商，本质是给 `NotifyChannel` 添新实现）。
- 问题：与 `UsernamePasswordAuthProvider` 类注释里"框架自带的**唯一一种**登录方式"这句话冲突，且不需要手机号登录的项目也要在核心 schema 里背这一列。

**方案二：整个手机号登录（含"用户表要不要有手机号"这件事）都由插件决定**
- 插件自带独立映射表（如 `sys_user_mobile(user_id, mobile)`），自己的建表脚本，**不碰核心 `sys_user`**。
- 插件的 `AuthProvider` 先按自己的表把手机号换成 `userId`，再复用核心已有的"拼装完整用户"逻辑——给 `AuthUserLoader` 加一个 `default Optional<AuthUser> loadByUserId(Long id)`（默认返回空，向后兼容，手法同 `TokenStore.listActive()` 当初新增 default 方法），`DbAuthUserLoader` 实现它；插件注入 `AuthUserLoader`，拿到 `userId` 后调这个方法。
- 不装这个插件，核心代码里完全没有"手机号"三个字，`sys_user` 表结构不受影响，没有存量库破坏性变更风险。代价是手机号和用户名分属两张表，用户管理页面要看/改手机号需要插件自己给前端加一段。

**建议**：方案二更符合项目"核心极薄、能力可插拔"的既定取向，且 `CLAUDE.md` §4.6 "只有部分项目需要 → 必须做插件"这条规则字面上就该这么套。方案一更省事但违背了"password 是唯一内置方式"的现有表述。最终选哪个待讨论后再定，前端 `code-login.vue` 的 UI 壳子已经在（就是 A 项提到的 Vben 演示脚手架），无论选哪个方案都需要把 `handleSendCode`/`handleLogin` 接到真实端点上，并让 `login.vue` 的 `showCodeLogin` 开关跟 `/auth/providers` 返回值联动。

> **进展（2026-08-22）**：讨论后拍板了一个介于方案一/二之间的第三条路——`mobile`/`email`
> 作为核心 `sys_user` 的常规字段直接落地（不算严格意义的方案一，因为没有内置
> `MobileCodeAuthProvider`，也没有违反"password 是唯一内置登录方式"这句表述；
> 也不是方案二，因为不需要插件自建映射表）。具体交付：
> - `AuthUserLoader` 新增 `default Optional<AuthUser> loadByUserId(Long userId)`
>   （方案二描述的钩子，手法同 `TokenStore.listActive()`），`DbAuthUserLoader` 已实现，
>   由抽取出的私有方法 `buildAuthUser(SysUser)` 同时支撑 `loadByUsername`/`loadByUserId`。
> - `sys_user` 新增 `mobile`/`email` 两列（可空，非空时 `SysUserService
>   .assertMobileEmailAvailable` 在应用层保证唯一，同 `username` 的既有处理方式）；
>   `SysUserController` 的创建/编辑端点已接入。
> - 认证插件取得 userId 的路径因此简化为两种：凭证已是核心字段（手机号/邮箱）→
>   直接查 `SysUserService.findByMobile`/`findByEmail`；凭证是外部系统标识
>   （第三方 openId）→ 插件仍需自建映射表。两种路径的第二步都一样，调
>   `loadByUserId` 拿完整用户。详见 `docs/registry.md` 准入规范第 10 条。
> - 对 CLAUDE.md §4.6 的这次例外已经写进 §4.6 正文（含 6 份副本）。
> - 手机验证码登录本身（发验证码、`MobileCodeAuthProvider` 一类的 `AuthProvider`
>   实现）**尚未立项**——`code-login.vue` 连同其路由已在 A 项里删除，不再留着空壳。
>
> **进展（2026-08-22，邮箱验证码登录插件）**：`mobile`/`email` 两个字段里，**邮箱**
> 这一半的登录方式已经交付——新插件 `framework-auth-email-starter`
> （`AuthProvider`，`type()="email"`，无密码验证码登录）走的正是本节方案二/三决定的
> 路径：`SysUserService.findByEmail` 换 userId → `AuthUserLoader.loadByUserId` 拼完整
> 用户，不新建任何映射表。发验证码走插件自己的 `POST /api/auth/email/code`
> 端点（业务方需自行加入 `permit-all`），验证码存 `CacheProvider`，用
> `spring-boot-starter-mail`/`JavaMailSender` 真实发信（GreenMail 验证）。已接入
> `sample-app`/`sample-frontend`，`sample-frontend` 新增 `email-login.vue` 页面。
> **手机验证码登录仍未立项**——短信通道（`docs/registry.md`"规划中"表）尚未开工，
> 邮箱插件不能直接复用（发信介质不同），是独立的后续工作。
> 插件代码本身已在本地写好并测试（28 例全绿），**远端 GitHub 仓库待人工确认后创建**。

---

## 验证方式（2026-08-22 已按此逐项验证完毕，见各节"进展"）

- **B/C 项**：`sample-app` 的 `FrameworkRuntimeIT` 新增
  `resetPasswordRevokesExistingTokens`/`changeOwnPasswordRejectsWrongOldPassword`/
  `changeOwnPasswordSucceedsAndRevokesTokens`/`disablingAccountRevokesExistingTokens`/
  `editingOtherFieldsDoesNotRevokeTokens` 五例，均用真实 MySQL Testcontainers 跑过。
- **A 项**：`pnpm -F @describeadmin/admin run typecheck`/`pnpm -F @describeadmin/ui run
  build` 均通过；`sample-frontend` 走了 `vite build` 生产构建验证（`vue-tsc` 会撞上一个
  与本轮改动无关的 `@describeadmin/ui` 预置 `.d.ts` 语法问题，见 `docs/PROGRESS.md`
  "已知遗留"）；未做 chrome-devtools 实际打开页面的人工走查。
- **D 项**：`InMemoryCacheProviderTest`/`RedisCacheProviderTest` 新增
  `keysWithPrefix` 用例（Redis 一侧用 Testcontainers 真实验证）；
  `LoginAttemptGuardTest` 新增 `listLockedUsernamesOnlyIncludesLockedOnes`/
  `unlockAllowsImmediateRetry` 等例；`sample-app` 的 `LoginLockoutIT` 新增
  `adminCanListAndUnlockLockedAccount`/`lockedAccountsEndpointRequiresPermission`。
- **E 项**：`InMemoryTokenStoreRefreshTest`/`RedisTokenStoreTest`（新增用例）覆盖
  轮换、`revokeAllOf` 同时吊销 access+refresh、过期/未知 token 返回空；`sample-app` 的
  `AuthFlowIT` 新增 `loginReturnsRefreshToken`/`refreshIssuesNewAccessToken`/
  `refreshRotatesOldRefreshToken`/`refreshEndpointIsPermitAll`/
  `refreshWithInvalidTokenReturnsBizError`。前端接入未做浏览器端到端验证。
- **F 项（邮箱登录插件）**：`framework-auth-email-starter` 28 例全绿（GreenMail 真实
  收发），完整覆盖 `docs/registry.md` 准入规范第 8 条"不引=行为不变"/"引了=能力生效"
  两条路径；`sample-app` 新增 `EmailLoginIT`（5 例，真实 GreenMail 走完整登录链路）。
  手机验证码登录插件立项后，仍需按同一份准入规范第 8 条补自己的两条路径测试
  （这是 CLAUDE.md §4.6 对插件的强制要求）。
