# Contact tường giữ ảnh của cặp bùa

Chỉ sửa hai nguồn trên bản riêng: scripts/spells/spell_executor.gd và scripts/presentation/slice_presentation.gd. Thêm tests/committed_wall_art_test.gd; không đổi Projectile, ImpactBurst, RenderedSpellArt, damage, collider, clocks, recipe/balance/save hoặc proc guard.

Nguyên nhân đã xác minh: Projectile đã truyền đúng SpellContext khi va chạm bằng move_and_collide, nhưng presentation_contact chỉ phát position/color/direction, bỏ recipe/root/source. Slice chỉ spawn spell_contact và không configure_spell_art; recipe rỗng làm helper chọn một crop Wind. Contact mục tiêu đã nhận event.spell_id nên không có khoảng trống này.

Fix giữ nguyên API presentation_contact ba argument cho observer cũ. Signal cosmetic committed_contact mới mang sáu scalar position/color/direction/recipe/root/source, phát tại cùng điểm trong wall_hit trước nhánh effect_triggered. Slice chỉ subscribe signal mới để tạo một burst/contact rồi configure_spell_art(recipe). Burst giữ root/source dưới dạng integer metadata; không giữ actor hoặc context/snapshot. Không dedup theo root vì fan ba projectile có ba va chạm hợp lệ. Các giới hạn24 impacts/8lights, lifetime và logic Overload/field vẫn thuộc owner hiện hành.

Tái hiện trước sửa: committed_wall_art_before chạy actual configured main → WorldCampaign tầng2 với QA save riêng, projectile thật và StaticBody2D stone trong lane trống. Thiếu committed identity và hai crop bị FAIL ở cả năm fixture. Raw receipt25 checks/11 failures được giữ. Một FAIL trong baseline là assertion ban đầu đếm Overload explosion như contact; đã sửa expectation để tính explosion có chủ ý riêng. Đó là sửa fixture, không thay hành vi runtime.

Sau sửa: committed_wall_art_fixed60 và fixed120 đều25/25, exit0, diagnostics rỗng. Năm fixture: Firestorm, Overload, Miasma, charged_slash ba nhánh và eclipse_blades dùng fan_blades ba nhánh. Kiểm legacy observer ba argument, current root/source/recipe, hướng snapshot, vị trí contact ở stone, hai AtlasTexture khác nhau visible; mỗi contact có một owner, Overload giữ explosion riêng, Miasma physicalcontact tạo một field và repeatedcontext không tạo thêm field. Sau clear/finite timeout, impact/field/light registries rỗng; exact profile bytes giữ nguyên và teardown hết spell_entities/time claims. Đây là controlled executor fixture, không là bằng chứng player tự tung chiêu hoặc trải nghiệm tự nhiên.

Native probe ngoài sản phẩm: spell_work/committed_wall_native_probe.gd extends test, root chạy với --capture và không Headless. Tạo năm PNG + wall_trace.json; camera chỉ riêng probe ghim lane tường để Player gravity không kéo contact khỏi màn. Agent không chạy GPU. Ảnh native cần root xem trước acceptance/merge.

Hai nguồn và test đóng băng trước01:28 UTC. SHA và preimage được ghi tại spell_work/COMMITTED_WALL_ART_MANIFEST.json; nguyên bản hai nguồn lưu ở spell_work/wall_art_pre_edit. Full strict R2 đã pass trước delta; root sở hữu kiểm delta/default gate tiếp theo và ghép main. Agent chưa ghép main.

Giới hạn còn lại: wall_hit vẫn dùng snapshot.direction như trước, nên contact của nhánh lệch góc dùng hướng aim trung tâm. Sửa direction đó cần thêm Projectile source và nằm ngoài delta hai file này. Chưa đo native frame-time của delta; không dùng các assertion logic thay cho native readability/performance acceptance.
