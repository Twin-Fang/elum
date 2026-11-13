# elum art guide

> Read by the agent before every image request. Keep it short and concrete.

## Look
- Medium and style: soft rounded 3D-ish shapes with a **matte, airbrushed gradient finish**, like the designer's Lumi (refs/lumi_body.png, refs/lumi_face.png). Friendly and calm.
- Line and shading: no outlines. Smooth gradients, soft inner glow. **No glossy specular highlights, no wet shine, no jelly or vinyl reflections, no rim light, no heavy bloom** (#1332: gloss made the art look AI-made).
- Palette: warm yellow (#FFD629), mint (#55CFBA), peach (#FFC9BB), soft periwinkle (#9CADF1), cream background (#F7F2EF). Pastel, medium saturation. Avoid dark or neon colors.
- Lighting: soft even light, very soft contact shadow only. No platforms or pedestals under characters unless asked.

## Reference images
- refs/lumi_body.png: designer's original Lumi (Figma). Body proportion: tall rounded bean body, short stubby arms, two small feet, sprout antenna with a glowing mint bulb. Ignore its angry eyebrows.
- refs/lumi_face.png: Lumi's face and finish. Two round dark eyes, small orange beak between and slightly below them, matte gradient yellow to mint at the bottom.
- refs/star_big.png: material and glow of small objects (icons, items)

## Lumi rules (never break)
- **Always two eyes, both fully visible, symmetric, facing the viewer (front or slight 3/4 at most).** Never a side profile that hides one eye. Exception: a wink when the brief asks for it.
- Face: eyes and beak sit in the upper middle of the body, beak is a small orange triangle. No mouth line, no teeth, no eyebrows unless the brief asks for an emotion.
- Proportion: body about 1.25x taller than wide, head and body are one shape, arms short, feet small. Do not stretch, squash or make the head separate.
- **Draw only Lumi unless the brief names another character.** Never add an extra small creature, baby, child or companion.

## Redrawing an existing asset (#1332)
- Keep pose and props: pass the existing asset as the FIRST reference, then refs/lumi_face.png and refs/lumi_body.png, in one flag: `--ref <asset> refs/lumi_face.png refs/lumi_body.png` (repeating `--ref` keeps only the last one).
- Prompt: "redraw the first reference faithfully, change only: two eyes, body proportion, matte finish".
- Judge on a gray `board` next to the old asset at full size; count the eyes.

## Layout rules for this app
- Icons and items: one object, centered, about 10% padding, readable at 48 px
- Transparent background for anything placed on cards

## Never
- Text, letters, numbers, logos, watermarks, frames
- Stars as a symbol for credits (stars are the child's reward)
- Coins, money, banknotes, gambling or loot-box imagery
- Photo-real, flat vector, or hard-edged styles
- Glossy plastic, jelly or vinyl toy shine
- Drawing with code (SVG, PIL, canvas). Images come from the image model only
