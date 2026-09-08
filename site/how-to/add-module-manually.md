# 手写一个业务模块（不用 codegen）

::: info 本页待补充
本页是文档骨架的占位页，内容正在编写中。下方列出的是本页将覆盖的要点与素材来源。
:::

## 本页将覆盖
- 继承 `BaseEntity` / `BaseMapper` / `BaseService` / `BaseController` 的四件套写法
- `@MapperScan` 要指向自己的包
- 建表 SQL 的红线（5.7 安全子集）与建表规范
- 手写 Controller 时 `permPrefix()` 的覆写（模块名含下划线 / 自定义 apiPrefix 时的 403 陷阱）
- 手动登记权限点到 `menu-*.sql` 并授权

## 素材来源
- `docs/CLAUDE.md` §3（数据库约定）、§4.1（分层与基类）、§4.5（权限点）
- [参考 · 框架约定](/reference/conventions)
