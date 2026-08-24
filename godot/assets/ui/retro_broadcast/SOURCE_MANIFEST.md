# 80 年代节目包装素材来源

本目录的 PNG 来自项目作者提供的本机原始美术目录：

- `E:\doc\channel doc\ai\1x\*.png`
- `home_title_layer.png` 来自 `E:\doc\channel doc\图层 2.png`，仅做 1600px 运行时缩放优化

这些文件作为《织梦频道》的项目自有视觉资产使用。Godot 运行时只引用本目录，
不会依赖 `E:` 盘符。目录中的中文文件名保留用于和原始 AI/PSD 导出层对应；新增代码
优先引用稳定的英文命名文件或直接绘制几何包装。

项目中文界面使用 `SourceHanSansCN-Regular.otf` 与 `SourceHanSansCN-Medium.otf`，
两份字体均从项目作者本机字体库复制到 `res://assets/fonts/`，运行时不依赖系统字体。
