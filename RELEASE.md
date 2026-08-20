# 发布手册

> 面向框架维护者。目标读者包括**几个月后的你自己**——发版是低频操作，
> 每次都要重新查一遍太浪费，所以这里把每一步都写死，包括为什么这么做。
>
> 命名空间：`io.github.describeadmin` ｜ npm 作用域：`@describeadmin`
> ｜ GitHub 组织：`describeadmin`
> 相关设计见 `develop_plan.md` 第七章。

## 三条发布链路

本项目有三条彼此独立的发布链路，**可逆性完全不同**，处置态度也应不同：

| 链路 | 仓库 | 目的地 | 可逆性 |
|---|---|---|---|
| Maven Central | `framework` | `io.github.describeadmin:*` | **完全不可逆**。不可删除、不可覆盖、不可撤回 |
| npm | `frontend` | `@describeadmin/*` | 72 小时内可 unpublish，但一旦有人装过，unpublish 会破坏对方构建——**实际上应当作不可逆对待** |
| GitHub Release | `codegen` | 可执行 fat jar | **可逆**。可删除重发 |

三者的版本号保持一致（当前 `0.1.0`）。`codegen` 与 `framework` 必须一致，
因为生成的代码要继承框架基类，兼容性只能成对理解。

发布顺序：**framework → codegen → frontend**。前两者之间没有依赖，
但 `sample-app` 要能从 Central 拉到框架，才谈得上验证接入路径。

§1–§4 讲 Maven Central，§4A 讲 codegen，§4B 讲 npm。

---

## 0. 一句话流程

配好 4 个 Secret → 手动触发 Release（**保持 dry-run**）验证签名链路 → 关掉 dry-run 发正式包 → 去 Central Portal 网页点 Publish。

---

## 1. 前置条件核对

| # | 事项 | 怎么核实 | 状态 |
|---|---|---|---|
| 1 | Central Portal 命名空间 `io.github.describeadmin` 已验证 | 登录 central.sonatype.com → View Namespaces，状态为 Verified | ✅ 已完成 |
| 2 | GPG 密钥已创建 | `gpg --list-secret-keys --keyid-format=long` | ✅ `4A054E489843BFFF`（RSA 4096） |
| 3 | GPG **公钥**已发布到公钥服务器 | 见 §2.3 的核实命令 | ✅ ubuntu / openpgp.org 均可查到 |
| 4 | Central Portal User Token 已生成 | 见 §3.1 | ⬜ 待办 |
| 5 | GitHub Actions Secrets 已配置 | 见 §3 | ⬜ 待办 |
| 6 | `maven-central` environment 已创建并设审批人 | 见 §3.3 | ⬜ 待办（可选但建议） |

> **第 3 项是 Central 的硬性要求**：它会用公钥服务器上的公钥去验证你上传的 `.asc` 签名，
> 公钥没发布出去，制品一定被拒。

---

## 2. GPG 相关操作

### 2.1 拿到私钥（用于 `GPG_PRIVATE_KEY`）

```bash
gpg --armor --export-secret-keys 4A054E489843BFFF
```

输出从 `-----BEGIN PGP PRIVATE KEY BLOCK-----` 到 `-----END PGP PRIVATE KEY BLOCK-----`，
**连头尾两行整段复制**。GitHub Secret 支持多行值。

Windows 上更稳妥（避免终端复制丢字符）：

```powershell
gpg --armor --export-secret-keys 4A054E489843BFFF > "$env:USERPROFILE\gpg-private.asc"
# 记事本打开 → 全选 → 复制 → 粘贴到 GitHub Secret
Remove-Item "$env:USERPROFILE\gpg-private.asc"     # 贴完立刻删除
```

> ⚠️ 这是私钥本体。不要提交进任何仓库、不要贴进聊天工具、不要留在磁盘上。
> `.gitignore` 已排除 `*.asc` 与 `settings.xml`，但请自行再确认一次。

### 2.2 口令（用于 `GPG_PASSPHRASE`）

就是 `gpg --full-generate-key` 时输入的那个口令。**它不存在于任何文件中**，无法导出或找回。

判断某把密钥是否设了口令（不会弹窗，安全）：

```bash
echo test > /tmp/t.txt
gpg --batch --yes --pinentry-mode loopback --passphrase '' \
    --local-user 4A054E489843BFFF --detach-sign -o /tmp/t.asc /tmp/t.txt \
  && echo "未设口令" || echo "已设口令"
rm -f /tmp/t.txt /tmp/t.asc
```

当前密钥实测结果：**已设置口令**。

口令遗忘时没有补救办法，只能重新生成并重新发布公钥，旧密钥用
`gpg --delete-secret-keys 4A054E489843BFFF` 删除。

### 2.3 核实公钥已发布

```bash
KEY=4A054E489843BFFF
curl -s "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x$KEY" | head -1
curl -s -o /dev/null -w '%{http_code}\n' "https://keys.openpgp.org/vks/v1/by-keyid/$KEY"
```

前者应输出 `-----BEGIN PGP PUBLIC KEY BLOCK-----`，后者应为 `200`。

若尚未发布：

```bash
gpg --keyserver keyserver.ubuntu.com --send-keys 4A054E489843BFFF
```

> 公钥服务器之间同步有延迟，发布后等几分钟再验证。

---

## 3. GitHub 配置

### 3.1 生成 Central Portal User Token

```
https://central.sonatype.com/usertoken
```

点 **Generate User Token**，得到一对 username / password。

> ⚠️ **弹窗关闭后无法再次取回**。当场存进密码管理器，再填到 GitHub。
> 丢了就重新生成一对，旧的作废。
>
> 注意：这**不是**你的 Sonatype 登录账号密码。命名空间验证通过 ≠ token 已生成，两件事相互独立。

### 3.2 配置 Actions Secrets

> **别和 GPG 公钥的位置搞混了**——GitHub 上有两个不同的地方：
>
> | 位置 | 放什么 | 作用 |
> |---|---|---|
> | Settings → SSH and GPG keys | GPG **公钥** | 让 commit 显示 "Verified" 徽章，**与发布无关** |
> | Settings → Secrets and variables → Actions | GPG **私钥** 等 | **发布用的是这里** |

多仓拓扑下建议配在**组织级**，一次配好全部仓库可用：

```
https://github.com/organizations/describeadmin/settings/secrets/actions
```

点 **New organization secret**，Repository access 选 `All repositories`
（或 `Selected repositories` 挑要发布的仓库）。

单仓库级备选：`https://github.com/describeadmin/framework/settings/secrets/actions`

需要配置的四个：

| Secret 名 | 值的来源 |
|---|---|
| `CENTRAL_TOKEN_USERNAME` | §3.1 生成的 token username |
| `CENTRAL_TOKEN_PASSWORD` | §3.1 生成的 token password |
| `GPG_PRIVATE_KEY` | §2.1 导出的私钥全文（含 BEGIN/END 行） |
| `GPG_PASSPHRASE` | §2.2 的密钥口令 |

### 3.3 创建 `maven-central` environment（建议）

```
https://github.com/describeadmin/framework/settings/environments
```

新建名为 `maven-central` 的 environment，勾选 **Required reviewers** 并填上自己。

**为什么值得加这道闸门**：发到 Maven Central 的版本**不可撤回、不可覆盖、不可删除**。
误触发一次就永久占用了一个版本号，只能靠发下一个版本来"修正"。
加了审批人之后，每次发布前需要人工点一下确认。

不想要这道闸门，就删掉 `release.yml` 里的 `environment: maven-central` 一行。

---

## 4. 发布流程

### 4.1 第一次：dry-run 验证链路

```
Actions → Release → Run workflow
  ✅ 保持 "只验证打包与签名，不上传到 Central" 勾选
```

它会做三件事，任何一步失败都不会污染 Central：

1. 用 JDK 21 构建、`release=17` 编译
2. GPG 签名全部制品
3. 逐模块校验 `jar` / `sources.jar` / `javadoc.jar` **及其 `.asc` 签名**齐备

这一步专门用来验证 **GPG 私钥导入与签名链路**是否真的通。跑绿了再做正式发布。

### 4.2 正式发布

**a. 确定版本号**（遵循 SemVer，见 `develop_plan.md` 第七章）

```bash
mvn -f framework/pom.xml versions:set -DnewVersion=0.1.0 -DgenerateBackupPoms=false
```

Central **不接受 SNAPSHOT 版本**，工作流里已有校验会直接拒绝。

**b. 更新 CHANGELOG**

必须分 Breaking Changes / New Features / Bug Fixes 三类。开源项目的使用者不限于内部业务方，这条纪律不能松。

**c. 提交并打 tag**

```bash
git commit -am "release: 0.1.0"
git tag v0.1.0        # tag 必须与 POM 版本一致，工作流会校验
git push && git push --tags
```

推 tag 会自动触发 Release 工作流。若配了 environment，需要先在 Actions 页点批准。

**d. 到 Portal 手动 Publish**

```
https://central.sonatype.com/publishing/deployments
```

工作流中 `autoPublish=false`，制品先落在 **draft** 状态。在网页上核对 groupId、版本号、
产物齐备性后手动点 Publish。

> 链路稳定、发过几次之后，可以把父 POM 里的 `<autoPublish>` 改成 `true` 省掉这一步。
> 但在 CHANGELOG 与版本治理流程跑顺之前，建议保留人工确认。

**e. 发布后**

同步到 Maven Central 检索通常需要几分钟到几十分钟。核实：

```bash
curl -s https://repo1.maven.org/maven2/io/github/describeadmin/framework-bom/maven-metadata.xml
```

> 用 repo1 核实，**不要用 `search.maven.org`**——那个索引已陈旧，
> 会对真实存在的制品返回假阴性（详见 `VERSION_BASELINE.md` 附录）。

---

## 4A. codegen 发布（GitHub Release）

**不发布到 Maven Central。** 理由不是省事：`develop_plan.md` 9.4 定了
`codegen` 绝不出现在业务方 `pom.xml` 的 `<dependencies>` 中——它是命令行工具，
产物一旦生成即脱离生成器。既然没有「依赖它」的消费者，发到 Central 没有意义。
Central 只对未来的 `describeadmin-codegen-maven-plugin` 形态有价值。

```bash
cd codegen
mvn versions:set -DnewVersion=<版本> -DgenerateBackupPoms=false
# 更新 CHANGELOG.md（工作流会抽取对应版本那一节作为 release notes）
git commit -am "release: <版本>" && git tag v<版本> && git push && git push --tags
```

工作流会先**实际执行一次** `java -jar` 生成产物并断言中文完好，
再创建 Release。只检查文件存在是不够的——shade 配置写错时 jar 照样产出，
用户下载下来第一条命令才失败。

发错了可以删 Release 重发，这条链路不需要审批闸门那么紧张。

## 4B. npm 发布（`@describeadmin/*`）

### 前置：`NPM_TOKEN`

推荐 **Granular Access Token**（npm 现在主推的类型）。
0.1.0 首发时在这上面连踩两次，两次的报错都把人往错误方向引：

| 设置 | 必须选什么 | 选错的后果 |
|---|---|---|
| **Bypass two-factor authentication (2FA)** | **必须勾选** | `403 Forbidden - Two-factor authentication or granular access token with bypass 2fa enabled is required` |
| Packages → Permissions | **Read and write** | 403 |
| Packages → Select packages | **All packages**（含 future packages） | 见下 |
| Organizations | **Read and write** + 勾 `describeadmin` | 无法在 scope 下创建包 |

> ⚠️ **「Only select packages and scopes」在首次发布时用不了。**
> 它只能勾选**已存在**的包，而首发时这些包一个都不存在。
> 必须给 **All packages**。

传统 Classic Token 若仍可用，选 **Automation**（天然绕过 2FA）；
**绝不能选 Publish**——后者要求 OTP，在 CI 里会挂起或直接失败。

**记下 token 的到期日**。到期后流水线会突然 403，而那个 403 与
「权限配错」的报错长得一模一样，极易把人引去反复检查权限配置。

配到与 Maven 那四个同一处（组织级 Actions Secrets），名字 `NPM_TOKEN`。

### ⚠️ npm 对新建包有发布速率限制

0.1.0 首发时实际撞上：27 个包发出 25 个后，第 26 个拿到

```
429 Too Many Requests - Could not publish, as user undefined: rate limited exceeded
```

结果是**半发布**——一部分包在 registry 上，一部分不在。

那次运气好，卡在 `layouts` / `plugins` 两个叶子包上，没有其他已发布包
依赖它们，已发出的 25 个内部仍然自洽。**若卡在 `core-shared` 这类被大量
依赖的包上，整组包会真的破损**：消费者装得到 A，却拉不到 A 依赖的 B。

对一个一次要发几十个新包的仓库，撞限流是**必然而不是意外**。
工作流已带指数退避重试（60/120/240/480 秒，共 5 次）。

重试之所以安全，是因为 `pnpm publish` 会跳过 registry 上**已存在的相同版本**，
只补发缺的。**这个幂等性是重试成立的前提**——没有它，重试就是危险动作。

限流窗口较长（实测第一次 429 后约 25 分钟内重试仍被拒），
job 内的退避不一定够；必要时隔半小时再从 `main` 用
`workflow_dispatch`（`dry_run=false`）补跑一次。

### ⚠️ 发布后核实必须逐个核对，不能抽查

0.1.0 首发的缺口是**人工比对 npm 页面上的包数量**才发现的，
不是流水线报出来的——当时的核实步骤只抽查 4 个包，
而那 4 个恰好都在已发出的 25 个里，于是报绿。

半发布状态的特征就是「大部分包在、少数不在」，**抽查天然会漏报**。
工作流现已改为逐个核对全部待发布包。

### 流程

```bash
cd frontend
# 全部 workspace 包版本置为目标版本（含 private 包，保持一致）
# 校验：不应有任何包还停在旧版本
grep -rn '"version": "<旧版本>"' --include=package.json packages apps internal scripts | grep -v node_modules
git commit -am "release: <版本>" && git tag v<版本> && git push && git push --tags
```

工作流有**两道独立门禁，缺一不可**：

| 门禁 | 保证什么 | 不保证什么 |
|---|---|---|
| `publint` | `package.json` 的 exports / files / types 正确 | 不保证 `dist` 有内容 |
| dist 非空校验 | 每个待发布包的 `dist` 总字节数 > 0 | 不保证内容正确 |

`exports` 写得再对，`dist` 是空的，业务方装上去照样白屏——这个组合
是实际踩过的（`core-design` 的 `exports.default` 曾指向不存在的
`./dist/design.css`，消费者拿到 0 字节 CSS）。

> ⚠️ **publint 那一步必须先删缓存**：`vsh publint` 按 `package.json`
> 内容哈希缓存结论，缓存命中时报的是**上一次**的结果，与当前 `dist` 无关。
> 不清缓存的话，`dist` 被删光也可能报「无问题」——门禁是反的。
> 工作流里已有 `rm -rf node_modules/.cache/publint`。

### 发布后核实

```bash
npm view @describeadmin/ui version
# 装到工作区之外的一个全新工程里真实构建一次，确认 CSS 产物非空
```

**不要只看 `npm view` 就下结论**。包能装 ≠ 能用，这是两件事。

---

## 5. 本地验证（不需要任何凭据）

日常开发完全不需要 GPG 和 token：

```bash
# 常规构建
mvn -f framework/pom.xml clean install

# 验证 release profile 能产出 Central 要求的三件套（跳过签名）
mvn -f framework/pom.xml clean verify -Prelease -Dgpg.skip=true
```

要在本地做完整的带签名发布（一般不需要，交给 CI 即可），
复制 `scripts/settings.xml.sample` 到 `~/.m2/settings.xml` 并按其中说明配好环境变量。

---

## 6. 故障排查

| 症状 | 原因 | 处置 |
|---|---|---|
| `gpg: signing failed: Inappropriate ioctl for device` | GPG 想弹交互式口令框，但 CI 无 tty | 父 POM 已配 `--pinentry-mode loopback`；确认 `GPG_PASSPHRASE` 已传入 |
| `401 Unauthorized` / `403` | token 错误，或用了登录账号密码 | 重新生成 User Token（§3.1），确认 `server-id` 是 `central` |
| 制品被拒：`Missing signature` | 公钥未发布到公钥服务器 | 见 §2.3 |
| 制品被拒：`Missing javadoc/sources` | 未启用 `-Prelease` | 发布必须带 `-Prelease` |
| `tag v0.1.0 与 POM 版本 X 不一致` | 忘了 `versions:set` 或忘了提交 | 对齐后重新打 tag |
| 版本号已被占用 | Central 版本**不可覆盖** | 只能发下一个版本号 |
| 构建用了错误的 JDK | 未配置 toolchains | 见 `scripts/toolchains.xml.sample` 与 `develop_plan.md` 2.2.2 |

---

## 7. 不可逆操作清单

发布相关的这几件事**做了就回不去**，动手前请确认：

- **发布到 Central 的版本无法删除、无法覆盖、无法撤回。** 发错了只能发新版本修正。
- **`autoPublish=true` 之后，推 tag 即直接发布**，没有人工确认环节。
- **GPG 私钥泄露后，唯一的补救是吊销密钥并重新签发**，已发布的制品签名随之失效。

因此建议长期保留：environment 审批人 + `autoPublish=false` 这两道闸门。
它们每次只多花十几秒，但能挡住整类不可逆的事故。
