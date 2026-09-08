# 接入 Redis（缓存 / 令牌）

::: info 本页待补充
本页是文档骨架的占位页，内容正在编写中。下方列出的是本页将覆盖的要点与素材来源。
:::

## 本页将覆盖
- 引入 `framework-cache-redis-starter`，把 `CacheProvider` / `TokenStore` 从内存实现切到 Redis
- 运行时开关（`@ConditionalOnProperty`），关掉后行为与「没引这个 jar」完全一致
- `@AutoConfiguration(before = ...)` 的装配顺序陷阱
- 适配的最低框架版本怎么查
- 多实例部署下令牌共享、`dataScope` / `deptId` 不丢失

## 素材来源
- `docs/registry.md`（插件目录与准入规范）
- 插件仓 [framework-cache-redis-starter](https://github.com/describeadmin/framework-cache-redis-starter) README 与 CHANGELOG
