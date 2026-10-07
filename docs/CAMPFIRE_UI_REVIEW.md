# Campfire item panels — private UI delta

The campfire/body panel now uses the approved AntiqueSkin with a red lacquer heading, worn wood panels, old-gold frames, illustrated resource counters and four groups: Trang bị, Chế tạo, Sử dụng and Cổ vật. The equipment selection shows the actual localized name, quality, condition, description, whole-item art, upgrade cost and carried counts. The relic selection shows its actual purpose and the three existing destinations. Missing item art uses an explicit neutral question marker and “Chưa có ảnh riêng”; no unrelated shield is substituted.

Header, feedback and footer have fixed regions. The tab body owns scrolling. The panel remains within 800×600, 1280×720 and 1920×1080, including after switching groups and changing resolution. Actions and group tabs have at least 44px height. The existing Godot font preserves Vietnamese glyphs; no external font, package or download was introduced.

The production SurvivalSession smuggler also uses the shared skin, its actual local offer name/art, visible 15 Tàn Hồn / 10 maximum-health prices, carried resource counts and stock/affordability states. Shop/storage and other hall services already received the previous approved antique/two-column batch and are unchanged here.

## Ownership and integration

This is a new, narrow private delta in `campfire_ui`. Apply the two modified files against their exact first 26-file antique baseline; those files are also unchanged in the final two-column baseline. The sole integrator must reconcile any later changes to those files. No writes were made to `D:/hầm ngục`, the integrator copy, previous handoff ZIPs, Map/Quest, region frames or `inventory_screen.gd`.

Modified product files:

- `scripts/ui/survival_panel.gd`: widget construction, responsive layout and read-only selection/availability presentation.
- `scripts/runtime/survival_session.gd`: smuggler widget construction and read-only view refresh. Its native `trade` and `use_consumable` remain unchanged.

New product resources: `scripts/ui/opening_item_presentation.gd`, its Godot UID and `assets/ui/antique/campfire_missing.svg`. The UI helper exposes `definition`, `item_name`, `item_icon`, `description`, `state`, `craft_quote`, `cost_text` and `dismantle_allowed`. It owns no items, UIDs, profile saves, recipe execution or economy writes. Shared `AntiqueSkin`, `ServiceItemCard`, `ItemArtCatalog` and every transaction/catalog file remain unchanged in this delta. Future verified ItemArtCatalog additions are picked up through the helper without changing this layout.

The original `_dismantle`, `_equip_item`, `_craft`, `_use` and `_equip_relic` blocks are identical after LF normalization. Broken and forging-blank items cannot be equipped. Equipped/socketed gear and relics remain protected from dismantling. Existing consumable guards, ingredient checks, trap limit, exact upgrade prices and UID identities remain in native methods. Armor and accessories continue to use the existing inventory equip flow, reached through the footer. The old campfire dismantle flow has no confirmation; this delta preserves that flow and marks its destructive action distinctly. Existing confirmations elsewhere were not touched.

## Other panel audit

- `ContentSession` F6 recipe matrix is guarded by explicit `qa_tools_enabled=false`; it is a QA-only tool, not an opening player item panel. Audited, unchanged.
- `PrologueHub` production shop/storage/crafting and NPC services use the previous batch; unchanged.
- `InventoryScreen` and Map/Quest remain the other UI worker’s scope; unchanged.
- `OpeningCultivationPanel` uses its separate previously delivered Container compatibility delta; unchanged here.
- Sanctuary legacy entry, save recovery and region/name frames are not item-list counterparts of this campfire board; unchanged.

## Focused evidence

- `campfire_ui_r8.log`: 287 checks, 0 failures, real `scenes/test_level.tscn` and actual GearInventory/SurvivalSession. All four groups and the merchant at the three target sizes; stable selection/UID metadata; no save on inspection; contextual art/missing markers; cost/counts; native keyboard equip/dismantle/upgrade/craft/use/relic/smuggler actions; stale callback duplication protection; full-health, no-poison, no-stock, no-ingredient and eight-trap guards; existing inventory handoff and time ownership teardown.
- `crafting_focused_final.log`: existing focused crafting suite, 32 checks, 0 failures. No full suite run.
- `campfire_geometry.json`: actual headless Control geometry for twelve size/group combinations.
- `protected_blocks.json` and `patch_apply_proof.json`: normalized transaction equality, source hashes and exact patch reconstruction.

GPU rendering used the parent-assigned slot. `campfire_gpu.stdout.log`: 303 checks, 0 failures, 16 real viewport captures on NVIDIA GeForce RTX 5080. Every image was inspected: four groups at all three sizes, the available merchant at all three sizes and the purchased/disabled merchant. The feedback/footer stay visible; at 800×600 lower actions use the native focus-following scroll body. Long list captions ellipsize and retain full tooltips; relic slot missing-art captions wrap in their small slots. Missing art remains explicit. Local/catalog art is used; external icon ZIPs were not consumer-verified, and this delta does not claim complete icon coverage.

The requested `--screen 1` was unavailable: Godot reported only one display, emitted an out-of-range screen diagnostic and rendered on screen 0. This engine limitation is retained in raw stderr and the release receipt; it is not counted as a clean engine-log gate. The own QA PID 22860 exited with code 0, and GPU release was recorded at 2026-10-03T05:50:41.9454209Z before uploading. User editor PID 31076 was preserved; no further GPU window was launched.

All 16 previews were created once through the parent-authorized native Library fallback. Library IDs and upload receipts are included in `preview_library_saved.json`. The unchanged transfer helper attempted local metadata immediately; Windows has no `os.setxattr`, so local identity metadata did not persist. Successful Library creates remain valid and were not recreated. The prior headless ZIP remains immutable; this final package changes only its QA fixture and review document, with all five product source/resource files byte-identical to the cleared checkpoint.
