# Dungeon Resonance — Godot 4 prototype

**Bàn giao nhóm 2026-10-08:** bắt đầu tại [hướng dẫn thành viên](docs/team/START_HERE.md). Có [kế hoạch/owner](docs/team/TEAM_PLAN.md), [map](docs/team/MAP_GUIDE.md), [bùa](docs/team/SPELL_GUIDE.md), [nhân vật](docs/team/CHARACTER_GUIDE.md), [skill portable](docs/team/AI_SKILL_GUIDE.md), [QA](docs/team/QA_AND_HANDOFF.md) và [backlog](docs/team/BACKLOG.md). Repo dùng chung [mminhnhut4/dungeon-resonance](https://github.com/mminhnhut4/dungeon-resonance), **private**; upload/commit xác nhận trong receipt bàn giao. Source snapshot không phải bản game export.

**Combat hiện hành Oct7:** atlas resident, cache save có byte guard, journal ẩn coalesce; bùa/cast/contact và Golem UV mesh rig đã nối runtime. Import/268headless/21native/5cold-load sạch, probe4walk sạch; p99 mẫunormal37.578→23.431ms. Còn save peaks, layout800×600 và native crash lịch sử chưa kết luận; chưa fullstrict/longrun mới. [Báo cáo và giới hạn](docs/COMBAT_VISUAL_FIX_20261007.md). Các số phía dưới là checkpoint lịch sử.

**2026-10-03:** opening/save/QA mặc định OFF, resident P2, polish quái hiện hữu và khung cổ vàng–đỏ chỉ có tên khu vực đã áp dụng vào dự án. Full strict trực tiếp đạt148gate/8.639check,170script/33scene; GPU trực tiếp519check/86ảnh thực. Xem [Project State](docs/PROJECT_STATE.md) để phân biệt phần đang chạy, các mốc lịch sử và phần thiết kế/worker chưa kích hoạt. Bản sửa NPC/cửa hàng5.666check/GPU31capture ngày2026-10-02 được giữ tại [báo cáo lịch sử](docs/TARGETED_REPAIR_20261002.md).

Godot **4.7.2**, GDScript, Compatibility, offline. Prototype có HUD khung rồng với TextureProgressBar, icon bùa/vũ khí, Player concept PNG, Slime/Golem/bia/rương PNG alpha, bục/cột đá AtlasTexture, canvas glow, arc kiếm khí bạc/jade, hạt đuôi phép, âm thanh tổng hợp và Skeleton2D. Player hiện có rig modular dùng cutout PNG/AtlasTexture và animation đọc clock gameplay; atlas bộ khởi đầu đã tích hợp. Xem [nền tảng nhân vật](docs/CHARACTER_FOUNDATION.md). Resident còn dùng hình vector tạm; chưa export Steam.

Mở project.godot và chạy main bằng F5. Main hiện là `scenes/maps/prologue_hub.tscn`, bắt đầu tại **Căn Cứ Lữ Khách** dùng ExteriorHub. Đến **Đường Bộ** và tương tác E/tay cầm X để đi theo tuyến ngoại cảnh; Esc/B hoãn khung tên vùng. Cổng Hub vẫn đưa vào campaign hiện hữu. Menu Tế Đàn/Alpha của các scene legacy không phải entrypoint main hiện tại. Phòng thử riêng: scenes/test_level.tscn → Run Current Scene.

- A/D hoặc ←/→: chạy; Space/W: nhảy; Shift/K: dash.
- Chuột trái/J: attack; chuột phải/I: cast; hướng theo cursor.
- Q: vũ khí; E: nhặt/mở/tương tác; Tab: khảm bùa, time 10%; C: wounds/crafting/relics.
- Phím **` / ~** (dưới Esc): bật/tắt chữ debug, mặc định tắt. Camera zoom1.35, bám chuột tối đa40px; kiếm/dao dùng Kiếm Sĩ, trượng dùng Thuật Sĩ. Xem [Camera và hai ngoại hình](docs/GAME_FEEL_SKINS.md).
- QA tools **mặc định tắt** trong main: F5–F8 và API cấp đồ/nội dung debug đều bị chặn. Chỉ fixture opt-in `qa_tools_enabled` mới dùng các shortcut QA đó. Trong editor F5/F6 vẫn là shortcut chạy scene.

Tiến độ và hướng dẫn chi tiết: [Dynamic Combat Polish](docs/DYNAMIC_COMBAT_POLISH.md), [Run và căn cứ tu luyện](docs/CULTIVATION_RUN_ROADMAP.md), [Full Visual](docs/COMBAT_ART_POLISH.md), [Polish Report](docs/MILESTONE_POLISH_REPORT.md), [Player Rig](docs/MODULAR_PLAYER_RIG.md), [Project State](docs/PROJECT_STATE.md), [Architecture](docs/PROJECT_ARCHITECTURE.md), [Content Report](docs/MILESTONE_CONTENT_REPORT.md), [Addon status](docs/ADDONS.md).

Ảnh được phân loại theo [Asset Pipeline](docs/ASSET_PIPELINE.md): Player/NPC trong assets/sprites; sheet đá/cột trong assets/environment/tilesets; props có thư mục riêng. [Art Integration](docs/ART_INTEGRATION.md) mô tả Player lật theo con trỏ, pivot chân/Tween thở và skin đá của Tiền Sảnh. Hitbox/Hurtbox/collider giữ cây vật lý hiện hữu. Nguồn staging được lưu trữ trong docs/verification và bị loại khỏi import.

```powershell
./tests/run_tests.ps1
```

Báo cáo polish lịch sử đạt **2.857/2.857 assertion**, giữ đủ 2.409 mốc Full Visual và thêm 448 cho procedural motion, global hit-stop/modal, audio, VFX, vòng đời Boss/HUD và giao dịch save. Movement55/Combat100 ở cả 60/120 physics Hz và Resolver20 giữ nguyên. Validator103 script/19 scene; import/editor/addon/exit đều đạt. Ở mốc lịch sử đó, preview14ảnh kiểm đến Boss bị giải phóng và cổng chiến thắng; bốn benchmark GPU Tiền Sảnh/Boss đạt gần60/120FPS trên RTX5080. Các số này không thay bằng chứng hiện tại148gate/8.639check và519GPUcheck/86ảnh, cũng không chứng nhận cân bằng/gamefeel15–20phút. Xem [verification summary](docs/verification/polish_test_summary.json) và [log cuối](docs/verification/hades_juice_strict_suite.log).

Các lượt chẩn đoán có native editor shutdown `0xC0000005` chưa xác định nguyên nhân; gate cuối sạch không chứng minh lỗi gián đoạn đã hết, xem [native audit](docs/verification/full_visual_native_audit.md). Runner giữ mọi ERROR/WARNING và không dùng GameplayOnly thay strict. Aseprite Wizard được cài nhưng tắt chờ thủ công; PNG/SpriteFrames không cần executable.


## Navigation kiến trúc — proposal và đích đến

[Module map, conventions và các batch migration](docs/architecture/README.md) · [History index](docs/history/README.md) · [Nhật ký vấp ngã](<nhật ký vấp ngã/README.md>).

Bộ tài liệu/navigation đã có trên bản chính; bố cục runtime đề xuất chưa migration. Catalog mô tả snapshot để review, không lệnh move hoặc chép đè file. Chờ AI/map handoff chốt trước migration code; các report gate phía trên giữ mốc lịch sử của chúng.
