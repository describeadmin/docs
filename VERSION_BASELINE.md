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
