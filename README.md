# describeadmin

面向政务/企业管理后台的**平台 / SDK**。不是可复制粘贴的模板——
框架以 Maven 制品与 npm 包的形式版本化交付，业务方通过依赖引用，
而不是把框架源码拷进自己的仓库。

**如果你是第一次来，直接看 [快速开始](./QUICKSTART.md)。**

---

## 仓库

| 仓库 | 内容 | 交付形态 |
|---|---|---|
| [framework](https://github.com/describeadmin/framework) | 后端框架核心：BOM + common / web / security / mybatis / cache / system 各 starter | Maven Central `io.github.describeadmin:*` |
| [framework-cache-redis-starter](https://github.com/describeadmin/framework-cache-redis-starter) | 可选插件：把 `CacheProvider` / `TokenStore` 切到 Redis | Maven Central（待发布） |
| [frontend](https://github.com/describeadmin/frontend) | 27 个 `@describeadmin/*` 前端包与管理后台应用外壳 | npm `@describeadmin/*` |
| [codegen](https://github.com/describeadmin/codegen) | 由 YAML spec 生成前后端两侧代码 | GitHub Release 可执行 jar |
| [sample-app](https://github.com/describeadmin/sample-app) | 以真实业务方姿态消费框架的活样本 | 不发布，供参考与起步 |
| [docs](https://github.com/describeadmin/docs) | 本仓库：方案、版本基线、编码规范母本、发布手册 | 不发布 |

## 本仓库的文件

| 文件 | 写什么 | 什么时候看 |
|---|---|---|
| [QUICKSTART.md](./QUICKSTART.md) | 从零到跑起来 | **第一次来看这个** |
| [PROGRESS.md](./PROGRESS.md) | 现在到哪了、下一步做什么 | **每次开工前看这个** |
| [develop_plan.md](./develop_plan.md) | 完整设计方案与论证过程 | 想知道「为什么这么设计」 |
| [VERSION_BASELINE.md](./VERSION_BASELINE.md) | 已核验的版本事实与已知的错误信息源 | 遇到版本/依赖问题 |
| [CLAUDE.md](./CLAUDE.md) | 编码规范母本（各子仓库同步副本） | 动手改代码之前 |
| [registry.md](./registry.md) | 插件目录与准入规范 | 写插件、或想知道某能力有没有现成的 |
| [RELEASE.md](./RELEASE.md) | 发布手册 | 只有维护者需要 |
| [repos.yml](./repos.yml) | 全部仓库与交付物的唯一登记处 | 想知道有哪些制品 |

## 三个设计目标

本项目的每一处取舍都服务于这三条，读方案时可以拿它们当标尺：

1. **生产级** —— 能在真实政务项目里用，包括国产化数据库与无公网出口的内网
2. **可持续升级** —— 业务方改一行版本号就能拿到框架的修复，
   而不是「框架修了，但你那份复制品修不到」
3. **面向 AI 编程** —— 约定显式、锚点稳定、错误在解析期就明确指出。
   所有交互元素强制带 `data-testid`，供 AI 自动化测试稳定定位

## 许可证

- 后端与生成器（`framework` / `codegen` / `sample-app` / `docs`）：**Apache-2.0**
- 前端（`frontend`）：**MIT** —— 源自 [Vben Admin](https://github.com/vbenjs/vue-vben-admin)（MIT），
  再分发必须保留其版权声明，这是继承来的义务而非选择
