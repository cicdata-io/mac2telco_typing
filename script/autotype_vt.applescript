use framework "AppKit"
use scripting additions
-- AutoType VT (Viettel): gõ clipboard bằng System Events keystroke
-- ============ CONFIG ============
property startDelay : 3 -- đếm ngược trước khi gõ (s)
property breatherEvery : 150 -- cứ N ký tự thì nghỉ dài 1 lần cho remote xả buffer
property prefKey : "vt.profile" -- nhớ chế độ tốc độ lần trước (defaults domain vn.autotype)
-- Các giá trị dưới được gán lại theo chế độ chọn lúc chạy
property chunkSize : 1 -- số ký tự mỗi lần bắn
property chunkDelay : 0.05 -- nghỉ giữa các lần bắn (s)
property lineDelay : 0.3 -- nghỉ sau Enter (s)
property shiftExtra : 0.04 -- nghỉ thêm sau ký tự cần Shift (s)
property breatherDelay : 0.6 -- thời gian nghỉ dài (s)
property typedCount : 0
property shiftChars : "~!@#$%^&*()_+{}|:\"<>?ABCDEFGHIJKLMNOPQRSTUVWXYZ"
-- DỪNG: bật Caps Lock, hoặc giữ Fn / 🌐
on run
	set typedCount to 0
	-- 1) Kiểm tra bộ gõ
	if not inputSourceOK() then return
	-- 2) Chọn tốc độ theo tình trạng mạng
	set profiles to {"Nhanh – mạng tốt", "Vừa", "Chậm – mạng yếu (khuyên dùng)", "Rất chậm – mạng rất lag"}
	set idx to pickProfile(profiles, prefKey)
	if idx = 0 then return
	if idx = 1 then
		setProfile(12, 0.03, 0.08, 0, 0.2)
	else if idx = 2 then
		setProfile(4, 0.05, 0.2, 0.02, 0.4)
	else if idx = 3 then
		setProfile(1, 0.04, 0.35, 0.04, 0.6)
	else
		setProfile(1, 0.1, 0.6, 0.08, 1.0)
	end if
	-- 3) Đọc clipboard + ước tính thời gian
	set clipboardText to normalizeText(the clipboard as text)
	set textLines to paragraphs of clipboardText
	set lineCount to count of textLines
	set totalChars to count of clipboardText
	set estSec to (totalChars / chunkSize) * chunkDelay + lineCount * lineDelay + (totalChars div breatherEvery) * breatherDelay
	set estSec to round estSec rounding up
	if not confirmStart(item idx of profiles, lineCount, totalChars, estSec, countUnsupported(clipboardText), "AutoType VT") then return
	set t0 to current date
	delay startDelay
	-- 4) Gõ (Enter chỉ bấm GIỮA các dòng -> giữ đúng xuống dòng như text gốc)
	repeat with i from 1 to lineCount
		if isAbortHeld() then
			beep
			display notification "Đã dừng tại dòng " & i & "/" & lineCount & " (Caps Lock / Fn)" with title "AutoType VT"
			return
		end if
		set thisLine to (item i of textLines) as string
		if thisLine is not "" then typeLine(thisLine)
		if i < lineCount then
			tell application "System Events" to key code 36 -- Enter
			delay lineDelay
		end if
	end repeat
	display notification "Hoàn tất " & lineCount & " dòng trong " & ((current date) - t0) & "s" with title "AutoType VT"
end run
on setProfile(cs, cd, ld, se, bd)
	set chunkSize to cs
	set chunkDelay to cd
	set lineDelay to ld
	set shiftExtra to se
	set breatherDelay to bd
end setProfile
-- Gõ 1 dòng: từng ký tự (chế độ chậm) hoặc theo cụm (chế độ nhanh)
on typeLine(theText)
	set theLen to count of theText
	set pos to 1
	repeat while pos ≤ theLen
		if isAbortHeld() then
			beep
			display notification "Đã dừng giữa dòng (Caps Lock / Fn)" with title "AutoType VT"
			error number -128
		end if
		set endPos to pos + chunkSize - 1
		if endPos > theLen then set endPos to theLen
		set chunk to text pos thru endPos of theText
		tell application "System Events" to keystroke chunk
		delay chunkDelay
		-- Ký tự cần Shift hay bị sai hoa/thường qua remote -> nghỉ thêm
		if chunkSize = 1 and shiftExtra > 0 then
			considering case
				if shiftChars contains chunk then delay shiftExtra
			end considering
		end if
		-- Nghỉ dài định kỳ để remote kịp xử lý buffer
		set typedCount to typedCount + (endPos - pos + 1)
		if typedCount ≥ breatherEvery then
			set typedCount to 0
			delay breatherDelay
		end if
		set pos to endPos + 1
	end repeat
end typeLine

-- ============ PHẦN CHUNG (giống hệt autotype_vnpt) ============
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
