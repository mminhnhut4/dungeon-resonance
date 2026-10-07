# Migration theo từng batch

Đây là proposal/đích đến để review trước migration runtime. **Batch0 navigation và bộ tài liệu đã đưa vào bản chính; chưa move runtime.** Nhật ký/AGENTS đã áp theo yêu cầu riêng và có backup/receipt. Dừng migration code cho đến khi AI/map handoff chốt.

| Batch | Phạm vi và trạng thái | Kiểm tối thiểu / điều kiện |
|---|---|---|
| 0 — navigation | README navigation, modulemap, conventions, catalog và history index đã có trên bản chính. GeneratedQA review/copies vẫn ở workspace riêng. Runtime không đổi. | Markdown link/Unicode, catalog200 unique current paths/targets, UID pairs, hash toàn runtime/data/assets/scenes. Không Godot/fullsuite/GPU. Không nhận là đã migration code; review từng batch runtime sau AI/map. |
| 1 — một leaf | Candidate đầu tiên: `scripts/runtime/profile_json_spans.gd` cùng UID → `scripts/core/persistence/profile_json_spans.gd`, nếu dependency/reference audit mới vẫn hẹp. Writer/test preload phải đổi cùng batch. Chưa thực hiện. | Refresh live freeze sau owner merges; enumerate literal refs cả tests/tools/docs/scenes, giữ class/API/UID/script logic; import một lần; `tests/profile_json_spans_test.gd` và focused writer span/opaque regression từ receipt tương ứng. Không tự chạy mọi save suite/120Hz. Rehearse rollback; review exact path-only diff trước original apply. |
| 2 — nội dung domain | Gom logical definitions/resources vào items/talisman, tối đa3–5 leaf scripts/batch. Không đụng `data/*.tres` IDs/values và current scene paths nếu chưa cần. Chưa thực hiện. | Path refs + UID checks + import; chọn `content_data_test.gd` hoặc `resonance_test.gd`/`gear_test.gd` đúng phần đổi. Exact multiset và immutable runtime ownership giữ nguyên. Không đồng thời đổi logic. |
| 3 — sessions/world | Gear/Content/SurvivalSession và application persistence là composition roots; nhận đề xuất folder mới sau khi dependency seams đã review. Hub/GameFlow/WorldCampaign hold. | Chờ map+AI handoff; verify UID transfer, return/save rollback, room/clock lifetime bằng subset tồn tại. Scene hierarchy/collider/hitbox unchanged. Không tách God object bằng đoán. |
| 4 — actors/NPC/presentation | Actor/player/FSM và hai NPC actor scripts không move khi AI/map/road-art đang ghép. UI/presentation paths đang khá rõ, ưu tiên giữ. | Chờ owner kết thúc, có current live freeze; chọn actor/UI regression đúng seam. GPU chỉ nếu hình/animation/layout đổi, không cho path-only audit. |
| 5 — docs/history/evidence | Navigation/index đã áp riêng theo yêu cầu tổ chức dự án. Giữ report/evidence cũ tại chỗ bằng index; migration history thật chỉ khi backlinks đã liệt kê. New QA output đi workspace `generated/qa`, không `res://docs/verification`. | Hash-copy/rewrite catalog/backlinks, `.gdignore`, source attribution. Không xóa backup, staging/archive, raw failure hoặc node_modules gốc. Không đụng `.godot`, user-data hoặc user files ngoài scope. |

Đích thư mục là hướng cho file mới, không lệnh đổi200script một lượt:

```text
scripts/core/{state_machine,ids,clocks,persistence,audio}
scripts/gameplay/{actors,combat,items,talisman,cultivation,quests,survival}
scripts/world/{flow,hub,dungeon,sessions,interactions,persistence}
scripts/npc/                     # resident / social / vendor services
scripts/ui/                      # native views + input/modal
scripts/presentation/            # rig / art / VFX / cosmetic audio
data/ assets/ scenes/ addons/     # giữ current paths trước
tests/ tools/                    # giữ runner; nhóm bằng index trước
docs/architecture/ docs/history/
nhật ký vấp ngã/
```

Mỗi row trong catalog là current path, proposed path, module, UID/hash và trạng thái HOLD/DEFERRED/KEEP. Class refs không bắt đủ literal preload/dynamic `%s` paths; phải xem scan path và tìm bổ sung trước từng move. Không coi catalog là authorization apply.

Khi báo kết quả, tách “private docs/proposal”, “path migration đã áp” và “gameplay/content mới”. Hầm đầu dungeon khác P02 ngoài trời; audit không thiết kế lại map hoặc sửa AI/NPC.
