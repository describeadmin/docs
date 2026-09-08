# 邮箱登录

::: info 本页待补充
本页是文档骨架的占位页，内容正在编写中。下方列出的是本页将覆盖的要点与素材来源。
:::

## 本页将覆盖
- `sys_user.email` 字段在核心表里，但邮箱**登录**能力是插件
- 引入 `framework-auth-email-starter` 注册对应 `AuthProvider`
- 验证码下发通道、有效期、失败锁定
- 不装插件时 `email` 只是普通联系方式

## 素材来源
- `docs/CLAUDE.md` §4.6 的「例外」段、`docs/LOGIN_MODULE_AUDIT.md` F 项
- 插件仓 [framework-auth-email-starter](https://github.com/describeadmin/framework-auth-email-starter) README
