# Sửa thứ tự thoại trong hai fixture NPC cũ

Chỉ thay tests/npc_dialogue_test.gd và tests/opening_loop_test.gd trên bản riêng. Không sửa callback, EconomySession, profile, giá, cân bằng hoặc dữ liệu thoại sản phẩm. Bản chính chưa ghép các test này.

Nguyên nhân đã xác minh: PrologueHub.open_npc thêm một trang số dư Tàn Hồn sau lời thoại Thanh Vy. DialogueBox.select_choice chỉ nhận lựa chọn sau khi đã hiển thị hết trang cuối. Fixture cũ chỉ advance một lần ở trang đầu rồi emit nút còn ẩn hoặc gọi select_choice trực tiếp. Callback không chạy, nên nâng cấp không được mua và healer_consumables không mở; fixture sau đó dereference nút potion chưa tồn tại và treo đến timeout. Hội thoại sau mua còn có trang xác nhận thứ ba; assertion cũ đếm hai trang cũng đã lỗi thời.

Nguồn trước sửa của cả hai test, DialogueBox, PrologueHub, NpcCatalog, EconomySession, SanctuaryProfile và catalog nâng cấp đã được đối chiếu SHA giữa main, private và original_snapshot. Các nguồn runtime liên quan đều khớp; đây không phải hồi quy do bản art hiện tại. Chạy headless cô lập trên MAIN, không import hay đổi nguồn: opening_loop_main_baseline60 tái hiện đúng 311 checks/4 FAIL/exit1; npc_dialogue_main_baseline60 tái hiện 6 FAIL nâng cấp, nil BuyConsumable_potion và timeout15 giây. Mọi save nằm trong QA APPDATA riêng, không dùng save thật.

Fixture mới đi qua các trang bằng input E thật, cuộn đến nút visible/enabled và click mouse thật. Thêm negative control: lựa chọn còn ẩn không trừ Tàn Hồn, không phát callback. Giữ kiểm tra mua đúng một lần, 20 Tàn Hồn/+10 HP, không hồi miễn phí, regeneration, ô Catalyst/inventory/runtime, giá vật phẩm, UID/rank, bounty và save/load. Màn thoại xác nhận được đọc đến đúng trang cuối. Layout matrix cũng đọc đủ trang của từng NPC trước khi thử goodbye. Potion/bandage dùng get_node_or_null kèm assertion thật để lỗi thiếu control kết thúc thành FAIL rõ ràng, không crash/timeout.

Opening loop giữ toàn bộ fault boundaries và kiểm tra vòng nhiệm vụ → Golem → nhặt25 Souls → về Hub → nâng cấp → save/load → trang bị → chết → phục hồi combo. Chỉ thay bước UI nâng cấp bị sai thứ tự; thêm hai assertion chặn lựa chọn trước trang cuối và nút dịch vụ thực. Tổng tăng từ311 lên314 do hai assertion mới và một kiểm tra cold reader trước đây bị short-circuit khi objective chưa complete.

Thực chạy focused headless, bốn receipt đều exit0, diagnostics rỗng:

- npc_dialogue_order_final60 và final120: mỗi96/96.
- opening_loop_order_final60 và final120: mỗi314/314.

Baseline strict và nguồn test cũ được giữ ngoài sản phẩm tại spell_work/legacy_npc_baseline_rejected. Hai baseline MAIN và bốn focused receipt giữ raw stdout/stderr/RUN_RESULT trong probes/. LEGACY_NPC_FIXTURE_MANIFEST.json chứa các SHA đối chiếu và SHA payload cuối. Kiểm logic/input này không chứng minh trải nghiệm tự nhiên hay native readability; root integrator chạy gate strict đầy đủ cuối và là đầu mối ghép main.
