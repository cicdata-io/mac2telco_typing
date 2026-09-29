# AutoType – gõ tự động nội dung clipboard (macOS)

Hai script "gõ" lại nội dung đang có trong clipboard vào nơi không cho paste (máy ảo, remote desktop, web console của telco).

| Telco | File | Cơ chế | Khi nào dùng |
|---|---|---|---|
| **Viettel (VT)** | [script/autotype_vt.applescript](script/autotype_vt.applescript) | `System Events` → `keystroke` (từng ký tự hoặc theo cụm) | Web console / trình duyệt |
| **VNPT** | [script/autotype_vnpt.applescript](script/autotype_vnpt.applescript) | Gửi **mã phím vật lý** (CGEvent, chương trình Swift nhỏ) | Máy ảo / remote desktop "nuốt" `keystroke` thường |

Hai script cùng một luồng và cùng giao diện:

1. Kiểm tra bộ gõ (phải là **ABC / U.S.**)
2. Chọn tốc độ theo tình trạng mạng (**tự nhớ lựa chọn lần trước**)
3. Hộp xác nhận: số dòng, số ký tự, **thời gian ước tính**, cảnh báo nếu có ký tự không gõ được
4. Đếm ngược 3s để bạn click vào máy ảo, sau đó bắt đầu gõ
5. Gõ xong hoặc bị dừng thì hiện thông báo (dừng ở dòng nào, mất bao lâu)

### Cách DỪNG

| | VT | VNPT |
|---|---|---|
| Bật **Caps Lock** (bấm 1 lần, không cần giữ) | ✅ | ✅ |
| Giữ **Fn / 🌐** (góc dưới-trái bàn phím Mac) | ✅ | ✅ |
| Giữ **ESC** | – | ✅ |

> **Khuyên dùng Fn**: 1 phím, không truyền vào máy ảo.
> Nên vào **System Settings → Keyboard → "Press 🌐 key to"** chọn **Do Nothing**, để bấm Fn không bật bảng emoji hay đổi bộ gõ sang Telex.
>
> Bấm Caps Lock lúc đang ở trong máy ảo thì Caps Lock **trong máy ảo** cũng bật theo. Dừng xong nhớ tắt lại.
> Script sẽ không chạy nếu Caps Lock đang bật từ trước.

---

## Chọn tốc độ

| Chế độ | VT | VNPT |
|---|---|---|
| Nhanh – mạng tốt | cụm 12 ký tự, nghỉ 30ms | 3ms/ký tự, gần như không nghỉ |
| Vừa | cụm 4 ký tự, nghỉ 50ms | 12ms/ký tự |
| **Chậm – mạng yếu (khuyên dùng)** | 1 ký tự / 40ms, nghỉ thêm 40ms sau ký tự cần Shift | như VT |
| Rất chậm – mạng rất lag | 1 ký tự / 100ms | như VT |

Cả hai đều nghỉ dài sau mỗi 150 ký tự (0.2–1s tuỳ chế độ) để remote kịp xả buffer.
**Mẹo:** dùng *Nhanh* khi test ở máy mình. Vào máy ảo thì bắt đầu với *Chậm*; thấy ổn thì lần sau hạ xuống *Vừa*.

---

## Yêu cầu

- macOS, có sẵn **Automator** và **Shortcuts**.
- **VNPT:** cần Swift compiler. Chạy `swift --version` trong Terminal, nếu báo lỗi thì cài bằng `xcode-select --install`.
- **Bộ gõ phải là `ABC` hoặc `U.S.`**. Tắt Telex/VNI/Unikey trước khi chạy, nếu không text sẽ bị loạn dấu.

---

## Cài đặt

### Bước 1 – Tạo app bằng Automator (làm cho từng script)

1. Mở **Automator** → **New Document** → chọn **Application**.
2. Tìm `AppleScript` ở ô bên trái, kéo action **Run AppleScript** sang khung bên phải.
3. Xoá code mẫu, dán **toàn bộ** nội dung file `.applescript`.
4. Bấm nút búa 🔨 (Compile) để kiểm tra không có lỗi.
5. **File → Save**, File Format = **Application**, đặt tên `AutoType VT.app` / `AutoType VNPT.app`, lưu vào `/Applications`.

### Bước 2 – Cấp quyền

**System Settings → Privacy & Security → Accessibility**, bấm `+` rồi bật cho:

- `AutoType VT.app`, `AutoType VNPT.app`
- **Automator**, **Shortcuts**
- Trình duyệt bạn dùng (Chrome / Safari / ...)

Nếu macOS hỏi quyền **Automation** (điều khiển "System Events") hoặc **Notifications** thì chọn **Allow**.

> Mỗi lần sửa và lưu lại app trong Automator, macOS có thể coi đó là app mới. Khi đó vào Accessibility **tắt rồi bật lại** (hoặc xoá rồi thêm lại) app đó.

### Bước 3 – Gán phím tắt bằng Shortcuts

1. Mở **Shortcuts**, bấm `+` tạo shortcut mới.
2. Thêm action **Open App**, chọn app AutoType vừa tạo.
3. Mở phần ⓘ (Details) → **Add Keyboard Shortcut** → bấm tổ hợp phím (vd. `⌃⌥⌘V` cho VT, `⌃⌥⌘B` cho VNPT).

### Bước 4 – Chạy thử

1. Chuyển bộ gõ về **ABC / U.S.**, tắt Caps Lock.
2. Copy một đoạn text, mở Google Docs hoặc TextEdit.
3. Bấm phím tắt → chọn tốc độ **Nhanh** → **Bắt đầu** → trong 3s click vào chỗ cần gõ.
4. Không gõ gì hoặc báo lỗi quyền thì quay lại Bước 2.

> **VNPT – lần chạy đầu tiên** script sẽ biên dịch bộ gõ Swift (vài giây, có thông báo) rồi cache vào `~/Library/Caches/vn.autotype/`. Từ lần sau chạy ngay, không phải chờ.

---

## Giới hạn

- Chỉ gõ được ký tự trên **bàn phím US** (chữ, số, ký hiệu, space, tab, Enter).
  - **VNPT** bỏ qua các ký tự khác (tiếng Việt có dấu, emoji…). Số ký tự bị bỏ qua hiện trong thông báo.
  - **VT** vẫn thử gõ, nhưng qua remote thường ra sai.
  - Hộp xác nhận luôn báo trước số ký tự loại này.
- Ký tự "đẹp" khi copy từ web/Word được tự đổi về ASCII: `“ ”` → `"`, `‘ ’` → `'`, `– —` → `-`, `…` → `...`, dấu cách không ngắt (NBSP) → dấu cách thường.
- Gõ **code** vào editor có auto-indent / auto-close ngoặc (vim, VS Code trong máy ảo…) sẽ bị thụt lề chồng hoặc thừa ngoặc. Nên tắt auto-indent (vd. `:set paste` trong vim) trước khi gõ.

---

## Tuỳ chỉnh

Mọi thông số nằm ở phần `CONFIG` đầu file, và trong `setProfile(...)` của từng chế độ:

- `startDelay`: thời gian đếm ngược (mặc định 3s)
- `breatherEvery`: cứ bao nhiêu ký tự thì nghỉ dài 1 lần (mặc định 150)
- **VT**: `setProfile(chunkSize, chunkDelay, lineDelay, shiftExtra, breatherDelay)`
- **VNPT**: `setProfile(charDelay, lineDelay, shiftExtra, breatherDelay)`, đơn vị giây

Mạng lag, sót ký tự hoặc sai hoa/thường thì tăng `chunkDelay`/`charDelay` và `shiftExtra`.

**VNPT:** code Swift nằm trong handler `swiftSource()`, dạng chuỗi AppleScript, nên mọi `"` và `\` phải escape thành `\"` và `\\`. Sửa code Swift xong thì script tự biên dịch lại ở lần chạy sau (cache theo hash của code).

Chế độ tốc độ đã chọn được lưu ở `defaults read vn.autotype`. Xoá bằng `defaults delete vn.autotype`.

---

## Xử lý lỗi thường gặp

| Hiện tượng | Cách xử lý |
|---|---|
| "CẢNH BÁO BỘ GÕ" | Chuyển input source sang ABC hoặc U.S. |
| Hộp "Caps Lock đang BẬT" | Tắt Caps Lock rồi bấm *Thử lại* |
| "Clipboard đang trống" | Copy lại text (ảnh / file không dùng được) |
| Bấm Bắt đầu nhưng không gõ gì | Thiếu quyền Accessibility → Bước 2, tắt/bật lại quyền cho app |
| `not allowed to send keystrokes` | Thiếu quyền Accessibility/Automation cho app hoặc Shortcuts |
| Text bị loạn dấu | Đang bật Telex/VNI trên Mac **hoặc trong máy ảo** |
| Sót ký tự, sai hoa/thường | Chọn chế độ chậm hơn |
| VNPT: "Không biên dịch được bộ gõ Swift" | `xcode-select --install`, rồi chạy lại |
| VNPT gõ lỗi sau khi cập nhật macOS | `rm -rf ~/Library/Caches/vn.autotype` để biên dịch lại |
