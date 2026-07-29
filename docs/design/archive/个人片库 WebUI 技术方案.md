# 个人片库 WebUI 技术方案

## 1. 项目目标

建立一个以番号为索引的个人资源管理 WebUI，用于：

- 录入、搜索和整理影片资料
- 保存用户自有文件、私人云盘地址或正版观看链接
- 管理收藏、观看状态与观看进度
- 从自己的存储中下载文件或在线播放
- 后续支持多设备同步

> 本工具不接入磁力站、不搜索或聚合未授权片源，也不保存第三方盗版下载信息。

## 2. 核心流程

```text
输入番号
  ↓
规范化编号并查重
  ↓
创建或补充影片资料
  ↓
添加合法资源（自有文件 / 私人云盘 / 正版平台）
  ↓
保存到数据库
  ↓
搜索番号并下载、播放或打开外部链接
```

## 3. 功能模块

### 3.1 影片管理

- 番号录入与格式规范化
- 标题、封面、年份、标签和备注
- 收藏、想看、已有、已看和归档状态
- 番号精确搜索与标题模糊搜索

### 3.2 资源管理

- 本地文件路径
- 用户私人对象存储或网盘链接
- 正版购买、租赁或播放页面
- 一个影片关联多个资源
- 文件大小、格式、清晰度和字幕信息
- 链接有效性与最后检查时间

### 3.3 播放与下载

- 浏览器支持的 MP4/WebM 直接播放
- 私有对象存储使用短时效签名 URL
- 下载自有文件
- 外部正版链接跳转
- 记录观看进度与最近观看时间

### 3.4 用户与同步

- 邮箱或第三方账号登录
- 每位用户的数据和文件相互隔离
- 云端数据库同步
- 可选的导入、导出与备份

## 4. 推荐技术栈

### 前端

- Next.js + TypeScript
- Tailwind CSS
- React Hook Form + Zod

### 后端与数据库

- Next.js Server Actions / Route Handlers
- Supabase Auth
- PostgreSQL（Supabase）
- Supabase Storage 或兼容 S3 的私人对象存储

### 部署

- Web：Vercel
- 数据库与认证：Supabase
- 大文件：Supabase Storage、Cloudflare R2 或用户自己的 S3

## 5. 数据模型

### `movies`

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | UUID | 主键 |
| `user_id` | UUID | 所属用户 |
| `code` | TEXT | 规范化后的番号 |
| `title` | TEXT | 标题 |
| `cover_url` | TEXT | 封面地址 |
| `release_date` | DATE | 发行日期 |
| `status` | TEXT | 想看、已有、已看或归档 |
| `notes` | TEXT | 备注 |
| `created_at` | TIMESTAMP | 创建时间 |
| `updated_at` | TIMESTAMP | 更新时间 |

建议设置唯一约束：`UNIQUE(user_id, code)`。

### `resources`

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | UUID | 主键 |
| `movie_id` | UUID | 关联影片 |
| `type` | TEXT | `upload`、`cloud`、`official` 或 `local` |
| `label` | TEXT | 资源名称 |
| `url` | TEXT | 文件或页面地址 |
| `storage_key` | TEXT | 私有存储对象键 |
| `mime_type` | TEXT | 文件类型 |
| `file_size` | BIGINT | 文件大小 |
| `quality` | TEXT | 清晰度 |
| `is_available` | BOOLEAN | 当前是否可用 |
| `last_checked_at` | TIMESTAMP | 最后检查时间 |

### `watch_progress`

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `user_id` | UUID | 用户 |
| `movie_id` | UUID | 影片 |
| `position_seconds` | INTEGER | 当前进度 |
| `duration_seconds` | INTEGER | 总时长 |
| `last_watched_at` | TIMESTAMP | 最近观看时间 |

## 6. 安全与隐私

- 存储桶默认设为私有
- 服务端按登录用户校验资源所有权
- 播放和下载使用短时效签名 URL
- 不在数据库保存云存储密钥
- 上传时限制文件大小和 MIME 类型
- 数据库启用 Row Level Security
- 日志中不记录签名链接和敏感令牌

## 7. MVP 范围

第一阶段只实现：

1. 登录
2. 番号录入、编辑和搜索
3. 影片列表与详情页
4. 保存自有资源或正版链接
5. 私有文件上传
6. 在线播放与下载
7. 收藏和观看状态

暂不实现：

- 磁力站、BT 索引或番号片源搜索
- 未授权资源抓取与聚合
- 公共资源分享
- 自动转码与大规模媒体处理

## 8. 后续迭代

- 批量导入已有片库
- 自动提取本地文件信息
- 封面与元数据的合规来源接入
- 字幕管理
- 视频缩略图与断点续播
- PWA 和移动端适配
- NAS、自建 S3 与 WebDAV 接入
