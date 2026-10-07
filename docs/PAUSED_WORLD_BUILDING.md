# Tạm dừng World-Building — 2026-10-01

**2026-10-02 — Sửa có mục tiêu đã hoàn tất:** NPC72/72 ở60/120Hz; full strict5.666/5.666 (116gate,111RESULT), validator148script/31scene/176Resource; GPUr2 retry31captures, exit0 và stderr sạch. Đã sửa viewport thoại, shop-key kiếm khởi đầu và chọn màn hợp lệ. [Báo cáo/bằng chứng](TARGETED_REPAIR_20261002.md). Handoff tạm dừng và các số gate phía dưới là lịch sử; mở rộng thế giới ngoài hầm ngục/cốt truyện20h vẫn là thiết kế chờ review, chưa triển khai rộng.

Người dùng: “tạm ngưng mai làm tiếp, hoãn tiến độ lại”. Dừng triển khai; chỉ resume khi người dùng yêu cầu. Không lên lịch tự chạy/khởi động lại hoặc tiếp tục sửa trong lúc nghỉ.

## Trạng thái cần tiếp nối

- Workspace `D:/hầm ngục`, Godot4.7.2/GDScript/Compatibility. Giữ editor gốcPID8568 và scene chưa lưu `node_2d.tscn`; không đóng cửa sổ này. Ưu tiên nền/CLI, preview ở màn phụ.
- Main `scenes/maps/prologue_hub.tscn` đã bật `world_building_enabled=true`, chọn `WorldCampaign`. PrologueHub có sân an toàn/nhà riêng/Kael/kho/rương thử/lửa/portal, baNPC mới và DialogueBox. Bảy ô starter115HP/11giáp/+2ATK và controller/physics cũ giữ nguyên.
- NPC art3,monster art4,weaponmodels10,materialicons13 đều đã duyệt và tích hợp bằng atlas. Không sản xuất lại hoặc hỏi duyệt lại. User chọn60data/qualityvariants dùng10models trước; art riêng theo bậc làm sau.
- WeaponVariantCatalog60variants,10moveset khác nhau,40ForgeRecipes. WeaponMotionPose/rig chỉ cosmetic đọc authoritativeclock. Focused world_weapons238/238 cả60/120Hz.
- Economy/Save/Loot/GameFlow đã sourcefreeze phía agentrig_foundation: WorldEconomy81/81 mỗi60/120, Economy117/SaveTransaction58/Sanctuary28/Alpha80/Gear35/Crafting32/Campaign31/StarterFlow15 clean; PrologueHub68/PrologueVisual75 cleanr2 theo báo cáoagent. Kiểm rawlogs khi resume trước khi trích số tổng.
- Sixstones5:1/maxgrade6, enhancement+12/max/+3%damage nền/cấp/100%, phẩm cấp/UID/affix không đổi. Divineforge50%, thất bại mất toàn bộ attemptmats, blueprintkept, savefailrollbackRNG/gear/coin/mats. Các giá còn là prototype.
- **Bản Nguyên Thần Thạch chỉ Boss đặc biệt tương lai. Không quái thường/elite/Golem hiện tại/chest/shop.** Definition/icon và yêu cầuLegendary/Divine đã có nhưng hiện không natural source. Không cấp đá vào save người chơi. Không tự chốt rate/Boss.
- Blueprint0,5%TOTAL mỗielite/Boss ưu tiênfamilyunknown; normalnone. DropTable pool riêngarchetype vànone35%prototype có thểrỗng hoàn toàn. Rương3–5món/large+1,qty3–5 vàRarebroken prototype. Thảo dược/sợi vải/rễ giải độc cóicon+craft. Mainworldkhông guaranteedcrystal/Soul mỗi kill.
- Coinrun escrow/deathlost/victorybankonce. SafeUIDwardrobe serialized/MOVEclear trước run sau save thành công. Victoryreturnsremaininggear once/deathstarterfresh; Souls đãnhặt/recipe/quest/permanent upgrades giữ. Stash15IDS có đủDISPLAY_NAMES VN.
- BaseEnemy/Motor/Data/State/Hazard/Visual4, WorldCampaign4chặng đã có. Roster typedArray ternary runtime đãfix `.assign()`; bat/wraith burst contacts đãfix. Focused enemy55/55@60r4clean; agent đang thêm actual4stage campaign/120/legacy khi bị dừng. StorytellerSwarm vàBodyConditionCripple hooks BaseEnemy đã thêm cần fullgate.
- Root đã thêm4suites vào `tests/run_tests.ps1`: world_weapons,world_enemy,world_economy,npc_dialogue. Gate mặc định đầy đủ, không dùng GameplayOnly thay strict. LegacyPrologue fixtures explicit worldflagfalse/campaignnull giữ hợp đồng cũ.

## Vấn đề đang mở — ưu tiên khi resume

1. DialogueBox portrait đẹp nhưng panel min-size bị content đẩy vượt chiều cao viewport, footer/Close bị cắt. Agent modular_equipment đang sửa; focusedNPC58 có1viewportfailure. File `scripts/ui/dialogue_box.gd`, `tests/npc_dialogue_test.gd`; xem `docs/verification/world_smith_dialogue.png`. NPCsuite phải parse `--hz=120` theo runner; agent đã được yêu cầu. StockKael đã thêmcommon_sword+starterclothing; trước đó GPU process load bảnũ nên nút missing.
2. GPUpreview `tests/preview_world_building.gd` r1 có31capture nhưng **INVALID**: console exit0/0failurecounter không đủ vìstderrmissingBuyWeapon_common_sword_0/nullbutton. Helper đã bắt lỗi đúng và runner exit1. Root đã thêmnullguard vàpurchasecostassertion; phải chạyr2sauUI sourcefreeze. Giữ rawr1logs. JSON cũ không được diễn giảiPASS.
3. Chạy focused enemy120/campaignfinal,NPC60/120 rồi đóngsource. Agent testfiles có thể ở giữa bổ sung khiinterrupt, inspect trước chạy.
4. Chạy defaultfull `tests/run_tests.ps1` sau mọi module ổn định. Chưa có fullPrologue/World PASS. Prologue_strict_gate_r1 từng failPolish40/fireaudio; lifecycle đãfix vàfocusedpass, cầnfullrerun. Không xóa/lọc ERROR/WARNING hoặc claim rootcause native0xC0000005 đãfix.
5. GPUpreviewr2/Hubbench currentNPC60/120; mixedAI benchmark đãPASS60=60.0055fps/p9517.528ms và120=119.9979/p958.892ms, 8sfixture2swarmup/6sample,all4actualattacks,hazards/fields2,RTX5080/1152x648. JSONworld_render_60/120. Không suy ra mỗiframe/mọi máy/run15–20phút.
6. Finalize `docs/WORLD_BUILDING_REPORT.md` (hiệndraft nói chưafullgate), PROJECT_STATE/ARCHITECTURE/DECISIONS/PROLOGUE_HUB/GAMEPLAY_ITEM_DIRECTION. Script `tools/update_world_evidence.ps1 -SuiteLog ...` chỉ chấp nhậnfullstrictclean, ghi content_manifest vàworld_building_test_summary; không ghi đèhistoricpolishsummary.
7. Artprovenance `docs/verification/world_art_provenance.json` đãread-onlyaudit4images/42regions vàhashsource match. Nativeimagegenonly; nguồn/promptapproval ởdocs/art_approval. Mipmaps4newPNGs đãbật/import cleanr2. Không chỉnh raster bằngPython; PILauditread-onlyđược.
8. Saufullgateclean, mởreport/interactivepreview màn1 bằngGUI, giữeditorPID8568. Không tự bậtpreview trong lúc user đang nghỉ.

## Công cụ và evidence

- CLI `D:/dowload/Godot_v4.7.2-stable_win64_console.exe`, GUI `_win64.exe`.
- `tools/run_render_check.ps1` hiddenconsole/screen1/timeout, capturestderr vàfailure; không coi sốcounterPASS che scriptERROR.
- `tests/preview_world_building.gd`: actualmain/NPCmouse/forgeVeryRare/enhance/stones/bandage/bounty/Kael/10Commonmodels/mixed4stages/4attacktelegraphs; save riêng `user://verification/world_preview_private.json`, suppliedmats/coin/recipe/heldHP. ZeroThầnThạch, không thayplayersave.
- PreviouscompleteHighFidelity3896/3896 là baseline. SixoldProloguebenchmarkPASS trước worldNPC được giữ như lịch sử; newmixedbenchmark nói phạm vi riêng.
- Agent ownership: foundation_review enemies/worldcampaign/survivalhooks; modular_equipment PrologueNPC/UI/dialogue; rig_foundation Economy/Save/Loot/GameFlow/permanentprogress. Root weapons/cosmetics/runner/GPUbench/preview/docs. Cácagentđãinterrupt theo yêu cầu dừng.

Luật/định hướng đã chốt được ghi đầu `docs/DECISIONS.md`; không hỏi lại các lựa chọn này. Trước tiếp tục đọc skillgodot-dungeon-dev, docs trạng thái vàhandoff này.
