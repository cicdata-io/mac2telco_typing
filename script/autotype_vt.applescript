-- AutoType VT (Viettel)
use framework "AppKit"
use scripting additions

-- ============ CONFIG ============
property chunkSize : 12 -- chars per burst (smaller = safer)
property chunkDelay : 0.03 -- pause between bursts (s)
property lineDelay : 0.08 -- pause after Enter (s)
property startDelay : 3 -- countdown before typing (s)
-- Abort hotkey: hold Control + Option (⌃⌥)

on run
	-- 1) Keyboard layout guard
	set currentInputSource to getInputSource()
	set okLayouts to {"com.apple.keylayout.ABC", "com.apple.keylayout.US", "ABC", "US"}

	if okLayouts does not contain currentInputSource then
		set userChoice to display dialog ¬
			"CẢNH BÁO BỘ GÕ: Hệ thống nhận diện [" & currentInputSource & "]" & return & return & ¬
			"Nếu đang bật Tiếng Việt, text sẽ bị loạn dấu. Hãy chuyển về US/ABC!" with title "Kiểm tra bộ gõ" buttons {"Hủy", "Vẫn gõ"} default button "Hủy" with icon caution
		if button returned of userChoice is "Hủy" then return
	else
		display dialog ¬
			"Gõ siêu tốc bằng AppleScript cho Viettel." & return & return & ¬
			"Giữ ⌃⌥ (Control+Option) bất cứ lúc nào để DỪNG." & return & ¬
			"Nhấn 'Bắt đầu', bạn có " & startDelay & ¬
			"s để click vào máy ảo." with title "Xác nhận gõ siêu tốc" buttons {"Hủy", "Bắt đầu"} default button "Bắt đầu" cancel button "Hủy"
	end if

	-- 2) Type
	set clipboardText to (the clipboard as text)
	set textLines to paragraphs of clipboardText
	set lineCount to count of textLines

	delay startDelay

	repeat with i from 1 to lineCount
		if isAbortHeld() then
			beep
			display notification "Đã dừng tại dòng " & i with title "AutoType VT"
			return
		end if
		set thisLine to (item i of textLines) as string
		if thisLine is not "" then typeChunked(thisLine)
		tell application "System Events" to key code 36 -- Enter
		delay lineDelay
	end repeat

	display notification "Hoàn tất " & lineCount & " dòng" with title "AutoType VT"
end run

-- Type a string in small bursts, checking the abort hotkey between bursts.
on typeChunked(theText)
	set theLen to count of theText
	set pos to 1
	repeat while pos ≤ theLen
		if isAbortHeld() then
			beep
			display notification "Đã dừng giữa dòng" with title "AutoType VT"
			error number -128 -- user cancelled
		end if
		set endPos to pos + chunkSize - 1
		if endPos > theLen then set endPos to theLen
		set chunk to text pos thru endPos of theText
		tell application "System Events" to keystroke chunk
		set pos to endPos + 1
		delay chunkDelay
	end repeat
end typeChunked

-- True if Control + Option are currently held (polled globally via NSEvent).
on isAbortHeld()
	set f to (current application's NSEvent's modifierFlags()) as integer
	set ctrlHeld to ((f div 262144) mod 2) = 1 -- NSEventModifierFlagControl
	set optHeld to ((f div 524288) mod 2) = 1 -- NSEventModifierFlagOption
	return (ctrlHeld and optHeld)
end isAbortHeld

on getInputSource()
	try
		set src to do shell script "defaults read com.apple.HIToolbox AppleSelectedInputSources | grep '\"InputSourceID\"' | head -n 1 | awk -F'\"' '{print $4}'"
		if src is "" then
			set src to do shell script "defaults read com.apple.HIToolbox AppleSelectedInputSources | grep 'KeyboardLayout Name' | head -n 1 | awk -F'=' '{print $2}' | tr -d ' ;\"'"
		end if
	on error
		set src to "Không xác định"
	end try
	return src
end getInputSource
