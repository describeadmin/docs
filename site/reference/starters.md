# Starter 目录

::: info 本页待补充
本页是文档骨架的占位页，内容正在编写中。下方列出的是本页将覆盖的要点与素材来源。
:::

## 本页将覆盖
每个 starter：引入什么依赖、装配哪些 Bean、有哪些 `@ConditionalOnProperty` 开关。

| Starter | 职责 |
|---|---|
| `framework-common` | `Result<T>`、异常体系、基础类型 |
| `framework-web-starter` | traceId、`FrameworkJsonModule`、全局异常处理器 |
| `framework-security-starter` | 令牌认证、`AuthProvider` 收集、`@PreAuthorize` |
| `framework-mybatis-starter` | `BaseEntity` / `BaseMapper` / `BaseService`、分页拦截器、审计填充 |
| `framework-cache-starter` | `CacheProvider` 契约 + 内存实现、`TokenStore` 契约 + 内存实现 |
| `framework-system-starter` | 用户 / 角色 / 菜单 / 部门 / 字典 / 参数 / 操作日志 / 数据权限 |
| `framework-storage-starter` | `StorageProvider` 契约 + 本地磁盘实现 |
| `framework-notify-starter` | `NotifyChannel` 契约 + `NotifyDispatcher` + 日志渠道 |

## 素材来源
- `docs/repos.yml` 的 `framework` 条目、各 starter 的 `autoconfigure/`
