# Kho và KAEL: hai cột trong cùng khung

Only storage and merchant item lists use two columns. The antique panel, fixed
heading/footer, viewport sizing, one shared ScrollContainer, transaction methods,
item IDs, quote values, native Button callbacks and direct action NodePaths remain.
Other service lists remain one column. Map/Quest and inventory files are untouched.

`ServiceItemGrid` lays out direct `ServiceItemCard` children in equal-width pairs;
labels and ordinary actions span the full width. An odd last item occupies the
left cell. Each pair uses its taller card's height. Focus moves horizontally within
a pair and vertically through rows, skips disabled targets, and reaches the fixed
footer. Tab navigation is row-major; the existing scroll follows focused controls.
The 12px antique scroll thumb has a 14px reserved strip, so it cannot cover the
right column. Native wheel input scrolls both columns together.

`ServiceItemCard.create(..., use_compact = false)` preserves the previous default.
Compact cards use 16px titles, 14px counts/prices, 56px image slots, 44px action
affordances and a minimum 76px whole-row native Button hit area. Long descriptions
remain in tooltips, and prices stay visible next to quality or stored quantity.
Disabled storage capability still creates no transaction callback. No substitute
icons were added for materials with missing approved art.

The 800×600, 1280×720 and 1920×1080 cases retain the exact previous panel sizes.
`two_column_service_ui_test.gd` measures complete/partial visible item counts from
actual Control rectangles, checks labels/art/actions remain within their cards,
executes focus input, and tests one real purchase in isolated QA data. Its baseline
run uses a fresh private copy of the final one-column handoff; old screenshots,
source and ZIP remain unchanged. GPU frames require the parent's assigned slot.

The approved final GPU run captured both services at all three sizes and passed
1,467 checks with no failures. Complete visible items increased from 2/1 (storage/
merchant) to 4/4 at 800×600, from 2/2 to 6/6 at 1280×720, and from 3/2 to 8/8 at
1920×1080. Partial rows are excluded. Prices remain visible before purchase.

A separate combined fixture uses the actual reviewed common owner R2 and
cultivation session. Six `OpeningCultivationPanel` parameter types widen from
`VBoxContainer` to `Container`; no behavior or transaction code changes. Training
remains one column. Its 71 checks passed, including the read-only lineage rows.
