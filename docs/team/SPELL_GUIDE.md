# Làm bùa và kỹ năng có thể chơi

## Pipeline hiện hành

`RuneData + ResonanceDefinition` → người chơi sở hữu rune trong `GearInventory` → Tab lắp vào `CatalystRuntime` qua session/modal → `ResonanceResolver` exact multiset → `ResonanceController.commit_cast()` → `SpellSnapshot` → action FSM/`SpellExecutor.spawn_cast()` → projectile/field → Hurtbox/DamageEvent/DamageResolver → accepted result → VFX/SFX.

Definition `.tres` dùng chung và chỉ đọc. UID/phẩm cấp/+level/dòng phụ/ô mở thuộc `GearItem`/runtime. Quality hiện được phép ảnh hưởng damage/slot/proc; luật cấm nâng chỉ số trong skill cũ đã được thay. Class/moveset theo trang bị; không dựng controller/class tách rời vòng gear/bùa.

## Bài thực hành: đọc và polish Bão Lửa đã có

1. Mở `data/resonances/firestorm.tres`: id`firestorm`, recipe`[fire,wind]`, behavior`firestorm`; đây là recipe **đã đăng ký**, không thêm bản trùng bằng đảo thứ tự. `FireRune.tres`, `WindRune.tres` dùng `scripts/definitions/RuneData.gd`.
2. `ResonanceController.recipes` preload catalog. `ResonanceResolver.canonical_key` sort đủ IDs và giữ số lượng. Hỏa+Phong bằng Phong+Hỏa; `[fire,wind,ice]` không tự dùng Bão Lửa bên trong. Empty→`basic.tres`; bộ lỗi→null, không fallback. Recipe key trùng làm catalog invalid.
3. Cho Player sở hữu hai rune bằng loot/flow thật; Tab ghép và kiểm preview trước commit. QA chỉ được grant trong fixture opt-in save riêng. Đừng set Catalyst trực tiếp trong main: discovery/session có thể resync về ledger thật.
4. Trace `commit_cast` và `spell_snapshot.gd`. **Code hiện tiêu 30 energy mỗi cast** ở `can_cast`/`commit_cast`; `energy_cost` trên recipe không quyết định chi phí thực tại đây. `effect_scene`, `maximum_procs_per_attack` cũng không là cơ chế tự nối mọi effect. Không nói sửa `.tres` là đã đổi runtime nếu chưa đọc consumer.
5. `SpellExecutor.primary_hit` đọc accepted result, chặn effect khi blocked; `context.effect_triggered` giữ một proc chính. Bão Lửa spawn từ contact/đụng tường hợp lệ, `firestorm_effect.gd` có elapsed/radius/pull/explosion thật. Chỉnh presentation theo chính các clocks/radius đó, không thêm damage vào VFX.
6. Các hook trình diễn: `rune_cast_cue.gd`, `spell_projectile_vfx.gd`, `impact_burst.gd`, `slice_presentation.gd`. Seal/arrow phải đọc hướng đã commit, body thấy quỹ đạo, contact đúng vị trí và pha nổ rõ. Kiểm z_index/layer/alpha/lifetime; scene HUD riêng, Compatibility glow chỉ world layer 0.
7. Cast rồi đổi gear/bùa: đạn đang bay giữ snapshot màu/damage/hướng cũ, cooldown theo recipe ID vẫn tồn tại. Miss/blocked không được tự phát reward/hit proc; caster/room chết phải cleanup.

## Khi được giao một kỹ năng mới

Viết brief trước: recipe ID, bộ rune exact, biểu hiện windup/active/recovery/contact, target/boss policy, duration/radius, damage source, cancel và ngân sách. Với 5 nguyên tố/10 cặp hiện tại, recipe trùng không được thêm chỉ để có VFX mới; polish hành vi cũ hoặc xin duyệt công thức khác.

Nếu behavior đã có, reuse executor nhưng kiểm trường dữ liệu thật sự được copy/đọc. Nếu behavior mới, làm component/scene hữu hạn cùng `SpellContext`, nối dispatch trong executor có owner; đưa field vào snapshot nếu cần. `effect_scene` hiện không tự thay dispatch. Parent/root causal ID đi xuyên effects; DOT/child không có quyền tự proc lại. Cap thực thể 64, chain hiện tối đa 2, visited/dedup và lifetime phải giữ; VFX/light/audio cũng có budget/room owner.

Nguồn sát thương phải qua DamageEvent/Hurtbox/Resolver; animation chỉ đọc clock, không gọi health trực tiếp. Một multi-hit cần hit-window riêng theo thiết kế, không dùng callback overlap để gây damage mỗi frame. Không sửa resource của actor khác khi đổi loadout.

## Kiểm tra để bàn giao

- Headless: `tests/resonance_test.gd`, test nội dung 5 nguyên tố/cặp liên quan trong bộ hiện có, `tests/gear_test.gd`; VFX thay đổi dùng `dynamic_vfx_test.gd`, `enemy_attack_vfx_test.gd`/test riêng theo scope. Không tạo test chỉ khớp tên/chuỗi.
- Hành vi: đảo thứ tự, duplicate, vượt slot, không recipe, empty basic; cast/hụt/trúng/tường/blocked; đổi bùa trong flight; cancel/Hurt/Dead/chuyển phòng; cooldown/energy và cap khi spam.
- Native: từ main lắp bùa bằng UI thật, ảnh windup/body/contact/recovery và boss resistance, frame-time trong mẫu không lẫn screenshot readback. Kiểm 5 đơn/10 cặp theo task, không lấy test logic thay ảnh.
- Save nếu sửa ownership/equip/schema: roundtrip và cold process; numeric seal2/float64/UID/rollback giữ, dùng profile QA. Default strict khi tích hợp milestone.

Acceptance: thành viên khác mở cùng commit, lấy đúng bùa từ flow, lắp/tung được, nhìn hướng/pha/contact và nhận đúng damage; raw log/exit/ảnh có, cleanup không để node/voice/light sống qua room. Asset VFX chưa bind chỉ là `Art ready`.
