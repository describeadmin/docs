# 加第一个业务模块

承接[从零跑起一个管理后台](/guide/getting-started)。这一篇用 codegen 从一份 YAML
生成一个业务模块的前后端代码，并把它接进已经跑起来的工程。

::: tip 前提
你已经有一个能登录的 `my-server`（后端）和 `my-web`（前端）。
:::

## 1. 写 spec

在 `my-server/codegen-specs/` 下新建 `order.yaml`，可参照 codegen 仓的
[`examples/project.yaml`](https://github.com/describeadmin/codegen/blob/main/examples/project.yaml)。

字段逐项说明见 [参考 · codegen YAML spec](/reference/codegen-spec)。

## 2. 跑生成器

从 [codegen 的 Release 页](https://github.com/describeadmin/codegen/releases) 下载
`codegen.jar`——**取与你 `pom.xml` 里 `<describeadmin.version>` 对应的那个**
（见[兼容性矩阵](/reference/compatibility)，codegen 生成的薄代码对应特定框架版本的基类契约）：

```bash
java -jar codegen.jar codegen-specs/order.yaml --out .
```

::: tip 用 workspace 工作空间时无需手动下载
`workspace` 仓的 codegen skill 会按框架版本自动取、校验、缓存到
`~/.describeadmin/codegen/<版本>/`。
:::

一次产出两侧的东西：

| 产物 | 落点 |
|---|---|
| Entity / Mapper / Service / Controller | `src/main/java/.../order/` |
| `schema-biz_order.sql` | `src/main/resources/db/` |
| `menu-biz_order.sql` | `src/main/resources/db/` |
| 列表页 `.vue` + API 封装 `.ts` | 前端工程（用 `--frontend-out` 指定） |

生成的是「薄」代码：通用逻辑（分页、审计填充、逻辑删除、RBAC 校验）在框架基类里，
所以框架升级时**这些生成文件不用动**。

## 3. 登记 SQL —— 最容易漏的一步

生成的两个 SQL **不会自动生效**，必须登记进 `application-local.yml`：

```yaml
spring:
  sql:
    init:
      schema-locations: classpath:db/schema-rbac.sql,classpath:db/schema-biz_order.sql
      data-locations: classpath:db/seed-rbac.sql,classpath:db/menu-biz_order.sql
      encoding: UTF-8          # ⚠️ 不能省
```

::: danger 两个骗人的症状
**漏掉 `menu-biz_order.sql`**：代码全在、编译通过、接口能调通，但页面在侧边栏里
根本不出现——因为菜单是后端 `sys_menu` 表下发的。

**漏掉 `encoding: UTF-8`**：Spring 用平台默认编码读脚本，中文 Windows 上是 GBK，
会把 UTF-8 脚本读坏，库里中文全是乱码，而 `COUNT(*)` 校验完全正常，环境看起来很健康。
:::

重启后端，页面就出现在侧边栏了。

## 4. 权限点

codegen 按 `<模块>:<对象>:<动作>` 生成权限点，动作只有 `list` / `add` / `edit` / `remove`
四个，`menu-*.sql` 里同时登记并授权给 `ADMIN`。规范细节与推导陷阱见
[参考 · 框架约定](/reference/conventions)。

## 相关

- [手写一个业务模块（不用 codegen）](/how-to/add-module-manually)
- [升级框架版本](/how-to/upgrade)
