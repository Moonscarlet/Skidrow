; save this as _HtmlTable2Array.au3
#include-once
#include <array.au3>
;
; #FUNCTION# ====================================================================================================================
; Name ..........: _HtmlTableGetList
; Description ...: Finds and enumerates all the html tables contained in an html listing (even if nested).
;                  if the optional parameter $i_index is passed, then only that table is returned
; Syntax ........: _HtmlTableGetList($sHtml[, $i_index = -1])
; Parameters ....: $sHtml               - A string value containing an html page listing
;                  $i_index             - [optional] An integer value indicating the number of the table to be returned (1 based)
;                                         with the default value of -1 an array with all found tables is returned
; Return values .: Success;               Returns an 1D 1 based array containing all or single html table found in the html.
;                                         element [0] (and @extended as well) contains the number of tables found (or 0 if no tables are returned)
;                                         if an error occurs then an ampty string is returned and the following @error code is setted
;                                         @error:   1 - no tables are present in the passed HTML
;                                                   2 - error while parsing tables, (opening and closing tags are not balanced)
;                                                   3 - error while parsing tables, (open/close mismatch error)
;                                                   4 - invalid table index request (requested table nr. is out of boundaries)
; ===============================================================================================================================
Func _HtmlTableGetList($sHtml, $i_index = -1)
    Local $aTables = _ParseTags($sHtml, "<table", "</table>")
    If @error Then
        Return SetError(@error, 0, "")
    ElseIf $i_index = -1 Then
        Return SetError(0, $aTables[0], $aTables)
    Else
        If $i_index > 0 And $i_index <= $aTables[0] Then
            Local $aTemp[2] = [1, $aTables[$i_index]]
            Return SetError(0, 1, $aTemp)
        Else
            Return SetError(4, 0, "") ; bad index
        EndIf
    EndIf
EndFunc   ;==>_HtmlTableGetList

; #FUNCTION# ====================================================================================================================
; Name ..........: _HtmlTableWriteToArray
; Description ...: It writes values from an html table to a 2D array. It tries to take care of the rowspan and colspan formats
; Syntax ........: _HtmlTableWriteToArray($sHtmlTable[, $bFillSpan = False[, $iFilter = 0]])
; Parameters ....: $sHtmlTable          - A string value containing the html code of the table to be parsed
;                  $bFillSpan           - [optional] Default is False. If span areas have to be filled by repeating the data
;                                         contained in the first cell of the span area
;                  $iFilter             - [optional] Default is 0 (no filters) data extracted from cells is returned unchanged.
;                                       -  0 = no filter
;                                       -  1 = removes non ascii characters
;                                       -  2 = removes all double whitespaces
;                                       -  4 = removes all double linefeeds
;                                       -  8 = removes all html-tags
;                                       - 16 = simple html-tag / entities convertor
; Return values .: Success:               2D array containing data from the html table
;                  Faillure:              An empty strimg and sets @error as following:
;                                         @error:   1 - no table content is present in the passed HTML
;                                                   2 - error while parsing rows and/or columns, (opening and closing tags are not balanced)
;                                                   3 - error while parsing rows and/or columns, (open/close mismatch error)
; ===============================================================================================================================
Func _HtmlTableWriteToArray($sHtmlTable, $bFillSpan = False, $iFilter = 0)
    $sHtmlTable = StringReplace(StringReplace($sHtmlTable, "<th", "<td"), "</th>", "</td>") ; th becomes td
    ; rows of the wanted table
    Local $iError, $aTempEmptyRow[2] = [1, ""]
    Local $aRows = _ParseTags($sHtmlTable, "<tr", "</tr>") ; $aRows[0] = nr. of rows
    If @error Then Return SetError(@error, 0, "")
    Local $aCols[$aRows[0] + 1], $aTemp
    For $i = 1 To $aRows[0]
        $aTemp = _ParseTags($aRows[$i], "<td", "</td>")
        $iError = @error
        If $iError = 1 Then ; check if it's an empty row
            $aTemp = $aTempEmptyRow ; Empty Row
        Else
            If $iError Then Return SetError($iError, 0, "")
        EndIf
        If $aCols[0] < $aTemp[0] Then $aCols[0] = $aTemp[0] ; $aTemp[0] = max nr. of columns in table
        $aCols[$i] = $aTemp
    Next
    Local $aResult[$aRows[0]][$aCols[0]], $iStart, $iEnd, $aRowspan, $aColspan, $iSpanY, $iSpanX, $iSpanRow, $iSpanCol, $iMarkerCode, $sCellContent
    Local $aMirror = $aResult
    For $i = 1 To $aRows[0] ;      scan all rows in this table
        $aTemp = $aCols[$i] ; <td ..> xx </td> .....
        For $ii = 1 To $aTemp[0] ; scan all cells in this row
            $iSpanY = 0
            $iSpanX = 0
            $iY = $i - 1 ; zero base index for vertical ref
            $iX = $ii - 1 ; zero based indexes for horizontal ref
            ; following RegExp kindly provided by SadBunny in this post:
            ; http://www.autoitscript.com/forum/topic/167174-how-to-get-a-number-located-after-a-name-from-within-a-string/?p=1222781
            $aRowspan = StringRegExp($aTemp[$ii], "(?i)rowspan\s*=\s*[""']?\s*(\d+)", 1) ; check presence of rowspan
            If IsArray($aRowspan) Then
                $iSpanY = $aRowspan[0] - 1
                If $iSpanY + $iY > $aRows[0] Then
                    $iSpanY -= $iSpanY + $iY - $aRows[0] + 1
                EndIf
            EndIf
            ;
            $aColspan = StringRegExp($aTemp[$ii], "(?i)colspan\s*=\s*[""']?\s*(\d+)", 1) ; check presence of colspan
            If IsArray($aColspan) Then $iSpanX = $aColspan[0] - 1
            ;
            $iMarkerCode += 1 ; code to mark this span area or single cell
            If $iSpanY Or $iSpanX Then
                $iX1 = $iX
                For $iSpY = 0 To $iSpanY
                    For $iSpX = 0 To $iSpanX
                        $iSpanRow = $iY + $iSpY
                        If $iSpanRow > UBound($aMirror, 1) - 1 Then
                            $iSpanRow = UBound($aMirror, 1) - 1
                        EndIf
                        $iSpanCol = $iX1 + $iSpX
                        If $iSpanCol > UBound($aMirror, 2) - 1 Then
                            ReDim $aResult[$aRows[0]][UBound($aResult, 2) + 1]
                            ReDim $aMirror[$aRows[0]][UBound($aMirror, 2) + 1]
                        EndIf
                        ;
                        While $aMirror[$iSpanRow][$iX1 + $iSpX] ; search first free column
                            $iX1 += 1 ; $iSpanCol += 1
                            If $iX1 + $iSpX > UBound($aMirror, 2) - 1 Then
                                ReDim $aResult[$aRows[0]][UBound($aResult, 2) + 1]
                                ReDim $aMirror[$aRows[0]][UBound($aMirror, 2) + 1]
                            EndIf
                        WEnd
                    Next
                Next
            EndIf
            ;
            $iX1 = $iX
            ; following RegExp kindly provided by mikell in this post:
            ; http://www.autoitscript.com/forum/topic/167309-how-to-remove-from-a-string-all-between-and-pairs/?p=1224207
            $sCellContent = StringRegExpReplace($aTemp[$ii], '<[^>]+>', "")
            If $iFilter Then $sCellContent = _HTML_Filter($sCellContent, $iFilter)
            For $iSpX = 0 To $iSpanX
                For $iSpY = 0 To $iSpanY
                    $iSpanRow = $iY + $iSpY
                    If $iSpanRow > UBound($aMirror, 1) - 1 Then
                        $iSpanRow = UBound($aMirror, 1) - 1
                    EndIf
                    While $aMirror[$iSpanRow][$iX1 + $iSpX]
                        $iX1 += 1
                        If $iX1 + $iSpX > UBound($aMirror, 2) - 1 Then
                            ReDim $aResult[$aRows[0]][$iX1 + $iSpX + 1]
                            ReDim $aMirror[$aRows[0]][$iX1 + $iSpX + 1]
                        EndIf
                    WEnd
                    $aMirror[$iSpanRow][$iX1 + $iSpX] = $iMarkerCode ; 1
                    If $bFillSpan Then $aResult[$iSpanRow][$iX1 + $iSpX] = $sCellContent
                Next
                $aResult[$iY][$iX1] = $sCellContent
            Next
        Next
    Next
    ; _ArrayDisplay($aMirror, "Debug")
    Return SetError(0, $aResult[0][0], $aResult)
EndFunc   ;==>_HtmlTableWriteToArray

;
; #FUNCTION# ====================================================================================================================
; Name ..........: _HtmlTableGetWriteToArray
; Description ...: extract the html code of the required table from the html listing and copy the data of the table to a 2D array
; Syntax ........: _HtmlTableGetWriteToArray($sHtml[, $iWantedTable = 1[, $bFillSpan = False[, $iFilter = 0]]])
; Parameters ....: $sHtml               - A string value containing the html listing
;                  $iWantedTable        - [optional] An integer value. The nr. of the table to be parsed (default is first table)
;                  $bFillSpan           - [optional] Default is False. If all span areas have to be filled by repeating the data
;                                         contained in the first cell of the span area
;                  $iFilter             - [optional] Default is 0 (no filters) data extracted from cells is returned unchanged.
;                                       -  0 = no filter
;                                       -  1 = removes non ascii characters
;                                       -  2 = removes all double whitespaces
;                                       -  4 = removes all double linefeeds
;                                       -  8 = removes all html-tags
;                                       - 16 = simple html-tag / entities convertor
; Return values .: success:               2D array containing data from the wanted html table.
;                  faillure:              An empty string and sets @error as following:
;                                         @error:   1 - no tables are present in the passed HTML
;                                                   2 - error while parsing tables, (opening and closing tags are not balanced)
;                                                   3 - error while parsing tables, (open/close mismatch error)
;                                                   4 - invalid table index request (requested table nr. is out of boundaries)
; ===============================================================================================================================
Func _HtmlTableGetWriteToArray($sHtml, $iWantedTable = 1, $bFillSpan = False, $iFilter = 0)
    Local $aSingleTable = _HtmlTableGetList($sHtml, $iWantedTable)
    If @error Then Return SetError(@error, 0, "")
    Local $aTableData = _HtmlTableWriteToArray($aSingleTable[1], $bFillSpan, $iFilter)
    If @error Then Return SetError(@error, 0, "")
    Return SetError(0, $aTableData[0][0], $aTableData)
EndFunc   ;==>_HtmlTableGetWriteToArray

; #FUNCTION# ====================================================================================================================
; Name ..........: _ParseTags
; Description ...: searches and extract all portions of html code within opening and closing tags inclusive.
;                  Returns an array containing a collection of <tag ...... </tag> lines. one in each element (even if are nested)
; Syntax ........: _ParseTags($sHtml, $sOpening, $sClosing)
; Parameters ....: $sHtml               - A string value containing the html listing
;                  $sOpening            - A string value indicating the opening tag
;                  $sClosing            - A string value indicating the closing tag
; Return values .: success:               an 1D 1 based array containing all the portions of html code representing the element
;                                         element [0] af the array (and @extended as well) contains the counter of found elements
;                  faillure:              An empty string and sets @error as following:
;                                         @error:   1 - no tables are present in the passed HTML
;                                                   2 - error while parsing tables, (opening and closing tags are not balanced)
;                                                   3 - error while parsing tables, (open/close mismatch error)
;                                                   4 - invalid table index request (requested table nr. is out of boundaries)
; ===============================================================================================================================
Func _ParseTags($sHtml, $sOpening, $sClosing) ; example: $sOpening = '<table', $sClosing = '</table>'
    ; it finds how many of such tags are on the HTML page
    StringReplace($sHtml, $sOpening, $sOpening) ; in @xtended nr. of occurences
    Local $iNrOfThisTag = @extended
    ; I assume that opening <tag and closing </tag> tags are balanced (as should be)
    ; (so NO check is made to see if they are actually balanced)
    If $iNrOfThisTag Then ; if there is at least one of this tag
        ; $aThisTagsPositions array will contain the positions of the
        ; starting <tag and ending </tag> tags within the HTML
        Local $aThisTagsPositions[$iNrOfThisTag * 2 + 1][3] ; 1 based (make room for all open and close tags)
        ; 2) find in the HTML the positions of the $sOpening <tag and $sClosing </tag> tags
        For $i = 1 To $iNrOfThisTag
            $aThisTagsPositions[$i][0] = StringInStr($sHtml, $sOpening, 0, $i) ; start position of $i occurrence of <tag opening tag
            $aThisTagsPositions[$i][1] = $sOpening ; it marks which kind of tag is this
            $aThisTagsPositions[$i][2] = $i ; nr of this tag
            $aThisTagsPositions[$iNrOfThisTag + $i][0] = StringInStr($sHtml, $sClosing, 0, $i) + StringLen($sClosing) - 1 ; end position of $i^ occurrence of </tag> closing tag
            $aThisTagsPositions[$iNrOfThisTag + $i][1] = $sClosing ; it marks which kind of tag is this
        Next
        _ArraySort($aThisTagsPositions, 0, 1) ; now all opening and closing tags are in the same sequence as them appears in the HTML
        Local $aStack[UBound($aThisTagsPositions)][2]
        Local $aTags[Ceiling(UBound($aThisTagsPositions) / 2)] ; will contains the collection of <tag ..... </tag> from the html
        For $i = 1 To UBound($aThisTagsPositions) - 1
            If $aThisTagsPositions[$i][1] = $sOpening Then ; opening <tag
                $aStack[0][0] += 1 ; nr of tags in html
                $aStack[$aStack[0][0]][0] = $sOpening
                $aStack[$aStack[0][0]][1] = $i
            ElseIf $aThisTagsPositions[$i][1] = $sClosing Then ; a closing </tag> was found
                If Not $aStack[0][0] Or Not ($aStack[$aStack[0][0]][0] = $sOpening And $aThisTagsPositions[$i][1] = $sClosing) Then
                    Return SetError(3, 0, "") ; Open/Close mismatch error
                Else ; pair detected (the reciprocal tag)
                    ; now get coordinates of the 2 tags
                    ; 1) extract this tag <tag ..... </tag> from the html to the array
                    $aTags[$aThisTagsPositions[$aStack[$aStack[0][0]][1]][2]] = StringMid($sHtml, $aThisTagsPositions[$aStack[$aStack[0][0]][1]][0], 1 + $aThisTagsPositions[$i][0] - $aThisTagsPositions[$aStack[$aStack[0][0]][1]][0])
                    ; 2) remove that tag <tag ..... </tag> from the html
                    $sHtml = StringLeft($sHtml, $aThisTagsPositions[$aStack[$aStack[0][0]][1]][0] - 1) & StringMid($sHtml, $aThisTagsPositions[$i][0] + 1)
                    ; 3) adjust the references to the new positions of remaining tags
                    For $ii = $i To UBound($aThisTagsPositions) - 1
                        $aThisTagsPositions[$ii][0] -= StringLen($aTags[$aThisTagsPositions[$aStack[$aStack[0][0]][1]][2]])
                    Next
                    $aStack[0][0] -= 1 ; nr of tags still in html
                EndIf
            EndIf
        Next
        If Not $aStack[0][0] Then ; all tags where parsed correctly
            $aTags[0] = $iNrOfThisTag
            Return SetError(0, $iNrOfThisTag, $aTags) ; OK
        Else
            Return SetError(2, 0, "") ; opening and closing tags are not balanced
        EndIf
    Else
        Return SetError(1, 0, "") ; there are no of such tags on this HTML page
    EndIf
EndFunc   ;==>_ParseTags

; #=============================================================================
; Name ..........: _HTML_Filter
; Description ...: Filter for strings
; AutoIt Version : V3.3.0.0
; Syntax ........: _HTML_Filter(ByRef $sString[, $iMode = 0])
; Parameter(s): .: $sString     - String to filter
;                  $iMode       - Optional: (Default = 0) : removes nothing
;                               - 0 = no filter
;                               - 1 = removes non ascii characters
;                               - 2 = removes all double whitespaces
;                               - 4 = removes all double linefeeds
;                               - 8 = removes all html-tags
;                               - 16 = simple html-tag / entities convertor
; Return Value ..: Success      - Filterd String
;                  Failure      - Input String
; Author(s) .....: Thorsten Willert, Stephen Podhajecki {gehossafats at netmdc. com} _ConvertEntities
; Date ..........: Wed Jan 27 20:49:59 CET 2010
; modified ......: by Chimp  Removed a double "&nbsp;" entities declaration,
;                            replace it with char(160) instead of chr(32),
;                            declaration of the $aEntities array as Static instead of just Local
; ==============================================================================
Func _HTML_Filter(ByRef $sString, $iMode = 0)
    If $iMode = 0 Then Return $sString
    ;16 simple HTML tag / entities converter
    If $iMode >= 16 And $iMode < 32 Then
        Static Local $aEntities[95][2] = [["&quot;", 34],["&amp;", 38],["&lt;", 60],["&gt;", 62],["&nbsp;", 160] _
                ,["&iexcl;", 161],["&cent;", 162],["&pound;", 163],["&curren;", 164],["&yen;", 165],["&brvbar;", 166] _
                ,["&sect;", 167],["&uml;", 168],["&copy;", 169],["&ordf;", 170],["&not;", 172],["&shy;", 173] _
                ,["&reg;", 174],["&macr;", 175],["&deg;", 176],["&plusmn;", 177],["&sup2;", 178],["&sup3;", 179] _
                ,["&acute;", 180],["&micro;", 181],["&para;", 182],["&middot;", 183],["&cedil;", 184],["&sup1;", 185] _
                ,["&ordm;", 186],["&raquo;", 187],["&frac14;", 188],["&frac12;", 189],["&frac34;", 190],["&iquest;", 191] _
                ,["&Agrave;", 192],["&Aacute;", 193],["&Atilde;", 195],["&Auml;", 196],["&Aring;", 197],["&AElig;", 198] _
                ,["&Ccedil;", 199],["&Egrave;", 200],["&Eacute;", 201],["&Ecirc;", 202],["&Igrave;", 204],["&Iacute;", 205] _
                ,["&Icirc;", 206],["&Iuml;", 207],["&ETH;", 208],["&Ntilde;", 209],["&Ograve;", 210],["&Oacute;", 211] _
                ,["&Ocirc;", 212],["&Otilde;", 213],["&Ouml;", 214],["&times;", 215],["&Oslash;", 216],["&Ugrave;", 217] _
                ,["&Uacute;", 218],["&Ucirc;", 219],["&Uuml;", 220],["&Yacute;", 221],["&THORN;", 222],["&szlig;", 223] _
                ,["&agrave;", 224],["&aacute;", 225],["&acirc;", 226],["&atilde;", 227],["&auml;", 228],["&aring;", 229] _
                ,["&aelig;", 230],["&ccedil;", 231],["&egrave;", 232],["&eacute;", 233],["&ecirc;", 234],["&euml;", 235] _
                ,["&igrave;", 236],["&iacute;", 237],["&icirc;", 238],["&iuml;", 239],["&eth;", 240],["&ntilde;", 241] _
                ,["&ograve;", 242],["&oacute;", 243],["&ocirc;", 244],["&otilde;", 245],["&ouml;", 246],["&divide;", 247] _
                ,["&oslash;", 248],["&ugrave;", 249],["&uacute;", 250],["&ucirc;", 251],["&uuml;", 252],["&thorn;", 254]]
        $sString = StringRegExpReplace($sString, '(?i)<p.*?>', @CRLF & @CRLF)
        $sString = StringRegExpReplace($sString, '(?i)<br>', @CRLF)
        Local $iE = UBound($aEntities) - 1
        For $x = 0 To $iE
            $sString = StringReplace($sString, $aEntities[$x][0], Chr($aEntities[$x][1]), 0, 2)
        Next
        For $x = 32 To 255
            $sString = StringReplace($sString, "&#" & $x & ";", Chr($x))
        Next
        $iMode -= 16
    EndIf
    ;8 Tag filter
    If $iMode >= 8 And $iMode < 16 Then
        ;$sString = StringRegExpReplace($sString, '<script.*?>.*?</script>', "")
        $sString = StringRegExpReplace($sString, "<[^>]*>", "")
        $iMode -= 8
    EndIf
    ; 4 remove all double cr, lf
    If $iMode >= 4 And $iMode < 8 Then
        $sString = StringRegExpReplace($sString, "([ \t]*[\n\r]+[ \t]*)", @CRLF)
        $sString = StringRegExpReplace($sString, "[\n\r]+", @CRLF)
        $iMode -= 4
    EndIf
    ; 2 remove all double withespaces
    If $iMode = 2 Or $iMode = 3 Then
        $sString = StringRegExpReplace($sString, "[[:blank:]]+", " ")
        $sString = StringRegExpReplace($sString, "\n[[:blank:]]+", @CRLF)
        $sString = StringRegExpReplace($sString, "[[:blank:]]+\n", "")
        $iMode -= 2
    EndIf
    ; 1 remove all non ASCII (remove all chars with ascii code > 127)
    If $iMode = 1 Then
        $sString = StringRegExpReplace($sString, "[^\x00-\x7F]", " ")
    EndIf

    Return $sString
EndFunc   ;==>_HTML_Filter