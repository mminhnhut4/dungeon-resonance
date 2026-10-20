# Nguồn bộ ứng viên lực chém/chưởng

Ứng viên ngoại tuyến, chưa được nghe duyệt. Chỉ dùng các file trong hai bộ CC0
đã lưu từ đợt review `2cb05e7cb5cd0e5433dc7c10178f407834241cf9`.
Không tải thêm nguồn, không dùng derivative `af52`.

| Tác giả / bộ | Nguồn đã lưu | Xuất xứ được xác nhận ở cấp bộ |
|---|---|---|
| artisticdude / Swishes Sound Pack | https://opengameart.org/content/swishes-sound-pack | Tác giả mô tả thu móc áo/que gỗ bằng camcorder và biên tập trong Logic Express. |
| rubberduck / 100 CC0 SFX | https://opengameart.org/content/100-cc0-sfx | Tác giả mô tả thu bằng thiết bị Android. Các file phân phối là Ogg. |

Giấy phép được ghi trên trang nguồn: CC0 1.0,
https://creativecommons.org/publicdomain/zero/1.0/.
Giữ credit và provenance để đối chiếu. Không có bằng chứng vật thể, microphone
hoặc chuỗi xử lý cụ thể cho từng file; tên `hit`, `metal`, `wooden` không chứng
minh đó là kiếm, thịt hoặc giáp thực.

Nguồn gốc trên máy:
`combat-sfx-review-20261019/sources/`, gồm HTML trang tác giả, hai ZIP và các
file âm giải nén. Audit riêng đã đối chiếu 113/113 file âm với member byte trong
hai ZIP; 7 hash tải/trang trong các manifest cũ đều khớp.

| Dữ liệu đã lưu | SHA-256 |
|---|---|
| `rubberduck-page.html` | `9c6eb3d53618feeeed570a64a5dc6b427d6b2975cefa019c8f32a8c92dd1e371` |
| `rubberduck-100cc0.zip` | `a5c135878c132f1c59cca54e60061c296cd0ac27ad031ca2c41b8cd5cab3c706` |
| `swishes-page.html` | `88aa1070a8e63e11c771c7016afc12520c8818584b1ef30ac4f499b66f28ad45` |
| `swishes.zip` | `7980215241b739a787dcf26f660ce510bb237900968789395a86911619795693` |

Các cue mới dùng:

- `melee_impact`: `hit_01`, `hit_02`, `hit_03`.
- `armor_impact`: `metal_02`, `metal_03`, `metal_06`.
- `spell_cast`: `swish-13`, `swish-10`, `paper_01`, `paper_04`.
- `spell_impact`: `hit_03`, `hit_04`, `wooden_01`.
- Hai `sword_swing` được sao chép nguyên byte từ bộ hiện tại; nguồn cũ là
  `swish-7` và `swish-12`.

`BUILD_MANIFEST.json` ghi hash từng raw file, crop theo sample, offset,
weight/gain, fade, hash WAV/TRES/PCM và hash builder/FFmpeg. Decode stereo mean
về 48 kHz, giữ pitch, tối đa hai lớp nguồn thu cho mỗi cue. Mọi fade hữu hạn;
gain phối cuối chỉ giảm hoặc giữ mức. Không có oscillator, noise sinh, EQ,
reverb, echo, compressor, limiter, loop hoặc time stretch trong derivative.

Các WAV là bản nghe cùng PCM với Resource `.tres`; không có runtime file I/O
hoặc importer mới được thêm trong phần chuẩn bị này.
