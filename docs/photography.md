# 摄影集

`/gallery/` 与 `/en/gallery/` 展示所有影集的可点击封面。每个影集在 `/gallery/<id>/` 中独立保存总导览与展室，中英文路径相互对应。

新增影集时，在 `data/photography/collections.json` 注册 `id`、`data_key`、资源页面 `page` 和 `cover`。`page` 用于查找 Hugo 资源页面，不能与影集入口 URL 混淆。每个影集使用自己的资源 bundle，中英文 `index.md` / `index.en.md` 保存完整总导览，封面和照片放在该页面的资源目录。中文 `index.md` 的 front matter `url` 写 `/gallery/<id>/`，英文 `index.en.md` 必须显式写 `/en/gallery/<id>/`。Hugo 不会为显式 `url` 自动补语言前缀；中英文使用不同 URL，避免生成页面时互相覆盖。

在 `data/photography/<data_key>/` 添加四份数据：

- `works.json`：源照片、中文和英文图像描述、真实 EXIF。原文件没有 EXIF 时，`exif` 保持空值；放大界面分别显示「原文件未包含 EXIF 信息」或 “No EXIF data in the original file.”，不补造拍摄参数。
- `rooms.json`：依次编号的展室、中英文标题、作品顺序 `ids` 与悬挂组合 `hang`。展室导览 `quote` 可省略；在同一章内更换题材时，可在对应 `hang` 的首幅悬挂上添加 `guide`（同样包含双语 `text`、`source`）和唯一 `anchor`，导览会出现在该段照片之前。`quote.url` 为 `#statement` 时，链接回本影集的总导览。
- `guide.json`：需要单独保护的中英文主题导览；无需独立导览时可用空对象。
- `selection.json`：`duplicate_of` 将不展出的高度近似照片 ID 映射到实际展出的对应作品 ID。没有重复时用空对象。

所有源作品必须恰好属于展出清单或重复清单之一。展出数量由当前库存数减去重复清单数得到。追加作品使用后续编号，保留已有库存；人工重新分组后同步该影集的主题边界检查。展出的照片只出现一次，`hang` 展开的顺序应与 `ids` 一致。原图继续保留，网站发布处理后的图片；放大界面显示真实 EXIF 或缺失信息说明。

新增影集页面及展室页面时，沿用现有 `exhibition` 模板、`collection` 与 `room` 参数。中文展室的 front matter `url` 写 `/gallery/<id>/<room>/`，英文展室必须写 `/en/gallery/<id>/<room>/`。影集列表页同理分别使用 `/gallery/` 与 `/en/gallery/`。使用现有影集页面作为示例，保持封面可点击、正文不折叠、图片保留原始比例。

运行 `make check` 会构建网站，并对 registry 中每个影集执行 `tools/check_exhibition.py`：检查中英文入口、完整导览、所有展室、作品与重复清单覆盖、真实图片资源及 EXIF。首个影集另有人工看图后确定的主题分组和终章顺序保护；新增影集不继承其作品数量与章名。

合并展室时，将旧页面设为草稿，并在保留页面的 front matter 中添加旧地址的 `aliases`。中英文文件的 alias 均写 `/gallery/<id>/<old-room>/`，Hugo 会补上语言前缀；显式 `url` 仍须遵守上面的双语路径规则。构建检查会验证旧山景地址跳转到同语言的合并章节。
