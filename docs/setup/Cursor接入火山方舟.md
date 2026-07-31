# Cursor 接入火山方舟 DeepSeek（BYOK）

Cursor **不能**用 `settings.json` 写入 OpenAI Key（存在安全保险箱）。请在 **Cursor Settings → Models** 里粘贴一次即可。

密钥在本机 `dream-channel/.env` 的 `ARK_API_KEY`（已 gitignore，勿提交）。

## 步骤

1. 打开 **Cursor Settings**（常见：`Ctrl+Shift+J`，或齿轮进 **Cursor Settings**）
2. 进入 **Models**
3. **OpenAI API Key**：粘贴 `.env` 里的 `ARK_API_KEY`
4. 点旁边的 **Save**（新版已去掉 **Verify**，找不到 Verify 是正常的）
5. 勾选 **Override OpenAI Base URL**，填：

```text
https://ark.cn-beijing.volces.com/api/v3
```

（不要加 `/chat/completions`。）

6. 用 **Add Custom Model** 手动加入（不要指望 Refresh Model List）：

```text
deepseek-v4-flash-260425
deepseek-v4-pro-260425
```

7. 聊天 / Agent 模型选择器里选上述模型，发一条「你好」测通。

## 注意

- Override Base URL 会把走 OpenAI 协议的请求都打到方舟；不用时关掉 Override。
- 使用自带 API Key 通常需要 Cursor Pro（或更高）；免费档可能静默不可用。
- 命令行脚本：`python cabin-slice/scripts/ark_chat.py 你好 --model flash`
