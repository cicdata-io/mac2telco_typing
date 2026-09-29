# Auto Type – gõ nhanh nội dung clipboard (macOS)

Hai script giúp "gõ" nội dung đang có trong clipboard vào những nơi không cho paste (máy ảo, remote desktop, web console...).

| Telco | File | Cơ chế | Phím DỪNG |
|---|---|---|---|
| **VNPT** | [script/autotype_vnpt.applescript](script/autotype_vnpt.applescript) | Gửi **mã phím vật lý** (CGEvent, qua Swift) – ăn được cả máy ảo / remote desktop | Giữ **ESC**, hoặc đưa chuột lên **góc trên-trái** màn hình |
| **Viettel (VT)** | [script/autotype_vt.applescript](script/autotype_vt.applescript) | `System Events` → `keystroke` theo từng cụm 12 ký tự | Giữ **Control + Option (⌃⌥)** |

> **Lưu ý:** Cả 2 chỉ gõ được ký tự ASCII theo bàn phím US. Script VNPT **bỏ qua** ký tự có dấu tiếng Việt; dấu nháy cong `“ ” ‘ ’` và gạch `– —` được đổi thành `" ' -`.

---

## Yêu cầu

- macOS có **Automator** và **Shortcuts** (có sẵn).
- Với `autotype_vnpt`: cần Swift (`xcode-select --install` nếu chạy `swift --version` báo lỗi).
- **Bộ gõ phải là `ABC` hoặc `U.S.`** — tắt Telex/VNI/Unikey trước khi chạy, nếu không text sẽ loạn dấu (script sẽ kiểm tra và cảnh báo).

---

## Bước 1 – Tạo app bằng Automator

Làm lần lượt cho từng script (hoặc chỉ script bạn cần):

1. Mở **Automator** → **New Document** → chọn **Application**.
2. Ở ô tìm kiếm bên trái gõ `AppleScript` → kéo action **Run AppleScript** sang khung bên phải.
3. Xoá code mẫu, dán **toàn bộ** nội dung file `.applescript` vào.
4. Bấm nút búa 🔨 (Compile) để kiểm tra không lỗi.
5. **File → Save**, File Format = **Application**, đặt tên `AutoType VNPT.app` / `AutoType VT.app`, lưu vào `/Applications`.

## Bước 2 – Cấp quyền

Mở **System Settings → Privacy & Security → Accessibility**, bấm `+` và bật cho:

- Các app vừa tạo ở Bước 1 (`AutoType VNPT.app`, `AutoType VT.app`)
- **Automator**
- **Shortcuts**
- Trình duyệt bạn dùng (Chrome / Safari / ...)

Nếu macOS hỏi thêm quyền **Automation** (điều khiển "System Events") hoặc **Input Monitoring** thì chọn **Allow**. Kiểm tra lại ở *Privacy & Security → Automation / Input Monitoring*.

> Sau khi sửa và lưu lại app trong Automator, macOS có thể coi đó là app mới → vào Accessibility **tắt rồi bật lại** (hoặc xoá và thêm lại) quyền cho app đó.

## Bước 3 – Gán phím tắt bằng Shortcuts

1. Mở **Shortcuts** → `+` tạo shortcut mới.
2. Thêm action **Open App** → chọn app auto type vừa tạo.
3. Mở phần ⓘ (Details) của shortcut → **Add Keyboard Shortcut** → bấm tổ hợp phím bạn muốn (vd. `⌃⌥⌘V`).

## Bước 4 – Chạy thử

1. Chuyển bộ gõ về **ABC / U.S.**
2. Copy một đoạn text.
3. Mở Google Docs (hoặc TextEdit) để test trước.
4. Bấm phím tắt → hộp thoại hiện ra → **Bắt đầu** → trong **3 giây** click vào chỗ cần gõ.
5. Nếu không gõ gì hoặc báo lỗi quyền → quay lại Bước 2 xem còn thiếu quyền nào.

Test OK rồi mới dùng trên máy ảo / hệ thống thật.

---

## Tuỳ chỉnh tốc độ

**VT – `script/autotype_vt.applescript`** – sửa phần CONFIG ở đầu file:

```applescript
property chunkSize : 12    -- số ký tự mỗi lần gõ (nhỏ = an toàn hơn)
property chunkDelay : 0.03 -- nghỉ giữa các cụm (giây)
property lineDelay : 0.08  -- nghỉ sau mỗi Enter (giây)
property startDelay : 3    -- đếm ngược trước khi gõ (giây)
```

**VNPT – `script/autotype_vnpt.applescript`** – sửa các `usleep(...)` trong phần Swift (đơn vị micro giây):

- `usleep(3_000_000)` – thời gian chờ trước khi gõ (3s)
- `usleep(code == 36 ? 25_000 : 3_000)` – nghỉ sau Enter / sau mỗi ký tự
- `usleep(12_000)`, `usleep(6_000)` – thời gian giữ Shift; tăng lên nếu VM hay mất chữ hoa / ký tự đặc biệt

VM lag hoặc bị sót ký tự → tăng các delay lên.

---

## Xử lý lỗi thường gặp

| Hiện tượng | Cách xử lý |
|---|---|
| Báo "LOI BO GO" / "CẢNH BÁO BỘ GÕ" | Chuyển input source sang ABC hoặc U.S. |
| Bấm Bắt đầu nhưng không gõ gì | Thiếu quyền Accessibility → Bước 2, bật lại quyền cho app |
| `not allowed to send keystrokes` | Thiếu quyền Accessibility/Automation cho app hoặc Shortcuts |
| Text bị loạn dấu | Đang bật Telex/VNI trên Mac hoặc trong máy ảo |
| Mất chữ hoa, ký tự `!@#...` sai trong VM | Tăng delay giữ Shift (`12_000`, `6_000`) |
| `swift: command not found` | Chạy `xcode-select --install` |
| Script VNPT bấm xong vài giây mới gõ | Bình thường – Swift phải compile code mỗi lần chạy (vài giây) |
