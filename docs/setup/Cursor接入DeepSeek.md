# Cursor 接入 DeepSeek 官方 API（BYOK）

Cursor **不能**用 `settings.json` 写入 API Key（存在安全保险箱）。请在 **Cursor Settings → Models** 里粘贴一次即可。

密钥在本机 `dream-channel/.env` 的 `DEEPSEEK_API_KEY`（已 gitignore，勿提交）。

## 参数

| PARAM | VALUE |
|-------|-------|
| base_url (OpenAI) | `https://api.deepseek.com` |
| base_url (Anthropic) | `https://api.deepseek.com/anthropic` |
| api_key | `.env` 里的 `DEEPSEEK_API_KEY` |
| model | `deepseek-v4-flash` / `deepseek-v4-pro` |

## 步骤

1. 打开 **Cursor Settings**（`Ctrl+Shift+J`）
2. 进入 **Models**
3. **OpenAI API Key**：粘贴 `DEEPSEEK_API_KEY`  
   - 输入框旁若有 **Save** 就点；没有则粘贴后失焦 / 关掉设置页也会保留
4. 勾选 **Override OpenAI Base URL**，填：

```text
https://api.deepseek.com
```

（不要加 `/chat/completions`。）

5. **Add Custom Model** 加入：

```text
deepseek-v4-flash
deepseek-v4-pro
```

6. 聊天 / Agent 模型选择器里选上述模型，发一条「你好」测通。

## 注意

- Cursor 走 OpenAI 兼容协议，用 OpenAI Base URL 即可；Anthropic URL 给支持 Anthropic 协议的客户端用。
- Override Base URL 会把走 OpenAI 协议的请求都打到 DeepSeek；不用时关掉 Override。
- 使用自带 API Key 通常需要 Cursor Pro（或更高）。
