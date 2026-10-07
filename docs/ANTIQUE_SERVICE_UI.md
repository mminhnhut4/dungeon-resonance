# Antique service UI — presentation handoff

The current black/green list panels are replaced by dark wood, muted brass corner carving, red lacquer headers, inset image sockets, restrained hover/focus/disabled states, and illustrated item rows. Ten small authored SVG resources use StyleBoxTexture nine-slice; no fonts, external packages, downloads, settings or gameplay resources were added.

Current PrologueHub storage renders all 15 actual MaterialCatalog entries with existing per-item artwork, name, carried/stored quantities, details/tooltip and existing withdraw callback. Merchant, repairs, forging, enhancement, stone combination and consumable crafting share the same card. Native Button text and direct action NodePaths are retained; child controls ignore mouse events so actual row clicks and keyboard focus reach one Button owner.

Shared `DungeonUI.make_theme()` now returns the antique theme. Its mutable `panel_style()` remains StyleBoxFlat for old explicitly typed callers. GearInventoryModal applies the textured frame/cells after InventoryScreen has built them and updates existing rune icon presentation on refresh. `inventory_screen.gd`, map/quest, region-card and quest-tracker behavior are untouched by this worker.

Secondary panels receive the same theme: SurvivalPanel/crafting, hidden content matrix, survival merchant, legacy Sanctuary, save retry. SurvivalPanel's content scroll and deferred sizing fix old overflow at800×600. Secondary fixed-layout legacy Sanctuary/content screens are themed only; their complete redesign is outside this slice's current-Hub layout evidence.

Theme API for the UI worker:

- `AntiqueSkin.make_theme() -> Theme`
- `AntiqueSkin.apply_panel(PanelContainer)` assigns theme and carved StyleBoxTexture.
- `AntiqueSkin.panel_style(margin=18) -> StyleBoxTexture`
- `AntiqueSkin.apply_tree(Control)` skins existing child panels/buttons after construction.
- `AntiqueSkin.section(text)` / `divider()` build section hierarchy.
- Tokens: WOOD `211811`, SURFACE `35271c`, GOLD `ad8852`, LACQUER `512722`, TEXT `eee0c5`, MUTED `c3ae8b`, JADE `92bca7`, WARM `e2be7e`.

Keep the user's Map+Quest requirements: unified screen; no persistent quest tracker; region frame contains only the region name. The UI worker owns those files and can call `apply_panel()` after removing its old panel overrides.

Focused validation: latest AntiqueServiceUI760/760 at800×600,1280×720,1920×1080, including all current service headers/footers/images/hit areas/scroll-focus, inventory/crafting bounds and denied-transfer callback removal. Existing NPC72/72 exercises actual mouse purchase and original forge/enhance/combine/consumable callbacks; Prologue68/68 exercises storage/sales/repairs, UID lifetime and rollback; ItemIcon20/20 verifies bounded existing imports and unchanged definitions/UID/damage. Runs use a separate APPDATA/LOCALAPPDATA under task-5/qa_data. No full suite was run.

Import_r1 is retained as a failed cold-import diagnostic: sandbox certificate access, addon assets before first import, and two unchanged original reference files with mislabeled PNG bytes. Services_r1 retains the sandbox certificate error. Services_r3/r4 retain the incomplete fixture and initial crafting deferred-layout failure. Those are not clean results. Elevated read-only final focused runs services_r6/npc_actions_r1/hub_actions_r1 have zero ERROR/WARNING and zero failures; this does not claim the historical native shutdown issue is fixed.

The parent granted one bounded first-service GPU pass. `--capture --first-service-preview` rendered actual storage and merchant at800×600 and1280×720, producing4 captures and277 checks with0 failures. All4 images were viewed directly: carved outer frame, wood texture, lacquer header, inset per-item images, readable Vietnamese names/counts/actions and fixed footer. GPU used RTX5080 Compatibility on screen1 of2. The process exited cleanly; read-only process recheck found only user editor31076 and another headless worker. No user process was stopped. The GPU slot is released.

Preview Library upload is blocked: the current prepared-upload helper reports `Library prepare_uploads is not available` before returning any file IDs. No retry, raw URL, helper bypass, direct-route switch or manual user transfer was attempted. The4 actual PNG captures and hashes remain in the local handoff. Library preview IDs cannot be claimed.

Integration compatibility: the newer cultivation catalog adds actual IDs `aptitude_herb` and `aptitude_pill`. Storage action construction now queries the existing read-only `EconomySession._can_transfer(id,1)` capability. Rejected transfers are disabled and have no connected withdraw callback. Unknown images show `Chưa có ảnh riêng`; no false icon reuse. The worker does not alter the economy guard, training/herb hooks, transaction prices or inventory logic.15 local artwork coverage refers to the audited baseline only; the integrated catalog has17 materials and2 pending-art rows.

Audit covers57 entries:15 materials,4 consumables,19 equipment definitions,5 runes,9 legacy weapon runtime entries,1 catalyst,4 relics.18 initial pending presentations dropped to12 after six contextual local legacy aliases were applied. Original13 remaining audit entries are retained with per-entry resolution status. The12 generated external assets still await supported local materialization; cultivation adds2 further pending-art material IDs.60 variant definitions share10 family models. Full per-item art coverage is not claimed.

Six local aliases: blade_fan→world_fan, blood_spiked_whip→world_chain, demon_greatsword→world_greatsword, gale_dual_daggers→world_twinblades, ritual_staff/storm_arcane_staff→world_staff. The existing whole-weapon atlas was directly inspected before reuse. ItemArtCatalog.icon()/gear_icon() only return texture aliases; broken-item handling remains first, equipment definitions and runtime factor/UID remain unchanged.

The first private copy omitted original import sidecars, causing5 existing user icons to import unbounded. Original sidecars were restored byte-for-byte, preserving256px limit+mipmap. ItemIcon20/20 then passed clean. Reimport_r2 has unchanged addon invalid-UID warnings; it is not called a clean editor/import gate. GPU evidence predates this import correction; visual layout/artwork and ordinary callbacks are unchanged, and no second GPU pass was launched.

New trap/pants/lightning/ice/poison assets exist in Library (ZIP libfile_83138b30dcac81918ef188b779b45ba9; SHA256 a1fe92b8dd47d65c35286c15e7d632f4d0352c084eb30a9a1c6b4a4183d23834). They are not integrated: supported Windows materialization reached `os.setxattr` AttributeError after one bounded authorized retry. No raw URL transfer, helper bypass, duplicate generation or manual user transfer was attempted.
