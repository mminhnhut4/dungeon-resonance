# Checkpoint opening: guide/combat/art/journey

Ngày2026-10-04, main D:/hầm ngục; Godot4.7.2.stable.official.ed1daf0bf. Guide và combat đã áp riêng có backup/rollback, không còn private runtime chờ merge. [Guide](FIRST_LOOP_GUIDE_INTEGRATION_20261004.md):2runtime/main41 sạch. [Combat](COMBAT_READABILITY_INTEGRATION_20261004.md):3runtime+3legacy assertion/main125 sạch. Giữ reader [numeric seal2](PROFILE_NUMERIC_SEAL_20261004.md), TravelerR3 và tám file floor-return. Handoff ban đầu28file đã áp trước đó,13backup cũ đối chiếu lại; không chép gói cũ đè thay đổi sau.

## UI và hình

Guide GPUr3:59/59,16ảnh800×600/1280×720, exit0/stderr trống; reviewer xem16ảnhr2 và3sample r3 cùng fixture/source. R1 lỗi fixture cuộn/tab/capacity; r2 mọi kiểm tra/ảnh xong nhưng native exit0xC0000005, giữ nguyên và không tính enginePASS. Một bounded retry sạch không chứng minh đã sửa native crash. Thẻ có tiêu đề/hành động đầu/focus, accept khi còn khả dụng và nút tiếp tục cố định;800×600 cần cuộn chi tiết để đọc toàn văn dài. Native Tab/Bùa kiểm phép đơn/cặp/bộ cũ. Không thêm combat GPU: tái dùng178headless/42GPU15ảnh producer, reviewer xem đủ15native.

## Art đang dùng

Rà12nguồn binding và69Resource liên quan cục bộ, không có file thiếu trong phạm vi này. Registry là Resource/constants hiện hữu, không tạo registry mới. Instance journey ghi rõ Sprite2D đang visible trongHub/P01/Golem và hash file thật; texture sinh runtime được tách riêng. P01 dùng data/pilgrimage_p01_art.tres, geometry/collision snapshot giữ nguyên; TravelerR3 vẫn bound. Khung vàng–đỏ RegionEntryCard chỉ có tên khu vực. Không tải/xuất/sửa asset. P01 có painted pack; các room road khác còn prototype. Golem vẫn PNG cũ, chưa có body/animation mới; icon fallback một số rune là giới hạn hiện hữu. Đây không là full art audit hoặc visual polish acceptance mới.

## Một journey và tiến trình mới

New game QA → P01/căn cứ → nhận quest bằng M/Enter → clear tầng1 và Continue → rương secret thật seed4242 → nhặt cả8loot gồm1gear decimal → native Tab/Bùa lắp rune sở hữu và caster trừ energy thật → về sảnh retreat → bank UID/quality/stat/đồng đúng, không Golemproof → gửi kho và mua+1 thật → chuyến mới từ tầng1 → fixture đi tới Golem/giết qua health owner với loot rỗng → final return → nhận kiếm một lần/đeo UID → derived next goal không giả Soul upgrade → process exit → process mới load.

Lượt write thực tế37/38 assertion đạt, exit1 vì harness sai một count art:12definition atlas sinh14sprite do tách hai bàn chân. Không gọi raw lượt đóPASS. Đã giữ nguyên log/source sai, sửa harness và dùng probe hẹp trong loader để kiểm12definitions/14sprites/splitshins; không chạy lại toàn journey chỉ để có xanh. Loader mới13/13, exit0/stderr trống, producerPID1348→reloadPID28136. Read-only coldload giữ bytes; playableHub giữ exact inventory/đồng/kho, UIDkiếm thưởng,+1,bùa,proof/claim và chống claimtrùng. Tất cả kiểm gameplay khác trong journey và corrected art probe đều đạt, không có bug sản phẩm từ count sai. Hai attempt trước chỉ parse lỗi Variant ở harness, chưa chạy gameplay; r2 đã sửa nhầm declaration, r3 sửa đúng explicit Variant. Không giấu các log lỗi hoặc cộng thành51/51 xanh.

Không chạm save người dùng: APPDATA/LOCALAPPDATA/QAroot riêng; loader dùng lại đúng profile đó. Một đá và5đồng hữu hạn để có quote; enemy/bossloot suppressed và stage4 có điều khiển. Không phải playthrough người thật, không bảo đảm loot nâng cấp hoặc20–30phút tự nhiên. Material-contact/parry audio chưa có callsite; cloud_return vẫn dodge. Native crash nguyên nhân chưa rõ. Không fullsuite/120Hz/importeditor/benchmark/upload/publish.

Receipt/backups/diff/zip/log/ảnh tại workspace opening_guide_combat_on_live2091_20261004_27; guide/combat package riêng giữ source checkpoint tương ứng. Các mốc pending trong báo cáo trước là lịch sử, trạng thái checkpoint này mới hơn.
