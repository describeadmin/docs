---
layout: home

hero:
  name: describeadmin
  text: 政务 / 企业管理后台的平台 SDK
  tagline: 框架以 Maven 制品与 npm 包版本化交付，业务方依赖引用，而不是把源码拷进自己的仓库
  actions:
    - theme: brand
      text: 从零跑起一个后台
      link: /guide/getting-started
    - theme: alt
      text: 操作指南
      link: /how-to/
    - theme: alt
      text: 参考手册
      link: /reference/configuration

features:
  - title: 生产级
    details: 能在真实政务项目里用，包括国产化数据库（达梦 / 金仓 / OceanBase）与无公网出口的内网。DDL 与生成器模板遵守 MySQL 5.7 语法安全子集。
  - title: 可持续升级
    details: 业务方改一行版本号就能拿到框架的修复。RBAC、审计字段、分页基类都在框架里，生成的业务代码是「薄」代码。
  - title: 面向 AI 编程
    details: 约定显式、锚点稳定、错误在解析期就明确指出。所有交互元素强制带 data-testid，供 AI 自动化测试稳定定位。
---

## 这是什么

describeadmin 是一个**平台 / SDK**，不是可复制粘贴的模板。你通过 Maven / npm 依赖引用它，
框架的修复通过版本升级到达你的工程，而不是「框架修了，你那份复制品修不到」。

一条命令即可得到一个**可登录、带完整 RBAC、含审计与操作日志**的后端工程；
再写一份 YAML，codegen 同时产出前后端两侧的增删改查代码。

## 从哪读起

| 你的情况 | 读这里 |
|---|---|
| 第一次来，想先跑起来 | [教程 · 从零跑起一个管理后台](/guide/getting-started) |
| 要解决一个具体问题（接 Redis、加模块、部署内网） | [操作指南](/how-to/) |
| 查配置项、SPI 签名、版本对应关系 | [参考](/reference/configuration) |
| 想理解「为什么这么设计」 | [解释](/explanation/platform-not-template) |
| 想知道现在还缺什么 | [当前限制与路线图](/about/limitations) |

## 组成

| 仓库 | 内容 | 交付形态 |
|---|---|---|
| [framework](https://github.com/describeadmin/framework) | 后端框架核心：BOM + web / security / mybatis / cache / system / storage / notify 各 starter，以及后端工程脚手架 | Maven Central `io.github.describeadmin:*` |
| [frontend](https://github.com/describeadmin/frontend) | `@describeadmin/*` 前端包与管理后台应用外壳 | npm `@describeadmin/*` |
| [codegen](https://github.com/describeadmin/codegen) | 由 YAML spec 生成前后端两侧代码 | GitHub Release 可执行 jar |
| 插件仓（`framework-*-starter`） | 可选能力：Redis、S3、Excel、字段加密、邮箱登录…… | Maven Central，独立版本线 |

> 设计方案、版本基线、编码规范母本等**维护者文档**在 [docs 仓](https://github.com/describeadmin/docs)。
> 本站是**面向使用者**的文档。
