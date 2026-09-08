# 自定义消息通道（NotifyChannel）

::: info 本页待补充
本页是文档骨架的占位页，内容正在编写中。下方列出的是本页将覆盖的要点与素材来源。
:::

## 本页将覆盖
- 实现 `NotifyChannel` 并注册为 Bean，框架通过 `Map<String, NotifyChannel>` 收集
- `NotifyDispatcher` 的分发逻辑
- 默认日志渠道、如何做钉钉 / 短信等外部渠道（应做成独立插件仓）

## 素材来源
- `docs/CLAUDE.md` §4.2、§4.6
- [参考 · SPI 接口](/reference/spi)
