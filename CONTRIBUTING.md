# Đóng góp vào Dungeon Resonance

Bắt đầu ở [docs/team/START_HERE.md](docs/team/START_HERE.md). Godot4.7.2/Compatibility, nhánh riêng và save QA. Chủ dự án giữ quyết định; một integrator ghép main.

```powershell
git clone https://github.com/mminhnhut4/dungeon-resonance.git
cd dungeon-resonance
git switch main
git pull --ff-only
git switch -c fix/dr-002-small-window-layout
# Sửa, kiểm tra và review diff; thay tên nhánh theo task của mình.
git add <cac-file-cua-task>
git commit -m "Fix DR-002 quest layout in small windows"
git push -u origin HEAD
```

Mở PR nhánh→main. Không force-push/main trực tiếp, chép ZIP đè checkout đang sửa hoặc commit cache/save/engine/log QA. Trước pull, commit/stash phần của mình nếu checkout bẩn; không reset--hard để dọn. Conflict file chung cần owner đối chiếu từng hunk/hành vi. Đăng nhập Git bằng luồng chính thức trên máy; không đưa token/mật khẩu vào chat/URL remote.

Giữ .gd.uid và asset .import sidecar settings; .godot được tái import. Giữ license addon/font và nguồn asset; chưa áp license chung cho dự án. Không commit pointer LFS nếu nhóm chưa chọn LFS; source hiện tại mở được không cần LFS. File mới lớn trao đổi integrator trước.

PR mô tả problem→hành vi sau→files/owner→validation thật→risk/pending. Gameplay/data cần test hành vi liên quan; visual cần ảnh native; save cần cold-load/rollback. Strict mặc định là gate mốc tích hợp, GameplayOnly chỉ chẩn đoán. Xem [QA](docs/team/QA_AND_HANDOFF.md).

Owner repo mời thành viên tại Settings→Collaborators/Manage access→Add people bằng username chính xác; người được mời nhận invitation rồi mới clone/push repo private. Link không tự cấp quyền. [Hướng dẫn GitHub](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/repository-access-and-collaboration/inviting-collaborators-to-a-personal-repository). Nhóm điền owner/reviewer trong BACKLOG; integrator giữ đầu mối merge.
