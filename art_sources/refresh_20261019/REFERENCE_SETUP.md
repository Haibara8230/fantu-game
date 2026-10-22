# 原作参考恢复与磁盘约束

所有命令从当前项目根目录运行。本包JSON、CSV和启动词中的路径相对于项目根目录，Markdown链接相对于所在文档。

已确认人物与分类样张已随包保存在 `approved_samples/`；这些文件优先于历史 `.tmp/style_samples_20261019/` 和 `.tmp/imagegen/` 缓存。`historical_paths` 仅记录过去的临时材料，不能当作现存输入。

29张原作截图的来源、原始直链、SHA-256与尺寸保存在 `reference_sources.json`。本机可用状态以 `status` 为准；`collection_status` 只记录当时收集情况。原图统一恢复到项目内 `PNG/mcs_style_reference_20261019/originals/`，该目录图片被Git忽略，并由 `PNG/.gdignore` 排除Godot导入，不进入正式资源。

先离线恢复：脚本扫描项目 `PNG/` 中已有图片，只有SHA-256完全一致才复用，不按相似画面或文件名替代。

```powershell
python -B tools/art/restore_art_references.py
```

若仍有缺图，可从清单中的原始HTTPS直链恢复。下载在内存校验SHA-256后直接写项目D盘目录，不使用浏览器、AI生图、系统下载目录或磁盘HTTP缓存。

```powershell
python -B tools/art/restore_art_references.py --download
python -B tools/art/repair_handoffs.py
```

脚本拒绝非D盘项目、逃出项目目录的目标和符号链接／联接造成的路径逃逸；Python必须带 `-B`，TEMP／TMP和临时目录固定到项目 `.tmp/art_handoff_repair/`。恢复报告在 `.tmp/art_handoff_repair/reference_restore.json`。网络失败或源图哈希变化时不把新内容冒称原图，退出码为1，并保留缺失状态；对应批次应先解决必需参考，不能凭描述猜图。

本工具只恢复已有来源的原始字节，不生成图片、不更新第三方来源版本、不替换正式 `assets/`。旧分类参考板、裁切配置和原版资源备份没有随Git携带；分类观察保留在参考文档中，实际作画查看原图及随包样张。需要新参考板时另存项目 `.tmp/`。

用户本轮已授权将内置imagegen的生成目录通过NTFS目录联接重定向至D盘项目 `.tmp/imagegen_storage/generated_images/`，并在核验后使用内置工具。联接的真实目标和写入探针必须通过 `tools/art/redirect_imagegen.ps1 -VerifyOnly` 检查；工具返回的C盘逻辑路径需要解析到该D盘目标。仅图片负载目录被重定向，Codex应用配置与日志未迁移。具体执行和引用规则见 [PRODUCTION_RULES.md](PRODUCTION_RULES.md)。
