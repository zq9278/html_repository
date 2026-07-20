# SND100 Design Dashboard

SND100 模拟前端设计管理面板。

Public entry:

```text
https://raw.githack.com/zq9278/html_repository/main/snd100-design-dashboard/index.html
```

## Data Persistence

填写内容会自动保存到当前浏览器的 `localStorage`。刷新页面或关闭浏览器后数据不会丢失。

更换电脑、浏览器，或清理浏览器数据前，请使用页面上的“导出 JSON”备份。

## GitHub Sync

页面支持直接同步到 GitHub，但不要把 Token 写进源码。

首次使用：

1. 在 GitHub 创建 Fine-grained token。
2. 只授权仓库 `zq9278/html_repository`。
3. 权限只开启 `Contents: Read and write`。
4. 打开页面后点击“设置 GitHub Token”。

设置后：

- 刷新页面会自动读取 GitHub 数据。
- 点击“保存到 GitHub”会写入：

```text
snd100-design-dashboard/data/dashboard.json
```
