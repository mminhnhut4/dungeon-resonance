# Cache writer: cô lập fixture — 2026-10-08

Freeze source **01:06:49 UTC**. Chỉ sửa private `tests/profile_writer_cache_test.gd`; không sửa writer/runtime, không xóa profile có sẵn, không đụng save thật hoặc main. Root ghép sau strict cuối.

## Nguyên nhân đã xác minh

Test baseline/main/private trước sửa cùng SHA256 `1DEF835C1C474253CF65587B642F3721B651259214AA058C50CF1915A201E47A`. ProfileCommitWriter cùng SHA `0BC848080EA3A1C48EEB5D3F048EB205B0C111EA9419BC33F967A6176692A584`; SanctuaryProfile cùng SHA `D15EA10DED9A2C153208D244463DDCCAEF6A23F3D82195DA33B3034EC85E366E` ở cả ba bản.

Strict chạy 60 rồi 120 Hz trong cùng QaDataRoot. Test cũ luôn dùng `user://verification/writer_cache.json`. Lần 60 lưu v2 có seal rồi ghi ngoại sinh một authority hợp lệ. Lần 120 tạo SanctuaryProfile mặc định v1 và cố ghi cùng file. Writer đã đọc được v2 và từ chối downgrade đúng luật `invalid_or_downgraded_v2` tại ProfileCommitWriter._commit_owned. Sau thất bại startup, test cũ vẫn truy cập next_event/payload chưa có nên SCRIPT ERROR rồi không quit, tạo timeout. Đây là lỗi fixture path và điều khiển thất bại, không phải writer bỏ qua authority.

Tái hiện hẹp độc lập trong cùng QA root `DgCacheSharedProof_20261008`: old_shared60 **8/8, exit0**; old_shared120_guarded **startup FAIL, exit1**, in rõ `invalid_or_downgraded_v2`. Bản external lần 120 chỉ thêm fail-fast sau startup để giữ bằng chứng từ chối mà không lặp timeout/Nil. SHA file authority trước/sau vẫn `194079D27D16170B3F14B3E7129F83741E841B7CF0B0DC7154BF2EBA91D0B4FE`; không xóa hoặc ghi đè.

## Sửa và kiểm thử

Fixture mới đọc --hz, yêu cầu QA user directory cô lập và dùng đường dẫn `writer_cache_<pid>_<hz>_<usec>.json`. Các bước startup/migration/payload/disk có guard: thất bại ghi FAIL rồi quit, không truy cập dữ liệu Nil. Giữ nguyên 8 assertion của luồng thành công và tăng điều kiện payload sử dụng được; không bỏ negative authority, seal hoặc byte rollback.

Hai lần focused chạy **liên tiếp và dùng cùng QA root vẫn chứa file authority cũ**:

| Receipt | Fixed FPS / Physics Hz | Kết quả | Đường dẫn fixture mới |
| --- | --- | --- | --- |
| isolated_shared60 | 60 / 60 | **8/8, exit0, diagnostics[]** | writer_cache_4592_60_366139.json |
| isolated_shared120 | 120 / 120 | **8/8, exit0, diagnostics[]** | writer_cache_17984_120_364359.json |

Cả hai vẫn thực hiện legacy save thật, migrate seal, durable mastery, mutate returned payload, kiểm seal/mastery chính xác, ghi external valid revision, stale-owner rejection `profile_changed_reload_required`, giữ byte ngoại sinh/rollback RAM và cold-load authority thực. File authority va chạm cũ không đổi sau hai test mới.

Runner external `profile_cache_work/run_probe.ps1 -Headless -Script res://tests/profile_writer_cache_test.gd -ProfileRoot <same QA root> -FixedFps 60/120`; lần 120 thêm `-UserArgs --hz=120`. Start-Process Hidden, cùng Godot 4.7.2, không import, không GPU/fullsuite. Raw stdout/stderr/RUN_RESULT.json và source/hash đầy đủ ở `PROFILE_CACHE_PAYLOAD_MANIFEST.json`.

Không claim sửa native crash C0000005. Strict lần trước có timeout vẫn FAILED; root cần kết quả strict mới sau freeze. Báo cáo này chỉ chứng minh cô lập fixture và nguyên vẹn luật writer trong mẫu hẹp.
