# AI 原生管理后台脚手架 —— 开发方案

**文档状态**：草案 v0.3，技术选型已全部确认，待团队最终评审
**技术栈**：Java 21 + Spring Boot 4.1（后端）／ Vue3 + Vben Admin + Ant Design Vue（前端）
**编写日期**：2026-08-19（v0.3 修订）

> 本文档基于前期方案讨论整理而成，目的是把已经达成共识的架构决策固化下来。所有此前悬而未决的技术选型（包括 Java 版本、MySQL 5.7 兼容范围）在 v0.3 中已经全部确认，具体改动记录见文末"附录 A：版本修订说明"。

---

## 一、背景与目标

这套脚手架不是一次性的项目模板，而是要作为公司内部长期演进的技术平台，供各业务部门在其上做二次业务开发。基于前期讨论，明确以下六个核心目标，也是贯穿整份方案的设计主线：

1. **生产级可靠性**：具备企业级后台系统应有的安全、可观测、可运维能力，而不是停留在"能跑起来"的demo水平。
2. **面向 AI 编程**：代码结构、命名规范、模块边界要足够规整和可预测，让 AI Agent 能够独立、准确地理解和扩展项目，减少对"团队隐性默契"的依赖。
3. **AI 自主完成端到端业务测试**：AI 能自主拉起隔离环境、通过真实浏览器操作走完整条业务链路、验证结果、销毁环境，形成开发自测闭环。
4. **完整支持 git worktree 并行开发**：多个互不相关的需求可以在同一台机器上真正并行推进，互不干扰。
5. **框架与业务解耦、可持续升级**：框架迭代时，业务方能以低成本、有节奏地同步升级，而不是被绑死在某个版本上，也不会出现"升级=重写"的情况。
6. **能力可插拔**：类似浙政钉登录、钉钉消息推送这类非通用需求，只有需要的业务方才引入，不强制耦合进所有项目。

这六点共同决定了整体架构的取舍方向：**脚手架的本质定位是"内部平台/SDK"，而不是"可复制粘贴的代码模板"**。这是后面所有设计决策的地基。项目按**开源方式**运作，面向中小规模项目，以单机或少量服务器部署为主，不做微服务拆分——这个定位在 v0.2 中已经明确，会影响后续多个章节的具体取舍（详见附录 A）。

---

## 二、总体架构

### 2.1 分层模型

```
┌─────────────────────────────────────────────┐
│  Business 层（各业务部门维护，多仓库/多worktree）  │
│  - 业务 Service / Controller（继承框架基类）      │
│  - 业务专属前端页面（依赖框架共享包）              │
│  - 只通过 Maven / npm 依赖引用 Platform 层         │
│  - 禁止 fork 框架源码到业务仓库                    │
└─────────────────────────────────────────────┘
                     ▲  依赖（版本化）
┌─────────────────────────────────────────────┐
│  Platform 层（框架团队维护，版本化发布）           │
│                                               │
│  framework-ext（可选插件，按需引入）              │
│  ├─ framework-auth-zhengwuding-starter       │
│  ├─ framework-notify-dingtalk-starter        │
│  └─ ...                                      │
│                                               │
│  framework-core（必选能力）                    │
│  ├─ framework-web-starter                    │
│  ├─ framework-security-starter（含SPI定义）    │
│  ├─ framework-mybatis-starter（含Base基类）    │
│  └─ framework-common                         │
│                                               │
│  framework-bom（版本仲裁）                      │
└─────────────────────────────────────────────┘
```

前端遵循同样的分层逻辑：Vben Admin 的 Monorepo 结构里，`packages/` 下沉淀框架共享能力（组件、请求封装、权限指令、动态路由），业务方的 `apps/` 只消费这些共享包，不直接修改框架源码。

### 2.2 技术栈总览

| 层面 | 选型 | 说明 |
|---|---|---|
| 后端语言/运行时 | **Java 21（LTS，已确认）** | Spring Boot 4.1 最低兼容 Java 17，同时首发支持 Java 25；21 是目前生产环境最成熟稳妥的 LTS 版本，已确认作为基线 |
| 后端框架 | **Spring Boot 4.1.x（当前 GA）** | 依赖 Spring Framework 7.0；v0.1 曾误写为 3.x，已修正，详见附录 A |
| 构建工具 | Maven 多模块 + BOM | 与 framework-bom 的版本仲裁思路配套，是本方案的核心机制之一 |
| ORM | MyBatis-Plus | 官方已发布 `mybatis-plus-spring-boot4-starter` 适配 Spring Boot 4，生态就绪 |
| 数据库 | **MySQL（已确认）**，5.7 为强制支持的最低版本，向上兼容至 8.4/9.x LTS | 5.7 早已 EOL，属于硬性兼容要求而非"尽量兼容"，工程约束与 CI 强制门禁见 2.3 节 |
| 缓存/会话 | Redis | 分布式 session、限流、验证码等场景 |
| 鉴权底座 | **Spring Security（已确认）** | 对应 Spring Security 7.0.x，随 Spring Boot 4.1 / Spring Framework 7 配套发布，已迭代到稳定补丁版本 |
| 配置中心 | **不引入（已确认）** | 插件运行时开关改用 `application.yml` + Profile 管理，调整需要随配置发布/重启生效 |
| 前端框架 | Vue3 + TypeScript + Vite | 已确认 |
| 前端脚手架 | Vben Admin（Monorepo） | 已确认，自带响应式布局，移动端场景已实测通过 |
| 前端 UI 组件库 | **Ant Design Vue（已确认）** | 详见 4.2 |
| 容器化 | Docker + Docker Compose | 本地开发、AI 自动化测试环境，以及生产部署 |
| 生产部署形态 | **单体应用 + Docker Compose，单机或少量服务器（已确认）** | 不引入 K8s；面向中小项目，不做微服务拆分。多模块 Maven 结构仍会保持良好的内部边界，但这只是工程卫生，不是为将来拆分做准备 |
| 组件发布方式 | **Maven Central + npm 公共仓库（已确认）** | 按开源方式运作，不建私有仓库（Nexus/Artifactory/Verdaccio），详见 3.1、4.1 |
| 版本管理工具 | OpenRewrite（Java）/ Changesets（前端） | 服务于框架升级机制，见第七章 |
| AI 浏览器自动化 | chrome-devtools MCP（或 Playwright） | 服务于自动化测试体系，见第五章 |

### 2.3 数据库版本兼容策略（MySQL 5.7 ~ 8.4/9.x LTS）

先把风险说清楚，再谈方案：MySQL 5.7 已于 **2023 年 10 月 31 日** 停止官方支持（EOL），距今近三年没有安全补丁。这个事实需要明确同步给使用 5.7 的业务方，由他们自行评估基础设施层面的安全和合规风险——框架层面能做的是保证应用兼容性，没办法替业务方兜底数据库本身失去官方补丁这件事。目前 MySQL 官方仍在支持期内的是 8.4 LTS（Premier 支持到 2029 年）和 9.7 LTS（支持到 2034 年），中间的 8.0.x 系列目前也已经过了支持期。

风险已经说清楚，态度也已经明确：**5.7 是必须支持的硬性要求，不是"有条件就兼容"的加分项**。下面的工程约束不是建议性质的最佳实践，而是强制规范，框架核心、代码生成器、以及后续所有业务方代码都要遵守。

在明确风险的前提下，要同时兼容 5.7 到最新 LTS 这个跨度，给出以下工程约束，把"跨版本兼容"变成几条明确、可执行的规则，而不是模糊的"注意兼容性"：

- **SQL 特性红线**：以 5.7 语法为基线，框架核心和代码生成器默认产出的 SQL 一律不使用窗口函数（`ROW_NUMBER()`/`RANK()` 等）、CTE（`WITH ... AS`）、函数索引、不可见列这些 8.0+ 才有的特性。个别业务方确实需要这些能力的，作为业务方自己代码里的"选用能力"，并在文档里明确标注"仅 MySQL 8.0+ 可用"，由业务方自行确认自己的数据库版本满足要求。
- **字符集与排序规则**：不依赖服务器默认值——5.7 默认 `utf8mb4_general_ci`，8.0+ 默认改成了 `utf8mb4_0900_ai_ci`，行为不完全一致。所有建表脚本显式声明 `CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci`，保证同一份 DDL 在不同 MySQL 版本上表现一致。
- **驱动与鉴权插件**：使用当前维护的 `mysql-connector-j`（8.x/9.x 系列），该驱动仍然兼容 5.7 服务端；但 5.7 默认鉴权插件是 `mysql_native_password`，8.0+ 默认改成了 `caching_sha2_password`，需要在连接串或建用户时显式指定，不要依赖版本默认值，否则同一套代码在不同版本的库上可能连不上。
- **分页与查询插件**：MyBatis-Plus 分页插件统一使用基于 `LIMIT/OFFSET` 的 MySQL 通用方言，5.7 和 8.x/9.x 都兼容，不需要按版本区分逻辑。
- **纳入 CI 强制门禁**：复用第五章的 AI 自动化测试基础设施，把 `mysql-test` 服务的镜像版本做成可参数化，让 5.7 和 8.4-LTS 两条线跑同一套种子脚本和核心业务流程测试；**5.7 这条线的测试结果作为 CI 的必过项**，任何 PR 只要在 5.7 上跑不过就不允许合并，把"必须支持 5.7"从文档承诺变成自动化强制的工程事实，而不是依赖人工代码审查时留意。

这样处理之后，"兼容 5.7"不会拖累整体设计的先进性，只是给 SQL 写法和测试范围加了几条明确的约束；业务方如果用的是较新的 MySQL 版本，不会因此损失任何能力。

---

## 三、后端架构设计

### 3.1 模块划分

框架核心按"必选 / 可选"拆成两条产品线，全部作为独立 Maven 制品发布到 **Maven Central**（通过 Sonatype 现行的 Central Portal 发布，legacy 的 OSSRH/JIRA 工单流程已经停用），业务方以依赖方式引入，**任何情况下都不直接拷贝框架源码**。项目按开源方式运作，不需要额外搭建和维护私有仓库（Nexus/Artifactory），发布链路只需要准备好一个经过验证的 groupId 命名空间（开源场景下最省事的方式是用 `io.github.<组织名>` 这类可以通过 GitHub 自动验证的命名空间，避免走独立域名验证的流程）和制品签名（GPG）配置：

**framework-bom**：统一仲裁 framework-core、framework-ext 各模块之间的版本兼容关系，业务方 pom.xml 只需引入 BOM，具体版本号不需要逐个操心。

**framework-core（必选）**
- `framework-web-starter`：统一响应体、全局异常处理、请求日志/链路追踪、统一参数校验
- `framework-security-starter`：认证鉴权基座（基于 Spring Security 7.x），内置用户名密码登录，同时定义 `AuthProvider` 等 SPI 接口供扩展
- `framework-mybatis-starter`：`BaseEntity` / `BaseMapper` / `BaseService` / `BaseController` 泛型基类，封装分页、通用查询、审计字段（创建人/创建时间/更新人/更新时间/逻辑删除），SQL 写法遵循 2.3 节的兼容性约束
- `framework-common`：通用工具类、常量、枚举、Result 包装类

**framework-ext（可选，按需引入）**
- `framework-auth-zhengwuding-starter`：浙政钉登录，实现 `AuthProvider`
- `framework-notify-dingtalk-starter`：钉钉消息推送，实现 `NotifyChannel`
- `framework-notify-wecom-starter` / `framework-notify-sms-starter`：企业微信、短信通道，同样按需引入
- 后续业务方专属的对接需求，可在业务方自己项目里实现同样的 SPI 接口，不必等框架团队排期开发官方插件

### 3.2 插件化 SPI 机制

以登录方式和消息通道为例，核心思路是框架只定义契约，不关心具体实现：

```java
// framework-security-starter 中定义，核心不感知具体实现
public interface AuthProvider {
    String type();                       // 登录方式标识，如 "zhengwuding"
    boolean supports(String type);
    LoginUser authenticate(AuthRequest request);
}

// framework-web-starter/common 中定义
public interface NotifyChannel {
    String channel();                    // 通道标识，如 "dingtalk"
    void send(NotifyMessage message);
}
```

框架核心通过 `List<AuthProvider>` / `Map<String, NotifyChannel>` 的方式做依赖注入收集，谁在 classpath 上、谁注册了 Bean，就会被自动纳入调度，核心逻辑完全不需要知道"浙政钉""钉钉"这些具体名字。

开关控制分两层：**编译期**（业务方 pom.xml 是否引入对应 starter）决定能力是否存在，**运行时**（`@ConditionalOnProperty` 配合 `application.yml` 的 Profile 配置）决定已引入的能力是否激活。两层结合既保证了按需引入不增加体积，也支持同一制品在不同环境下通过配置文件灵活开关——需要注意的是，由于项目不引入配置中心，运行时开关的调整依赖配置文件重新发布/服务重启才能生效，不支持动态热切换，这一点需要在插件文档里向业务方说明清楚，避免误以为改个配置就能立即生效。

前端配合的做法是登录页不硬编码某个登录方式的按钮，而是调用后端 `/api/auth/providers` 之类的接口动态获取当前项目启用的登录方式列表，再动态渲染对应组件。

### 3.3 代码生成器与"基类继承"边界

这是保证框架可持续升级的关键设计点之一。生成器的输出必须是"薄"业务代码，通用逻辑留在框架基类里：

- 输入：数据库表结构（或后续演进为 YAML/DSL 定义，脱离对具体数据库的依赖）
- 输出：`XxxEntity extends BaseEntity`、`XxxMapper extends BaseMapper<XxxEntity>`、`XxxService extends BaseService<...>`、`XxxController extends BaseController<...>`，业务方只填充业务特有字段和方法
- 前端同步生成对应的列表页/表单页，同样是"薄"页面，复用框架共享组件

好处是框架升级大多数情况下改的是基类（属于 Platform 层，版本化发布），业务方生成的"薄"代码基本不需要跟着大改，从源头上减少了升级摩擦。

---

## 四、前端架构设计

### 4.1 基于 Vben Admin 的复用方式

沿用 Vben Admin 的 Monorepo 结构：

- `packages/`：沉淀框架侧共享能力，包括基础布局、权限路由、通用业务组件（表格封装、表单生成器）、请求封装、公共 utils，以 **npm 公共仓库** 的 scoped 包形式发布（如 `@你的组织名/ui`、`@你的组织名/utils`、`@你的组织名/auth`，发布时用 `npm publish --access public`），和后端一致按开源方式运作，不需要搭建私有 npm 仓库（Verdaccio 等）
- `apps/`：各业务方的具体应用，只依赖框架发布的 npm 包，业务专属页面代码物理上和框架代码分开

### 4.2 UI 组件库：Ant Design Vue（已确认）

已确认选用 Ant Design Vue。Vben Admin 本身对 Ant Design Vue 的原生支持比较成熟，其设计语言也更贴近浙政钉这类政务场景的中后台风格，与第三章插件化设计里规划的浙政钉登录、钉钉推送场景在视觉语言上是一致的，不需要再额外做统一风格的适配工作。

### 4.3 移动端适配

Vben Admin 内置的响应式布局已经过实测验证，不再单独引入 Vant 等移动端专属组件库，降低了技术栈复杂度。需要注意的是，导航、整体布局这类"外壳"部分通常适配得比较好，真正容易出问题的是宽表格、多字段复杂表单这类"重"页面，建议在核心业务页面开发完成后，安排一轮真机验证（而不仅是浏览器缩放模拟），确认这些页面在手机端依然可用，再正式定档"不需要额外移动端方案"这个结论。

---

## 五、AI 自动化端到端测试体系

### 5.1 环境编排

新建 `docker-compose.test.yml`，与开发环境的 compose 文件分离，避免互相干扰：

- `mysql-test` / `redis-test`：独立于开发库的测试专用实例；`mysql-test` 的镜像版本做成可参数化（覆盖 5.7 和 8.4-LTS 两条线跑同一套种子脚本），把 2.3 节的数据库版本兼容性验证纳入自动化测试范畴
- `backend` / `frontend`：测试专用镜像或直接跑本地构建产物
- `seed-job`：一次性任务容器，执行 `schema.sql` + `seed.sql` 完成后自动退出，保证每次测试拿到的都是确定、干净的初始数据

### 5.2 提速策略：快照替代重建

如果每个业务场景都走一次完整的 `docker compose down && up`，速度会很慢。更实际的做法是种子数据准备好后做一次数据库快照（`mysqldump` 或者基于卷的快照），场景之间用快照恢复来重置状态，只有在切换测试批次或环境异常时才做完整的容器重建，这样能把单场景的重置时间从"分钟级"压缩到"秒级"。

### 5.3 浏览器自动化

使用 chrome-devtools MCP（基于 Chrome DevTools Protocol）驱动真实浏览器，AI Agent 直接完成点击、输入、截图、读取 DOM、查看 console 报错和网络请求这些操作。配套要求前端统一给关键交互元素加 `data-testid` 或规范的 `aria-*` 属性，保证自动化工具定位元素的稳定性，减少因选择器脆弱导致的假失败。

### 5.4 测试用例规范（结构化 Spec）

为了让 AI 自主执行测试的过程可控、可复核，测试场景不建议用纯自然语言描述，而是用结构化格式定义步骤和断言点，AI 按 Spec 执行并留痕。示例：

```yaml
scenario: 新增部门后在部门树中可见
preconditions:
  - login_as: admin
steps:
  - action: navigate
    target: /system/dept
  - action: click
    selector: '[data-testid="dept-add-btn"]'
  - action: fill
    selector: '[data-testid="dept-name-input"]'
    value: "测试部门-自动化"
  - action: click
    selector: '[data-testid="dept-submit-btn"]'
assertions:
  - type: ui
    selector: '[data-testid="dept-tree"]'
    expect: contains_text("测试部门-自动化")
  - type: db
    query: "SELECT COUNT(*) FROM sys_dept WHERE dept_name = '测试部门-自动化'"
    expect: equals(1)
evidence:
  - screenshot: after_each_step
  - console_log: on_error
  - network_log: on_error
```

`assertions` 里同时包含 UI 断言和 DB 断言，是为了避免 AI 仅凭"页面看起来正常"这种视觉判断就下结论——视觉判断容易有误判，结构化断言 + 证据留存（截图、console、网络日志）结合起来，AI 出具的测试报告才有可复核性，早期阶段建议保留人工抽查报告的环节，等误判率验证得足够低之后，再逐步走向完全自动化闭环。

### 5.5 与 Worktree 机制联动

测试环境的命名空间隔离直接复用第六章的 worktree 隔离方案，保证不同 worktree 各自的测试环境不会互相冲突，测试完成后统一 `down -v` 清理，不留残留资源。

---

## 六、Git Worktree 并行开发支持

### 6.1 命名空间隔离策略

Git worktree 本身是原生能力，真正需要做的工作是让项目工具链感知多 worktree 场景，核心是把所有硬编码的资源标识参数化：

- 根据 worktree 的目录路径或分支名计算出一个唯一 slug（比如取路径 hash 的前 8 位）
- 用这个 slug 派生 `COMPOSE_PROJECT_NAME`、端口偏移量（如 `8080 + offset`）、数据库 schema 名
- 数据库/Redis 建议共用一个实例、按 worktree 分 schema / db index，避免每个 worktree 都起一套重资源容器；后端、前端这类应用服务则按 worktree 走独立进程/容器，保证代码热更新互不干扰

### 6.2 开发者体验封装

建议提供一个统一入口脚本（`./scripts/dev.sh up|down|test`），自动识别当前所在 worktree、计算隔离参数、生成对应的 `.env` 覆盖文件，开发者（以及 AI Agent）不需要手动记忆端口和命名规则，一条命令即可拉起或销毁当前 worktree 专属的完整环境。

---

## 七、框架版本治理与升级机制

这是保证"业务方能同步升级"这个核心诉求真正落地的部分，光有依赖化的架构还不够，需要配套的流程和工具：

- **语义化版本（SemVer）**：只有大版本号才允许破坏性变更，小版本号只做兼容性的功能新增和修复
- **废弃周期**：旧接口废弃时先标记 `@Deprecated`，至少保留 1-2 个小版本周期才允许真正移除，业务方有明确的缓冲时间
- **CHANGELOG 规范**：每次发版明确列出 Breaking Changes、New Features、Bug Fixes 三类变更
- **自动化迁移工具**：大版本发布时同步提供 OpenRewrite 迁移脚本（Java 侧）和 codemod 脚本（前端侧），业务方跑一个命令即可完成大部分机械式的适配改动，而不是人工逐处排查
- **兼容性测试门禁**：维护一个"业务模拟"样板应用，复用第五章的 AI 自动化测试基础设施，每次框架发版前跑一遍完整的业务流程测试，验证新版本没有破坏现有能力，作为发版前的质量关卡
- **治理角色**：需要有明确的框架 Owner 负责评审核心变更、把控兼容性承诺，工具能降低升级成本，但如果没有人对 API 稳定性负责，工具本身也会形同虚设
- **开源属性带来的额外约束**：既然组件发布到 Maven Central / npm 公共仓库，潜在的使用者不再局限于内部业务方，版本兼容性和废弃流程的严肃性要求比纯内部工具更高一些，SemVer 和 CHANGELOG 的纪律性尤其不能放松

---

## 八、插件目录（Registry）规范

维护一份结构化的插件清单文档（`framework-ext/registry.md`），每个插件登记以下信息，方便人和 AI Agent 快速判断"这个能力框架有没有现成的，还是需要自己按接口实现"：

| 插件 | 坐标 | 实现的 SPI | 最低框架版本 | 说明 |
|---|---|---|---|---|
| 浙政钉登录 | `io.github.xxx:framework-auth-zhengwuding-starter` | `AuthProvider` | 1.0.0 | 政务场景登录 |
| 钉钉消息推送 | `io.github.xxx:framework-notify-dingtalk-starter` | `NotifyChannel` | 1.0.0 | 工作通知类推送 |
| 企业微信登录/推送 | 【规划中】 | `AuthProvider` / `NotifyChannel` | - | 按业务方需求排期 |
| 短信通道 | 【规划中】 | `NotifyChannel` | - | 验证码、通知短信 |

> 表中 groupId 以 `io.github.xxx` 为示意，实际以团队在 Maven Central Central Portal 注册并验证通过的命名空间为准。

---

## 九、实施路线图

不给出具体日期（取决于团队规模和投入节奏），按依赖关系给出建议顺序，每个阶段建议找一个真实业务方做小范围试点验证后再推广，而不是全部埋头做完再一次性交付：

**阶段 0：基础设施骨架**
仓库结构搭建、CI 骨架、`framework-bom`/父 POM、基于 Vben Admin 的前端起点定制、打通 Maven Central 与 npm 公共仓库的发布链路（GPG 签名、Central Portal 账号与命名空间验证）。验收标准：能跑通一个空的登录+首页流程，并成功发布一个占位包到 Maven Central 和 npm 验证发布链路可用。

**阶段 1：核心能力**
用户名密码登录（基于 Spring Security）、RBAC 权限模型、菜单管理、`BaseXxx` 基类、代码生成器 v1（遵循 2.3 节 MySQL 兼容性约束）。验收标准：能通过生成器产出一个完整可用的业务 CRUD 模块，且在 MySQL 5.7 和 8.4-LTS 两个版本上均验证通过。

**阶段 2：插件化落地**
`AuthProvider` / `NotifyChannel` SPI 接口定稿，浙政钉登录、钉钉推送两个官方插件跑通，验证"可插拔"架构在真实场景下成立。

**阶段 3：AI 自动化测试基础设施**
`docker-compose.test.yml`、种子数据+快照机制、chrome-devtools MCP 集成、首批核心业务流程的结构化测试用例。验收标准：至少一个完整业务流程能被 AI 自主测试、出具可复核报告。

**阶段 4：Worktree 工具链**
`dev.sh` 脚本、端口/数据库隔离参数化、配套文档。验收标准：两个 worktree 同时拉起环境互不冲突。

**阶段 5：版本治理**
SemVer 发布流程、CHANGELOG 规范落地、首个 OpenRewrite 迁移脚本试点、兼容性测试门禁接入 CI。验收标准：完成一次真实的框架小版本升级，业务方全程无需手工排查兼容性问题。

---

## 十、主要风险与应对

风险不是要回避讨论，而是提前想清楚应对方式：

AI 自主测试存在误报/漏报的可能，尤其是纯视觉判断类的场景，应对方式是坚持结构化断言（UI+DB双重校验）加证据留存，早期保留人工抽查环节，不追求一步到位的完全自动化信任。

多个 worktree 同时运行会带来本地机器或 CI 资源消耗的成倍增长，应对方式是数据库/缓存类重资源共享实例、只对应用服务做真隔离，并考虑给闲置环境加自动回收机制。

插件化 SPI 接口一旦被多个业务方依赖，本身也需要走版本治理，不能随意变更方法签名，否则会把"可插拔"变成新的耦合点，应对方式是 SPI 接口本身纳入 framework-core 的兼容性承诺范围。

MySQL 5.7 长期处于无安全补丁状态，这是数据库基础设施层面的风险，框架能做的只是保证应用兼容性，无法替业务方消除这个风险敞口，需要业务方自行评估、按自身节奏推进升级。

工具能力再完善，如果没有组织层面的治理跟进（比如没人对框架 API 稳定性负责、业务方各自为政绕过依赖机制直接改框架源码），整套体系依然会退化成"能力有但没人守规矩"，这一点需要在项目启动时就明确框架 Owner 角色和基本的协作规范，而不是等问题出现了再补救。

---

## 附录 A：版本修订说明

### v0.3（本次）

相比 v0.2，本次修订内容：

1. **Java 版本确认**：正式确定为 21（LTS），不再是待定项。
2. **MySQL 5.7 从"兼容目标"升级为"强制门禁"**：明确 5.7 是硬性最低支持版本，2.3 节的工程约束从建议性质改为强制规范，并把 5.7 测试通过率纳入 CI 必过项，PR 在 5.7 上测试不过则不允许合并。
3. 附录 B 由"待确认事项清单"改为"技术选型确认状态"汇总表，技术选型已无遗留悬项。

### v0.2

相比 v0.1，本次修订内容：

1. **后端框架版本修正**：Spring Boot 由误写的 3.x 修正为当前 GA 的 4.1.x。v0.1 沿用了"3.x 是最新大版本"这个过时认知，没有核实是否已有更新的 GA 版本，这是一处实际的疏漏，此处直接更正，不为旧结论辩护。核实后的情况是：Spring Boot 4.0.0 已于 2025 年 11 月正式 GA，构建在 Spring Framework 7.0 之上，最低兼容 Java 17、首发支持 Java 25；关键依赖 MyBatis-Plus 已经发布 `mybatis-plus-spring-boot4-starter` 官方适配，Spring Security 也已经迭代到 7.0.x 的稳定补丁版本，说明生态适配已经到位。考虑到这是一个从零开始的新项目、不存在存量代码的迁移成本，没有理由继续锚定在旧的大版本上。唯一需要坦率指出的权衡是：4.x 发布时间相对还比较新，AI 编程工具（包括我自己）在训练语料里见过的 4.x 专属 API 用法会比成熟的 3.x 少一些，短期内 AI 生成涉及框架新特性的代码时，出错率可能略高于用 3.x，这个差距会随时间推移自然消失，不构成继续用旧版本的理由，但值得在团队内部知会一声，代码审查阶段对这类新 API 的生成结果多留意一下。
2. **MySQL 兼容性要求**：补充了兼容 MySQL 5.7 的具体工程约束，详见 2.3 节。5.7 已经 EOL 近三年，这个风险已经明确告知，工程上按 2.3 节的约束处理即可保证跨版本兼容性。
3. **技术选型确认**：数据库（MySQL）、鉴权底座（Spring Security）、前端 UI 库（Ant Design Vue）、配置中心（不引入）、生产部署形态（不引入 K8s，单体 + Docker Compose）均已拍板，详见 2.2 表格。
4. **发布方式调整**：明确项目按开源方式运作，后端组件发布至 Maven Central，前端组件发布至 npm 公共仓库，不建私有仓库。
5. **部署规模定位**：明确面向中小项目，单机或少量服务器部署，不做微服务拆分，相关章节中"预留拆分空间"一类的表述已经去除。

## 附录 B：技术选型确认状态

截至 v0.3，方案中涉及的技术选型已全部确认，不再有遗留的"待确认"项：

| 事项 | 结论 |
|---|---|
| Java 版本 | 21（LTS） |
| Spring Boot 版本 | 4.1.x（当前 GA） |
| 数据库 | MySQL，5.7 为强制支持的最低版本（CI 强制门禁） |
| 鉴权底座 | Spring Security |
| 前端 UI 组件库 | Ant Design Vue |
| 配置中心 | 不引入 |
| 生产部署形态 | 单体 + Docker Compose，不引入 K8s |
| 组件发布方式 | Maven Central + npm 公共仓库（开源） |

后续如果实施过程中出现需要重新评估的情况（比如某个约束在实践中证明不可行），按第七章的版本治理流程走变更，而不是私下改动。