#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=Files\icon.ico
#AutoIt3Wrapper_UseX64=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include "Files\wd_helper.au3"
#include "Files\wd_capabilities.au3"
#include <Array.au3>
#include <String.au3>
#include <File.au3>
Opt("TrayIconDebug", 1)

TraySetIcon(@ScriptDir & "\files\icon.ico")

#Region Other

#Region Browser Setup
Func SetupGecko($bHeadless = False)
	_WD_Option('DRIVERCLOSE', True)
	_WD_Option('Driver', @ScriptDir & '\Files\geckodriver.exe')
	_WD_Option('DriverParams', '--log trace')
	_WD_Option('Port', 4444)

;~ 	Global $sCapabilities = '{"capabilities": {"alwaysMatch": {"browserName": "firefox", "acceptInsecureCerts":true}}}'
	_WD_CapabilitiesStartup()
	_WD_CapabilitiesAdd('alwaysMatch', 'firefox')
	_WD_CapabilitiesAdd('browserName', 'firefox')
	_WD_CapabilitiesAdd('acceptInsecureCerts', True)
	If $bHeadless Then _WD_CapabilitiesAdd('args', '--headless')
;~ 	_WD_CapabilitiesDump(@ScriptLineNumber) ; dump current Capabilities setting to console - only for testing in this demo
	Global $sCapabilities = _WD_CapabilitiesGet()
	Return $sCapabilities
EndFunc   ;==>SetupGecko

Func SetupChrome($bHeadless = False)
;~ 	_WD_Option('OUTPUTDEBUG', False)
	$_WD_DEBUG = 0
	_WD_Option('DRIVERCLOSE', True)
	_WD_Option('Driver', 'Files\chromedriver.exe')
	_WD_Option('Port', 9515)
	_WD_Option('DriverParams', '--verbose --log-path="' & @ScriptDir & '\Files\chrome.log"')

;~ 	Global $sCapabilities = '{"capabilities": {"alwaysMatch": {"goog:chromeOptions": {"w3c": true, "excludeSwitches": [ "enable-automation"]}}}}'
	_WD_CapabilitiesStartup()
	_WD_CapabilitiesAdd('alwaysMatch', 'chrome')
	_WD_CapabilitiesAdd('w3c', True)
	_WD_CapabilitiesAdd('excludeSwitches', 'enable-automation')
	_WD_CapabilitiesAdd('args', 'disable-notifications')
	_WD_CapabilitiesAdd('args', '--load-extension=' & @ScriptDir & '\files\ublock')

	If $bHeadless Then _WD_CapabilitiesAdd('args', '--headless')
;~ 	_WD_CapabilitiesDump(@ScriptLineNumber) ; dump current Capabilities setting to console - only for testing in this demo
	Global $sCapabilities = _WD_CapabilitiesGet()
	Return $sCapabilities
EndFunc   ;==>SetupChrome
#EndRegion Browser Setup


Global $nowLogFileName = @MON & "-" & @MDAY & "-" & @YEAR & "_" & @HOUR & "-" & @MIN & "-" & @SEC
Global $logFileName = @ScriptDir & "\Logs\" & $nowLogFileName & ".log"
Func _log($text)
	Global $now = @MON & "/" & @MDAY & "/" & @YEAR & " " & @HOUR & ":" & @MIN & ":" & @SEC
	FileWriteLine(@ScriptDir & "\Logs\main.log", $nowLogFileName & @TAB & $text) ;All days
	FileWriteLine($logFileName, $nowLogFileName & @TAB & $text)
EndFunc   ;==>_log

Func _FindLatestResult($dir, $mask = "*.txt")
	Global $latestTime = 0, $currentTime = 0, $latestFile = 0
	Global $files = _FileListToArray($dir, $mask, 1)
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

	Global $latestResult[0]
	If $latestFile Then
		$latestResultLine = StringSplit(FileReadLine($dir & "\" & $latestFile, 2), @TAB, 2)
		_ArrayAdd($latestResult, $latestResultLine[0])
		_ArrayAdd($latestResult, $latestResultLine[1])
	Else
		_ArrayAdd($latestResult, " ")
		_ArrayAdd($latestResult, " ")
	EndIf
	Return $latestResult
EndFunc   ;==>_FindLatestResult
#EndRegion Other

_Go()
Func _Go()
	_Input()
	_ProgressBar()
	_InitBrowser()
	_Start()
	_Pages()
	_Games()
	_CloseBrowser()
	_Finishing()
EndFunc   ;==>_Go


#Region Input
Func _Input()
	Global $gamesPerPage = 130
	Global $gameResults = InputBox("Results", "How many games do you want? (there is " & $gamesPerPage & " per page)", 3900)
	If @error Then Exit
	Global $siteURL = InputBox("Page", "Enter starting page URL:" & @CRLF & "(change only if you want other pages (2,3,4...etc))", "https://www.skidrowreloaded.com/pc/", Default, 288)
	If @error Then Exit

	Global $deleteDuplicates = MsgBox(3 + 32, "Duplicate Games", "Skip duplicate games (same original game URL)?")
	If $deleteDuplicates = 6 Then ;yes > skip
		$deleteDuplicates = True
	ElseIf $deleteDuplicates = 7 Then ;no > keep
		$deleteDuplicates = False
	ElseIf $deleteDuplicates = 2 Then ;cancel > exit
		Exit
	EndIf

	Global $stopAtLastPreviousResult = MsgBox(3 + 32, "Stop", "Stop at last previous result?")
	If $stopAtLastPreviousResult = 6 Then ;yes > stop
		$stopAtLastPreviousResult = True
		$latestResult = _FindLatestResult(@ScriptDir & "\results") ;title and post date in array 0,1
		ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : $latestResult = ' & $latestResult[0] & @TAB & $latestResult[1] & @CRLF) ;### Debug Console
	ElseIf $stopAtLastPreviousResult = 7 Then ;no > get all
		$stopAtLastPreviousResult = False
	ElseIf $stopAtLastPreviousResult = 2 Then ;cancel > exit
		Exit
	EndIf

	Global $neededPages = Ceiling($gameResults / $gamesPerPage)
EndFunc   ;==>_Input
#EndRegion Input


#Region Progressbar
Func _ProgressBar()
	Global $steps = $gameResults * 2 + 3
	Global $currentStep = 0
	ProgressOn("Skidrow", "", "", Default, Default, 16)
	ProgressSet((100 / $steps) * $currentStep, "Starting browser...")
	$currentStep += 1
EndFunc   ;==>_ProgressBar
#EndRegion Progressbar


#Region Init browser
Func _InitBrowser()
	$sCapabilities = SetupChrome(False) ;headless or not
;~ $sCapabilities = SetupGecko(False)
	_WD_Startup()
	_WD_ConsoleVisible(False)
	Global $sSession = _WD_CreateSession($sCapabilities)

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	_WD_Navigate($sSession, $siteURL)
	_WD_Window($sSession, "Maximize")
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	_WD_LoadWait($sSession)
EndFunc   ;==>_InitBrowser
#EndRegion Init browser


#Region Start
Func _Start()
	Global $timer = TimerInit()
	Global $aGames[0][3], $aGamesResult[0][11]
	Global $iTotalNumberofGames = 0 ;counter if chosen to stop at last result
	_ArrayAdd($aGames, "Title|URL|PostDate")
	_ArrayAdd($aGamesResult, "Title|PostDate|ReleaseDate|Genre|Size|URL|OGLink|Video|Poster|SS1|SS2")
	Global $outputTxtFile = @ScriptDir & "\Results\" & @MDAY & "-" & @MON & "-" & @YEAR & " " & @HOUR & "-" & @MIN & "-" & @SEC & ".txt"
	FileWriteLine($outputTxtFile, "Title" & @TAB & "PostDate" & @TAB & "ReleaseDate" & @TAB & "Genre" & @TAB & "Size" & @TAB & "URL" & @TAB & "OGLink" & @TAB & "Video" & @TAB & "Poster" & @TAB & "SS1" & @TAB & "SS2")
EndFunc   ;==>_Start
#EndRegion Start


#Region Pages
Func _Pages()
	For $k = 1 To $neededPages
		Global $oElements = _WD_FindElement($sSession, $_WD_LOCATOR_ByXPath, "//ul[@id='lcp_instance_1']/li", Default, True)
		For $i = 0 To $gamesPerPage - 1 ;UBound($oElements) - 1
			ProgressSet((100 / $steps) * $currentStep, "Games:" & $i + 1 + (($k - 1) * $gamesPerPage) & "/" & $gameResults & @TAB & @TAB & "Pages:" & $k & "/" & $neededPages & @TAB & @TAB & Round((100 / $steps) * $currentStep, 2) & "%", "Getting Posts Titles and Dates...")
			$currentStep += 1
			Global $title = _WD_ElementAction($sSession, $oElements[$i], 'text') ;title+date
			Global $postDateMatches = StringRegExp($title, "\b(January|February|March|April|May|June|July|August|September|October|November|December)\s\d{1,2},\s\d{4}\b", 2)
			$postDate = $postDateMatches[0] ;matched date

			$title = StringReplace($title, " " & $postDate, "") ;remove date from title

			Global $oLink = _WD_FindElement($sSession, $_WD_LOCATOR_ByXPath, "./a", $oElements[$i])
			Global $url = _WD_ElementAction($sSession, $oLink, 'attribute', 'href')

			If $stopAtLastPreviousResult And $title = $latestResult[0] And $postDate = $latestResult[1] Then ExitLoop 2

			$iTotalNumberofGames += 1 ;

			_ArrayAdd($aGames, $title & "|" & $url & "|" & $postDate)
			_ArrayAdd($aGamesResult, "")
			If $i + 1 + (($k - 1) * $gamesPerPage) = $gameResults Then ExitLoop
		Next

		Global $sDesiredClass = "lcp_nextlink"
		Global $sDesiredInnerHTML = ">>"
		Global $sXPath = "//a[@class='" & $sDesiredClass & "' and contains(.,'" & $sDesiredInnerHTML & "')]"
		Global $oButton = _WD_FindElement($sSession, $_WD_LOCATOR_ByXPath, $sXPath)
		Global $nextURL = _WD_ElementAction($sSession, $oButton, 'attribute', 'href') ;url of next page
		_WD_Navigate($sSession, $nextURL)
	Next
	ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : $iTotalNumberofGames = ' & $iTotalNumberofGames & @CRLF & '>Error code: ' & @error & @CRLF)     ;### Debug Console
EndFunc   ;==>_Pages
#EndRegion Pages


#Region Games
Func _Games()
;~ 	_ArrayDisplay($aGames,"$aGames")
;~ 	_ArrayDisplay($aGamesResult,"$aGamesResult")
	If $iTotalNumberofGames = 0 Then Return
	For $i = 1 To $iTotalNumberofGames ;UBound($oElements) - 1  	 	0idx is headers
		ProgressSet((100 / $iTotalNumberofGames) * $currentStep, $i & "/" & $iTotalNumberofGames & @TAB & @TAB & @TAB & @TAB & @TAB & Round((100 / $steps) * $currentStep, 2) & "%", "Getting Each Game Details...")
		$currentStep += 1

		_WD_Navigate($sSession, $aGames[$i][1])
		_WD_LoadWait($sSession)
		Global $htmlSource = _WD_GetSource($sSession)

		Global $dateRelease = _getReleaseDate()
		Global $genre = _getGenre()

;~ 		Global $size = _getSize()
		$xpath = "//p[contains(translate(., 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), 'size')]"
		$element = _WD_FindElement($sSession, $_WD_LOCATOR_ByXPath, $xpath)
		If @error Then
			$size = " "
		Else
			$size = _WD_ElementAction($sSession, $element, 'text')
			$size = StringRegExp($size, "(?mi)\bSize:\h*(\d+(\.\d+)?(?:\h*MB|\h*GB)).*$", 3)
			If @error Then
				$size = " "
			Else
				$size = $size[0]
			EndIf
		EndIf


		Global $linkOG = _getOGLink()

		Global $video = StringRegExp($htmlSource, '(?<=iframe src=")(?:https?:)?\/\/www\.youtube\.com\/[^"]+', 2)
		$video = @error ? " " : StringReplace($video[0], "embed/", "watch?v=")
		If StringLeft($video, 2) = "//" Then $video = "https:" & $video

		;;;POSTER SS1 SS2
		While 1
;~ 			$xpath = "//img[not(@id='fsb_image') and contains(@src, '.jpg')]"
			$xpath = "//img[not(@id='fsb_image') and contains(@data-lazy-src, '.jpg')]"
			$screenshotsELEMENTS = _WD_FindElement($sSession, $_WD_LOCATOR_ByXPath, $xpath, Default, True)
			If UBound($screenshotsELEMENTS) > 1 Then
				ExitLoop
			Else
				ConsoleWrite("REFRESHING " & @CRLF)
				_WD_Action($sSession, "REFRESH")

				$xpath = "//li[@role='tab']//a[text()='SCREENSHOTS']"
				$element = _WD_FindElement($sSession, $_WD_LOCATOR_ByXPath, $xpath)
				_WD_ElementAction($sSession, $element, "click")
				_WD_HighlightElements($sSession, $element)
				Sleep(2000)
			EndIf
		WEnd

		Local $screenshots[0]
		For $s In $screenshotsELEMENTS
;~ 			_ArrayAdd($screenshots, _WD_ElementAction($sSession, $s, 'attribute', 'src'))
			_ArrayAdd($screenshots, _WD_ElementAction($sSession, $s, 'attribute', 'data-lazy-src'))
		Next
;~ 		_ArrayDisplay($screenshots)
		$poster = $screenshots[0]
		ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : $poster = ' & $poster & @CRLF) ;### Debug Console
		$ss1 = UBound($screenshots) > 1 ? $screenshots[1] : " "
		ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : $ss1 = ' & $ss1 & @CRLF) ;### Debug Console
		$ss2 = UBound($screenshots) > 2 ? $screenshots[2] : " "
		ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : $ss2 = ' & $ss2 & @CRLF) ;### Debug Console

		;;;;POSTER
;~ 		$xpath = "//img[not(@id='fsb_image') and contains(@src, '.jpg') and contains(@src, 'skidrow')]"
;~ 		$element = _WD_FindElement($sSession, $_WD_LOCATOR_ByXPath, $xpath)
;~ 		$poster = _WD_ElementAction($sSession, $element, 'attribute', 'src') ? _WD_ElementAction($sSession, $element, 'attribute', 'src') : " "
;~ 		ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : $poster = ' & $poster & @CRLF) ;### Debug Console


		;;;;SS1
;~ 		$timerTemp = TimerInit()
;~ 		$xpath = "(//div//div//div//div//div//div//p//img[not(@id='fsb_image') and contains(@data-lazy-src, '.jpg') and not(contains(@data-lazy-src, 'skidrow'))])[1]"
;~ 		Do
;~ 			_WD_LoadWait($sSession)
;~ 			$element = _WD_WaitElement($sSession, $_WD_LOCATOR_ByXPath, $xpath, 0, 150)
;~ 			If @error Then
;~ 				_WD_Action($sSession, "REFRESH")
;~ 				ConsoleWrite("REFRESHING " & @CRLF)
;~ 			EndIf
;~ 		Until $element <> @error Or TimerDiff($timerTemp) > 10000
;~ 		$ss1 = _WD_ElementAction($sSession, $element, 'attribute', 'data-lazy-src') ? _WD_ElementAction($sSession, $element, 'attribute', 'data-lazy-src') : " "
;~ 		ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : $ss1 = ' & $ss1 & @CRLF) ;### Debug Console

		;;;;;SS2
;~ 		$timerTemp = TimerInit()
;~ 		$xpath = "(//div//div//div//div//div//div//p//img[not(@id='fsb_image') and contains(@data-lazy-src, '.jpg') and not(contains(@data-lazy-src, 'skidrow'))])[2]"
;~ 		Do
;~ 			_WD_LoadWait($sSession)
;~ 			$element = _WD_WaitElement($sSession, $_WD_LOCATOR_ByXPath, $xpath, 0, 150)
;~ 			If @error Then
;~ 				_WD_Action($sSession, "REFRESH")
;~ 				ConsoleWrite("REFRESHING " & @CRLF)
;~ 			EndIf
;~ 		Until $element <> @error Or TimerDiff($timerTemp) > 10000
;~ 		$ss2 = _WD_ElementAction($sSession, $element, 'attribute', 'src') ? _WD_ElementAction($sSession, $element, 'attribute', 'src') : " "
;~ 		ConsoleWrite('@@ Debug(' & @ScriptLineNumber & ') : $ss2 = ' & $ss2 & @CRLF) ;### Debug Console


		$aGamesResult[$i][0] = $aGames[$i][0] ;title
		$aGamesResult[$i][1] = $aGames[$i][2] ;postdate
		$aGamesResult[$i][2] = IsArray($dateRelease) ? StringReplace($dateRelease[0], ",", "") : " " ;release date 	remove commas
		$aGamesResult[$i][3] = IsArray($genre) ? $genre[0] : " " ;genre
;~ 		$aGamesResult[$i][4] = IsArray($size) ? $size[0] : " " ;size
		$aGamesResult[$i][4] = $size ;size
		$aGamesResult[$i][5] = $aGames[$i][1] ;URL
		$aGamesResult[$i][6] = IsArray($linkOG) ? $linkOG[0] : " " ;game link in its original site
		$aGamesResult[$i][7] = $video ;ut gameplay video
		$aGamesResult[$i][8] = $poster
		$aGamesResult[$i][9] = $ss1
		$aGamesResult[$i][10] = $ss2

		If $deleteDuplicates And _ArraySearch($aGamesResult, $aGamesResult[$i][6], Default, Default, Default, Default, Default, 6) >= 0 _
				And _ArraySearch($aGamesResult, $aGamesResult[$i][6], Default, Default, Default, Default, Default, 6) <> $i Then ;if not found before and not the same one cause its already added
			ContinueLoop ;skip
		EndIf

		$output = $aGamesResult[$i][0]
		For $ss = 1 To 10
			$output = $output & @TAB & $aGamesResult[$i][$ss]
		Next

		FileWriteLine($outputTxtFile, $output)
	Next
EndFunc   ;==>_Games
#EndRegion Games


#Region Close browser
Func _CloseBrowser()
	ProgressSet((100 / $steps) * $currentStep, @TAB & @TAB & @TAB & @TAB & @TAB & Round((100 / $steps) * $currentStep, 2) & "%", "Closing Browser...")
	$currentStep += 1

	_WD_LoadWait($sSession)
	_WD_DeleteSession($sSession)
	ProcessClose("chromedriver.exe")
EndFunc   ;==>_CloseBrowser
#EndRegion Close browser


#Region Finishing
Func _Finishing()
	ProgressSet((100 / $steps) * $steps, "Finishing...")
	Sleep(1000)
	ProgressOff()

	If $iTotalNumberofGames > 0 Then
		MsgBox(262144 + 32, "Done!", $iTotalNumberofGames & " games finished in " & Round(Floor(TimerDiff($timer)) / 1000 / 60, 2) & " minutes!")
		ShellExecute(@ScriptDir & "\page.html")
	Else
		MsgBox(262144 + 32, "Done!", "No new games found since last time!")
		FileDelete($outputTxtFile)
	EndIf

	FileDelete(@ScriptDir & "\files\chrome.log")
EndFunc   ;==>_Finishing
#EndRegion Finishing


#Region Handling Variations in Texts
Func _getReleaseDate()
	Local $rd = 0
	Local $vars = ["Release dte:", "Rekease date: ", "Reelase date: ", "release date date:", "releasee date:", "date de parution :", "release dae:", "releaase date:", "release dated:", "release de:", "release date::", "releas date:", "release date :", "release:", "Release Date: ", "Release datee: ", "Release date te: ", "release dat: ", "Release date "]
	For $v In $vars
		$rd = _StringBetween(StringLower($htmlSource), StringLower($v), "<", Default, True)
		If IsArray($rd) Then
			$rd[0] = _StringProper($rd[0])
			Return $rd
		EndIf
	Next
	Return $rd
EndFunc   ;==>_getReleaseDate

Func _getGenre()
	Local $rd = 0
	Local $vars = ["Genre: : ", "Genr: ", "Genrer: ", "Gene: ", "Gener: ", "Gente: ", "Genrte: ", "Genre: "]
	For $v In $vars
		$rd = _StringBetween(StringLower($htmlSource), StringLower($v), "<", Default, True)
		If IsArray($rd) Then
			$rd[0] = _StringProper($rd[0])
			Return $rd
		EndIf
	Next
	Return $rd
EndFunc   ;==>_getGenre

Func _getSize()
	Local $rd = 0
	Local $vars = ["Size:", "Size: "]
	For $v In $vars
		$rd = _StringBetween(StringLower($htmlSource), StringLower($v), "<", Default, True)
		If IsArray($rd) Then
			$rd[0] = _StringProper($rd[0])
			Return $rd
		EndIf
	Next
	Return $rd
EndFunc   ;==>_getSize

Func _getOGLink()
	Local $rd = 0
	Local $vars = ['• <a href="', 'â€¢ <a href="']
	For $v In $vars
		$rd = _StringBetween(StringLower($htmlSource), $v, '"', Default, True)
		If IsArray($rd) Then
;~ 			$rd[0] = _StringProper($rd[0])
			If StringLeft($rd[0], 2) = "//" Then $rd[0] = "https:" & $rd[0]
			If StringInStr($rd[0], "//") Then Return $rd
		EndIf
	Next
	Return $rd
EndFunc   ;==>_getOGLink

#EndRegion Handling Variations in Texts
