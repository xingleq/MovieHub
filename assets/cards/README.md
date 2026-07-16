# MovieHub 卡片资源

抽卡页面使用本地卡池。把 AI 生成的卡片图放到对应稀有度目录后，应用会优先显示图片；图片缺失时会显示内置渐变卡面。

这些图片是个人本地素材，`.gitignore` 已忽略 `assets/cards/images/**/*.png|jpg|jpeg|webp`，不会随代码上传。

## 目录

```text
assets/cards/images/c/      C
assets/cards/images/b/      B
assets/cards/images/a/      A
assets/cards/images/s/      S
assets/cards/images/ssr/    SSR
```

## 命名建议

```text
assets/cards/images/c/c-gqs.png
assets/cards/images/b/b-ygs.png
assets/cards/images/a/a-bls.png
assets/cards/images/s/s-jxbls.png
assets/cards/images/ssr/ssr-zdbls.png
```

## 图片建议

- 竖版卡面：建议 768x1075 或 1024x1434。
- PNG/WebP 均可，当前代码里的路径是 PNG。
- 图片里可以只放角色立绘和背景；稀有度、攻击力、防御力、技能名会由应用 UI 绘制，避免 AI 写错字。

## AI 制图提示词模板

```text
请根据下面的角色设定生成一张竖版抽卡卡面插画。
不要在图片里写任何文字、数字、等级、攻击力、防御力或技能名。
只画角色、动作、背景、光效和稀有度氛围。

角色名称：蓝星守护者
作品/世界观：MovieHub 原创儿童向冒险世界
角色性格：勇敢、可靠、保护同伴
年龄气质：小朋友喜欢的可爱少年英雄，不要成人化
外观要点：蓝白色护目镜、星星徽章、短披风、圆润机甲手套
服装颜色：天空蓝、白色、少量金色
动作：举起护盾保护身后的伙伴
背景：柔和云朵、星光、浅蓝色天空
稀有度：SSR，金色和蓝色光效，闪亮但不要刺眼
画风：明亮、干净、儿童友好、动画电影质感
构图：角色完整居中，留出顶部和底部安全边距，适合竖版卡牌裁切
负面要求：不要文字，不要水印，不要恐怖元素，不要真实照片风格，不要过度复杂背景
```
