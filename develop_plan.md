# AI 原生管理后台脚手架 —— 开发方案

**文档状态**：草案 v0.5，技术选型已全部确认并经**权威源核验**，待团队最终评审
**技术栈**：Java 17+（构建用 21）+ Spring Boot 3.5.16（后端）／ Vue3 + Vben Admin 5.7.0 + Element Plus（前端）
**组织**：`describeadmin`（GitHub：<https://github.com/describeadmin）>
**编写日期**：2026-08-19（v0.4 修订）

> v0.4 是第一个所有版本号都经过实际核验的版本。v0.3 及以前的版本号来自记忆和讨论，其中若干条已被证伪（详见附录 A）。核验明细与数据来源见同目录 `VERSION_BASELINE.md`。

***

## 一、背景与目标

这套脚手架不是一次性的项目模板，而是要作为长期演进的技术平台，供各业务方在其上做二次业务开发。明确以下六个核心目标，也是贯穿整份方案的设计主线：

1. **生产级可靠性**：具备企业级后台系统应有的安全、可观测、可运维能力，而不是停留在"能跑起来"的 demo 水平。
2. **面向 AI 编程**：代码结构、命名规范、模块边界要足够规整和可预测，让 AI Agent 能够独立、准确地理解和扩展项目，减少对"团队隐性默契"的依赖。
3. **AI 自主完成端到端业务测试**：AI 能自主拉起隔离环境、通过真实浏览器操作走完整条业务链路、验证结果、销毁环境，形成开发自测闭环。
4. **完整支持 git worktree 并行开发**：多个互不相关的需求可以在同一台机器上真正并行推进，互不干扰。
5. **框架与业务解耦、可持续升级**：框架迭代时，业务方能以低成本、有节奏地同步升级，不会出现"升级=重写"的情况。
6. **能力可插拔**：类似浙政钉登录、钉钉消息推送这类非通用需求，只有需要的业务方才引入，不强制耦合进所有项目。

这六点共同决定了整体架构的取舍方向：**脚手架的本质定位是"平台/SDK"，而不是"可复制粘贴的代码模板"**。项目按**开源方式**运作，面向中小规模项目，以单机或少量服务器部署为主，不做微服务拆分。

### 1.1 业务场景约束（v0.4 新增，影响多个技术决策）

主要承接**政务类项目**，由此带来一条贯穿全局的硬约束：**业主的数据库不由我们选择**。实际会遇到三类情况：

1. 业主采购了**国产化数据库**（达梦、人大金仓、OceanBase 等），宣称"兼容 MySQL 5.7"
2. 业主直接采购的就是 **MySQL 5.7**
3. 业主使用较新的 MySQL（8.0/8.4）

这条约束是 2.3 节全部设计的来源。需要特别指出的是：**国产化数据库的"MySQL 兼容"通常是子集而非超集**，因此它对框架的约束比真实的 MySQL 5.7 更强，也更难通过 CI 穷举验证——这直接改变了数据库兼容策略的设计思路（见 2.3）以及代码生成器的优先级（见 3.3）。

***

## 二、总体架构

### 2.1 分层模型

```
┌─────────────────────────────────────────────┐
│  Business 层（各业务方维护，多仓库/多worktree）   │
│  - 业务 Service / Controller（继承框架基类）      │
│  - 业务专属前端页面（依赖框架共享包）              │
│  - 只通过 Maven / npm 依赖引用 Platform 层         │
│  - 自行选择数据库与 JDBC 驱动（见 2.3）             │
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

前端遵循同样的分层逻辑：框架侧共享能力沉淀为独立发布的 npm 包，业务方的应用只消费这些包，不直接修改框架源码。需要注意前端的起点与后端不同，见 4.1。

### 2.2 技术栈总览（版本均经 repo1.maven.org / registry.npmjs.org 核验）

| 层面               | 选型                                                                  | 说明                                                     |
| ---------------- | ------------------------------------------------------------------- | ------------------------------------------------------ |
| 后端语言/运行时         | **最低 Java 17，构建用 Java 21，编译目标** **`release=17`**                    | Spring Boot 3.5 的 Java 基线为 17；策略与理由见 2.2.2             |
| 后端框架             | **Spring Boot 3.5.16**                                              | 累计 16 个补丁版本，2026-06-25 仍在发布；选型依据见 2.2.1                |
| Spring Framework | 6.2.19                                                              | 由 spring-boot-dependencies 3.5.16 管理                   |
| Spring Security  | 6.5.11                                                              | 同上                                                     |
| Jackson          | 2.21.4（`com.fasterxml.jackson.*`）                                   | 同上                                                     |
| 构建工具             | Maven 多模块 + BOM                                                     | 与 framework-bom 的版本仲裁配套，是本方案的核心机制之一                    |
| ORM              | **MyBatis-Plus 3.5.17**（`mybatis-plus-spring-boot3-starter`）        | 对应 Spring Boot 3.x 线                                   |
| 数据库              | **由业务方决定**，框架只承诺 SQL 语法基线与分层支持矩阵                                    | 详见 2.3，这是 v0.4 相对 v0.3 改动最大的一节                         |
| JDBC 驱动          | **由业务方声明**，框架不作为传递依赖引入，仅提供安全默认值                                     | 详见 2.3.3                                               |
| 缓存/会话            | Redis（Lettuce 6.6.0.RELEASE）                                        | 分布式 session、限流、验证码等场景                                  |
| 鉴权底座             | Spring Security                                                     | <br />                                                 |
| 配置中心             | **不引入**                                                             | 插件运行时开关改用 `application.yml` + Profile 管理，调整需随配置发布/重启生效 |
| 前端框架             | Vue3 + TypeScript + Vite                                            | <br />                                                 |
| 前端脚手架            | **Vben Admin 5.7.0（一次性取材，独立演进）**                                    | 起点为官方 `apps/web-ele`；复用方式见 4.1                         |
| 前端 UI 组件库        | **Element Plus 2.14.x**                                             | 详见 4.2                                                 |
| 容器化              | Docker + Docker Compose                                             | 本地开发、AI 自动化测试环境，以及生产部署                                 |
| 生产部署形态           | 单体应用 + Docker Compose，单机或少量服务器                                      | 不引入 K8s；不做微服务拆分                                        |
| 组件发布方式           | Maven Central（`io.github.describeadmin`）+ npm（`@describeadmin/*`） | 开源运作，不建私有仓库                                            |
| 版本管理工具           | OpenRewrite（Java）/ Changesets（前端）                                   | 服务于框架升级机制，见第七章                                         |
| AI 浏览器自动化        | chrome-devtools MCP（或 Playwright）                                   | 服务于自动化测试体系，见第五章                                        |

#### 2.2.1 关于 Spring Boot 选 3.5.x 而非 4.x

这是一处需要说明理由的取舍。核验时点上，Spring Boot 有三条可选线：

| <br />  | **3.5.16（选定）**            | 4.0.7                    | 4.1.0      |
| ------- | ------------------------- | ------------------------ | ---------- |
| Jackson | 2.21.4（`com.fasterxml.*`） | 3.1.4（`tools.jackson.*`） | 3.1.4      |
| 累计补丁数   | 16                        | 7                        | **0**      |
| 最新补丁发布  | 2026-06-25                | 2026-06-10               | 2026-06-10 |
| AI 训练语料 | 充沛                        | 稀薄                       | 稀薄         |
| 线的状态    | 活跃打补丁                     | **退役期**                  | current    |

**排除 4.0.x**：它承担了 4.x 的全部代价（Jackson 3 包名重命名、Spring Framework 7、Tomcat 11、AI 语料稀薄），却不是 4.x 的当前线——4.0.7 与 4.1.0 同日发布，是典型的"上一个 minor 收尾版"，此后十周无 4.0.8。在长期演进的平台上起步即选一条正在退役的线，是最差选项。

**选择 3.5.x 而非 4.1.0**：核心理由回到目标 #2。4.x 语料稀薄会**持续**侵蚀"AI 能独立准确扩展项目"这一核心卖点，损耗是每天发生的；而 3.x→4.x 迁移债是**一次性、可计划、有 OpenRewrite 官方脚本兜底**的。用一次可计划的迁移，换掉日常持续的 AI 出错率，这笔账划算。

**必须诚实记录的代价**：新项目起步即采用上一代大版本，未来 3.x→4.x 的迁移（Jackson 2→3 包名重命名、Spring Framework 6→7、Tomcat 10→11）是**已知的、必然要还的技术债**。路线图中为此预留独立阶段（见第十章阶段 6），不等被动触发。

> ⚠️ **未决事项**：Spring Boot 3.5.x 的 OSS 支持终止日期未能核实（`spring.io` 支持时间线页与 `endoflife.date` 在核验环境均不可达）。间接证据表明该线仍活跃，但**精确 EOL 日期需人工查证**，因为它直接决定上述迁移债的偿还时点。这是本方案目前唯一的开放技术问题。

#### 2.2.2 Java 版本策略：最低 17，构建 21，编译目标 17（v0.4 新增）

**事实基线**（已核验）：Spring Boot 3.5.16 的最低 Java 版本是 **17**，不是 21。判据两条——`spring-boot-starter-parent-3.5.16.pom` 中 `<java.version>17</java.version>`；`spring-boot-3.5.16.jar` 的 `MANIFEST.MF` 中 `Build-Jdk-Spec: 17`。

在此基础上确定三条策略：

| 项                            | 取值             | 理由                  |
| ---------------------------- | -------------- | ------------------- |
| **框架构建 JDK**                 | 21             | 使用较新的编译器与工具链        |
| **`maven.compiler.release`** | **17**         | 产出字节码在 Java 17 上可运行 |
| **业务方运行时要求**                 | **17+**（建议 21） | 框架不替业务方决定 JDK 版本    |

**为什么编译目标定 17 而不是 21**：这与 2.3 节"框架不指定数据库与驱动"是同一条原则。政务项目中业主环境的 JDK 版本同样不由我方选择，把目标定在 21 会无谓地将仍在 17 上的使用方挡在门外。而这套框架的核心价值不在虚拟线程、模式匹配这类 21 语言特性上——兼容面比这些特性更值钱。若将来确有必须使用 21+ 特性的场景，按第七章流程作为一次大版本变更处理。

**多 JDK 共存的工程约束**：开发机上普遍并存多个 JDK，依赖"每次记得设置 `JAVA_HOME`"对协作者和 AI Agent 都不可靠。因此：

- 父 POM 引入 `maven-toolchains-plugin`，显式声明本项目所需的 JDK 版本
- 开发者本地维护 `~/.m2/toolchains.xml` 登记各 JDK 路径，Maven 自行选择，与 `PATH` 上是哪个 `java` 无关
- CI 侧由 `actions/setup-java` 固定版本
- `toolchains.xml` 的样例与配置说明作为阶段 0 交付物

### 2.3 数据库兼容策略（v0.4 重写）

v0.3 的 2.3 节把两件本质不同的事捆在了一起，导致得出了错误的工程约束。v0.4 将其拆开：

- **2.3.1 SQL 语法基线** —— 框架责任，**不可下放**
- **2.3.2 数据库与驱动选择** —— 业务方责任，**框架不干预**
- **2.3.3 框架侧的安全默认值与支持矩阵**

划分的依据很简单：**框架自己产出、并将运行在业主库上的东西，框架必须负责；业务方自己声明和运维的东西，框架不该越界。**

#### 2.3.1 SQL 语法基线（框架责任，强制规范）

框架发布的建表 DDL、基类拼装的 SQL、代码生成器产出的 SQL，都会直接跑在业主的数据库上，业务方无从选择。因此语法基线必须由框架统一确定，并作为强制规范而非建议：

- **基线定义**：以 **MySQL 5.7 语法的一个安全子集**为准。之所以是"子集"而不是"5.7 全集"——国产化数据库的 MySQL 兼容通常是子集而非超集，按 5.7 全集写仍可能在达梦、Kingbase 上失败。
- **SQL 特性红线**：框架核心与代码生成器默认产出的 SQL 一律不使用窗口函数（`ROW_NUMBER()`/`RANK()` 等）、CTE（`WITH ... AS`）、函数索引、不可见列、`JSON_TABLE`、生成列等 8.0+ 特性；同时避免依赖 5.7 中各家兼容实现差异较大的部分（如 CHECK 约束的实际生效行为、`ON UPDATE CURRENT_TIMESTAMP` 的多列使用）。
- **字符集与排序规则**：不依赖服务器默认值——5.7 默认 `utf8mb4_general_ci`，8.0+ 默认 `utf8mb4_0900_ai_ci`，国产化库各不相同。所有建表脚本显式声明 `CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci`。
- **索引键长度**：按 5.7 较保守的限制设计，避免在部分库上触发索引长度上限。
- **主键策略**：**默认使用数据库自增主键**（MyBatis-Plus `IdType.AUTO`），但**做成可配置项**（`mybatis-plus.global-config.db-config.id-type`），业务方可切换为雪花Walking Skeleton ID（`IdType.ASSIGN_ID`）。默认选自增的理由是本方案定位为中小型单体项目、不涉及应用层分布式，且自增在单机 MySQL 上具有更好的索引局部性（B+ 树顺序插入，页分裂少）与运维可读性。需要切换为雪花 ID 的典型场景（政务项目中并不罕见，应在文档中提示业务方）：①多区县各建一套系统、后期数据需汇总到市级——各库自增 ID 会冲突；②存在跨库数据迁移或双向同步；③目标库是 OceanBase、TiDB 这类分布式数据库，其自增序列的单调性与性能特征与单机 MySQL 不同。配置项的存在就是为这些场景预留的，框架不替业务方锁死选择。
- **分页与方言**：MyBatis-Plus 的 `DbType` 做成**配置项**，不硬编码 `DbType.MYSQL`。默认走基于 `LIMIT/OFFSET` 的 MySQL 通用方言，业务方可按实际库覆盖。
- **业务方的"选用能力"**：业务方自己代码里确实需要 8.0+ 特性的，属于其自身选择，需在其文档中标注"仅 MySQL 8.0+ 可用"，自行确认目标库满足要求。框架不阻止，但也不承担。

#### 2.3.2 数据库与 JDBC 驱动选择（业务方责任）

**框架不指定数据库版本，也不指定 JDBC 驱动。** 这与 Spring Boot 自身的做法一致——`spring-boot-starter-jdbc` 不携带任何驱动，由使用者声明。

具体约定：

- `framework-mybatis-starter` **不将任何 JDBC 驱动作为传递依赖引入**（`optional` 或不声明）
- 业务方在自己的 `pom.xml` 中声明目标数据库的驱动及版本
- 框架文档提供一张"数据库 → 驱动坐标"对照表：

| 数据库        | 驱动坐标                                  | 备注                                  |
| ---------- | ------------------------------------- | ----------------------------------- |
| MySQL 8.0+ | `com.mysql:mysql-connector-j`         | 当前线（9.x/26.x）均可                     |
| MySQL 5.7  | `com.mysql:mysql-connector-j:8.2.0`   | **8.2.0 是最后一个官方声明支持 5.7 的版本**，见下方说明 |
| OceanBase  | `com.oceanbase:oceanbase-client`      | MySQL 模式                            |
| 达梦         | `com.dameng:DmJdbcDriver18`           | <br />                              |
| 人大金仓       | `cn.com.kingbase:kingbase8`           | <br />                              |
| openGauss  | `org.opengauss:opengauss-jdbc`        | <br />                              |
| GaussDB    | `com.huaweicloud.gaussdb:gaussdbjdbc` | <br />                              |

> **关于 MySQL 5.7 与 Connector/J 的事实**（逐版本核对官方 Release Notes 原文）：8.0.33 "suitable for use with MySQL Server versions 8.0 and 5.7"；8.1.0 与 **8.2.0**（2023-10-25）"can be used against MySQL Server version 5.7 and later"；**自 8.3.0（2024-01-15）起改为 "8.0 and later"**，8.4.0 及 9.x/26.x 同。即**最后一个官方支持 5.7 的驱动是 8.2.0**。
>
> Oracle 移除 5.7 支持的时点距 MySQL 5.7 EOL（2023-10-31）仅两个多月——整个生态按"5.7 已终结"演进，后续在连接池、Testcontainers 镜像、监控 agent 上会持续遇到同类问题。这一点需向使用 5.7 的业务方明确告知。

#### 2.3.3 框架侧的安全默认值与支持矩阵

"不钉死"不等于"不给默认值"。若业务方声明 `com.mysql:mysql-connector-j` 而不写版本，会拿到 Spring Boot 管理的当前版本（3.5.16 管理 9.7.0），随后在 5.7 上以一个不易读的错误失败。因此：

`framework-bom` 将 `mysql-connector-j` 的管理版本压回 **8.2.0**（5.7-safe），并明确标注可被业务方覆盖。

> ⚠️ **实测修正（Walking Skeleton 阶段发现，v0.4.1）**：本节初稿曾断言"这样能让业务方什么都不配的默认路径是安全的"，**该断言不成立**。
>
> Maven 的 `dependencyManagement` 优先级是：**从父 POM 继承来的条目 > 以 `import` 引入的 BOM 条目**。而绝大多数 Spring Boot 业务工程都继承 `spring-boot-starter-parent`，其中已管理 `mysql-connector-j`，因此 `framework-bom` 的覆盖会被业务方的父 POM 直接压掉。
>
> 三种布局的实测结果：
>
> | 业务方工程布局 | 驱动实际解析 |
> |---|---|
> | 继承 `spring-boot-starter-parent` + import `framework-bom` | ❌ **9.7.0**（不支持 5.7） |
> | 同上，且在自己的 `<properties>` 中写 `<mysql.version>8.2.0</mysql.version>` | ✅ 8.2.0 |
> | 不继承 `spring-boot-starter-parent`，只 import `framework-bom` | ✅ 8.2.0 |

据此，面向 5.7 / 国产化库的业务方，框架给出的约定是：

1. **必须显式声明，不能依赖 BOM 默认值。** 继承 `spring-boot-starter-parent` 的业务工程，需在自己的 `<properties>` 中加一行 `<mysql.version>8.2.0</mysql.version>`。这一条必须写进业务方接入文档的显著位置。
2. **框架提供构建期检查，而非仅靠文档。** `framework-mybatis-starter` 附带一条可选的 `maven-enforcer-plugin` 规则：业务方声明目标库为 5.7 时，若解析到的 `mysql-connector-j` ≥ 8.3.0 则构建失败。把"文档里写了但没人看"变成"构建直接红"。
3. 业务方使用 MySQL 8.0+ 或国产化库时无需额外动作，或直接声明对应厂商驱动。

这条修正同时印证了阶段 -1 Walking Skeleton 的价值：该问题**只有在真实构建一个业务方视角的工程时才会暴露**，靠阅读文档和推理发现不了。

**分层支持矩阵**（框架的正式承诺边界）：

| 层级         | 覆盖范围                        | 框架承诺                              |
| ---------- | --------------------------- | --------------------------------- |
| **Tier 1** | MySQL 5.7、MySQL 8.4         | CI 双线覆盖，测试必过；框架负责修复               |
| **Tier 2** | 达梦、人大金仓、OceanBase（MySQL 模式） | 提供兼容性自检工具与适配文档，不做 CI；问题按 issue 处理 |
| **Tier 3** | 其余数据库                       | 不承诺，业务方自行验证                       |

**数据库兼容性自检工具（v0.4 新增，重要）**：

CI 测 MySQL 5.7 只能证明"框架没有使用 8.0+ 语法"，**不能证明"达梦能跑"**；而各家国产化库因授权与镜像问题无法穷举进 CI。因此框架需提供一个可在业务方目标环境直接运行的自检工具：

- 在目标库上执行框架的全部 DDL、核心查询模式、分页/逻辑删除/审计字段等基类行为
- 输出结构化兼容性报告，明确指出哪些能力在该库上不可用
- 复用第五章的结构化断言与证据留存机制，AI Agent 可直接执行并解读

这比继续往 CI 里堆数据库实例更有效，也是 Tier 2 承诺得以成立的技术基础。

***

## 三、后端架构设计

### 3.1 模块划分与仓库拓扑

框架核心按"必选 / 可选"拆成两条产品线，全部作为独立 Maven 制品发布到 **Maven Central**（通过 Sonatype Central Portal 发布，legacy 的 OSSRH/JIRA 工单流程已停用），业务方以依赖方式引入，**任何情况下都不直接拷贝框架源码**。

**命名空间**：groupId 为 `io.github.describeadmin`（通过 GitHub 组织自动验证，免域名验证流程）。

> ✅ **命名空间已全部落地（v0.4.1）**：GitHub 组织 `describeadmin`、Maven groupId `io.github.describeadmin`（Central Portal 命名空间已验证通过）、npm 组织 `@describeadmin`、GPG 密钥已创建并发布至公钥服务器。
>
> 全部标识符统一为无连字符的 `describeadmin`，**groupId 与 Java 包名 `io.github.describeadmin.*` 完全一致**，无需任何映射。Spring 配置前缀同样统一为 `describeadmin.<模块>`。
>
> （早期方案曾按带连字符的组织名规划，需要处理 groupId 与 Java 包名不一致的问题——组织更名后该问题已不存在，相关规范已删除。）

**framework-bom**：统一仲裁 framework-core、framework-ext 各模块之间的版本兼容关系，业务方 `pom.xml` 只需引入 BOM。同时承载 2.3.3 中的安全默认值（如 `mysql.version`）。

**framework-core（必选）**

- `framework-web-starter`：统一响应体、全局异常处理、请求日志/链路追踪、统一参数校验
- `framework-security-starter`：认证鉴权基座（基于 Spring Security 6.5.x），内置用户名密码登录，同时定义 `AuthProvider` 等 SPI 接口供扩展
- `framework-mybatis-starter`：`BaseEntity` / `BaseMapper` / `BaseService` / `BaseController` 泛型基类，封装分页、通用查询、审计字段（创建人/创建时间/更新人/更新时间/逻辑删除），SQL 写法遵循 2.3.1 的语法基线；**不引入任何 JDBC 驱动**
- `framework-common`：通用工具类、常量、枚举、Result 包装类，以及跨模块契约
  （`CurrentUserProvider`、`PermissionChecker`、`FrameworkVersion`）
- `framework-cache-starter`：`CacheProvider` 契约 + 零依赖内存实现。
  集中式实现走插件，本模块不允许引入任何缓存中间件依赖
- `framework-system-starter`：RBAC（用户 / 角色 / 菜单 / 部门）与登录端点

> 正文早期只列了四个模块，与实际不符，v0.5 回填。**"必选"的判据见能力规划的三条**
> （定义契约 / 必须唯一且全局生效 / 缺席就不安全），三条全否即应做插件。

**framework-ext（可选，按需引入）**

每个插件**独立仓库、独立版本线、独立发布**，不作为 framework 仓的 module（见 3.1.1）。
清单与准入规范见 `registry.md`；插件 POM **不继承 `framework-parent`**，
改为 `import framework-bom`——那正是业务方消费框架的姿势。

- `framework-cache-redis-starter`：把 `CacheProvider` / `TokenStore` 切到 Redis
  （**已落地**，第一个真实插件）
- `framework-auth-zhengwuding-starter`：浙政钉登录，实现 `AuthProvider`
- `framework-notify-dingtalk-starter`：钉钉消息推送，实现 `NotifyChannel`
- `framework-notify-wecom-starter` / `framework-notify-sms-starter`：企业微信、短信通道，同样按需引入
- 业务方专属的对接需求，可在自己项目里实现同样的 SPI 接口，不必等框架团队排期

#### 3.1.1 仓库拓扑：按模块细分多仓

已确认采用**按模块细分多仓**：`framework-core`、每个 `framework-ext` 插件、代码生成器、前端各共享包分别独立仓库。

这个拓扑的好处是插件解耦彻底、各自版本线独立；代价是**跨仓联调成本高**——修改一个 SPI 接口需要同步改动 core、插件、前端多个仓库。为避免这一点侵蚀目标 #2（AI 能独立理解项目），必须配套：

- 组织根仓库维护 `repos.yml`，登记全部仓库及其相互关系
- 提供拉取脚本，一条命令把全套仓库检出到同一父目录，使开发者与 AI Agent 拿到完整上下文
- 组织根仓库维护统一的 `CLAUDE.md`，各仓库以软链或同步机制复用

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

开关控制分两层：**编译期**（业务方 `pom.xml` 是否引入对应 starter）决定能力是否存在，**运行时**（`@ConditionalOnProperty` 配合 `application.yml` 的 Profile 配置）决定已引入的能力是否激活。由于不引入配置中心，运行时开关的调整依赖配置文件重新发布/服务重启才能生效，不支持动态热切换，需在插件文档里向业务方说明清楚。

前端配合的做法是登录页不硬编码某个登录方式的按钮，而是调用后端 `/api/auth/providers` 之类的接口动态获取当前项目启用的登录方式列表，再动态渲染对应组件。

### 3.3 代码生成器与"基类继承"边界

这是保证框架可持续升级的关键设计点之一。生成器的输出必须是"薄"业务代码，通用逻辑留在框架基类里：

- 输出：`XxxEntity extends BaseEntity`、`XxxMapper extends BaseMapper<XxxEntity>`、`XxxService extends BaseService<...>`、`XxxController extends BaseController<...>`，业务方只填充业务特有字段和方法
- 前端同步生成对应的列表页/表单页，同样是"薄"页面，复用框架共享组件
- 产出的 SQL 严格遵循 2.3.1 的语法基线

好处是框架升级大多数情况下改的是基类（属于 Platform 层，版本化发布），业务方生成的"薄"代码基本不需要跟着大改，从源头上减少了升级摩擦。

#### 3.3.1 输入形态：YAML/DSL 优先，而非直连数据库（v0.4 优先级调整）

v0.3 把"以数据库表结构为输入"作为 v1 方案，"演进为 YAML/DSL 定义"列为后续演进。**在政务/国产化场景下这个优先级是错的，v0.4 予以调整：YAML/DSL 定义为 v1 的主输入形态。**

理由有二：

1. **各家国产化数据库的** **`information_schema`** **差异极大**——元数据表结构、类型映射、注释字段都不一致。生成器直连读元数据这条路在达梦、Kingbase 上大概率失败，等于生成器在最需要它的场景下不可用。
2. **业主环境往往连不上**。政务项目中开发机通常无法直连业主的生产/测试库，"以数据库为输入"这个前提本身就不成立。

因此 v1 即以 YAML/DSL 作为唯一可靠输入，脱离对具体数据库的依赖；"从现有库反向生成 YAML"作为一个**可选的辅助工具**提供，仅在标准 MySQL 环境下承诺可用。

***

## 四、前端架构设计

### 4.1 基于 Vben Admin 的复用方式（v0.4 重写）

v0.3 假设可以把 Vben 的 `packages/` 作为 npm 包依赖使用。**核验结果表明这个前提不成立**：

- `vue-vben-admin` 根 `package.json` 为 `"private": true`
- 内部包全部以 `workspace:*` 互相引用；`@vben-core/shadcn-ui`、`@vben/common-ui` 在 npm 上均为 404
- npm 上存在的 `@vben/utils@1.0.1`、`vben@1.0.11` 是**其他发布者的同名无关包，不可使用**

Vben Admin 是**模板仓库**，交付形态是"复制源码"，不是"版本化依赖"。

**已确认的处置：一次性取材后独立演进。**

- 将 Vben **5.7.0** 作为起点快照 fork，以官方 `apps/web-ele` 为基础
- 把 `packages/` 改造为 `@describeadmin/*` scope 下的可发布 npm 包（如 `@describeadmin/ui`、`@describeadmin/layouts`、`@describeadmin/access`、`@describeadmin/request`），以 `npm publish --access public` 发布
- 此后**与 Vben 上游断开**，独立演进
- 业务方应用只依赖这些已发布的包，业务页面代码与框架代码物理分离

**选择理由**：与已确认的"按模块细分多仓"拓扑兼容——"跟随上游"要求保持单 monorepo 结构才能 merge，与多仓拓扑在工程上不兼容；同时这使本节设想的"依赖化 + 版本治理"真正成立。

**必须诚实记录的成本**：Vben 上游后续的所有更新与 bugfix 都与本项目无关，`packages/` 的全部维护责任由框架团队承担。这一条需落到第七章的框架 Owner 职责中，否则会变成无人负责的黑洞。

### 4.2 UI 组件库：Element Plus

**先澄清 v0.3 的一处理解偏差**：Vben Admin **不自带业务组件库**。其内核 `@vben-core/*` 基于 `reka-ui`（无样式组件原语）+ Tailwind CSS 4，确实是 UI 库无关的，只提供布局外壳、权限、路由、偏好设置；但 `apps/` 层官方并列提供三个版本，**必须三选一**——实际业务页面的表格、表单、弹窗均来自所选 UI 库。

三个官方适配应用的维护活跃度实测：

| 官方应用                   | UI 库           | npm latest | 最后发布                     | 状态 |
| ---------------------- | -------------- | ---------- | ------------------------ | -- |
| `apps/web-antd`        | Ant Design Vue | 4.2.6      | **2024-11-11**（约 21 个月前） | 停更 |
| **`apps/web-ele`（选定）** | Element Plus   | 2.14.4     | 2026-08-07               | 活跃 |
| `apps/web-naive`       | Naive UI       | 2.45.0     | 2026-08-16               | 活跃 |

v0.3 选择 Ant Design Vue 的理由是"设计语言更贴近浙政钉这类政务场景"，**这个判断本身是成立的**，并非拍脑袋。但它漏掉了两点：①UI 库在 Vben 中是**可替换的适配层**，不是不可逆的架构决策；②ADV 是三者中唯一停更的，而同期 Vue 已到 3.5.40、Vite 8、Tailwind 4。

**Element Plus 是同一视觉谱系中仍在活跃维护的替代**——同样是偏正统的中后台政务视觉语言，与 ADV 的风格差距远小于 Naive UI，同时保持活跃发布。因此 v0.4 改选 Element Plus。

### 4.3 前端版本基线

> **v0.5 修正**：本表 v0.4 版本的数字与 Vben 5.7.0 的实际 catalog 大面积不符
> （7/8 行偏高，pinia 连大版本都写错），详见 VERSION_BASELINE.md 发现 ⑩。
> 下表以 `pnpm-workspace.yaml` 的 catalog 与 `node_modules` 实测为准。

| 组件 | 上游 5.7.0 catalog | 本机实测安装 | 说明 |
| --- | --- | --- | --- |
| Vben Admin | 5.7.0（起点快照） | — | 已 fork，与上游断开，不做 merge |
| Vue | `^3.5.34` | 3.5.34 | |
| Vite | `^8.0.13` | 8.0.13 | |
| Element Plus | `^2.14.0` | 2.14.0 | |
| TypeScript | `^6.0.3` | 6.0.3 | |
| Tailwind CSS | `^4.3.0` | 4.3.0 | 内核样式基础 |
| reka-ui | `^2.9.7` | 2.9.7 | `core-shadcn-ui` 的无样式组件原语 |
| pinia | `^3.0.4` | 3.0.4 | **不是 4.x**，pinia 尚无 4.x |
| vue-router | `^5.0.7` | 5.0.7 | |

**Node / pnpm**：上游 5.7.0 的 engines 是 `node: ^22.18.0 || ^24.0.0`、
`pnpm: >=10.0.0`（`packageManager: pnpm@10.33.4`）。本项目已 fork 独立演进，
按自己的基线钉到 `node: ^22.18.0 || ^24.12.0`、`pnpm: >=11`（`pnpm@11.21.0`，本机实测可用）。
**这是我们的选择，不是上游的事实**，两者不要混为一谈。

**版本核查纪律同样适用于 npm 侧**：来自上游的版本号必须从上游仓库文件里读，
不能凭记忆或搜索结果写——这与后端禁用 `search.maven.org/solrsearch` 是同一条纪律。

#### 4.3.1 已落地的改造

| 项 | 处置 |
| --- | --- |
| npm scope | `@vben/*` → `@describeadmin/*`，`@vben-core/*` → `@describeadmin/core-*`（520 个文件）；`@vben/common-ui` → `@describeadmin/ui` |
| 组件名 `VbenButton`、CSS 类名 `vben-*` | **保留不改**——上千处机械替换收益为零、风险不低，保留前缀也让代码出处一目了然，与 MIT 署名同向 |
| 版本号 | 从 5.7.0 重置为 0.0.1，走我们自己的 SemVer 线 |
| 官方其余 UI 库版本、`playground`、`docs` | 删除 |
| `apps/web-ele` | 保留并更名 `apps/admin`，本项目唯一应用 |
| `apps/backend-mock` | **删除**。用 mock 开发前端，等于把前后端契约不一致的问题全部推迟到联调阶段 |
| 权限模式 | `accessMode: 'backend'`，菜单与路由全部由后端 `sys_menu` 下发 |

⚠️ 合并 scope 会打断上游基于双 scope 的 eslint 分层约束，必须补否定规则，
详见 VERSION_BASELINE.md 第六轮。

### 4.4 移动端适配

Vben Admin 内置的响应式布局已经过实测验证，不再单独引入移动端专属组件库，降低技术栈复杂度。需要注意的是，导航、整体布局这类"外壳"部分通常适配得比较好，真正容易出问题的是宽表格、多字段复杂表单这类"重"页面。建议在核心业务页面开发完成后，安排一轮真机验证（而不仅是浏览器缩放模拟），再正式定档"不需要额外移动端方案"这个结论。

> 注：v0.3 的这一结论基于 Ant Design Vue 的实测，改用 Element Plus 后需要**重新验证一次**。
> v0.5 状态：桌面分辨率（1440×900 / 1600×950）下布局与四个系统管理页面均已实测正常，
> **移动端真机验证仍未做**。系统管理的表格列数较多（用户管理 6 列 + 320px 操作列），
> 正是 4.4 所说"真正容易出问题的重页面"，不要在真机验证前就下"不需要额外移动端方案"的结论。

***

## 五、AI 自动化端到端测试体系

### 5.1 环境编排

新建 `docker-compose.test.yml`，与开发环境的 compose 文件分离，避免互相干扰：

- `mysql-test` / `redis-test`：独立于开发库的测试专用实例；`mysql-test` 的镜像版本做成可参数化，覆盖 **5.7 和 8.4-LTS 两条 Tier 1 线**跑同一套种子脚本
- `backend` / `frontend`：测试专用镜像或直接跑本地构建产物
- `seed-job`：一次性任务容器，执行 `schema.sql` + `seed.sql` 后自动退出，保证每次测试拿到确定、干净的初始数据

### 5.2 提速策略：快照替代重建

如果每个业务场景都走一次完整的 `docker compose down && up`，速度会很慢。更实际的做法是种子数据准备好后做一次数据库快照（`mysqldump` 或基于卷的快照），场景之间用快照恢复来重置状态，只有在切换测试批次或环境异常时才做完整的容器重建，把单场景重置时间从"分钟级"压缩到"秒级"。

### 5.3 浏览器自动化

使用 chrome-devtools MCP（基于 Chrome DevTools Protocol）驱动真实浏览器，AI Agent 直接完成点击、输入、截图、读取 DOM、查看 console 报错和网络请求。配套要求前端统一给关键交互元素加 `data-testid` 或规范的 `aria-*` 属性，保证自动化工具定位元素的稳定性，减少因选择器脆弱导致的假失败。

### 5.4 测试用例规范（结构化 Spec）

测试场景不用纯自然语言描述，而是用结构化格式定义步骤和断言点，AI 按 Spec 执行并留痕：

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

`assertions` 里同时包含 UI 断言和 DB 断言，是为了避免 AI 仅凭"页面看起来正常"这种视觉判断就下结论。结构化断言 + 证据留存（截图、console、网络日志）结合起来，AI 出具的测试报告才有可复核性。早期阶段建议保留人工抽查环节，等误判率验证得足够低之后再走向完全自动化闭环。

### 5.5 数据库兼容性自检工具（v0.4 新增）

2.3.3 提出的自检工具直接复用本章基础设施：

- 以同一套结构化 Spec 描述"框架能力 → 期望行为"
- 在业务方的目标库（含 Tier 2 的国产化库）上实际执行框架 DDL 与核心查询模式
- 输出结构化兼容性报告，明确标注不可用能力及其影响范围
- AI Agent 可直接执行并解读报告，无需人工逐条排查

这是 Tier 2 承诺成立的技术基础，也是本方案里 CI 无法覆盖部分的补位手段。

### 5.6 与 Worktree 机制联动

测试环境的命名空间隔离直接复用第六章的 worktree 隔离方案，保证不同 worktree 各自的测试环境不会互相冲突，测试完成后统一 `down -v` 清理，不留残留资源。

***

## 六、Git Worktree 并行开发支持

### 6.1 命名空间隔离策略

Git worktree 本身是原生能力，真正需要做的工作是让项目工具链感知多 worktree 场景，核心是把所有硬编码的资源标识参数化：

- 根据 worktree 的目录路径或分支名计算出一个唯一 slug（比如取路径 hash 的前 8 位）
- 用这个 slug 派生 `COMPOSE_PROJECT_NAME`、端口偏移量（如 `8080 + offset`）、数据库 schema 名
- 数据库/Redis 建议共用一个实例、按 worktree 分 schema / db index，避免每个 worktree 都起一套重资源容器；后端、前端这类应用服务则按 worktree 走独立进程/容器，保证代码热更新互不干扰

### 6.2 开发者体验封装

提供一个统一入口脚本（`./scripts/dev.sh up|down|test`），自动识别当前所在 worktree、计算隔离参数、生成对应的 `.env` 覆盖文件，开发者（以及 AI Agent）不需要手动记忆端口和命名规则，一条命令即可拉起或销毁当前 worktree 专属的完整环境。

> 多仓拓扑下需额外注意：该脚本需要能跨多个仓库协同工作，与 3.1.1 的 `repos.yml` 拉取脚本配套设计。

***

## 七、框架版本治理与升级机制

- **语义化版本（SemVer）**：只有大版本号才允许破坏性变更，小版本号只做兼容性的功能新增和修复
- **废弃周期**：旧接口废弃时先标记 `@Deprecated`，至少保留 1-2 个小版本周期才允许真正移除
- **CHANGELOG 规范**：每次发版明确列出 Breaking Changes、New Features、Bug Fixes 三类变更
- **自动化迁移工具**：大版本发布时同步提供 OpenRewrite 迁移脚本（Java 侧）和 codemod 脚本（前端侧）
- **兼容性测试门禁**：维护一个"业务模拟"样板应用，复用第五章的 AI 自动化测试基础设施，每次框架发版前跑一遍完整业务流程测试
- **开源属性带来的额外约束**：组件发布到 Maven Central / npm 公共仓库，潜在使用者不限于内部业务方，SemVer 和 CHANGELOG 的纪律性尤其不能放松

### 7.1 框架 Owner 职责（v0.4 明确）

需要有明确的框架 Owner。工具能降低升级成本，但如果没有人对 API 稳定性负责，工具本身也会形同虚设。v0.4 明确以下职责，其中后两项是本次新增：

1. 评审核心变更、把控兼容性承诺，SPI 接口纳入 framework-core 的兼容性承诺范围
2. **前端** **`packages/`** **的完整维护责任**——因已选择与 Vben 上游断开（4.1），上游的 bugfix 与安全修复不再自动获得，需要框架团队自行跟进 Vue / Vite / Element Plus 生态的变化
3. **跟踪 Spring Boot 3.x 的 EOL 时点，并主导 3.x→4.x 迁移**（见 2.2.1 与第十章阶段 6）

***

## 八、插件目录（Registry）规范

维护一份结构化的插件清单文档（`framework-ext/registry.md`），每个插件登记以下信息，方便人和 AI Agent 快速判断"这个能力框架有没有现成的，还是需要自己按接口实现"：

| 插件        | 坐标                                                            | 实现的 SPI                          | 最低框架版本 | 说明       |
| --------- | ------------------------------------------------------------- | -------------------------------- | ------ | -------- |
| 浙政钉登录     | `io.github.describeadmin:framework-auth-zhengwuding-starter` | `AuthProvider`                   | 1.0.0  | 政务场景登录   |
| 钉钉消息推送    | `io.github.describeadmin:framework-notify-dingtalk-starter`  | `NotifyChannel`                  | 1.0.0  | 工作通知类推送  |
| 企业微信登录/推送 | 【规划中】                                                         | `AuthProvider` / `NotifyChannel` | -      | 按业务方需求排期 |
| 短信通道      | 【规划中】                                                         | `NotifyChannel`                  | -      | 验证码、通知短信 |

***

## 九、业务方接入路径（v0.5 新增）

前八章描述的是框架自身如何构造。本章描述的是**框架发布之后，一个业务方从零到跑起来要做什么**——这条路径此前只散落在 `sample-app` 的 POM 注释与 `VERSION_BASELINE.md` 的实测发现里，从未被当作设计对象。

把它补成独立一章的理由：**它是目标 #1、#2、#5 的最终检验**。框架内部分层再干净，如果业务方接入要走九个步骤、踩三个已知的坑，那"生产级"与"面向 AI 编程"就没有真正兑现。

### 9.1 一个业务方项目由什么构成

业务方持有两个仓库，与 3.1.1 的多仓拓扑一致：

| 仓库 | 内容 | 依赖框架的方式 |
|---|---|---|
| `<业务>-server` | Spring Boot 应用、业务实体/服务/控制器、建表与菜单 SQL | Maven：`import framework-bom` + 若干 `framework-*-starter` |
| `<业务>-web` | Vue 应用外壳、业务页面 | npm：`@describeadmin/*` |

不合并为一个仓的理由：前后端构建链、发布节奏、CI 矩阵完全不同；且 `codegen` 会同时向两个仓输出（见 9.4）。

### 9.2 后端接入

#### 9.2.1 业务方工程的形态

`sample-app` 就是这个形态的活样本——它刻意**不继承** `framework-parent`，以真实业务方的姿态消费框架。要点：父 POM 是 `spring-boot-starter-parent`；只 `import framework-bom`，框架模块一律不写版本号；JDBC 驱动由业务方声明（2.3.2）。

#### 9.2.2 三个必须由模板固化的坑

手工照抄 POM 会踩到三个**已实测**的问题。它们的共同特征是：报错信息与真实原因相距很远，靠阅读文档发现不了。

| 坑 | 来源 | 现象 | 必须的动作 |
|---|---|---|---|
| BOM 驱动默认值失效 | 发现 ② | 父 POM 继承的 `dependencyManagement` 优先级高于 import 的 BOM，实际解析到 Spring Boot 管理的新版驱动，连 5.7 直接失败 | 业务方 `<properties>` 显式写 `<mysql.version>8.2.0</mysql.version>` |
| ~~多 JDK 共存~~ | 发现 ⑥ | 用 `PATH` 上恰好存在的 JDK 编译 `release=17`，报"不支持发行版本 17" | ~~业务方工程同样要配 `maven-toolchains-plugin`~~ **已推翻**，见下 |
| `@MapperScan` 屏蔽框架 Mapper | 发现 ⑧ | 业务方写了 `@MapperScan("自己的包")`，框架的系统管理 Mapper 全部扫不到，登录即失败 | 不写，或把框架包一并纳入扫描范围 |

> **发现 ⑥ 的处置已于 2026-08-20 推翻**（VERSION_BASELINE 第八轮）。
> 真实原因是"Maven 当时跑在 JDK 11 上"，而 Maven 跑在 17+ 本就是硬要求
> （`repackage` 加载不了），满足后 `release=17` 必然能编，toolchains 无增量价值；
> 反而因业务方开发机普遍没有 `~/.m2/toolchains.xml` 而会直接打死构建。
> **archetype 不生成 toolchains 配置**，业务方用哪个 JDK 构建是业务方的自由。
> 该配置只在 `sample-app` 保留，用途是框架团队"以最低支持版本构建"的兼容性验证。

**结论：接入不能靠文档，必须靠模板。** 框架需交付一个 Maven archetype：

```bash
mvn archetype:generate \
  -DarchetypeGroupId=io.github.describeadmin \
  -DarchetypeArtifactId=describeadmin-archetype \
  -DarchetypeVersion=<框架版本>
```

archetype 的职责不是"少敲几行 XML"，而是**把上述三条固化成默认正确的初始状态**，使这三个坑对业务方不可见。此外它还应产出：`application.yml` 骨架（含 `spring.sql.init.encoding=UTF-8`，见 2.3.1 与编码规范 3.6）、`@SpringBootApplication` 入口、`.gitattributes`（见发现 ⑫）、以及一份指向框架文档的 `README.md`。

> **交付物归属**：archetype 与 `framework` 同仓发布，版本号与框架保持一致——它生成的 POM 里写的就是框架版本，两者必须同步。

### 9.3 前端接入：本章发现的设计缺口

4.1 节确定了"把 `packages/` 改造为可发布的 `@describeadmin/*`，业务方只依赖这些包"。**但它没有回答：业务方的应用本身从哪里来。**

Vue 应用不是装几个组件包就能跑的：router、access、bootstrap、layouts 装配、`vite.config.ts`、`.env`、locales、adapter 这些外壳必须实际存在于业务方仓库中。当前实测分布：

| 部分 | 行数 | 目标交付形态 |
|---|---|---|
| `packages/` | 34,485 | ✅ 发布为 `@describeadmin/*`，版本化依赖 |
| `apps/admin/src` | 4,649 | ❓ 4.1 未定义 |

4.1 极准确地诊断了 Vben 的缺陷——**"Vben Admin 是模板仓库，交付形态是复制源码，不是版本化依赖"**。但如果业务方通过 fork `apps/admin` 起步，这个缺陷会在业务方这一层被原样重现，只是换了个位置。

#### 9.3.1 系统管理页面必须收进包（前后端对称）

`apps/admin/src` 的 4,649 行里，**1,376 行是系统管理页面**：

| 页面 | 行数 |
|---|---|
| `views/system/user` | 435 |
| `views/system/menu` | 349 |
| `views/system/role` | 309 |
| `views/system/dept` | 283 |

这些是**框架功能**，不是业务代码。后端对应的 `framework-system-starter` 已经收回框架，业务方引一个依赖就得到完整 RBAC，框架修了 bug 升个版本就拿到；前端却把对应页面留在了应用层。这个不对称的后果是：业务方复制走 `apps/admin` 之后就永久拥有了这 1,376 行，框架此后对用户管理页面的任何修复都到不了他们那里。

**决定：新增 `@describeadmin/system-ui` 包**，承载系统管理四个页面与其 API 封装，与 `framework-system-starter` 一一对应。业务方的应用里只保留路由挂载点。

#### 9.3.2 应用外壳由生成器交付，不由复制仓库交付

收走系统管理页面后，外壳约剩 2,200 行，且其中不再包含会被框架修改的东西。这部分通过一条命令生成：

```bash
npm create @describeadmin/app <项目名>
```

生成器负责：应用骨架、`@describeadmin/*` 的当前版本号、`vite.config.ts` 的后端代理配置、`.env` 骨架（含 `VITE_APP_STORE_SECURE_KEY` 的替换提示）、`.gitattributes`。

**必须诚实记录的代价**：生成出去的外壳不会自动升级，这一点与 Vben 的模板模式没有本质区别。区别只在**量**——2,200 行的薄外壳与 4,649 行（含框架功能）的厚外壳，在框架演进多轮之后的漂移成本差一个量级。因此"外壳尽可能薄"不是洁癖，而是升级机制能否成立的前提；任何往应用外壳里加通用能力的提议，都应先问一次"它是否应该属于某个包"。

### 9.4 codegen 的定位与交付形态

`codegen` 独立成仓（见 3.1.1 与 `repos.yml`），依据是**依赖方向**：它只产出源码文本，运行时不需要任何框架类，其 POM 除 SnakeYAML 外无其他依赖。三条理由：

1. **不污染业务方依赖树**——若并入 `framework`，业务方为跑一次生成器要拖进整个框架依赖树
2. **版本节奏不同**——生成器是开发期工具，可以快速迭代；框架是运行时制品，受 SemVer 兼容承诺约束。两者绑定会互相拖累
3. **生命周期不同**——产物一旦生成即脱离生成器，业务方运行时完全不需要它

由此得到一条硬规定：

> **`codegen` 绝不出现在业务方 `pom.xml` 的 `<dependencies>` 中。** 它是命令行工具，不是库。

#### 9.4.1 交付形态

`codegen` 会**同时向两个仓库输出**（后端 Java/SQL → `<业务>-server`，Vue/TS → `<业务>-web`），因此其交付形态需要能跨仓工作：

| 形态 | 用途 |
|---|---|
| **Maven 插件**（主）`describeadmin-codegen-maven-plugin` | 在 `<业务>-server` 中声明于 `<build><plugins>`，`frontendOut` 指向同级的 `<业务>-web`。版本由 `framework-bom` 仲裁，与框架版本联动 |
| **可执行 fat jar**（辅） | 随 GitHub Release 分发，供不使用 Maven 的场景与 CI 使用 |

选 Maven 插件为主的理由与目标 #2 直接相关：**它在 `pom.xml` 里是可被发现的**——AI Agent 读一遍业务方的 POM 就知道这个项目用什么生成代码、如何调用；而一条需要外部记忆的 `java -jar` 命令不具备这个性质。

#### 9.4.2 使用位置

生成器由**业务方开发者（或其 AI Agent）在开发期调用**，不进入运行时，也不进入业务方的生产构建。典型循环：

写 `codegen-specs/<模块>.yaml` → 跑生成 → 把新增的 `schema-*.sql` / `menu-*.sql` 登记进 `spring.sql.init` → 重启 → 页面出现在侧边栏 → 跑生成出的结构化验收用例。

### 9.5 目标状态下的完整接入流程

```bash
# 1. 后端工程
mvn archetype:generate -DarchetypeGroupId=io.github.describeadmin \
    -DarchetypeArtifactId=describeadmin-archetype -DarchetypeVersion=<版本>

# 2. 前端工程
npm create @describeadmin/app <项目名>

# 3. 建库（archetype 已产出 schema/seed 的执行说明）

# 4. 起服务，用初始账号登录，得到一个带完整 RBAC 的后台

# 5. 加业务模块：写 spec → mvn describeadmin:gen → 登记 SQL → 重启
```

**验收标准**：一个此前没接触过本框架的开发者，照上述步骤能在 30 分钟内得到一个可登录、带 RBAC、含一个自建业务模块的后台，且全程不需要阅读 `VERSION_BASELINE.md`。

### 9.6 业务方升级时做什么

| 层 | 动作 | 破坏性变更时 |
|---|---|---|
| 后端框架 | 改 `<describeadmin.version>` 一行 | 框架提供 OpenRewrite 脚本（第七章） |
| 前端包 | `pnpm up @describeadmin/*` | 框架提供 codemod 脚本（第七章） |
| 生成的业务代码 | 不动——"薄代码"设计的目的正在于此（3.3） | 视基类变更而定 |
| 应用外壳 | **不会自动升级** | 由 CHANGELOG 提示手工跟进 |

最后一行是这套体系里唯一没有自动化兜底的部分，也正是 9.3.2 要求外壳尽可能薄的原因。

### 9.7 对路线图的影响

本章新增四项此前不在路线图中的交付物：

| 交付物 | 建议阶段 |
|---|---|
| ~~`describeadmin-archetype`~~ **已实现**（2026-08-20，待发布到 Central） | 阶段 0（与发布链路同期，它本身就要发布到 Central） |
| `@describeadmin/system-ui`（前端系统管理收包） | 阶段 1（与 `framework-system-starter` 对称，宜同期完成） |
| `npm create @describeadmin/app` | 阶段 1 |
| `describeadmin-codegen-maven-plugin` | 阶段 1（codegen 本体已有，此处只是补交付形态） |

***

## 十、实施路线图

> ⚠️ **本章是 v0.4 的战略分期，不是进度表。**
> 当前实际进展、各仓状态与下一步动作见 **[`PROGRESS.md`](./PROGRESS.md)**——
> 那里才是收工时更新的地方。本章的阶段 -1 / 0 / 1 已完成，阶段 2 部分完成
> （第一个官方插件已跑通，厂商插件未开始）。
> 后续能力按能力规划的 A~G 分期推进，两套分期的合并尚未完成。

不给出具体日期（取决于团队规模和投入节奏），按依赖关系给出建议顺序。每个阶段建议找一个真实业务方做小范围试点验证后再推广。

> **v0.4 的重要调整**：v0.3 的路线图存在依赖环——阶段 1 的验收标准要求"在 5.7 和 8.4 上均验证通过"，但双版本测试环境是阶段 3 才交付的。按原顺序执行，阶段 1 会在没有门禁的情况下积累一批违反语法基线的 SQL，等阶段 3 门禁上线时集中返工。因此**双版本 CI 矩阵提前至阶段 0**。

**阶段 -1：Walking Skeleton（垂直切片，v0.4 新增，1\~2 周）**

在铺开任何阶段之前，先打一根穿透全栈的最薄切片。目的不是交付功能，而是**在投入大量代码前一次性验证所有高风险假设**：

- 用户名密码登录 → 一张业务表 CRUD → Element Plus 列表页 → 5.7/8.4 双线 CI → 1 条 5.4 节格式的结构化测试用例 → 发布 `0.0.1-SNAPSHOT` 占位包验证发布链路

待验证的具体假设（来自 `VERSION_BASELINE.md`）：

1. MyBatis-Plus 3.5.17（boot3 starter）与 Spring Boot 3.5.16 的实际兼容性
2. Connector/J 8.2.0 在 Java 21 + Spring Boot 3.5.16 下的可用性，含 `mysql_native_password`（5.7）与 `caching_sha2_password`（8.0+）两种鉴权
   2b. **`release=17`** **产物在 Java 17 运行时上的实际可用性**——用 JDK 21 构建、在 JDK 17 上运行一遍，验证 2.2.2 的兼容承诺成立（本机已有 `ms-17.0.20` 可直接用于此项验证）
3. Element Plus 2.14.x 在 Vue 3.5.40 + Vite 8 + Vben 5.7.0 下的构建与类型兼容性
4. Vben 要求的 node `^22.18 || ^24.12` + pnpm 11 与团队现有环境的一致性

任一假设不成立，此时推倒的成本是几天；等到阶段 2 才发现，是几周。

**阶段 0：基础设施骨架**

多仓结构搭建与 `repos.yml`、CI 骨架（**含 5.7/8.4 双版本矩阵**）、`framework-bom`/父 POM（含 `maven-toolchains-plugin` 与 `maven.compiler.release=17`，见 2.2.2）、`toolchains.xml` 样例与说明、Vben fork 与 `packages/` 改造、打通 Maven Central 与 npm 发布链路（GPG 签名、Central Portal 的 `io.github.describeadmin` 命名空间验证）、**组织级** **`CLAUDE.md`** **与编码规范**（含 3.1.1 的包名规范、2.3.1 的 SQL 红线与主键策略）。

验收标准：空的登录+首页流程可跑通；占位包成功发布到 Maven Central 和 npm；双版本 CI 矩阵可用。

> 目标 #2「面向 AI 编程」在 v0.3 中没有对应交付物，v0.4 将 `CLAUDE.md`、编码规范、模块模板明确列为本阶段的显式交付物。

**阶段 1：核心能力**

用户名密码登录、RBAC 权限模型、菜单管理、`BaseXxx` 基类、**代码生成器 v1（以 YAML/DSL 为主输入，见 3.3.1）**。

验收标准：能通过生成器产出一个完整可用的业务 CRUD 模块，且在 MySQL 5.7 和 8.4 两个版本上均验证通过。

**阶段 2：插件化落地**

`AuthProvider` / `NotifyChannel` SPI 接口定稿，浙政钉登录、钉钉推送两个官方插件跑通，验证"可插拔"架构在真实场景下成立。

**阶段 3：AI 自动化测试基础设施 + 数据库兼容性自检工具**

`docker-compose.test.yml`、种子数据+快照机制、chrome-devtools MCP 集成、首批核心业务流程结构化测试用例、**2.3.3/5.5 的数据库兼容性自检工具**。

验收标准：至少一个完整业务流程能被 AI 自主测试并出具可复核报告；自检工具能在一个 Tier 2 国产化库上产出有效报告。

**阶段 4：Worktree 工具链**

`dev.sh` 脚本、端口/数据库隔离参数化、跨多仓协同、配套文档。

验收标准：两个 worktree 同时拉起环境互不冲突。

**阶段 5：版本治理**

SemVer 发布流程、CHANGELOG 规范落地、首个 OpenRewrite 迁移脚本试点、兼容性测试门禁接入 CI。

验收标准：完成一次真实的框架小版本升级，业务方全程无需手工排查兼容性问题。

**阶段 6：Spring Boot 3.x → 4.x 迁移（v0.4 新增，时点待定）**

这是 2.2.1 选型决策带来的**已知技术债**，不是可选项。触发时点取决于 Spring Boot 3.5.x 的 EOL 日期（当前未核实）。范围包括 Jackson 2→3 包名重命名、Spring Framework 6→7、Tomcat 10→11。作为框架的一次大版本升级，按第七章流程走，并向业务方提供 OpenRewrite 迁移脚本。

***

## 十一、主要风险与应对

AI 自主测试存在误报/漏报的可能，尤其是纯视觉判断类场景，应对方式是坚持结构化断言（UI+DB 双重校验）加证据留存，早期保留人工抽查环节，不追求一步到位的完全自动化信任。

多个 worktree 同时运行会带来本地机器或 CI 资源消耗的成倍增长，应对方式是数据库/缓存类重资源共享实例、只对应用服务做真隔离，并考虑给闲置环境加自动回收机制。

插件化 SPI 接口一旦被多个业务方依赖，本身也需要走版本治理，不能随意变更方法签名，否则会把"可插拔"变成新的耦合点，应对方式是 SPI 接口本身纳入 framework-core 的兼容性承诺范围。

**MySQL 5.7 的双层无补丁风险**：5.7 服务端自 2023-10-31 EOL 后无安全补丁；而唯一官方支持 5.7 的驱动 Connector/J 8.2.0 停留在 2023-10-25，同样近三年无补丁。使用 5.7 的业务方实际承担的是**两层**无补丁风险。框架能做的只是保证应用兼容性与安全默认值，无法替业务方消除这个敞口。此外，整个生态（连接池、Testcontainers 镜像、监控 agent、可观测性工具）都在按"5.7 已终结"演进，后续会持续遇到同类问题。

**国产化数据库的兼容性不可穷举验证**：Tier 2 数据库因授权与镜像问题无法纳入 CI，且其 MySQL 兼容通常是子集而非超集。应对方式是 2.3.1 的保守语法基线 + 5.5 的自检工具 + 明确的分层支持矩阵，而不是承诺"全面兼容"。

**Spring Boot 3.x→4.x 迁移债**：选择 3.5.x 换取 AI 语料充沛与 Jackson 2 稳定性，代价是未来必然要还的大版本迁移。应对方式是阶段 6 已在路线图中预留，且 Owner 需持续跟踪 3.5.x 的 EOL 时点——**该日期目前未核实，是本方案唯一的开放技术问题**。

**前端与 Vben 上游断开的维护成本**：选择独立演进后，Vben 的 bugfix 与安全修复不再自动获得，Vue / Vite / Element Plus 生态的跟进完全由框架团队承担。应对方式是 7.1 中已明确列为 Owner 职责，但需在人力投入上如实评估——这是一笔持续性成本，不是一次性的。

**多仓拓扑的联调摩擦**：按模块细分多仓会显著提高跨仓改动（尤其是 SPI 变更）的成本，并可能削弱 AI Agent 获取完整上下文的能力。应对方式是 3.1.1 的 `repos.yml` + 统一拉取脚本 + 组织级 `CLAUDE.md`；若实践中证明摩擦过大，按第七章流程重新评估是否收敛为更少的仓库。

工具能力再完善，如果没有组织层面的治理跟进，整套体系依然会退化成"能力有但没人守规矩"。这一点需要在项目启动时就明确框架 Owner 角色和基本的协作规范，而不是等问题出现了再补救。

***

## 附录 A：版本修订说明

### v0.5（本次）

1. **新增第九章「业务方接入路径」**，原第九、十章顺延为第十、十一章。补的是一个结构性缺口：前八章描述框架如何构造，但"框架交付出去之后业务方怎么用"从未被当作设计对象，而它恰恰是目标 #1、#2、#5 的最终检验。
2. **发现并记录前端分层的不对称**：系统管理的后端已收回 `framework-system-starter`，前端页面（实测 1,376 行）却仍留在应用层，导致框架修复无法到达业务方。决定新增 `@describeadmin/system-ui`（9.3.1）。
3. **补齐 4.1 未回答的问题**——业务方的应用外壳从何而来。决定由 `npm create @describeadmin/app` 生成，并如实记录"外壳不会自动升级"这一代价（9.3.2）。
4. **明确 codegen 的定位与交付形态**：独立成仓的依据是依赖方向；交付形态为 Maven 插件（主）+ fat jar（辅）；并规定其绝不作为业务方运行时依赖（9.4）。
5. **接入不靠文档靠模板**：三个已实测的接入坑（发现 ②⑥⑧）改由 `describeadmin-archetype` 固化（9.2.2）。
6. **4.3 前端版本表按 Vben 5.7.0 实际 catalog 修正**——该修正已在正文标注为 v0.5，此前未在本附录登记，此处补记。

### v0.4

本次修订的性质与前几次不同：**v0.4 是第一个所有版本号都经过权威源实际核验的版本**（Maven Central 仓库本体、npm registry 本体、MySQL 官方文档），核验明细见 `VERSION_BASELINE.md`。核验推翻了 v0.3 的多处结论。

**被证伪的 v0.3 结论：**

1. **"`mysql-connector-j`（8.x/9.x）仍然兼容 5.7 服务端"—— 错误。** 逐版本核对官方 Release Notes：8.2.0（2023-10-25）是最后一个声明 "5.7 and later" 的版本，自 8.3.0 起改为 "8.0 and later"。这直接推翻了 v0.3 的 2.3 节。
2. **"Vben 的** **`packages/`** **可作为 npm 包依赖使用"—— 前提不成立。** Vben 根 `package.json` 为 `private: true`，内部包均未发布到 npm。这推翻了 v0.3 的 4.1 节。
3. **Spring Boot 版本认知再次落后。** v0.2 曾把 3.x 修正为 4.x；核验发现当前 GA 实为 4.1.0（2026-06-10），4.0.x 已进入退役期。但综合评估后 v0.4 **主动选择回到 3.5.16**，理由见 2.2.1——这不是"跟不上版本"，而是基于 AI 语料充沛度的有意取舍。
4. **Spring Security 版本写为 7.0.x —— 不准确**（Spring Boot 4.1 实际管理 7.1.0）。因改用 3.5.16，此项已改为 6.5.11。
5. **`mybatis-plus-spring-boot4-starter`** **确实存在** —— v0.3 此条正确。（核验过程中 `search.maven.org` 曾返回 numFound=0，属该索引陈旧导致的假阴性，已改用 repo1 作为唯一版本事实来源。）

**结构性调整：**

1. **2.3 节完全重写**，拆分为"SQL 语法基线（框架责任，不可下放）"与"数据库/驱动选择（业务方责任，框架不干预）"。v0.3 把两者捆在一起，是导致错误工程约束的根源。新增分层支持矩阵与数据库兼容性自检工具。
2. **新增 1.1 节业务场景约束**，明确国产化数据库场景，这是 2.3 节全部设计的来源。
3. **3.3 节代码生成器优先级调整**：YAML/DSL 由"后续演进"提前为 v1 主输入形态，理由是国产化库的 `information_schema` 差异与业主环境不可直连。
4. **前端 UI 库由 Ant Design Vue 改为 Element Plus**，并澄清 v0.3 的一处理解偏差（Vben 不自带业务组件库，`apps/` 层必须三选一）。改选理由是维护活跃度，非设计语言——v0.3 关于 ADV 更贴近政务视觉语言的判断是成立的。
5. **路线图修复依赖环**：双版本 CI 矩阵由阶段 3 提前至阶段 0；新增阶段 -1（Walking Skeleton）与阶段 6（3.x→4.x 迁移）。
6. **目标 #2 补齐交付物**：`CLAUDE.md`、编码规范、模块模板明确列入阶段 0。
7. **明确仓库拓扑**（按模块细分多仓）与**命名空间**（GitHub 组织 `describeadmin`、groupId `io.github.describeadmin`、npm `@describeadmin`），三者标识符统一无连字符。
8. **第十一章新增五条风险**：5.7 双层无补丁、国产化库不可穷举验证、3.x→4.x 迁移债、前端独立演进成本、多仓联调摩擦。
9. **Java 版本策略修正（新增 2.2.2）**：v0.3 把 Java 21 写成运行时要求，核验后确认 Spring Boot 3.5.16 的实际基线是 **17**。改为"最低 17、构建用 21、编译目标 `release=17`"，业务方 17+ 即可使用。同时引入 `maven-toolchains-plugin` 解决多 JDK 共存问题。
10. **主键策略修正（2.3.1）**：改为**默认数据库自增、可配置切换雪花 ID**。本方案定位为中小型单体项目、不涉及应用层分布式，自增在单机 MySQL 上索引局部性与运维可读性更优；同时保留配置项以覆盖多地数据汇总、跨库迁移、分布式数据库等场景。

### v0.3

1. Java 版本确认为 21（LTS）。*（v0.4 注：核验后确认 Spring Boot 3.5.16 的最低要求是 Java 17，21 为建议而非门槛；已改为"最低 17、构建 21、编译目标 17"，见 2.2.2。）*
2. MySQL 5.7 从"兼容目标"升级为"强制门禁"。*（v0.4 注：该升级当时的成本评估——"只是给 SQL 写法和测试范围加几条约束"——已被证伪，见附录 A v0.4 第 1、6 条。）*
3. 附录 B 由"待确认事项清单"改为"技术选型确认状态"汇总表。

### v0.2

1. 后端框架版本由误写的 3.x 修正为 4.1.x。*（v0.4 注：核验后确认当时的 GA 实为 4.1.0；但 v0.4 基于 AI 语料考量主动选择 3.5.16，见 2.2.1。）*
2. 补充 MySQL 5.7 兼容的工程约束。
3. 数据库、鉴权底座、前端 UI 库、配置中心、生产部署形态拍板。
4. 明确按开源方式运作，发布至 Maven Central 与 npm 公共仓库。
5. 明确面向中小项目、单机或少量服务器部署，不做微服务拆分。

## 附录 B：技术选型确认状态

| 事项                           | 结论                                                                                                                  | 核验状态                    |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------- | ----------------------- |
| 组织 / 命名空间                    | `describeadmin`；groupId `io.github.describeadmin`，Java 包名 `io.github.describeadmin.*`，npm 组织 `@describeadmin`（已申请） | ✅ 全部落地                     |
| Java 版本                      | 最低 **17**，构建用 21，`maven.compiler.release=17`                                                                        | ✅ 已核验（SB 3.5.16 基线为 17） |
| 主键策略                         | 默认数据库自增（`IdType.AUTO`），可配置切换雪花 ID                                                                                   | 已确认                     |
| Spring Boot 版本               | **3.5.16**                                                                                                          | ✅ 已核验                   |
| Spring Security              | 6.5.11                                                                                                              | ✅ 已核验                   |
| Jackson                      | 2.21.4                                                                                                              | ✅ 已核验                   |
| ORM                          | MyBatis-Plus 3.5.17（boot3 starter）                                                                                  | ✅ 已核验                   |
| 数据库                          | 由业务方决定；框架承诺 SQL 语法基线 + 分层支持矩阵                                                                                       | 已确认                     |
| JDBC 驱动                      | 由业务方声明；框架默认值 `mysql-connector-j:8.2.0`（5.7-safe，可覆盖）                                                                | ✅ 已核验                   |
| 仓库拓扑                         | 按模块细分多仓 + `repos.yml`                                                                                               | 已确认                     |
| 前端脚手架                        | Vben Admin 5.7.0，一次性取材后独立演进                                                                                         | ✅ 已核验                   |
| 前端 UI 组件库                    | **Element Plus 2.14.x**                                                                                             | ✅ 已核验                   |
| 配置中心                         | 不引入                                                                                                                 | 已确认                     |
| 生产部署形态                       | 单体 + Docker Compose，不引入 K8s                                                                                         | 已确认                     |
| 组件发布方式                       | Maven Central + npm 公共仓库（开源）                                                                                        | 已确认                     |
| **Spring Boot 3.5.x EOL 日期** | **未知**                                                                                                              | ⚠️ **未能核实，需人工查证**       |

后续如果实施过程中出现需要重新评估的情况，按第七章的版本治理流程走变更，而不是私下改动。

## 附录 C：版本核验方法

所有版本事实以下列权威源为准，**不采信搜索引擎摘要、聚合站点或记忆**：

- Maven 制品：`https://repo1.maven.org/maven2/**/maven-metadata.xml`（Central 仓库本体）
- 依赖管理版本：`spring-boot-dependencies-<version>.pom` 实际内容
- npm 包：`https://registry.npmjs.org/<pkg>`（registry 本体）
- MySQL 驱动兼容性：`dev.mysql.com` 官方 Release Notes 逐版本原文
- 上游仓库结构：`raw.githubusercontent.com` 实际文件内容

> ⚠️ **已知不可用源**：`search.maven.org/solrsearch` 索引已陈旧（最新仅到 Spring Boot 3.5.3），并会对实际存在的制品返回 numFound=0（假阴性）。任何版本核查不得使用该源。

详细核验记录见同目录 `VERSION_BASELINE.md`。
