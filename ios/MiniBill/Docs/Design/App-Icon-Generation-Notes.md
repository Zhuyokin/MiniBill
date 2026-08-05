# MiniBill App Icon 生成说明

## 最终方向

采用用户参考图的核心语义：绿色底、白色账本、人民币符号和笔；重新设计为 Apple 式极简微拟物。推荐文件：`assets/app-icon-recommended-1024.png`。

生成路径：Codex 内置 ImageGen，image2 模型路径。参考图仅作为构图和语义参考，不作为直接编辑目标。

## 最终提示词

```text
Use case: logo-brand
Asset type: iOS App Store icon master for MiniBill, square icon concept
Input images: Image 1 is a visual reference for the core composition and meaning only; do not copy its flat vector rendering.
Primary request: Reimagine the reference as an Apple-style extremely minimal skeuomorphic app icon for small-business bookkeeping.
Subject: A single small ivory-white bookkeeping ledger sheet/notebook centered on a rich emerald green background. The ledger has softly rounded corners, a thin stack of warm paper visible at one edge, and a subtle raised rim. On its face is one clearly recognizable, exact Chinese yuan symbol “¥”, formed as a tasteful embossed emerald-green mark. A single compact pen crosses the lower-right edge of the ledger diagonally, with an ivory body, emerald grip, and tiny satin-metal nib.
Style/medium: Apple industrial-design minimalism plus restrained modern skeuomorphism; premium molded enamel, soft-touch paper, micro-beveled edges, precise geometry, tactile but not photorealistic; simpler and cleaner than the previous leather notebook concepts.
Composition/framing: preserve the reference’s strong centered symbol and green/white hierarchy; one ledger and one pen only; large bold silhouette; generous safe area; full-bleed green canvas without an outer white border or pre-rounded iOS mask.
Lighting/mood: very soft top-left studio light, delicate ambient occlusion, tiny contact shadows, calm and trustworthy.
Color palette: emerald green close to #07C160, warm ivory white, a tiny near-black or satin-metal accent; no other bright colors.
Text: render only the exact symbol “¥”; no words, no letters, no numbers, no app name.
Constraints: readable at 60 px; exact yuan glyph; no chart, calculator, coins, receipt roll, hands, extra stationery, watermark, border, or speech bubble; do not copy the WeChat logo; do not create a floating circular badge inside the square.
Avoid: flat vector-only look, heavy realism, leather texture, ornate fountain pen, excessive gloss, complex shadows, clutter, illegible micro-detail.
```

## 使用说明

当前文件是设计确认稿，尚未自动写入 `Assets.xcassets/AppIcon.appiconset`。进入实现阶段时再生成或配置 Xcode 所需资源，并在真机主屏、设置页和 Spotlight 中检查小尺寸效果。
