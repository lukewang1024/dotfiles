# Codex app-server 协议

优先查看已安装版本的 `codex app-server --help`，必要时用 `generate-json-schema` 或对应源码核对协议。当前实现依据 codex-cli 0.163.0 本机协议；重置卡属于可能随版本变化的实验能力，方法缺失时停止并说明版本限制，不猜测 HTTP 接口。

官方说明：[OpenAI app-server 文档：Earned rate limit resets](https://developers.openai.com/codex/app-server/#8-earned-rate-limit-resets-chatgpt)。

启动 `codex app-server --stdio`，使用现有登录状态；发送 `initialize`，包含 `capabilities.experimentalApi: true`，再发送 `initialized` 通知。不创建对话或推理任务，不申请或保存 API key。

查询使用 `account/rateLimits/read`，当前版本传 `{"excludeResetCreditDetails": false}`。`rateLimitResetCredits.availableCount` 是权威数量，返回的 `credits` 不一定是全部卡片。null 表示尚未返回明细；空列表表示已查询但没有可用明细。卡片的 `expiresAt` 为 Unix 秒或 null，null 表示没有到期时间。仅接受 `resetType: codexRateLimits` 和 `status: available` 的指定卡；未知状态停止处理。

兑换使用 `account/rateLimitResetCredit/consume`：

```json
{"creditId": "明确选择的卡片 ID", "idempotencyKey": "为本次逻辑操作生成并持久保存的 UUID"}
```

即使协议允许省略 `creditId`，本 skill 始终显式指定，防止后端自动选另一张。网络错误后复用同一幂等键；已提交但未收到回执时，卡片从可用明细消失并不等于失败。执行器只允许在原窗口内以原 ID、原键查询/重提，不替换卡片。

| outcome | 回报含义 |
| --- | --- |
| reset | 已兑换并重置符合条件的额度窗口 |
| alreadyRedeemed | 同一幂等请求此前已兑换，不是又使用一张 |
| nothingToReset | 没有需要重置的窗口，本次没有完成额度重置 |
| noCredit | 没有可用于本次兑换的卡 |
| 其他或无回执 | 未确认，保留原始结果并停止自动处理 |

四个已知结果均为本次任务的终态；只对前两个结果报告重置已确认。兑换响应不是完整额度快照，需要重新读 `account/rateLimits/read` 验证当前值，刷新失败不重复消费。
