#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=Files\icon.ico
#AutoIt3Wrapper_UseX64=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include "Files\wd_helper.au3"
#include "Files\wd_capabilities.au3"
#include <Array.au3>
#include <String.au3>
#include <Excel.au3>

TraySetIcon(@ScriptDir & "\files\icon.ico")
#Region Browser Setup
Func SetupGecko($bHeadless = False)
	_WD_Option('DRIVERCLOSE', True)
	_WD_Option('Driver', @ScriptDir & '\Files\geckodriver.exe')
	_WD_Option('DriverParams', '--log trace')
	_WD_Option('Port', 4444)

;~ 	Local $sCapabilities = '{"capabilities": {"alwaysMatch": {"browserName": "firefox", "acceptInsecureCerts":true}}}'
	_WD_CapabilitiesStartup()
	_WD_CapabilitiesAdd('alwaysMatch', 'firefox')
	_WD_CapabilitiesAdd('browserName', 'firefox')
	_WD_CapabilitiesAdd('acceptInsecureCerts', True)
	If $bHeadless Then _WD_CapabilitiesAdd('args', '--headless')
;~ 	_WD_CapabilitiesDump(@ScriptLineNumber) ; dump current Capabilities setting to console - only for testing in this demo
	Local $sCapabilities = _WD_CapabilitiesGet()
	Return $sCapabilities
EndFunc   ;==>SetupGecko

Func SetupChrome($bHeadless = False)
;~ 	_WD_Option('OUTPUTDEBUG', False)
	_WD_Option('DRIVERCLOSE', True)
	_WD_Option('Driver', 'Files\chromedriver.exe')
	_WD_Option('Port', 9515)
	_WD_Option('DriverParams', '--verbose --log-path="' & @ScriptDir & '\Files\chrome.log"')

;~ 	Local $sCapabilities = '{"capabilities": {"alwaysMatch": {"goog:chromeOptions": {"w3c": true, "excludeSwitches": [ "enable-automation"]}}}}'
	_WD_CapabilitiesStartup()
	_WD_CapabilitiesAdd('alwaysMatch', 'chrome')
	_WD_CapabilitiesAdd('w3c', True)
	_WD_CapabilitiesAdd('excludeSwitches', 'enable-automation')
	_WD_CapabilitiesAdd('args', 'disable-notifications')
;~ 	_WD_CapabilitiesAdd('useAutomationExtension', False)
;~ 	_WD_CapabilitiesAdd('args', '--load-extension='&@ScriptDir&'\adblock');ADBLOCK

	If $bHeadless Then _WD_CapabilitiesAdd('args', '--headless')
;~ 	_WD_CapabilitiesDump(@ScriptLineNumber) ; dump current Capabilities setting to console - only for testing in this demo
	Local $sCapabilities = _WD_CapabilitiesGet()
	Return $sCapabilities
EndFunc   ;==>SetupChrome
#EndRegion Browser Setup


#Region Input
;~ Local $gameResults = InputBox("Results", "How many games do you want? (250 max.)", 250) ; < 250 cause 1 page
Local $gameResults = InputBox("Results", "How many games do you want? (there is 250 per page)", 250) ; < 250 cause 1 page
If @error Then Exit
Local $siteURL = InputBox("Page", "Enter starting page URL:" & @CRLF & "(change only if you want other pages (2,3,4...etc))", "https://www.skidrowreloaded.com/pc/", Default, 288)
If @error Then Exit

Local $deleteDuplicates = MsgBox(3 + 32, "Duplicate Games", "Skip duplicate games (same original game URL)?")
If $deleteDuplicates = 6 Then ;yes > skip
	$deleteDuplicates = True
ElseIf $deleteDuplicates = 7 Then ;no > keep
	$deleteDuplicates = False
ElseIf $deleteDuplicates = 2 Then ;cancel > exit
	Exit
EndIf

Local $neededPages = Ceiling($gameResults / 250)
#EndRegion Input


#Region Progressbar
$steps = $gameResults * 2 + 3
$currentStep = 0
ProgressOn("Skidrow", "", "", Default, Default, 16)
ProgressSet((100 / $steps) * $currentStep, "Starting browser...")
$currentStep += 1
#EndRegion Progressbar


#Region Init browser
$sCapabilities = SetupChrome(True) ;headless or not
;~ $sCapabilities = SetupGecko(False)
_WD_Startup()
_WD_ConsoleVisible(False)
$sSession = _WD_CreateSession($sCapabilities)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
_WD_Navigate($sSession, $siteURL)
_WD_Window($sSession, "Maximize")
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
_WD_LoadWait($sSession)
#EndRegion Init browser


#Region Start
Local $timer = TimerInit()
Local $aGames[0][3], $aGamesResult[0][11]
_ArrayAdd($aGames, "Title|URL|PostDate")
_ArrayAdd($aGamesResult, "Title|PostDate|ReleaseDate|Genre|Size|URL|OGLink|Video|Poster|SS1|SS2")
Local $outputTxtFile = @ScriptDir & "\Results\" & @MDAY & "-" & @MON & "-" & @YEAR & " " & @HOUR & "-" & @MIN & "-" & @SEC & ".txt"
FileWriteLine($outputTxtFile,"Title"&@TAB&"PostDate"&@TAB&"ReleaseDate"&@TAB&"Genre"&@TAB&"Size"&@TAB&"URL"&@TAB&"OGLink"&@TAB&"Video"&@TAB&"Poster"&@TAB&"SS1"&@TAB&"SS2
")
Exit
#EndRegion Start


#Region Pages
For $k = 1 To $neededPages
	ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : $k = ' & $k & @CRLF) ;### Debug Console
	Local $oElements = _WD_FindElement($sSession, $_WD_LOCATOR_ByXPath, "//ul[@id='lcp_instance_1']/li", Default, True)
	For $i = 0 To 250 - 1 ;UBound($oElements) - 1
		ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : $i = ' & $i & @CRLF) ;### Debug Console
		ProgressSet((100 / $steps) * $currentStep, "Games:" & $i + 1 + (($k - 1) * 250) & "/" & $gameResults & @TAB & @TAB & "Pages:" & $k & "/" & $neededPages & @TAB & @TAB & Round((100 / $steps) * $currentStep, 2) & "%", "Getting Posts Titles and Dates...")
		$currentStep += 1
		Local $title = _WD_ElementAction($sSession, $oElements[$i], 'text') ;title+date
		Local $postDateMatches = StringRegExp($title, "\b(January|February|March|April|May|June|July|August|September|October|November|December)\s\d{1,2},\s\d{4}\b", 2)
		$postDate = $postDateMatches[0] ;matched date

		$title = StringReplace($title, " " & $postDate, "") ;remove date from title

		Local $oLink = _WD_FindElement($sSession, $_WD_LOCATOR_ByXPath, "./a", $oElements[$i])
		Local $url = _WD_ElementAction($sSession, $oLink, 'attribute', 'href')

		_ArrayAdd($aGames, $title & "|" & $url & "|" & $postDate)
		_ArrayAdd($aGamesResult, "")
		If $i + 1 + (($k - 1) * 250) = $gameResults Then ExitLoop
	Next

	Local $sDesiredClass = "lcp_nextlink"
	Local $sDesiredInnerHTML = ">>"
	Local $sXPath = "//a[@class='" & $sDesiredClass & "' and contains(.,'" & $sDesiredInnerHTML & "')]"
	Local $oButton = _WD_FindElement($sSession, $_WD_LOCATOR_ByXPath, $sXPath)
	Local $nextURL = _WD_ElementAction($sSession, $oButton, 'attribute', 'href') ;url of next page
	_WD_Navigate($sSession, $nextURL)
;~ 	_WD_LoadWait($sSession, 3000)
Next
#EndRegion Pages


#Region Games
For $i = 1 To $gameResults ;UBound($oElements) - 1  	 	0idx is headers
	ProgressSet((100 / $steps) * $currentStep, $i & "/" & $gameResults & @TAB & @TAB & @TAB & @TAB & @TAB & Round((100 / $steps) * $currentStep, 2) & "%", "Getting Each Game Details...")
	$currentStep += 1

	_WD_Navigate($sSession, $aGames[$i][1])
	_WD_LoadWait($sSession)
	Local $htmlSource = _WD_GetSource($sSession)

	Local $dateRelease = _StringBetween($htmlSource, "Release Date: ", "<", Default, True) ;get date
	Local $genre = _StringBetween($htmlSource, "Genre: ", "<", Default, True)
	Local $size = _StringBetween($htmlSource, "Size: ", "<", Default, True)
	Local $linkOG = _StringBetween($htmlSource, '• <a href="', '"', Default, True)
	Local $video = StringRegExp($htmlSource, '(?<=")(https?:\/\/)?(www\.)?(youtube\.com|youtu\.?be)\/.+?(?=")', 2)
	$video = @error ? " " : StringReplace($video[0], "embed/", "watch?v=")

	Local $images = _StringBetween($htmlSource, 'img class="lazy aligncenter" src="', '"', Default, True)
	Local $images2 = _StringBetween($htmlSource, 'img class="aligncenter" src="', '"', Default, True)
	If IsArray($images) Then
		_ArrayConcatenate($images, $images2)
		$images = _ArrayUnique($images, Default, Default, Default, 0)
	Else
		$images = $images2
	EndIf

	If Not StringInStr($images[0], "www.skidrowreloaded") Then
		For $img = 0 To UBound($images) - 1
			If StringInStr($images[$img], "www.skidrowreloaded") Then
;~ 			_ArrayDisplay($images,"FOUND in "&$img)
				$poster = $images[$img]
				_ArrayDelete($images, $img)
;~ 			_ArrayDisplay($images,"DELETED")
				_ArrayInsert($images, 0, $poster)
;~ 			_ArrayDisplay($images,"ADDED AT 0")
			EndIf
		Next
	EndIf

	$aGamesResult[$i][0] = $aGames[$i][0] ;title
	$aGamesResult[$i][1] = $aGames[$i][2] ;postdate
	$aGamesResult[$i][2] = IsArray($dateRelease) ? StringReplace($dateRelease[0], ",", "") : " " ;release date 	remove commas
	$aGamesResult[$i][3] = IsArray($genre) ? $genre[0] : " " ;genre
	$aGamesResult[$i][4] = IsArray($size) ? $size[0] : " " ;size
	$aGamesResult[$i][5] = $aGames[$i][1] ;URL
	$aGamesResult[$i][6] = IsArray($linkOG) ? $linkOG[0] : " " ;game link in its original site
	$aGamesResult[$i][7] = $video ;ut gameplay video
	$aGamesResult[$i][8] = IsArray($images) ? $images[0] : " " ;poster
	$aGamesResult[$i][9] = IsArray($images) And UBound($images) > 1 ? $images[1] : " " ;ss1
	$aGamesResult[$i][10] = IsArray($images) And UBound($images) > 2 ? $images[2] : " " ;ss2

	$output = $aGamesResult[$i][0]
	For $ss= 1 to 10
		$output = $output &"\t"&$aGamesResult[$i][$ss]
	Next
	FileWriteLine($outputTxtFile,$output)
Next
#EndRegion Games


#Region Close browser
ProgressSet((100 / $steps) * $currentStep, @TAB & @TAB & @TAB & @TAB & @TAB & Round((100 / $steps) * $currentStep, 2) & "%", "Closing Browser...")
$currentStep += 1

_WD_LoadWait($sSession)
_WD_DeleteSession($sSession)
ProcessClose("chromedriver.exe")
#EndRegion Close browser


#Region Excel
ProgressSet((100 / $steps) * $currentStep, @TAB & @TAB & @TAB & @TAB & @TAB & Round((100 / $steps) * $currentStep, 2) & "%", "Creating and Filling Excel...")
$currentStep += 1

;~ $oExcel = _Excel_Open()
;~ $file = _Excel_BookNew($oExcel, 1)
;~ _Excel_RangeWrite($file, Default, $aGamesResult)
;~ If $deleteDuplicates Then
;~ 	Local $iLastRow = $file.Activesheet.Range("A1000000").End(-4162).Row
;~ 	Local $aColumns = [7]
;~ 	$file.Activesheet.Range("A1:K" & $iLastRow).RemoveDuplicates($aColumns)
;~ 	$iLastRow = $file.Activesheet.Range("A1000000").End(-4162).Row
;~ 	$gameResults = $iLastRow - 1 ;cause header
;~ EndIf

;~ _Excel_BookSaveAs($file, $outputTxtFile)
;~ $oExcel.DisplayAlerts = True
#EndRegion Excel


#Region Finishing
ProgressSet((100 / $steps) * $steps, "Finishing...")
Sleep(1000)
ProgressOff()
MsgBox(262144 + 32, "Done!", $gameResults & " games finished in " & Round(Floor(TimerDiff($timer)) / 1000, 2) & " seconds!")
#EndRegion Finishing

FileDelete(@ScriptDir & "\files\chrome.log")
ShellExecute(@ScriptDir & "\page.html")
