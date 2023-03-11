#include <File.au3>
#include <Array.au3>

; Func: _FindLatestLog
; Searches the latest file in specified directory with specified mask
; Example of usage: FindLatestLog (@UserProfileDir & "\\AppData\\Roaming\\Application", "*Waiter*.log")
Func _FindLatestResult($dir, $mask = "*.txt")
	Local $latestTime = 0, $currentTime = 0, $latestFile = 0
	Local $files = _FileListToArray($dir, $mask, 1)
	If @error = 1 Then Return SetError(1, 0, "")
	For $i = 1 To UBound($files) - 1
		$currentTime = FileGetTime($dir & "\" & $files[$i], 0, 1)
		If @error Then ContinueLoop
		If ($currentTime > $latestTime) Then
			$latestTime = $currentTime
			$latestFile = $files[$i]
		EndIf
	Next
;~ 	Return SetError(0, 0, $latestFile)

	$latestResultLine = StringSplit(FileReadLine($dir&"\"&$latestFile,2),@TAB,2)
	Local $latestResult[0]
	_ArrayAdd($latestResult, $latestResultLine[0])
	_ArrayAdd($latestResult, $latestResultLine[1])
	Return $latestResult
EndFunc   ;==>_FindLatestResult

; Example usage:
$latestFile = _FindLatestResult(@ScriptDir & "\results")
ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : $latestFile = ' & $latestFile[0]&@TAB & $latestFile[1] & @CRLF & '>Error code: ' & @error & @CRLF) ;### Debug Console
