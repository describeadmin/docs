# 自定义登录方式（AuthProvider）

::: info 本页待补充
本页是文档骨架的占位页，内容正在编写中。下方列出的是本页将覆盖的要点与素材来源。
:::

## 本页将覆盖
- 实现 `AuthProvider` 接口（`type()` / `supports()` / `authenticate()`）并注册为 Bean
- 框架通过 `List<AuthProvider>` 自动收集
- 框架核心代码里不允许出现具体实现的名字——你的实现放自己的模块
- 登录响应结构、令牌字段是 `data.token`

## 素材来源
- `docs/CLAUDE.md` §4.2、[参考 · SPI 接口](/reference/spi)
- `docs/LOGIN_MODULE_AUDIT.md`
