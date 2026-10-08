# Exact imagegen prompts — sect NPC staging, 2026-10-08

Built-in imagegen only. Every call used transparent_background=true. R1 calls generated new images. R2 calls referenced the matching staged R1 PNG. No CLI/API fallback, installation, postprocessed sprite, or tracked project mutation.

## Thanh Van r1: generate

```text
Use case: stylized-concept.
Asset type: ONE production candidate raster NPC sprite for a 2D side-scrolling Eastern cultivation action game, to be rendered at about 60 pixels body height.
Primary request: a full-body Thanh Van sword disciple, slim and disciplined, pale jade and ivory robes with muted blue layers, black hair bound simply, practical dark boots. One straight sword gripped naturally in the right hand beside the right hip, held in a relaxed but ready low guard, blade extending diagonally toward screen-right and ending above the boot sole line. The sword, hands, hair, and both feet are fully visible.
Style/medium: dark hand-painted ink illustration; expressive dark contour work, painterly shaded cloth folds, worn woven material, restrained broad decorative trim. Belongs against a painted, weathered mountain and ruined stone temple world with charcoal lines, muted jade and slate colors. Detailed enough to feel handcrafted but designed around large readable shapes at tiny gameplay scale. Not flat vector, not pixel art, not 3D render, not photoreal.
View and pose: orthographic side-scroller view, three-quarter SIDE view strongly facing screen-RIGHT, nose and both boots pointing right. Quiet balanced ready stance with two legs distinguishable, both soles resting on the same imaginary horizontal ground line; no lunging, floating, perspective foreshortening, or front-facing portrait.
Composition: single isolated character centered on a portrait canvas. Entire body and weapon within frame with generous transparent margin on every edge, at least 10 percent above the head and below the soles, and clear space beyond the sword tip. Clear narrow upright silhouette, no trailing strips that detach visually. The near hand has an anatomically plausible grip; exactly two arms and two legs.
Lighting and palette: soft painted top-left light and cool restrained shadows; pale jade/ivory/blue are distinct readable blocks with dark ink edges. No luminous aura.
Background: genuine transparent alpha, clean cutout edges. Absolutely no scenery, floor, pedestal, cast shadow blob, smoke, frame, checkerboard baked into the image, text, symbols, logos, interface, or extra characters.
Output: one transparent full-body sprite, one pose only; retain crisp large silhouettes rather than tiny ornament clusters.
```

## Xich Lo r1: generate

```text
Use case: stylized-concept.
Asset type: ONE full-body transparent raster NPC sprite for a 2D side-scrolling Eastern cultivation action game. The sprite will be displayed around 60 pixels body height, so shape and broad materials must read clearly.
Primary request: one Xich Lo sect guard, sturdy broad shoulders and grounded build. Earth-red cloth tabard, copper edging, dark iron lamellar armor with large restrained plates, practical wrapped dark boots, black hair bound close. Holding ONE heavy broad dao blade naturally in the right hand beside the right hip, in low ready guard pointing diagonally forward toward screen-RIGHT. Blade tip stays above the bottom of the feet. No shield, no extra weapons.
Style/medium: dark hand-painted ink illustration with painterly material shading, rough weathered copper and iron, readable cloth folds, controlled dark outlines. Suitable for a game with painted weathered mountain and ruined temple backgrounds. Distinct earthy red/copper/dark silhouette with broad planes, no tiny ornament clusters, no flat vector look, no pixel art, no neon, no photorealism or 3D rendering.
View and pose: orthographic side-scroller three-quarter SIDE view strongly facing RIGHT. Head, nose, chest orientation and both boots aimed screen-right, not toward the viewer. Quiet balanced standing combat-ready pose, two arms, two clearly separated legs; both boots visibly planted on exactly the SAME horizontal imaginary ground level, with zero vertical offset between their sole contact lines. No floating, lunging or perspective floor.
Composition: single isolated character, entire body and full broad blade visible on a portrait canvas. Generous actual empty transparent padding around all anatomy and weapon: approximately 12 percent above head, 12 percent below boot soles, and at least 8 percent at either side. Character must not fill or touch the frame.
Lighting: restrained directional painted light on the character only. Keep dark armor readable through copper/rust-red and muted slate highlights.
Background and alpha: actual fully transparent background, clean tight alpha around the character. Outside the hard silhouette is EMPTY: no semi-transparent mist or gray aura, no white halo, no soft edge glow, no shadow puddle, no floor, no backdrop, no checkerboard artwork. No particles, environment, text, emblem writing, watermark, frame, UI, extra figure or turnaround sheet.
Output one isolated still pose, ready for separate native gameplay binding review.
```

## Thanh Van r2: edit feet and padding

```text
Use case: precise-object-edit.
Edit the supplied Thanh Van sword-disciple sprite. Preserve the same character identity, slim build, pale jade/ivory/muted blue clothes, painted ink shading, head, torso, arms, natural right-hand sword grip and complete straight sword design.
Correct ONLY the gameplay pose and framing defects:
1. Both boots must face screen-RIGHT in side profile; the nearer boot must no longer point toward the camera. Keep two distinguishable legs in a quiet balanced stance.
2. Put the bottom contact edges of BOTH boot soles on exactly the same horizontal image row, so both can stand on a flat side-scroller ground without one foot floating. Keep the whole figure strongly facing right, no perspective ground.
3. Scale the complete artwork down within the same portrait canvas to leave at least 10% genuinely empty transparent space above the hair and below the soles, plus comfortable transparent side padding beyond all cloth and the sword tip. No anatomy or blade clipping.
Keep one full-body still character and one blade only. Preserve the clean readable dark ink silhouette and material blocks suitable for 60-pixel body height. Do not add decorations, props, text, environment, floor, cast-shadow patch, smoke, haze, aura or glow. Background must remain true transparent alpha with empty pixels around the silhouette. Do not bake the apparent preview background into the image.
```

## Xich Lo r2: edit feet and padding

```text
Use case: precise-object-edit.
Edit the supplied Xich Lo guard sprite. Preserve the same adult sturdy character identity, beard, tied black hair, earth-red cloth, copper trim, dark iron lamellar armor, strong broad torso, painted ink style, arms, right-hand grip and heavy broad dao blade.
Correct only the leg pose and framing:
- The nearer boot currently points at the viewer. Turn BOTH boots to point screen-RIGHT in an orthographic side-profile foot pose. Both legs remain distinguishable and naturally support the body.
- The bottom contact edges of both boot soles must align on the SAME horizontal image row. Flat side-scroller ground, no perspective depth offset between the feet, no floating foot.
- Keep the complete body and entire blade inside a portrait canvas with generous transparent padding: around 10% above hair and below soles and clean side margin beyond the blade. Do not crop the blade or body.
Keep a quiet grounded combat-ready three-quarter side view facing RIGHT. One still character, one broad blade, two arms, two legs only. Maintain broad readable earth-red/copper/dark forms for roughly 60-pixel gameplay height.
Preserve actual transparent alpha. Outside the character silhouette must remain empty: no floor, pedestal, contact shadow, glow, halo, atmospheric haze, backdrop, text, frame, symbol writing, UI, or extra objects. Do not bake apparent preview-background RGB into opaque pixels.
```

