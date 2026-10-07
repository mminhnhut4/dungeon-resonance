# P0: số thập phân trong seal của profile

Đã sửa và áp riêng ngày2026-10-04 trên nền live2.088 sau TravelerR3/floor-return. Rương secret thật seed4242 cho gear có affix `0.013505235314369202`; JSON native đọc lại thành `0.0135052353143692`. Candidate trước ghi hợp lệ nhưng checksum sau đọc không khớp, nên writer từ chối trở về và giữ save cũ. Đây là blocker ghi dữ liệu, không có bằng chứng đã mất save người dùng.

## Chính sách

[Writer chung](../scripts/runtime/profile_commit_writer.gd) vẫn giữ primary checksum SHA256, validate payload, journal/fence/durable decision, quarantine và rollback hiện có. Profile format vẫn2; seal1 cũ được kiểm nguyên thuật toán cũ. Với đúng float mà JSON native không round-trip chính xác, seal metadata2 thêm bảng path/8-byte float64 dạng hex. Cả bảng nằm trong seal. Reader kiểm JSON wire khớp kết quả parser của số gốc, khôi phục exact bits rồi mới kiểm checksum đầy đủ và model. Không làm tròn stat, bỏ đồ, bỏ seal hoặc chấp nhận checksum sai. Opaque byte-span đã giữ có đường riêng hiện hữu; không tạo owner save song song.

Bảng tối đa4.096 số, path tối đa24 phần, chỉ số/kiểu/hex/finite và path trùng được kiểm. Path không được trỏ metadata. Wire mâu thuẫn, bits/stat/đồng bị sửa, schema tương lai hoặc sai kiểu bị từ chối; file tamper không bị ghi đè. Đây là kiểm integrity hiện hữu, không biến SHA không có khóa thành chứng thực chống người có quyền viết và tự tính lại seal.

Save cũ hợp lệ seal1 vẫn load mà không sửa byte; chỉ lần commit được yêu cầu mới dùng seal2 nếu cần exact numbers. Build writer cũ không hiểu seal2 sẽ từ chối/read-only thay vì ghi đè. Hoàn tác code về reader cũ không làm save seal2 đọc được; cần giữ reader mới khi tiếp tục dùng save mới. Không đọc/chỉnh/sao chép save thật của người dùng trong QA hay triển khai này.

## Bằng chứng

- Probe độc lập trên nguồn2088 nguyên vẹn tái hiện lỗi, exit1 dự kiến; log được giữ. Hai thử nghiệm stringify/parse lặp và reliable precision không ổn định/giảm số nên bị loại, không áp vào sản phẩm.
- Source private cuối:250/250 writer regression (migration, current schemas, common transactions, NPC fences, opaque retention, fault/recovery) và64/64 numeric/tamper/old-seal/rollback/recovery; stderr trống. Có207 giá trị nested gồm âm, scientific và subnormal trong ca numeric, bit-exact qua reader.
- All-loot rương thực:11/11, nhặt cả tám pickup, có một gear decimal; về sảnh và cold load giữ UID/quality/stat/đồng, không mở khóa Golem/victory. Bằng chứng private trước guard malformed-type cuối được xác nhận lại bằng bản chính sau áp.
- Bản chính:64/64 numeric và11/11 all-loot bằng headless/profile QA riêng trên source cuối; không thêm GPU/fullsuite/120Hz/import editor. Source/history được đối chiếu hash, bản sao lưu ba file cũ và diễn tập rollback ba file sản phẩm.
- Log numeric r1 có fixture affix ngoài bound0.015 và kỳ vọng UID tạo lại, đã sửa fixture. Lượt r3 tuy60 assertion xanh nhưng có SCRIPT ERROR schema boolean nên không tính đạt; guard kiểu được sửa, r4 và writer cuối sạch. Không lọc/bỏ các log lỗi.

Sản phẩm: một writer sửa, [test focused](../tests/profile_numeric_seal_test.gd) và UID mới. Không đổi GearInventoryCodec, loot/economy, AI, Player/Golem art, TravelerR3, tám file floor-return hoặc giá/cờ quest. Guide/combat vẫn là handoff riêng đang review; chưa chốt ưu tiên1/2 hoặc mở3/4 chỉ từ việc đóng P0 này. Lỗi native editor0xC0000005 lịch sử chưa được sửa bởi thay đổi này.

Receipt/log/diff/sourcefreeze/backups/package local ở workspace `profile_numeric_seal_fix_live2088_20261004_26`. Không upload/publish.
