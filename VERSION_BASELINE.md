# 版本基线表（Step 0 核验结果）

**核验日期**：2026-08-19
**状态**：v3 —— 六项决策已全部落定（见第一节）；所有冲突项均已闭环，仅余一条待人工查证（见第五节）
**配套文档**：`develop_plan.md` v0.4

**核验方法**：只采信权威源，不依赖搜索索引或记忆
- Maven：`https://repo1.maven.org/maven2/**/maven-metadata.xml`（Central 仓库本体）
- npm：`https://registry.npmjs.org/<pkg>`（registry 本体）
- 依赖管理版本：`spring-boot-dependencies-<v>.pom` 实际内容
- MySQL 驱动兼容性：`dev.mysql.com` Connector/J Developer Guide
- Vben 结构：`raw.githubusercontent.com/vbenjs/vue-vben-admin/main/**`

> ⚠️ `search.maven.org/solrsearch` 索引已陈旧（最新只到 Spring Boot 3.5.3），且对
> `mybatis-plus-spring-boot4-starter` 返回 numFound=0，是**假阴性**。版本核查一律以 repo1 为准。

---

## 一、已确认的决策

| # | 决策 | 结论 |
|---|---|---|
| 1 | Spring Boot 基线 | **3.5.16**（3.5.x 线） |
| 2 | 前端 UI 库 | **Element Plus**（Vben `apps/web-ele`） |
| 3 | 前端框架复用方式 | **一次性取材后独立演进**（fork Vben 5.7.0 快照，改造为自有 scope 的 npm 包并自行维护，与上游断开） |
| 4 | 数据库与 JDBC 驱动 | **由业务方声明**；框架不引入传递依赖，`framework-bom` 提供 5.7-safe 默认值 `8.2.0`（可覆盖）；框架只承诺 SQL 语法基线 + 分层支持矩阵 |
| 5 | Java 版本策略 | 最低 **17**、构建用 **21**、`maven.compiler.release=17`；`maven-toolchains-plugin` 管理多 JDK |
| 6 | 主键策略 | **默认数据库自增**（`IdType.AUTO`），可配置切换雪花 ID |

### 决策 1 的依据：三条线对比

| | **3.5.16（选定）** | 4.0.7 | 4.1.0 |
|---|---|---|---|
| Jackson | **2.21.4**（`com.fasterxml.*`）✅ | 3.1.4（`tools.jackson.*`）❌ | 3.1.4 ❌ |
| 补丁数 | 16 ✅ | 7 | **0** ⚠️ |
| 最新补丁发布 | **2026-06-25** | 2026-06-10 | 2026-06-10 |
| AI 训练语料 | 充沛 ✅ | 稀薄 ❌ | 稀薄 ❌ |
| 管理的 mysql 驱动 | 9.7.0（需覆盖） | 9.7.0（需覆盖） | 9.7.0（需覆盖） |
| 线的状态 | 活跃打补丁 | **退役期**（4.0.7 与 4.1.0 同日发布，之后 10 周无 4.0.8） | current |

**排除 4.0.x 的理由**：它承担了 4.x 的全部代价（Jackson 3 迁移、Spring Framework 7、Tomcat 11、AI 语料稀薄），
却不是 4.x 的当前线，已进入退役期。对长期演进的平台是最差选项。

**选择 3.5.x 而非 4.1.0 的理由**：方案目标 #2 是"面向 AI 编程"，4.x 语料稀薄会**持续**侵蚀这一核心卖点；
而 3.x→4.x 迁移债是**一次性、可计划、有 OpenRewrite 官方脚本兜底**的。用一次可计划的迁移换掉日常持续的 AI 出错率。

> 📌 必须记入方案第十章：3.x→4.x 迁移（Jackson 2→3 包名重命名、Spring Framework 6→7、Tomcat 10→11）
> 是**已知的、必然要还的技术债**，应在路线图中预留独立阶段，而非等被动触发。

---

## 二、锁定基线

### 后端（Spring Boot 3.5.16 线）

| 组件 | 锁定版本 | 来源 |
|---|---|---|
| Java（最低） | **17** | `spring-boot-starter-parent-3.5.16.pom` 的 `<java.version>17</java.version>`；`spring-boot-3.5.16.jar` MANIFEST 的 `Build-Jdk-Spec: 17` |
| Java（构建） | 21 | 本机已装 `ms-21.0.12`（见第六节） |
| `maven.compiler.release` | **17** | 使业务方 17+ 即可使用；理由见方案 2.2.2 |
| Spring Boot | **3.5.16** | repo1，2026-06-25 发布 |
| Spring Framework | 6.2.19 | 由 spring-boot-dependencies 3.5.16 管理 |
| Spring Security | 6.5.11 | 同上 |
| Jackson | 2.21.4 | 同上（`com.fasterxml.jackson.*`） |
| Hibernate | 6.6.53.Final | 同上 |
| Tomcat | 10.1.55 | 同上 |
| Lettuce | 6.6.0.RELEASE | 同上 |
| JUnit Jupiter | 5.12.2 | 同上 |
| Testcontainers | 1.21.4 | 同上 |
| Logback / SLF4J | 1.5.34 / 2.0.18 | 同上 |
| MyBatis-Plus | **3.5.17**（`com.baomidou:mybatis-plus-spring-boot3-starter`） | repo1，2026-07-08 |
| MySQL JDBC | **由业务方声明**；`framework-bom` 默认值 **8.2.0**（5.7-safe，可覆盖） | 见冲突 A |

### 前端（Vben Admin 5.7.0 + Element Plus）

| 组件 | 版本 | 说明 |
|---|---|---|
| Vben Admin | 5.7.0 | GitHub 源码，**未发布 npm**，见冲突 B |
| 起点应用 | **`apps/web-ele`** | 官方三选一之一 |
| Element Plus | ^2.14.3（catalog）／ npm latest 2.14.4 | 最后发布 2026-08-07，活跃 |
| Vue | ^3.5.40（catalog）／ npm latest 3.5.41 | |
| Vite | ^8.2.1 | |
| TypeScript | ^6.0.3（Vben catalog；npm latest 已 7.0.2） | Vben 落后一个大版本 |
| Tailwind CSS | ^4.3.3 | Vben 内核样式基础 |
| reka-ui | ^2.10.1 | `@vben-core/shadcn-ui` 的无样式组件原语 |
| pinia / vue-router | ^4.0.2 / ^5.2.0 | |
| Node / pnpm | node `^22.18.0 \|\| ^24.12.0`，pnpm `>=11`（pnpm@11.16.0） | Vben 5.7.0 engines 约束 |

---

## 三、冲突与处置

### ✅ 冲突 A：MySQL 5.7 与 JDBC 驱动（**已决策：拆分框架责任与业务方责任**）

方案 2.3 节称"`mysql-connector-j`（8.x/9.x 系列）仍然兼容 5.7 服务端"——**错误**。
逐版本核对官方 Release Notes 原文：

| Connector/J | 官方原文 | 发布日期 | 5.7 |
|---|---|---|---|
| 8.0.33 | "suitable for use with MySQL Server versions 8.0 and 5.7" | 2023-04 | ✅ |
| 8.1.0 | "can be used against MySQL Server version 5.7 and later" | 2023-07 | ✅ |
| **8.2.0** | "can be used against MySQL Server version 5.7 and later" | **2023-10-25** | ✅ **最后一个** |
| 8.3.0 | "can be used against MySQL Server version 8.0 and later" | 2024-01-15 | ❌ |
| 8.4.0 | "can be used against MySQL Server version 8.0 and later" | 2024-04-27 | ❌ |
| 9.x / 26.7 | "supports MySQL 8.0 and up" | — | ❌ |

> 📌 更正记录：本文档 v1 曾称"8.4.0 是最后一条官方支持 5.7 的线"，系由"8.1.0 支持 5.7 and later"
> 外推所得，且误以为 8.4 作为 LTS 版本会更保守，**两项均未经验证，结论错误**。实际转折点是 8.3.0。

**生态信号**：Oracle 在 8.3.0（2024-01）移除 5.7 支持，距 MySQL 5.7 EOL（2023-10-31）仅两个多月。
整个生态按"5.7 已终结"演进，后续在连接池、Testcontainers 镜像、监控 agent、可观测性工具上会持续遇到同类问题。

**Spring Boot 3.5.16 / 4.0.7 / 4.1.0 三条线全部管理 `mysql-connector-j:9.7.0`**，均需显式覆盖。

#### 处置选项与最终决策

| | 方案 | 优点 | 代价 |
|---|---|---|---|
| ① | pin `com.mysql:mysql-connector-j:8.2.0` | 声明为 "5.7 and later"，**单驱动即可覆盖 5.7 与 8.4 双线 CI**，工程最简 | 驱动近 3 年无安全补丁；与 5.7 服务端叠加成**两层无补丁** |
| ② | 改用 `org.mariadb.jdbc:mariadb-java-client:3.5.10`（2026-07-29，活跃维护） | 仍有安全补丁；官方称兼容 all MariaDB and MySQL server versions | 非 Oracle 驱动：URL scheme `jdbc:mariadb://`、`caching_sha2_password`、JSON 类型、时区处理均有行为差异；MyBatis-Plus 方言与分页插件按 Connector/J 验证，必须双线实测 |
| ③ | 直接用 8.4.0 / 9.7.0 | 无 | **不建议**：厂商已明确移出支持矩阵，与方案首要目标"生产级可靠性"直接冲突 |

#### ⚠️ 曾提出的上位问题及其解决

方案 v0.3 将 5.7 由"兼容目标"升级为"强制 CI 门禁"时，成本认知是其 2.3 节原话——
"不会拖累整体设计的先进性，只是给 SQL 写法和测试范围加了几条明确的约束"。**该成本评估已被证伪**。

但进一步讨论澄清了一个更关键的问题：**该问题的划分本身是错的**。v0.3 把"驱动能否连 5.7"与
"框架产出的 SQL 能否在 5.7 上跑"捆在同一节，才导致把一个本可下放的问题（驱动）当成了框架必须承担的约束。

**最终决策：按责任边界拆分，而非在三个驱动选项中二选一。**

| 事项 | 责任方 | 处置 |
|---|---|---|
| SQL 语法基线（框架 DDL、基类 SQL、生成器产出） | **框架** | 不可下放。以 MySQL 5.7 语法的**安全子集**为基线（国产化库的 MySQL 兼容通常是子集而非超集）；见方案 2.3.1 |
| 数据库版本与 JDBC 驱动 | **业务方** | 框架不指定，`framework-mybatis-starter` 不引入任何驱动传递依赖，与 `spring-boot-starter-jdbc` 的做法一致；见方案 2.3.2 |
| 默认值安全性 | 框架 | `framework-bom` 将 `mysql-connector-j` 管理版本压回 **8.2.0**（5.7-safe，可覆盖）。⚠️ **该默认值对继承 `spring-boot-starter-parent` 的业务方无效**——已由 Walking Skeleton 实测证伪，见第七节发现 ②；业务方必须显式声明 |
| 承诺边界 | 框架 | 分层支持矩阵 Tier 1（MySQL 5.7 / 8.4，CI 必过）／ Tier 2（达梦、金仓、OceanBase，自检工具 + 文档）／ Tier 3（不承诺） |

上表中前述选项①的 8.2.0 保留为**框架默认值**而非强制 pin；选项②（MariaDB Connector/J）不采用，
因其行为差异需大量实测才能建立信心，而在"驱动由业务方决定"的新划分下已无必要；选项③维持不采用。

**业务场景背景**（v0.4 补入方案 1.1 节）：主要承接政务项目，业主数据库不由我方选择——
可能是宣称兼容 MySQL 5.7 的国产化库（达梦、金仓、OceanBase 等），也可能就是 MySQL 5.7 本身。
这正是"驱动必须下放"的根本原因：各国产化库有各自完全不同的驱动坐标，框架无法也不应钉死其中任何一个。

| 数据库 | 驱动坐标 | 核验到的最新版本 |
|---|---|---|
| OceanBase | `com.oceanbase:oceanbase-client` | 2.4.18 |
| 达梦 | `com.dameng:DmJdbcDriver18` | 8.1.3.140 |
| 人大金仓 | `cn.com.kingbase:kingbase8` | 9.0.1.jre7 |
| openGauss | `org.opengauss:opengauss-jdbc` | 7.0.0-RC3-og |
| GaussDB | `com.huaweicloud.gaussdb:gaussdbjdbc` | 506.0.0.b058-jdk7 |

### ✅ 冲突 B：Vben Admin 不发布 npm 包（**已决策**）

- `vue-vben-admin` 根 `package.json`：`"private": true`
- 内部包全部以 `workspace:*` 互相引用；`@vben-core/shadcn-ui`、`@vben/common-ui` 在 npm 上 **404**
- npm 上的 `@vben/utils@1.0.1`、`vben@1.0.11` 是**其他发布者的同名无关包**，不可使用

方案 4.1 节"`packages/` 发布为 npm 包、`apps/` 只消费依赖"在 Vben 上**没有现成路径**。
**决策**：采用「一次性取材后独立演进」——将 Vben 5.7.0 作为起点快照 fork，把 `packages/` 改造为自有 scope 的
可发布 npm 包（如 `@<组织>/ui`、`@<组织>/layouts`、`@<组织>/access`），此后与上游断开。
理由：与已选的「按模块细分多仓」拓扑兼容（跟随上游需保持单 monorepo 才能 merge），
且使方案 4.1 节的「依赖化 + 版本治理」真正成立。
**承接的成本**：Vben 上游后续更新与本项目无关，`packages/` 的全部维护责任由框架团队承担，需在第七章治理角色中明确。

### ✅ 冲突 C：Jackson 3.x —— **已因降级解决**

3.5.16 管理 Jackson 2.21.4，包名仍为 `com.fasterxml.jackson.*`。无需迁移。

### ✅ 冲突 D：Spring Boot 起步线成熟度 —— **已因降级解决**

3.5.16 累计 16 个补丁版本。

### ✅ 风险 E：Ant Design Vue 停更 —— **已因改用 Element Plus 规避**

三个官方 UI 适配应用的维护活跃度实测：

| Vben 应用 | UI 库 | npm latest | 最后发布 | 状态 |
|---|---|---|---|---|
| `apps/web-antd` | Ant Design Vue | 4.2.6 | **2024-11-11**（21 个月前） | 停更 |
| **`apps/web-ele`（选定）** | Element Plus | 2.14.4 | 2026-08-07 | 活跃 |
| `apps/web-naive` | Naive UI | 2.45.0 | 2026-08-16 | 活跃 |

> 澄清方案 4.2 节的一处理解偏差：Vben Admin **不自带业务组件库**。其内核 `@vben-core/*` 基于
> `reka-ui` + Tailwind，确实是 UI 库无关的（只提供布局外壳、权限、路由、偏好设置）；但 `apps/` 层
> 官方并列提供 antd / element-plus / naive 三个版本，**必须三选一**——实际业务页面的表格、表单、
> 弹窗均来自所选 UI 库。因此方案写 Ant Design Vue 并无错误，只是漏掉了两点：
> ①UI 库在 Vben 中是**可替换的适配层**，不是不可逆的架构决策；②ADV 是三者中唯一停更的。
> 方案 4.2 节"ADV 设计语言更贴近政务场景"的判断成立，Element Plus 是同一视觉谱系中仍在活跃维护的替代。

---

## 四、待 Walking Skeleton 实测的事项

1. MyBatis-Plus 3.5.17（boot3 starter）与 Spring Boot 3.5.16 的实际兼容性
2. Connector/J **8.2.0**（框架默认值） 在 Java 21 + Spring Boot 3.5.16 下的可用性，含 `mysql_native_password`（5.7）与 `caching_sha2_password`（8.0+）两种鉴权
3. Element Plus 2.14.x 在 Vue 3.5.40 + Vite 8 + Vben 5.7.0 下的构建与类型兼容性
4. ~~Vben 要求的 node `^22.18 || ^24.12` + pnpm 11 与团队现有环境的一致性~~ —— ✅ **已验证通过**，见第六节

## 五、未能核实、需人工确认

- **Spring Boot 3.5.x 的 OSS 支持终止日期**：`spring.io` 支持时间线页面与 `endoflife.date` 在本环境均不可达。
  间接证据表明该线仍活跃（3.5.16 于 2026-06-25 发布，晚于 4.1.0 GA 的 2026-06-10），但**精确 EOL 日期未经证实**，
  建议人工查证后再最终定档，因为它直接决定 3.x→4.x 迁移债的偿还时点。
- 观察项：截至核验时点，Spring 生态最新制品集中在 2026-06-08 ~ 06-25，此后约 10 周无新发布
  （`spring-core` 7.0.8 / `spring-security-core` 7.1.0 交叉验证一致，非单点数据陈旧）。原因未明，建议复核。

---

## 六、本机开发环境实测（2026-08-19）

| 工具 | 版本 | 状态 |
|---|---|---|
| node | v24.19.0 | ✅ 满足 Vben `^22.18.0 \|\| ^24.12.0` |
| pnpm | 11.21.0 | ✅ 满足 Vben `>=11` |
| mvn | 3.9.16 | ✅ |
| gpg | 2.4.9 | ✅ |
| git | 2.55.0.windows.3 | ✅ |
| gh | 未安装 | ⚠️ 非必需；Central Portal 验证仓库可用网页创建 |

**本机已安装的 JDK**（`C:\Users\Jeffr\.jdks\`）：

| 目录 | 版本 | 用途 |
|---|---|---|
| `corretto-11.0.31` / `corretto-11.0.32` | 11 | 当前 `PATH` 上的默认 java，**不满足**框架要求 |
| `ms-17.0.20` | 17 | 满足最低要求，可用于验证 `release=17` 的产物 |
| **`ms-21.0.12`** | **21** | **框架构建用 JDK** |

已实测：指定 `JAVA_HOME=C:/Users/Jeffr/.jdks/ms-21.0.12` 后 `mvn -v` 正确报告
`Java version: 21.0.12, vendor: Microsoft`。

> 由于 `PATH` 上的默认 java 是 11，**不能依赖默认环境构建**。阶段 0 需交付 `toolchains.xml`
> 与 `maven-toolchains-plugin` 配置，使构建不依赖 `PATH` 与手工 `JAVA_HOME`（见方案 2.2.2）。

---

## 七、Walking Skeleton 实测发现（2026-08-19，后端骨架阶段）

三条假设已验证，并发现两个**只有真实构建才会暴露**的问题。

### ✅ 已验证通过

| # | 假设 | 结果 |
|---|---|---|
| 1 | MyBatis-Plus 3.5.17（boot3 starter）与 Spring Boot 3.5.16 兼容 | 通过（需补一个依赖，见发现 ① ） |
| 2b | `release=17` 策略成立 | 通过：toolchains 选中 `ms-21.0.12` 编译，产物 class file `major version: 61`（Java 17） |
| 4 | node / pnpm 满足 Vben engines | 通过：node 24.19.0 / pnpm 11.21.0 |

### 🔍 发现 ①：`PaginationInnerInterceptor` 已迁出 `mybatis-plus-extension`

MyBatis-Plus 自 **3.5.9** 起将 JSqlParser 改为可选依赖，`PaginationInnerInterceptor`
随之从 `mybatis-plus-extension` 迁移到独立制品 **`com.baomidou:mybatis-plus-jsqlparser`**。

实测依据（本地仓库 jar 内容比对）：

| 制品 | 是否含 `PaginationInnerInterceptor.class` |
|---|---|
| `mybatis-plus-extension-3.5.3.x.jar` | ✅ 含 |
| `mybatis-plus-extension-3.5.17.jar` | ❌ 不含 |
| `mybatis-plus-jsqlparser-3.5.17.jar` | ✅ 含 |

**症状**：只引 `mybatis-plus-spring-boot3-starter` 时报
`找不到符号: 类 PaginationInnerInterceptor`。
**处置**：`framework-mybatis-starter` 显式增加 `com.baomidou:mybatis-plus-jsqlparser` 依赖，
传递引入 `jsqlparser:5.2`。

> 附带风险，待阶段 3 验证：分页的 count 查询由 JSqlParser 解析 SQL 生成。
> 国产化数据库上的方言写法能否被 JSqlParser 正确解析，需要纳入兼容性自检工具的检查项。

### 🔴 发现 ②：BOM 的驱动默认值对继承 `spring-boot-starter-parent` 的业务方【无效】

**Maven 的 `dependencyManagement` 优先级：从父 POM 继承的条目 > 以 `import` 引入的 BOM 条目。**

而绝大多数 Spring Boot 业务工程都继承 `spring-boot-starter-parent`（其中已管理
`mysql-connector-j:9.7.0`），因此 `framework-bom` 压回的 8.2.0 会被业务方的父 POM 直接盖掉。

实测（`sample-app` 模拟业务方视角，三种布局）：

| 业务方工程布局 | `mysql-connector-j` 实际解析 |
|---|---|
| 继承 `spring-boot-starter-parent` + import `framework-bom` | ❌ **9.7.0**（不支持 5.7） |
| 同上 + 自身 `<properties>` 写 `<mysql.version>8.2.0</mysql.version>` | ✅ 8.2.0 |
| 不继承 `spring-boot-starter-parent`，只 import `framework-bom` | ✅ 8.2.0 |

**影响**：直接推翻方案 2.3.3 初稿"让默认路径是安全的"这一论断。已修订，见 develop_plan.md 2.3.3 的实测修正块。

**处置**：①业务方接入文档必须显著位置写明需显式声明；②框架提供可选 enforcer 规则，
目标库为 5.7 且解析到的驱动 ≥ 8.3.0 时构建失败——把文档约定变成构建期强制。

> 这两条都印证了阶段 -1 的价值：靠读文档和推理发现不了，必须真实构建一次业务方视角的工程。

### 🔧 顺带修正的设计缺陷（构建期暴露）

- **父 POM 与 BOM 的 import 环**：初版让 `framework-parent` import `framework-bom`，
  而后者的 parent 又是前者，Maven 直接报 `dependencies ... form a cycle` 并中止。
  已改为：上游 BOM 与框架模块的管理条目全部声明在 `framework-parent`，
  `framework-bom` 自身 `dependencyManagement` 留空、通过继承导出。
  已用 `help:effective-pom` 与 `sample-app` 双向验证该导出确实生效。

### 第二轮实测（基类 + 数据库双线 + JDBC 连通性）

#### ✅ 假设 2 已验证：Connector/J 8.2.0 + JDK 21 → 两条 Tier 1 线均可用

实测两个容器的默认鉴权插件确实不同，覆盖了目标场景：

| 目标库 | 实际 server 版本 | 默认鉴权插件 | 连接 | 中文读写 | `LocalDateTime` 往返 | 自增主键回填 |
|---|---|---|---|---|---|---|
| `mysql:5.7` | 5.7.44 | `mysql_native_password` | ✅ | ✅ | ✅ | ✅ |
| `mysql:8.4` | 8.4.11 | `caching_sha2_password` | ✅ | ✅ | ✅ | ✅ |

连接串：`useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Shanghai&characterEncoding=utf8`。
两库 `@@collation_server` 均为 `utf8mb4_general_ci`（显式声明生效，未被服务器默认值干扰）。

#### ✅ 假设 2b 已验证：`release=17` 产物在 JDK 17 上真实运行

用 `ms-17.0.20` 加载 `framework/*/target/*.jar` 实际执行 `Result` / `PageQuery` 夹紧 /
`PageResult` 分页计算 / `LoginUser` / `AuthRequest` / `BaseEntity` 加载，全部正常。
2.2.2 的「业务方 Java 17+ 即可使用」承诺成立。

#### ✅ SQL 语法基线纪律有效

同一份 `schema-rbac.sql` + `seed-rbac.sql` 在 5.7 与 8.4 上结果完全一致：
`users=1 roles=1 menus=2 user_role=1 role_menu=2`。

#### 🔍 发现 ③：`IService` / `ServiceImpl` 已迁出 `mybatis-plus-extension`

| 类 | 旧路径（绝大多数资料与 AI 输出） | 3.5.17 实际路径 | 制品 |
|---|---|---|---|
| `IService` / `ServiceImpl` | `com.baomidou.mybatisplus.extension.service[.impl]` | `com.baomidou.mybatisplus.spring.service[.impl]` | `mybatis-plus-spring` |

与发现 ① 合计，MyBatis-Plus 3.5.x 后期做过两次拆分。**这两条直接放大了方案 2.2.1
所述的 AI 语料风险**——AI 会按旧包名生成代码且看起来完全合理。已写入 CLAUDE.md 3.6 作为强制约定。

#### 🔴 发现 ④：seed-job 字符集缺省导致中文静默损坏（计数校验查不出）

`seed-job` 最初直接调用 `mysql ... < seed.sql`，CLI 使用其默认字符集导入，
中文被写坏。但**行数校验全部正确**，环境看上去健康。

暴露方式：JDBC 读取 `sys_user.nickname` 与预期字面量比对为 `false`，
而同一连接下 JDBC 自己写入再读回却是 `true` —— 说明 schema 与 collation 均正确，
问题只在 CLI 导入环节。

**处置**：①三处 `mysql` 调用统一加 `--default-character-set=utf8mb4`；
②给 `seed-job` 增加**值断言**（比对 `nickname='超级管理员'`），编码坏了直接 `exit 1`。

> 教训（已反映到测试规范）：**计数断言不足以验证数据正确性**。这与方案 5.4 节
> "不能仅凭页面看起来正常就下结论"是同一类问题，只不过发生在数据层。
> 结构化测试用例的 `db` 断言应尽量比对具体值，而非只比对 `COUNT(*)`。

### 第三轮实测（sample-app 集成测试：运行时行为）

以业务方视角构建 `sample-app`（继承 `spring-boot-starter-parent`，只 import `framework-bom`），
用 Testcontainers 拉起真实 MySQL，覆盖此前只验证到编译期的运行时行为。

**结果：Tier 1 两条线各 14/14 全绿。**

| 验证项 | 5.7.44 | 8.4.11 |
|---|---|---|
| 审计字段自动填充（`AuditMetaObjectHandler`） | ✅ | ✅ |
| 主键自增回填（`IdType.AUTO`） | ✅ | ✅ |
| 分页插件 + count 查询正确（25 条取第 2 页） | ✅ | ✅ |
| `PageQuery` size 上限夹紧 | ✅ | ✅ |
| 逻辑删除（查询过滤 + 物理行保留） | ✅ | ✅ |
| 乐观锁（版本自增 + 过期版本更新失败） | ✅ | ✅ |
| 中文经 ORM 往返 | ✅ | ✅ |
| 种子数据中文完整性 | ✅ | ✅ |
| `AuthProvider` 自动收集 | ✅ | ✅ |
| 登录成功并带出角色/权限 | ✅ | ✅ |
| 认证失败不泄露账号是否存在 | ✅ | ✅ |
| 未知登录方式被拒绝 | ✅ | ✅ |
| `AuthUserLoader` 的 RBAC 三表 JOIN 在 5.7 子集下可用 | ✅ | ✅ |
| `@@collation_server` 为显式声明值 | ✅ | ✅ |

至此**假设 1（MyBatis-Plus 3.5.17 × Spring Boot 3.5.16）完整验证通过**——
不仅编译，运行时的拦截器链、元数据填充、方言生成全部正常。

#### 🔴 发现 ⑤：`spring.sql.init` 默认用平台编码读脚本，中文再次被静默写坏

与发现 ④ **同类但入口不同**：④ 是 docker-compose 的 `mysql` CLI，本次是 Spring 的
`spring.sql.init`。两者都默认使用**平台默认编码**（中文 Windows 上是 GBK）读取 UTF-8 的 SQL 文件。

暴露方式：`seedChineseIntact` 与 `loginSucceeds` 两个断言失败，实际值为 `超级管理` + 半个坏字符。
**行数断言依然全绿**。

**处置**：`spring.sql.init.encoding=UTF-8` 显式指定；surefire 增加
`-Dfile.encoding=UTF-8` 保证测试字面量与输出不受平台编码影响。

> 同一类错误在两个不同入口各犯一次，说明这不是偶然疏忽而是**系统性陷阱**：
> 任何"读取 SQL/数据文件"的环节都必须显式指定编码。已列入 CLAUDE.md 强制约定。

#### 🔍 发现 ⑥：业务方工程同样需要 toolchains 配置

`sample-app` 继承的是 `spring-boot-starter-parent`，不含 `maven-toolchains-plugin`，
构建时用了 `PATH` 上恰好存在的 JDK 11 去编译 `release=17`，直接报
**「不支持发行版本 17」**。

业务方开发机上普遍并存多个 JDK，会一模一样地踩到。
**处置**：`sample-app` 增加 `maven-toolchains-plugin`，且**刻意指定 JDK 17 而非 21**——
用最低支持版本构建业务工程，端到端证明方案 2.2.2 的承诺（业务方 Java 17+ 即可）成立。
该配置需作为业务方接入文档的必备章节。

> **2026-08-20 修正（第八轮）**：这条结论对**业务方工程**已作废，只对 `sample-app` 保留。
>
> 真实原因不是"业务工程需要 toolchains"，而是"Maven 当时跑在 JDK 11 上"。
> 而 Maven 跑在 17+ 本来就是硬要求（`spring-boot-maven-plugin:repackage` 加载不了），
> 一旦满足，`release=17` 就必然能编，toolchains 没有增量价值。
>
> 反过来它有明确的害处：业务方开发机上大多没有 `~/.m2/toolchains.xml`，
> 配了会以 `Cannot find matching toolchain` 直接打死构建——比它要防的坑更劝退。
> 因此 `describeadmin-archetype` 生成的工程**不带** toolchains 配置。
> `sample-app` 保留该配置，用途也随之变窄：它是框架团队"用最低支持版本 JDK 17 构建"
> 的兼容性验证载体，不是业务方该抄的模板。

### 第四轮（framework-system-starter：系统管理收回框架）

#### 架构修正：系统管理原先放错了层

方案 3.1 的 `framework-core` 四个模块全是【技术能力】（Web/安全底座/ORM 基类/工具），
**没有任何模块用于承载业务功能**；而方案阶段 1 的交付物明确包含"RBAC 权限模型、菜单管理"。
这个缺口导致 RBAC 最初被实现在 `sample-app` 里，等于**要求每个业务方自己实现一遍用户/角色/菜单**，
同时违反目标 #1（生产级）与目标 #5（可持续升级——落在业务仓库的代码框架永远修不了）。

**处置**：新增 `framework-system-starter`，把用户、角色、菜单、部门及登录接口收回框架；
RBAC 的 DDL 由 `framework-security-starter` 迁入（安全底座只提供认证契约，不该规定表结构）；
`sample-app` 退回为纯测试夹具，业务表换成明确属于业务域的 `biz_project`。

验证结果：`sample-app` 未写一行 RBAC 代码，`SystemModuleIT` 注入的全部 Bean 均来自
`io.github.describeadmin.system.*`。Tier 1 两条线各 **23/23 通过**。

#### 🔴 发现 ⑦：跨 starter 使用 `@ConditionalOnBean` 的顺序陷阱

`framework-security-starter` 的内置用户名密码登录带
`@ConditionalOnBean(AuthUserLoader.class)`，而该 Bean 由 `framework-system-starter` 提供。

`@ConditionalOnBean` **只检查当前已注册的 Bean 定义**，完全依赖自动配置的评估顺序。
security 若先于 system 被评估，条件不满足，内置登录方式被**静默跳过**——
编译、启动均无任何异常，直到调用登录才报「不支持的登录方式: password」。

**处置**：`FrameworkSystemAutoConfiguration` 声明
`@AutoConfiguration(before = FrameworkSecurityAutoConfiguration.class)`。

> 教训：跨模块的 `@ConditionalOnBean` 必须显式声明自动配置顺序。
> 该问题编译期毫无征兆，只有真实 Spring 上下文才暴露——又一次印证集成测试不可省。

#### 🔍 发现 ⑧：业务方的 `@MapperScan` 会屏蔽框架 Mapper 的自动扫描

业务方应用一旦声明 `@MapperScan("com.业务方...")`，MyBatis 的自动扫描即失效，
框架自己的 Mapper 不会被注册。

**处置**：`FrameworkSystemAutoConfiguration` 显式声明
`@MapperScan("io.github.describeadmin.system.mapper")` 与对应的 `@ComponentScan`，
框架为自己的组件登记扫描路径，业务方无需（也不应）关心。

#### 设计记录：树结构在内存构建，不使用递归 CTE

菜单树与部门树用 `TreeBuilder` 在内存组装。MySQL 8.0 的 `WITH RECURSIVE` 最直观，
但被 SQL 红线禁用（5.7 无此特性，部分国产化库亦不支持）。
菜单/部门数据量通常在百到千级，全量查询 + 内存组装的开销可忽略，
以此换取跨数据库确定性是划算的。数据量真正大到不可接受时应改用物化路径（`ancestors` 字段），
那同样只需基础 SQL。

孤儿节点（父节点不存在或已逻辑删除）会被提升为根而非静默丢弃——数据有问题时让它可见更利于排查。

### 第五轮（codegen v1：代码生成器）

独立仓库，**不依赖任何 framework-\* 模块**——生成器只产出源码文本，运行时不需要框架类。
这样它能独立于框架版本演进，也不必让业务方为跑生成器而拖进整个框架依赖树。

#### 设计要点

**SQL 红线固化在类型系统里。** `FieldType` 枚举刻意不提供 `timestamp` / `boolean` /
`json` / `double`，写了会在解析阶段报错并给出替代方案。结果是**生成器根本产不出违规 SQL**，
而不是靠使用者记得规范：

| 被排除 | 原因 | 替代 |
|---|---|---|
| `timestamp` | 2038 上限，自动更新语义各库不一致 | `datetime` |
| `boolean` | MySQL 中实为 `TINYINT(1)` 别名 | `flag` |
| `json` | 函数集在 5.7 与国产化库上差异大 | `text` + 应用层序列化 |
| `float`/`double` | 金额场景丢精度 | `decimal` |

**校验一次性报出全部错误**，每条指明位置与修法。生成器是 AI Agent 的主要接口之一，
"错误可操作"直接决定它能否自主用好——遇到第一个错就中断会让 AI 陷入"改一个跑一次"的循环。

**产出包含结构化端到端验收用例**（develop_plan.md 5.4 格式）。代码与验收用例一起生成，
AI Agent 拿到就能执行端到端验证，把目标 #2 与目标 #3 连起来，而非事后补测试。

#### 已验证

| 验证项 | 结果 |
|---|---|
| 生成的 DDL 在 MySQL 5.7 上实际执行 | ✅ 14 列 / 4 索引，中文注释完好，`collation=utf8mb4_general_ci`，时间列为 `datetime` |
| 生成的 4 个 Java 文件在真实框架依赖树下编译 | ✅（用 `mvn dependency:build-classpath` 取 sample-app 的 65 条依赖） |
| 生成的测试 Spec 是合法 YAML | ✅ 用 SnakeYAML `loadAll` 解析产物断言 |
| 单元测试 | ✅ 25/25 |

#### 🔴 发现 ⑨：Java 文本块剥离公共缩进，与 YAML 的缩进敏感性叠加会产出结构错乱的文件

用文本块拼装 YAML 时，编译器会剥离"偶然缩进"，导致嵌套层级丢失。首版生成的测试 Spec 中
`- action: fill` 掉到了顶格，同时 SQL 字面量用了双引号——嵌在双引号 YAML 标量里会提前终止字符串。

**两处都是"肉眼扫一遍看不出问题"的错误**，文件长得像合法 YAML，实际解析会失败或结构错误。

**处置**：
1. `TestSpecGenerator` 改为显式字符串拼接，缩进由代码直接控制，不用文本块
2. SQL 字面量统一单引号，整条 query 包成 YAML 单引号标量并做 `''` 转义
3. **新增测试：用 SnakeYAML 实际解析生成的 Spec**，断言步骤被解析为对象而非字符串

> 教训：**生成 YAML/JSON 这类格式敏感内容时，必须用真正的解析器验证产物**，
> 不能只做字符串包含断言——后者对结构错乱完全无感。
> 这与发现 ④⑤（字符集）同属一类：产物"看起来对"不等于"真的对"。

### 第六轮（frontend：Vben 取材、鉴权链路、系统管理页面）

#### 后端补齐：令牌与鉴权链路

前端接不上的根因是后端**没有任何凭证机制**：`/api/auth/login` 只返回 `LoginUser`，
其余接口也无人把守。补齐后的形态见 framework 仓库 `aebcd5d`。

**为什么选不透明令牌而不是 JWT**（这是一个会被反复质疑的决定，记在这里）：
管理后台的「禁用用户立即失效」「强制下线」是常规需求，而 JWT 一旦签发就无法在过期前收回，
要做这两件事仍得维护黑名单——复杂度并不低于直接用服务端存储，反而多一套签名依赖。
不透明令牌 + `TokenStore` SPI 则把部署形态差异（单机内存 / Redis / 落库留痕）全部吸收进接口，
换实现不影响任何上层代码。默认的 `InMemoryTokenStore` 有两条明确局限：
**重启即全部失效**、**不支持多实例**，单机部署可接受，写在类注释里。

顺带修掉两个既有缺陷：

| 缺陷 | 表现 |
|---|---|
| `AuditMetaObjectHandler` 被无参构造成 `CurrentUserProvider.NOOP` | `create_by` / `update_by` **永远为空**，而审计字段正是 BaseEntity 的卖点 |
| `/api/auth/menus` 的 `userId` 取自请求参数 | 任何登录用户都能读到别人的菜单树，是一个越权读取 |

前者的处置顺带把 `CurrentUserProvider` 从 mybatis-starter 移到 framework-common——
它是「谁在操作」这个跨切面契约，不属于 ORM。

#### 前端取材：一次性 fork 后独立演进

按方案 4.1 执行。保留 `packages/`（824 文件）、`apps/web-ele → apps/admin`、`internal/`、
`scripts/`；删除其余三个 UI 库版本、`playground`、`docs`、`backend-mock`、上游 `.github`。

**scope 改名只改包名，不改标识符**：`@vben/*` → `@describeadmin/*`、
`@vben-core/*` → `@describeadmin/core-*`（共 520 个文件），
而 `VbenButton`、CSS 类名 `vben-*` **一律不动**——上千处机械替换收益为零、风险不低，
保留前缀也让代码出处一目了然，与 MIT 署名要求同向。

**⚠️ 合并 scope 会打断上游的分层约束。** 上游用 `@vben` 与 `@vben-core` 两个 scope
天然隔离层级，eslint `no-restricted-imports` 的 `group: ['@vben/*']` 因此不会误伤
`@vben-core/*`。合并成单一 scope 后，`group: ['@describeadmin/*']` 会连 `core-*` 一起匹配，
把 `@core` 内部包之间的正常互相引用**全部误杀**。已补 `'!@describeadmin/core-*'` 否定规则，
并实测两个方向都对：正常的 core 互引不报错，真实越层引用仍会报错。

`apps/backend-mock` 刻意删掉：用 mock 开发前端，等于把前后端契约不一致的问题
全部推迟到联调阶段才暴露。本项目的前端从第一天起就打真实后端。

#### 🔴 发现 ⑩：方案 4.3 的前端版本表与 Vben 5.7.0 的实际 catalog 大面积不符

以 `pnpm-workspace.yaml` 的 catalog 与 `node_modules` 实测为准：

| 组件 | 方案 4.3 所写 | 实际 catalog | 实测安装 |
|---|---|---|---|
| Vue | `^3.5.40` | `^3.5.34` | 3.5.34 |
| Vite | `^8.2.1` | `^8.0.13` | 8.0.13 |
| Element Plus | `^2.14.3` | `^2.14.0` | 2.14.0 |
| Tailwind CSS | `^4.3.3` | `^4.3.0` | 4.3.0 |
| reka-ui | `^2.10.1` | `^2.9.7` | 2.9.7 |
| vue-router | `^5.2.0` | `^5.0.7` | 5.0.7 |
| **pinia** | **`^4.0.2`** | `^3.0.4` | 3.0.4 |
| TypeScript | `^6.0.3` | `^6.0.3` | 6.0.3 ✅ |

前七行全部偏高，其中 **pinia 连大版本都不对**（方案写 4.x，实际是 3.x，pinia 尚无 4.x）。
`^3.5.40` 这类范围与实测的 3.5.34 在语义上直接矛盾——说明这些数字不是从仓库读出来的。

`engines` 同样对不上：方案与 CLAUDE.md 写 pnpm `>=11`，
Vben 5.7.0 实际是 `"pnpm": ">=10.0.0"` + `packageManager: "pnpm@10.33.4"`。
我们已 fork 独立演进，故按自己的基线钉到 `>=11` / `pnpm@11.21.0`（本机 11.21.0 实测可用），
**但这是我们的选择，不是上游的事实**，两者不要混为一谈。

> 教训：**"来自上游的版本号"必须从上游仓库文件里读，不能从记忆或搜索结果里写。**
> 这与禁用 `search.maven.org/solrsearch` 是同一条纪律，只是换到了 npm 侧。

#### 🔴 发现 ⑪：`accessMode: 'backend'` 下前端静态路由模块完全不参与路由生成

`generateRoutesByBackend` 只消费接口返回的菜单树，`accessRoutes`（即
`router/routes/modules/*.ts`）**一条都不会被注册**。后果是：

- 上游默认的 `defaultHomePath: '/analytics'` 指向前端静态路由，登录后直接落到 404
- 页面显示的是「哎呀！未找到页面」，且因为不在 Layout 内，**侧边栏整个不出现**

故障表现极具误导性：菜单接口明明正确返回、直接访问 `/system/dept` 也正常，
唯独首页空白无菜单，很容易被误判成「菜单渲染坏了」而去查前端菜单组件。

**处置**：首页也由菜单表下发（seed 中补「工作台」目录 + 「概览」菜单），
`defaultHomePath` 改为 `/dashboard/workbench`。
这也更符合 backend 模式的本意——**所有**菜单都该来自同一份数据。

#### 清理上游演示内容（不是洁癖，是交付质量）

| 移除项 | 原因 |
|---|---|
| 登录页「选择账号」下拉 | 会把 `vben` / `admin` / `jack` 连同密码 `123456` 自动填进表单，等于在登录页公示测试账号 |
| 登录页滑块验证码 | 只在浏览器里校验、后端完全不参与，挡不住任何脚本化攻击，却确实挡住 AI 的端到端自测（目标 #3）。防不住攻击者、只防得住自己人 = 净损失 |
| `views/demos`、`dashboard/analytics|workspace` | 图表数字写死，快捷入口指向已删除的 `/demos/*` |
| logo / 默认头像 / PWA 图标的 unpkg CDN 链接 | 目标部署环境（政务内网）通常无公网出口，外链资源表现为「一直转圈」，排查时易被误判成样式问题 |
| `VBEN_GITHUB_URL` 等常量的取值 | 界面上显示的仓库/文档地址若还指着上游，是在向使用者提供错误信息（常量名保留） |

#### 已验证

`apps/admin/e2e/smoke.mjs`：真实浏览器 → vite dev server → 代理 → Spring Boot → MySQL 5.7，
**全链路无 mock**，20/20 通过。

| 验证项 | 结果 |
|---|---|
| 登录 → 令牌 → 动态菜单 → 四个页面 | ✅ 20/20 |
| 浏览器内新建部门后的数据库状态 | ✅ `dept_name` 中文完好，**`create_by = 1`** —— 令牌链路与审计填充在真实 HTTP 下确实生效 |
| 后端测试全量 | ✅ 34/34（含新增的 11 条 HTTP 端到端鉴权用例） |
| `vue-tsc` 类型检查 / 生产构建 | ✅ 均通过 |
| eslint 分层规则双向验证 | ✅ core 互引不报错；真实越层引用仍报错 |

浏览器用 `channel: 'chrome'` 驱动本机已安装的 Chrome，**不下载 Playwright 自带的 Chromium**
（本机实测下载失败，而政务项目开发机常处于受限网络）。

#### 🔍 发现 ⑫：Windows 上 Python 的 `Path.write_text` 会把 `
` 悄悄转成 `
`

本轮大量用脚本批改文件（scope 改名涉及 520 个文件），每写一次就重新引入一次 CRLF，
而仓库 `.gitattributes` 规定 `eol=lf`，`oxfmt --check` 因此在 524 个文件上报错。

**先在上游快照上跑一次 `oxfmt --check` 确认它是通过的**，才敢断定问题是我们引入的——
否则很容易误判成"上游本来就不规范"而去改配置迁就。

处置：批量改文件时按字节写（`write_bytes`），不用 `write_text`。
这与发现 ④⑤（字符集）同源：**平台默认值在 Windows 上和在 CI 的 Linux 上不一样，
凡是"用默认值"的地方都要显式指定。**

#### 🔴 发现 ⑬："我跑过 lint 了" 必须指项目自己定义的那条命令

本轮为此连着返工三次：

| 第几次 | 跑了什么 | 漏了什么 |
|---|---|---|
| 1 | `eslint packages apps internal` | oxfmt、oxlint、stylelint、cspell 全没跑 |
| 2 | 补了 oxfmt | oxlint 仍没跑，e2e 脚本的 `no-console` 没暴露 |
| 3 | `eslint packages apps internal` | 范围不含根目录，`package.json`、`pnpm-workspace.yaml` 的问题没暴露 |

根因是**给 CI 写了一条自己拼的检查命令**，与 lefthook `pre-commit` 实际执行的
`pnpm check`（oxfmt + oxlint + eslint + stylelint + turbo typecheck + cspell）不一致。
两边不一致的直接后果是：**本地能提交的代码，到 CI 才挂**。

处置：CI 改为直接跑 `pnpm check`，与钩子完全同一条命令。

> 附带发现：lefthook 钩子是在**第二次** `pnpm install` 时才装上的——
> 首次 install 时目录还不是 git 仓库，`prepare` 阶段的 `lefthook install` 失败了。
> 因此最初几次提交完全没被检查到，问题一直积到最后才集中爆发。
> 新建仓库时应当 **先 `git init` 再 `pnpm install`**。

顺带清掉 15 条已失效的 catalog 项（`ant-design-vue`、`naive-ui`、`tdesign-vue-next`、
`vitepress` 系、`h3` / `jsonwebtoken` / `@faker-js/faker` 等）——
对应的包在取材时就删了，catalog 里的声明成了死条目，`pnpm/yaml-no-unused-catalog-item` 会报。

### 第七轮（codegen v2：补齐前端生成，闭合「代码 + 验收用例」）

#### 补上的是哪一半

codegen v1 产出的测试 Spec 断言的是 `[data-testid="xxx-add-btn"]` 这类选择器，
而**页面没人生成**——那份 Spec 按定义就是跑不起来的。
「代码与它的验收用例一起生成」此前只兑现了一半，v2 补的是另一半。

新增产出：`src/views/<module>/index.vue`、`src/api/<module>.ts`、`db/menu-<table>.sql`。

**菜单 SQL 不是可选项**：前端 `accessMode: 'backend'`，路由完全由 `sys_menu` 下发，
只生成 `.vue` 而没有菜单行，页面在系统里根本不可达——这正是发现 ⑪ 的同一个坑，
换到生成器场景又会重演一次，所以由生成器一并产出。

**`data-testid` 的命名规则单点提供**（`VueGenerator`），`TestSpecGenerator` 复用同一套。
两处各写一套的后果是用例定位失败，而现象看起来像"页面坏了"，排查方向一开始就走偏。
有一条测试专门断言「Spec 引用的每个锚点在页面里都真实存在」。

#### 🔴 发现 ⑭：spec 里的 `query` 此前完全是死的

`BaseController.list` 只接 `PageQuery`、从不构造 Wrapper，
于是 spec 写 `query: like/eq/range` 只生成了一段 Javadoc。
若照此生成前端搜索栏，就是一个**点了没反应**的控件——比没有这个功能更糟。

处置：`BaseController` 增加 `buildListWrapper(Map)` 覆写点，codegen 生成其实现。

**为什么是「固定签名 + 一个覆写点」，而不是让子类各自声明 `@RequestParam`**：
子类若声明一个签名不同的 `list(...)` 并标 `@GetMapping`，它**不是覆写而是重载**，
同一个 GET 路径上出现两个映射，Spring 启动直接报 `Ambiguous mapping`。
留一个签名固定的入口，从结构上杜绝这种写法。

#### 🔴 发现 ⑮：接口路径重复 `/api` 前缀，报错信息与真实原因毫不相干

生成的前端客户端用了 spec 里的 `apiPrefix`（`/api/project`），
而 `requestClient` 的 `baseURL` 已经是 `/api`，拼出来是 `/api/api/project`。
后端按静态资源处理，抛 `NoResourceFoundException: No static resource api/api/project`，
经全局异常处理器变成 **500**。

故障表现的误导性是重点：前端看到的是"新增按钮点了报服务器错误"，
后端日志里是"找不到静态资源"——**没有任何一条信息指向"路径拼重了"**。
已加回归测试断言生成的客户端里不出现 `/api/` 前缀。

#### 三个 bug 的暴露时机（这一轮最值得记的一条）

| bug | 何时暴露 |
|---|---|
| 查询参数类型没进 import | 编译期 |
| `@Override` 签名不匹配 → 重复映射 | 编译期（javac 先报 @Override）+ 启动期 |
| **`/api` 前缀重复** | **只有真正打开页面点一次才会暴露** |

前两个跑一次 `mvn compile` 就能发现，第三个必须端到端实跑。
这解释了为什么"生成器单元测试全绿"完全不足以说明生成器可用——
**必须把产物放进真实工程跑起来**。

另有一条工具链教训：`mvn compile` 不加 `clean` 时增量编译会**跳过已改动的文件**，
本轮因此一度以为带 `@Override` 的产物编译通过了。判断"能不能编译"必须用 `clean`。

#### 已验证

`sample-app` 的 `project` 模块**没有一行手写代码**，输入只有 `codegen-specs/project.yaml`。

| 验证项 | 结果 |
|---|---|
| codegen 单元测试 | ✅ 40/40 |
| 生成物在真实框架依赖树下编译 + 全量后端测试 | ✅ 34/34 |
| 生成的 `.vue` / `.ts` 过 oxfmt / eslint / vue-tsc | ✅ 且与格式化结果**逐字节一致** |
| 浏览器实跑生成的页面 | ✅ 9/9（菜单 → 打开 → 新增 → 搜索命中且筛掉不匹配项 → 重置 → 删除） |
| 原有前端冒烟无回归 | ✅ 20/20 |
| 数据库侧复核 | ✅ 中文完好、`create_by` 由框架填充、删除为逻辑删除（`deleted=1`，物理行保留） |

「生成的 `.vue` 与格式化结果逐字节一致」这条是刻意做到的：
业务方拿到生成物应当能直接提交，而不是先被 pre-commit 钩子拦一次。

### 第八轮（describeadmin-archetype：业务方后端脚手架）

方案 9.2.2 要求的 Maven archetype 落地。目标是把接入方式从"以样例仓库为起点、
拿到后再删掉示例模块"换成"一条命令生成空工程"。

已随 **0.1.1** 发布到 Maven Central（2026-08-20；框架六个模块本身无功能变更，
跟随版本线是为了让"archetype 版本 == 生成物引用的框架版本"这条约定成立）。

已验证（**空本地仓库，全部走 Central**；来源经 `_remote.repositories=central` 与
SHA256 双重核对）：

| 验证项 | 结果 |
|---|---|
| `archetype:generate` 生成工程 | ✅ 6 个文件齐全，变量全部替换到位 |
| 制品来源 | ✅ `central=`，jar 的 SHA256 与 repo1 一致 |
| 用 **JDK 17** 构建生成物 | ✅ `mvn package` 通过（不配 toolchains） |
| 起服务 → 登录 | ✅ `code: 0`，令牌 43 字符，`roles: [ADMIN]`，20 个权限点 |
| 中文按字节核验 | ✅ `nickname` = `e8b685e7baa7e7aea1e79086e59198`（`超级管理员`） |
| archetype 自带 IT（`mvn verify` 自动执行） | ✅ 生成 + `validate` 通过 |

生成物**不含任何 SQL 文件**：`schema-rbac.sql` / `seed-rbac.sql` 在
`framework-system-starter` 的 jar 里，工程通过 `classpath:` 引用。
"空工程可直接登录"由此成立，框架对 RBAC 的修复也能通过升版本到达业务方。

#### 🔍 发现 ⑯：Maven 的默认排除规则会悄悄吃掉 `.gitignore`（`.gitattributes` 不受影响）

模板里的 `.gitignore` 在打包阶段消失，生成的工程里没有这个文件，**全程零报错**。

两个反直觉之处：

1. **只吃 `.gitignore`**——`.gitattributes` 不在 plexus 的 `DEFAULTEXCLUDES` 里，
   同目录下的两个点文件一个在一个不在，很容易误判成"点文件都没进去"或"都进去了"
2. **`maven-resources-plugin` 的 `addDefaultExcludes=false` 不够**——它只管到
   `target/classes`（那一层确实有这个文件），真正丢弃发生在 `archetype:jar` 打包时，
   而那个 goal 没有对应开关

**处置**：把模板文件命名为 `__dot__gitignore`，并在描述符里声明属性 `dot=.`。
文件名中的 `__属性__` 由生成器替换，落地即 `.gitignore`。
另附带一条可用的事实：**有默认值的 `requiredProperty` 不会在交互模式下提问**
（`archetype:generate` 的 `askForDefaultPropertyValues` 默认 `false`），
所以这个纯内部用途的属性不会打扰使用者。

CI 的 `archetype-e2e` job 分别断言这两个文件存在——这类"静默缺失"只能靠断言守。

#### 🔍 发现 ⑰：Velocity 把行首 `##` 当单行注释，markdown 二级标题会整行消失

archetype 的文件过滤走 Velocity。给 `README.md` 开过滤后，
每一个 `## 标题` 都会被当作注释整行吃掉，**不报任何错**，
生成物看起来像是"作者忘了写标题"。

**处置**：不需要变量替换的文件（`README.md` 与两个点文件）在描述符里就不标 `filtered`。
真要在 markdown 里用变量，得把内容包进 Velocity 的 `#[[ ]]#` 未解析块。

顺带核实掉一个此前的担心：模板 `pom.xml` 里需要**原样保留**的 `${describeadmin.version}`
**不需要转义**——Velocity 对未定义的引用原样输出。生成物里它确实是 `${describeadmin.version}`。
（`${symbol_dollar}` 那套写法是给"上下文中确实存在同名变量"的场景准备的，这里用不上。）

#### 🔍 发现 ⑱：archetype 发布到 Central **不需要** sources / javadoc 附件

动手前的担心是：`maven-archetype` 打包没有 Java 源码，
`maven-javadoc-plugin` 产不出附件，会被 Central Portal 的校验挡下，
需要造空 jar 绕过。**实测证明这个担心不成立。**

按项目的版本核查纪律直接查 `repo1.maven.org` 上近期发布的 archetype：

| 制品 | 发布时间 | 实际附件 |
|---|---|---|
| `com.vaadin:vaadin-archetype-application:25.2.6` | 2026-08 | 仅 `.jar` + `.pom` |
| `io.helidon.archetypes:helidon-quickstart-se:4.5.3` | 2026-08 | 仅 `.jar` + `.pom` |

两者都是 `packaging=maven-archetype`。因此本模块的发布不需要任何额外配置。

**0.1.1 发布后，这条已由本项目自身的制品坐实**——
`describeadmin-archetype:0.1.1` 在 Central 上的实际附件是
`.jar` / `.pom` / 两个 `.asc` / `-sources.jar`，**没有 `-javadoc.jar`（404）**，
Portal 照样校验通过并发布成功。
