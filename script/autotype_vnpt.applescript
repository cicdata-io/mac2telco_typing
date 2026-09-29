use framework "AppKit"
use scripting additions
-- AutoType VNPT: gõ clipboard bằng MÃ PHÍM VẬT LÝ (CGEvent qua Swift) -> ăn được máy ảo / remote desktop
-- Lần chạy đầu tiên sẽ biên dịch bộ gõ Swift (~10-20s) và cache ở ~/Library/Caches/vn.autotype
-- ============ CONFIG ============
property startDelay : 3 -- đếm ngược trước khi gõ (s)
property breatherEvery : 150 -- cứ N ký tự thì nghỉ dài 1 lần cho remote xả buffer
property prefKey : "vnpt.profile" -- nhớ chế độ tốc độ lần trước (defaults domain vn.autotype)
-- Các giá trị dưới được gán lại theo chế độ chọn lúc chạy
property charDelay : 0.04 -- nghỉ sau mỗi ký tự (s)
property lineDelay : 0.35 -- nghỉ sau Enter (s)
property shiftExtra : 0.04 -- nghỉ thêm sau ký tự cần Shift (s)
property breatherDelay : 0.6 -- thời gian nghỉ dài (s)
-- DỪNG: bật Caps Lock, giữ Fn / 🌐, hoặc giữ ESC
on run
	-- 0) Chuẩn bị bộ gõ Swift (chỉ biên dịch lần đầu / khi code đổi)
	set typer to prepareTyper()
	if typer is "" then return
	-- 1) Kiểm tra bộ gõ
	if not inputSourceOK() then return
	-- 2) Chọn tốc độ theo tình trạng mạng
	set profiles to {"Nhanh – mạng tốt", "Vừa", "Chậm – mạng yếu (khuyên dùng)", "Rất chậm – mạng rất lag"}
	set idx to pickProfile(profiles, prefKey)
	if idx = 0 then return
	if idx = 1 then
		setProfile(0.003, 0.025, 0, 0)
	else if idx = 2 then
		setProfile(0.012, 0.1, 0.01, 0.3)
	else if idx = 3 then
		setProfile(0.04, 0.35, 0.04, 0.6)
	else
		setProfile(0.1, 0.6, 0.08, 1.0)
	end if
	-- 3) Đọc clipboard (qua Swift để đếm đúng như lúc gõ) + ước tính thời gian
	set stats to splitText(do shell script quoted form of typer & " stats", "|")
	set totalChars to (item 1 of stats) as integer
	set lineCount to (item 2 of stats) as integer
	set shiftCount to (item 3 of stats) as integer
	set unsupported to (item 4 of stats) as integer
	-- 7ms = nhấn/nhả phím, 22ms = giữ/nhả Shift (cố định trong code Swift)
	set estSec to totalChars * (charDelay + 0.007) + lineCount * lineDelay + shiftCount * (shiftExtra + 0.022) + (totalChars div breatherEvery) * breatherDelay
	set estSec to round estSec rounding up
	if not confirmStart(item idx of profiles, lineCount, totalChars, estSec, unsupported, "AutoType VNPT") then return
	set t0 to current date
	delay startDelay
	-- 4) Gõ
	set envVars to "AT_CHAR_MS=" & toMs(charDelay) & " AT_LINE_MS=" & toMs(lineDelay) & " AT_SHIFT_MS=" & toMs(shiftExtra) & " AT_BREATHER_MS=" & toMs(breatherDelay) & " AT_BREATHER_EVERY=" & breatherEvery
	set outcome to splitText(do shell script envVars & " " & quoted form of typer & " type", "|")
	set skippedNote to ""
	if (item 3 of outcome) as integer > 0 then set skippedNote to " (bỏ qua " & (item 3 of outcome) & " ký tự)"
	if item 1 of outcome is "abort" then
		beep
		display notification "Đã dừng tại dòng " & (item 2 of outcome) & "/" & lineCount & skippedNote & " (Caps Lock / Fn / ESC)" with title "AutoType VNPT"
	else
		display notification "Hoàn tất " & lineCount & " dòng trong " & ((current date) - t0) & "s" & skippedNote with title "AutoType VNPT"
	end if
end run
on setProfile(cd, ld, se, bd)
	set charDelay to cd
	set lineDelay to ld
	set shiftExtra to se
	set breatherDelay to bd
end setProfile
on toMs(s)
	return (round (s * 1000)) as integer
end toMs
on splitText(t, d)
	set oldTID to AppleScript's text item delimiters
	set AppleScript's text item delimiters to d
	set parts to text items of t
	set AppleScript's text item delimiters to oldTID
	return parts
end splitText
-- Biên dịch Swift 1 lần rồi cache theo hash của code -> các lần sau chạy tức thì (thay cho `swift -` mỗi lần mất vài giây)
on prepareTyper()
	set code to swiftSource()
	set cacheDir to (POSIX path of (path to library folder from user domain)) & "Caches/vn.autotype"
	set srcHash to do shell script "printf %s " & quoted form of code & " | shasum | cut -c1-12"
	set binPath to cacheDir & "/typer_" & srcHash
	try
		do shell script "test -x " & quoted form of binPath
	on error
		display notification "Lần đầu chạy: đang biên dịch bộ gõ (~10-20s)…" with title "AutoType VNPT"
		try
			do shell script "mkdir -p " & quoted form of cacheDir & " && rm -f " & quoted form of cacheDir & "/typer_* && printf %s " & quoted form of code & " > " & quoted form of (binPath & ".swift") & " && swiftc -O " & quoted form of (binPath & ".swift") & " -o " & quoted form of binPath & " 2>&1"
		on error errMsg
			display dialog "Không biên dịch được bộ gõ Swift." & return & return & "Cài Command Line Tools bằng lệnh:" & return & "xcode-select --install" & return & return & errMsg with title "AutoType VNPT" buttons {"OK"} default button "OK" with icon stop
			return ""
		end try
	end try
	return binPath
end prepareTyper
on swiftSource()
	return "import Foundation
import AppKit
import CoreGraphics

// Tham số truyền qua biến môi trường (đơn vị ms, số nguyên để khỏi dính dấu thập phân theo locale)
let env = ProcessInfo.processInfo.environment
func ms(_ key: String, _ def: Int) -> useconds_t { useconds_t(max(0, Int(env[key] ?? \"\") ?? def) * 1000) }
let charDelay = ms(\"AT_CHAR_MS\", 40)
let lineDelay = ms(\"AT_LINE_MS\", 350)
let shiftExtra = ms(\"AT_SHIFT_MS\", 40)
let breatherDelay = ms(\"AT_BREATHER_MS\", 600)
let breatherEvery = Int(env[\"AT_BREATHER_EVERY\"] ?? \"\") ?? 150

// Mã phím vật lý theo bàn phím US: (keycode, cần Shift)
var keyMap: [Character: (CGKeyCode, Bool)] = [\" \": (49, false), \"\\n\": (36, false), \"\\t\": (48, false)]
let letterCodes: [CGKeyCode] = [0, 11, 8, 2, 14, 3, 5, 4, 34, 38, 40, 37, 46, 45, 31, 35, 12, 15, 1, 17, 32, 9, 13, 7, 16, 6]
for (ch, code) in zip(\"abcdefghijklmnopqrstuvwxyz\", letterCodes) {
    keyMap[ch] = (code, false)
    keyMap[Character(ch.uppercased())] = (code, true)
}
let symbolCodes: [CGKeyCode] = [18, 19, 20, 21, 23, 22, 26, 28, 25, 29, 27, 24, 33, 30, 42, 41, 39, 43, 47, 44, 50]
for ((plain, shifted), code) in zip(zip(\"1234567890-=[]\\\\;',./`\", \"!@#$%^&*()_+{}|:\\\"<>?~\"), symbolCodes) {
    keyMap[plain] = (code, false)
    keyMap[shifted] = (code, true)
}

// Đổi ký tự \"đẹp\" khi copy từ web/Word về ASCII; CRLF/CR -> LF (Swift coi \"\\r\\n\" là 1 ký tự)
func normalized(_ s: String) -> String {
    var t = s
    let pairs = [(\"\\r\\n\", \"\\n\"), (\"\\r\", \"\\n\"), (\"\\u{201C}\", \"\\\"\"), (\"\\u{201D}\", \"\\\"\"), (\"\\u{2018}\", \"'\"), (\"\\u{2019}\", \"'\"),
                 (\"\\u{2013}\", \"-\"), (\"\\u{2014}\", \"-\"), (\"\\u{2026}\", \"...\"), (\"\\u{00A0}\", \" \")]
    for (a, b) in pairs { t = t.replacingOccurrences(of: a, with: b) }
    return t
}

// DỪNG: Caps Lock bật, giữ Fn (🌐), hoặc giữ ESC
func shouldAbort() -> Bool {
    let f = CGEventSource.flagsState(.combinedSessionState)
    return f.contains(.maskAlphaShift)
        || f.contains(.maskSecondaryFn)
        || CGEventSource.keyState(.combinedSessionState, key: 53)
}

let source = CGEventSource(stateID: .hidSystemState)
let shiftKey: CGKeyCode = 56
func post(_ code: CGKeyCode, down: Bool, shift: Bool) {
    let e = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down)
    if shift { e?.flags = .maskShift }
    e?.post(tap: .cghidEventTap)
}
func press(_ code: CGKeyCode, shift: Bool) {
    if shift {
        post(shiftKey, down: true, shift: true)
        usleep(12_000) // cho VM kịp nhận Shift
    }
    post(code, down: true, shift: shift)
    usleep(4_000)
    post(code, down: false, shift: shift)
    if shift {
        usleep(6_000) // giữ Shift thêm chút rồi mới nhả
        post(shiftKey, down: false, shift: false)
        usleep(4_000)
    }
}

let text = normalized(NSPasteboard.general.string(forType: .string) ?? \"\")

// \"stats\": in ra \"ký tự|dòng|ký tự cần Shift|ký tự không gõ được\" để AppleScript ước tính thời gian
if CommandLine.arguments.dropFirst().first == \"stats\" {
    var lines = 1, shifted = 0, unsupported = 0
    for ch in text {
        guard let (code, shift) = keyMap[ch] else { unsupported += 1; continue }
        if code == 36 { lines += 1 }
        if shift { shifted += 1 }
    }
    print(\"\\(text.count)|\\(lines)|\\(shifted)|\\(unsupported)\")
    exit(0)
}

// Gõ: in ra \"done|dòng|bỏ qua\" hoặc \"abort|dòng|bỏ qua\"
var line = 1, skipped = 0, sinceBreather = 0
for ch in text {
    if shouldAbort() {
        print(\"abort|\\(line)|\\(skipped)\")
        exit(0)
    }
    guard let (code, shift) = keyMap[ch] else { skipped += 1; continue }
    press(code, shift: shift)
    if code == 36 {
        line += 1
        usleep(lineDelay)
    } else {
        usleep(charDelay)
        if shift { usleep(shiftExtra) }
    }
    sinceBreather += 1
    if breatherEvery > 0 && sinceBreather >= breatherEvery {
        sinceBreather = 0
        usleep(breatherDelay) // nghỉ dài cho remote xả buffer
    }
}
print(\"done|\\(line)|\\(skipped)\")"
end swiftSource

-- ============ PHẦN CHUNG (giống hệt autotype_vt) ============
-- True nếu Caps Lock đang BẬT, hoặc đang giữ Fn / 🌐
on isAbortHeld()
	set f to (current application's NSEvent's modifierFlags()) as integer
	set capsOn to ((f div 65536) mod 2) = 1 -- NSEventModifierFlagCapsLock
	set fnHeld to ((f div 8388608) mod 2) = 1 -- NSEventModifierFlagFunction
	return capsOn or fnHeld
end isAbortHeld
on isCapsLockOn()
	set f to (current application's NSEvent's modifierFlags()) as integer
	return ((f div 65536) mod 2) = 1
end isCapsLockOn
on inputSourceOK()
	set currentInputSource to getInputSource()
	set okLayouts to {"com.apple.keylayout.ABC", "com.apple.keylayout.US", "ABC", "US", "U.S."}
	if okLayouts contains currentInputSource then return true
	set userChoice to display dialog ¬
		"CẢNH BÁO BỘ GÕ: Hệ thống nhận diện [" & currentInputSource & "]" & return & return & ¬
		"Nếu đang bật Tiếng Việt, text sẽ bị loạn dấu. Hãy chuyển về US/ABC!" with title "Kiểm tra bộ gõ" buttons {"Hủy", "Vẫn gõ"} default button "Hủy" with icon caution
	return button returned of userChoice is "Vẫn gõ"
end inputSourceOK
on getInputSource()
	try
		set src to do shell script "defaults read com.apple.HIToolbox AppleSelectedInputSources | grep '\"Input Mode\"' | head -n 1 | awk -F'\"' '{print $4}'"
		if src is "" then
			set src to do shell script "defaults read com.apple.HIToolbox AppleSelectedInputSources | grep '\"KeyboardLayout Name\"' | head -n 1 | awk -F'=' '{print $2}' | tr -d ' ;\"'"
		end if
		if src is "" then set src to "Không xác định"
	on error
		set src to "Không xác định"
	end try
	return src
end getInputSource
-- Hộp chọn tốc độ, mặc định là chế độ dùng lần trước. Trả về 1..4, 0 nếu Hủy.
on pickProfile(profiles, key)
	set lastIdx to 3
	try
		set lastIdx to (do shell script "defaults read vn.autotype " & key) as integer
	end try
	if lastIdx < 1 or lastIdx > (count of profiles) then set lastIdx to 3
	set picked to choose from list profiles with title "Tốc độ gõ" with prompt "Mạng tới máy ảo đang thế nào?" default items {item lastIdx of profiles}
	if picked is false then return 0
	set picked to item 1 of picked
	repeat with i from 1 to count of profiles
		if item i of profiles is picked then
			try
				do shell script "defaults write vn.autotype " & key & " -int " & i
			end try
			return i
		end if
	end repeat
	return 0
end pickProfile
-- Hộp xác nhận + bắt tắt Caps Lock. Trả về false nếu Hủy.
on confirmStart(profileName, lineCount, totalChars, estSec, unsupported, appTitle)
	if totalChars = 0 then
		display dialog "Clipboard đang trống (hoặc không phải text)." with title appTitle buttons {"OK"} default button "OK" with icon stop
		return false
	end if
	set warn to ""
	if unsupported > 0 then set warn to return & "⚠️ " & unsupported & " ký tự ngoài bàn phím US (tiếng Việt có dấu, emoji…) có thể bị bỏ qua / sai." & return
	try
		display dialog ¬
			"Chế độ: " & profileName & return & ¬
			lineCount & " dòng, " & totalChars & " ký tự, ước tính ~" & estSec & "s." & return & warn & return & ¬
			"Bật CAPS LOCK (hoặc giữ Fn / 🌐) bất cứ lúc nào để DỪNG." & return & ¬
			"Nhấn 'Bắt đầu', bạn có " & startDelay & "s để click vào máy ảo." with title appTitle buttons {"Hủy", "Bắt đầu"} default button "Bắt đầu" cancel button "Hủy"
		-- Caps Lock đang bật thì script sẽ dừng ngay, nên bắt tắt trước
		repeat while isCapsLockOn()
			display dialog "Caps Lock đang BẬT." & return & "Hãy tắt Caps Lock rồi bấm 'Thử lại'." with title "Caps Lock" buttons {"Hủy", "Thử lại"} default button "Thử lại" cancel button "Hủy" with icon caution
		end repeat
	on error number -128
		return false
	end try
	return true
end confirmStart
-- Đổi ký tự "đẹp" hay gặp khi copy từ web/Word về ASCII: “ ” ‘ ’ – — … và NBSP
on normalizeText(t)
	set pairs to {{character id 8220, "\""}, {character id 8221, "\""}, {character id 8216, "'"}, {character id 8217, "'"}, {character id 8211, "-"}, {character id 8212, "-"}, {character id 8230, "..."}, {character id 160, " "}}
	set oldTID to AppleScript's text item delimiters
	repeat with p in pairs
		set AppleScript's text item delimiters to item 1 of p
		set parts to text items of t
		set AppleScript's text item delimiters to item 2 of p
		set t to parts as text
	end repeat
	set AppleScript's text item delimiters to oldTID
	return t
end normalizeText
-- Đếm ký tự không gõ được bằng bàn phím US (ngoài ASCII in được, tab, xuống dòng)
on countUnsupported(t)
	if t is "" then return 0
	set n to 0
	repeat with c in ((id of t) as list)
		set c to c as integer
		if c > 126 or (c < 32 and c is not in {9, 10, 13}) then set n to n + 1
	end repeat
	return n
end countUnsupported
