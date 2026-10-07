# Procedural SFX

Gameplay sinh năm `AudioStreamWAV` PCM mono 16-bit, 22.050 Hz một lần khi AudioManager khởi tạo. Dữ liệu được tổng hợp từ sine/chirp và noise có seed; không tải file bên ngoài, không loop, không cần Aseprite hay dịch vụ mạng.

`polish_sfx_preview.wav` là bản nghe thử nối lần lượt: **vung kiếm → dash → nổ phép → quái gầm → nhận đòn**. Mỗi cue cách nhau 0,35 giây im lặng. File nghe thử không được gameplay tự phát.

Tạo lại preview bằng Godot CLI với `--headless --script res://tests/audio_test.gd -- --export-audio`. Playback thật qua WASAPI có thể kiểm yên lặng bằng `--headless --audio-driver WASAPI --script res://tests/audio_test.gd -- --silent-output`; test chỉ mute bus DungeonSFX của tiến trình đó.

Âm thanh là dữ liệu tổng hợp nguyên bản của dự án, không chứa sample bên thứ ba. PCM đã kiểm RMS > 0,015, peak < 0,86 và hai đầu về zero. Chất âm vẫn cần đánh giá bằng tai trong playtest.

Autoload `/root/AudioManager` nhận sự kiện đóng cửa sổ và trì hoãn thoát ít nhất 80 ms theo wall-clock để mixer thật giải phóng playback. Các nút Thoát dùng `AudioManager.request_quit()`; yêu cầu lặp được gộp. Manager test riêng không thay chính sách đóng cửa sổ. `tests/audio_quit_test.gd` kiểm đóng khi 12 cue còn hoạt động; WASAPI được mute riêng trong probe.
