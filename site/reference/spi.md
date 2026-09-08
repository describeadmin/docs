# SPI 接口

::: info 本页待补充
本页是文档骨架的占位页，内容正在编写中。下方列出的是本页将覆盖的要点与素材来源。
:::

## 本页将覆盖
逐个列出可扩展点的完整签名、收集方式、注册要求：

- `AuthProvider` — `String type()` / `boolean supports(String)` / `LoginUser authenticate(AuthRequest)`，`List<AuthProvider>` 收集
- `NotifyChannel` — `Map<String, NotifyChannel>` 收集
- `CacheProvider` + `InMemoryCacheProvider` 默认实现
- `TokenStore` + `InMemoryTokenStore` 默认实现
- `StorageProvider` + 本地磁盘默认实现

每个都标注：`api/` 包 = 兼容性承诺范围，签名变更 = Breaking Change。

## 素材来源
- 各 starter 的 `api/` 包、`docs/CLAUDE.md` §2、§4.2、§4.6
