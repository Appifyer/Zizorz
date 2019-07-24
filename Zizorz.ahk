/*
	< ZIZORZ > (Heritage: ScreenCapture (Sean), ScreenClipping (Learning One), ScreenClipping (Sumon), ScreenClipper (Sumon), Zizorz (Sumon) 
    
      Script Function:
      Copy, save or upload a part of the screen as an image.  
*/
    
ScriptVersion := "1.4"

/*
	Author: Simon Strålberg [sumon @ Autohotkey forums]
    Based on: Learning one's ScreenClipping with inspiration from Zonanic, Sean & more...  [History: http://www.autohotkey.com/forum/viewtopic.php?t=49950]
	Autohotkey version: AHK_L
	Dependencies:
		- Notify.ahk by gwarble & more [http://www.autohotkey.com/forum/viewtopic.php?t=48668]
        - httpQuery [http://www.autohotkey.com/forum/topic33506.html]
		
	CHANGELOG:
	v.
        - v1.4 Fixed imgur uploads. 
        - v1.3 Changed Notify GUI style
        - v1.2 Uploads to http://imgur.com, oAuth support, improved DragBox(), default directory changed, full file name is returned, GDIP, code cleanup
        - v 0.94(b) Added notification disable/enable
        - v 0.94 (20110409) Added Settings & Help (NICE GUI), cleaned up some unneeded functions, renamed to Zizorz, added Winkey support, changed hotkeys (Leftclick again)
		- v 0.9 (20110407) Added version numbers, removed httpQuery (added requirement)
		- v 0.x Changed mousebutton, made sure it worked in Ansi, fixed GUI
        - v 0.xx Added sounds
	
	TODO:

	LICENSE: If no license documentation exists, [http://appifyer.com/ahk/license.html]
	Script created using Autohotkey [http://www.autohotkey.com]
	
*/

; ======== INITIATION ========

#Include <GDIP>
SetBatchLines, 10ms
#SingleInstance force
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.

pToken := gdip_startup()
If !pToken
   throw Exception("Gdip could not start up.")

IncludeImages := "exit.ico|feedback.ico|filedir.ico|key.ico|help.ico|notification.ico|save.ico|settings.ico|shortcut.ico|zizorz.ico|zizorz_header.jpg"
Loop, Parse, IncludeImages, |
{
   If (!FileExist("data\img\" A_LoopField))
   {
      Gosub, Install
      break
   }
}

IniRead, ImgFolder, data\ZizorzSettings.ini, Folder, Path, PrintScreens
IniRead, Notification, data\ZizorzSettings.ini, Notification, Enabled, 1

If (!ImgFolder)
{
   RegRead, MyPictures, HKEY_CURRENT_USER, Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders, My Pictures ; looks for Pictures folderlocation
   ImgFolder := MyPictures ? MyPictures "\Screenshots" : "data\PrintScreens"
}

IfNotExist, %ImgFolder%
   FileCreateDir, %ImgFolder%

SetSystemCursor("IDC_Cross") ; To show that you can click-drag, and give better precision

; ======== LAUNCH ========

Menu, Tray, Icon, data\img\Zizorz.ico
Menu, Tray, NoStandard
Menu, Tray, Tip, Zizorz`nRight-click to open menu
Menu, Tray, Add, Settings
   Menu, Tray, Icon, Settings, data\img\settings.ico,, 32
Menu, Tray, Add, Help, GuiHelp
   Menu, Tray, Icon, Help, data\img\help.ico,, 32
Menu, Tray, Add, Feedback
   Menu, Tray, Icon, Feedback, data\img\feedback.ico,,32
Menu, Tray, Add, Exit
   Menu, Tray, Icon, Exit, data\img\exit.ico,, 32
If (Notification != 0)
   NotifyID := Notify("Zizorz", "Capture image by dragging a box while holding:`n(Shift/Ctrl/Alt to Upload/Copy/Save)", 8,, "data\img\Zizorz.ico")

; ======== HOTKEYS ========

Hotkey, *+LButton, UploadClip ; Shift (Upload)
Hotkey, *^LButton, CopyClip ; Ctrl (Clipboard)
Hotkey, *!LButton, SaveClip ; Alt (File)
Hotkey, F1, Settings
Hotkey, F2, Settings

Sleep 8000 ; Wait for reminder
If (!ClipType)
   Traytip, Zizorz:, Need help? Press f1 (or f2) to access help & settings, 16, 1
return

~Esc:: Gosub, Exit
return


; ======== CLIPDRAG: Main Function ========

SaveClip:
UploadClip:
CopyClip:
ClipType := {SaveClip: "Save",   UploadClip: "Upload", CopyClip: "Copy"  }[A_ThisLabel] ; Meaning, if ClipDrag is called under a different label, use that label to define the ClipType Function

ClipDrag:

If (GetKeyState("LWin")) ; If LWin was also being held
{   
   ; Capture current window
   MouseGetPos,,, MouseWin
   pbitmap := gdip_bitmapFromHWND(MouseWin)
   win_Flash(MouseWin, "b85bea")
   Gosub, ClipDragDone
   return
}

db := DragBox() ; Hold mouse and drag to select area to capture

; Disable all hotkeys when done
Hotkey, *+LButton, Off ; Shift (Upload)
Hotkey, *^LButton, Off ; Ctrl (Clipboard)
Hotkey, *!LButton, Off ; Alt (File)
RestoreCursors()

; ======== CAPTURE ========


Area := db["X1"] "|" db["Y1"] "|" db["W"] "|" db["H"] ; _BitMapFromScreen(Area) does not accept an object as input
If (db["Hotkey"])
   ClipType := {Alt: "Save",   Shift: "Upload", Ctrl: "Copy" }[db["Hotkey"]]

Sleep, 50 ; Allow GUI to disappear before capturing
pBitmap := gdip_BitmapFromScreen(Area)
If (pBitmap = -1)
   throw Exception(Area " was passed incorrectly to gdip_BitmapFromScreen")

ClipDragDone:
If FileExist("data\sounds\scissors.wav")
   SoundPlay, data\sounds\scissors.wav
If (ClipType = "Copy") ; Copy
{
   Traytip, Zizorz:, Copied to clipboard, 3
   gdip_SetBitmapToClipboard(pBitmap)
}
else ; (File or Upload)
{
    ; Find an available filename.
   IfNotExist, %ImgFolder%
      FileCreateDir, %ImgFolder%
   start := 1
   
   FormatTime, CurrentDateTime,, yyyy-MM-dd
   
   If FileExist(NewFileName := imgfolder . "\Zizshot " CurrentDateTime . ".jpg")
      While FileExist(NewFileName := imgfolder . "\Zizshot " CurrentDateTime . "(" start ").jpg")
         start++

   ; Capture screenshot
   If (errorcode := gdip_SaveBitmapToFile(pBitmap, NewFileName, 100))
   {
      throw Exception(Errorcode " recieved when saving to file " NewFileName)
   }
      
   If (ClipType = "Save") ; SAVE: If we just wanted to save an image, we are done now :)
   {
      If FileExist(newFileName)
         {
            SplitPath, newFileName, shortName, OutDir
            Notify("File saved:", shortName, 4)
            Clipboard := newFileName
            Sleep 4000 ; Sleep before Exit
         }
      else
      {
         Traytip, Zizorz:, Error. File %NewFileName% could not be created`nErrorCode: %ErrorCode%, 4 ; Something went wrong in creating file
         Sleep 10000 ; Sleep before Exit
      }
      Gosub, Exit
   }
   ; UPLOAD: If ClipType was not FILE (or COPY), then it was ClipType = "Upload"
   
   ; --------------
   ; START OF UPLOAD
   ; --------------
   Anonymous_API_Key := "4879223de36cb88"  ; NOTE: Please do not copy Zizorz API key (starting with 4879...) from the source code, get your own at https://api.imgur.com/
   image_file := newFileName
      
   try
   {
      image_url := UploadToImgur(image_file, Anonymous_API_Key)
      
      If (Notification)
      {
         Notify("Uploaded!", (Clipboard := image_url), 4)
         SoundPlay, data\sounds\drop.wav
      }
      else
         Clipboard := image_url
      Sleep 4000 ; Time to read notice, before quitting app
      } catch errMsg {
          MsgBox, 48, Error, % errMsg
      }
           
      gosub Exit
}

Sleep 3000
Gosub, Exit
Return

NotifyOff: ; Triggered when user is starting to drag a box
Gui, %NotifyID%:Hide
return

; === SETTINGS ======

#Include %A_ScriptDir%\lib\Feedback.ahk ; Feedback, FeedbackSubmit, FeedbackSendEmail, return

Settings:
If WinExist("Zizorz Settings")
{
   WinActivate, Zizorz Settings ; Just activate it again, no need to redraw
   return
}

RestoreCursors() ; For normal cursor at GUI

Gui, Settings: Default
Gui, Destroy
Gui, Color, FFffFF
Gui, Font, s10, Verdana
Gui, Add, Pic, x0 gGuiDrag, data\img\zizorz_header.jpg

AddGraphicButton("ChangeDir", "data\img\filedir.ico", "x10 w40 h40 gGuiChangeDir")
StringRight, DisplayDir, ImgFolder, 30
Gui, Add, Text, x60 yp+10 vImgFolder w250, {... %DisplayDir%}

AddGraphicButton("CreateShortCut", "data\img\shortcut.ico", "x10 w40 h40 gGuiCreateShortcut")
Gui, Add, Text, x60 yp+10 w250, Create a shortcut && hotkey for Zizorz
IniRead, Notification, data\ZizorzSettings.ini, Notification, Enabled, 1

;~ AddGraphicButton("APIKey", "data\img\key.ico", "x10 w40 h40 gGuiAPI") ; Removed in v 1.4
;~ API_Display := (Imgur_AccountName()) ? ("imgur user: " Imgur_AccountName()) : "[ No imgur API key ]"
;~ Gui, Add, Text, x60 yp+10 w250, %API_Display% 

AddGraphicButton("Notification", "data\img\notification.ico", "x10 w40 h40 gGuiToggleNotification")
NotificationDisplay := ((Notification = 1)?"enabled":"disabled")
Gui, Add, Text, x60 yp+10 w250 vNotificationDisplay, Notification %Notificationdisplay%

AddGraphicButton("Feedback", "data\img\feedback.ico", "x10 w40 h40 gFeedback")
Gui, Add, Text, x60 yp+10 w250, Feedback && support

AddGraphicButton("HelpButton", "data\img\help.ico", "x200 w40 h40 gGuiHelp")
AddGraphicButton("ExitButton", "data\img\exit.ico", "x245 yp w40 h40 gGuiClose")
AddGraphicButton("SaveButton", "data\img\save.ico", "x290 yp w40 h40 gGuiSubmit default")
Gui, -Caption +Border
Gui, Show,, Zizorz Settings
return

;~ GuiAPI: ; Removed in v 1.4
;~ MsgBox, 35, Change imgur account?, Do you want to authenticate with another imgur user?
;~ IfMsgBox, Yes
;~ {
   ;~ FileDelete, data\Zizorz_oAuth.ini
   ;~ If FileExist(A_WinDir "\Media\Speech Off.wav")
      ;~ SoundPlay, %A_WinDir%\Media\Speech Off.wav
   ;~ Sleep 1000
   ;~ Reload
;~ }
;~ return

GuiToggleNotification:
If (Notification = 1)
   Notification := 0
else
   Notification := 1
SoundPlay, data\sounds\click.wav
NotificationDisplay := ((Notification = 1)?"enabled":"disabled")
GuiControl,, NotificationDisplay, Notification %NotificationDisplay%
return

GuiHelp:
MsgBox, 32, Zizorz help, Zizorz™ is a tool to create`, save & upload images quickly and intuitively`, making it easier to create & share content with others.`n`nTo capture an area`, hold and drag the left mouse button. To capture a window`, hold the Windows key and leftclick. Depending on what modifier you use (you must use one)`, you can achieve one of following three options:`n`n[ Shift ] Upload to imgur.com`n[ Ctrl ] Copy to clipboard`n[ Alt ] Save as a file in the pre-chosen folder`n[ + Win ] Copy the entire window clicked`n`nIn cases 1 & 3`, the link to the URL respectively file folder will be in your clipboard. In case 4, you need to hold the Windows key and one additional modifier to decide what do do with the caputred window.`n`nZizorz will not run in the background`, but instead exits when finished`, so it doesn't require memory when not used. Therefore`, it is recommended that you launch Zizorz using an applauncher such as Appifyer™.`n`nThe current version is %ScriptVersion%`nZizorz™ was made by Simon Strålberg in 2011 using Autohotkey (http://www.autohotkey.com)
return

GuiChangeDir:
FileSelectFolder, ImgFolder, *ImgFolder, 3, Select the folder that your saved images will go to
If Errorlevel
   return
StringRight, DisplayDir, ImgFolder, 30
GuiControl,, ImgFolder, {... %DisplayDir%}
return

GuiCreateShortCut:
FileCreateShortcut, %A_ScriptDir%\%A_ScriptName%, %A_Desktop%\Zizorz.lnk, %A_ScriptDir%,, Launch Zizorz, %A_ScriptDir%\data\img\Zizorz.ico, Z
SoundPlay, data\sounds\click.wav
MsgBox, 65, Shortcut created, Created a shortcut for Zizorz™ on your desktop.`nAdded the default hotkey Ctrl+Alt+Z to launch Zizorz.`nYou may change the hotkey by editing the shortcut.`n`nTip: If you use Appifyer™ (made by the same author as Zizorz)`, you can define your own hotkey for any file or app. Do you want to check out Appifyer.com?
IfMsgBox, OK
   Run http://www.appifyer.com
return

GuiClose:
Gui, Settings:Destroy
Hotkey, F1, Off ; Can't reenable Help upon exiting
Gosub, Exit
return

GuiSubmit: 
Gui, Submit
Hotkey, F1, Off ; Can't reenable Help upon exiting
IniWrite, %ImgFolder%, data\ZizorzSettings.ini, Folder, Path
IniWrite, %Notification%, data\ZizorzSettings.ini, Notification, Enabled
return


GuiDrag:
PostMessage, 0xA1, 2,,, A
return
; === Extra subroutines ======================
; Change if you want to have it running constantly

Install:
Gui, Install:Default
gui, font, s10, Verdana  ; Set 10-point Verdana.
Gui, Add, Text, vInstallText, This is the first time you run Zizorz! `n`nExtract required data to "/data" directory?
Gui, Add, Button, x10 w125 h40 gInstallFiles default, Sure!
Gui, Add, Button, x135 w125 yp h40 gExit, No thanks!
Gui, -Caption +Border
Gui, Color, ffFFff
Gui, Show,, Extract files?
WinWaitClose, Extract files?,, 30 ; Wait max 30s
return

;~ oAuthCheck: ; Not used in v 1.4
;~ IfNotExist, % IniFile := "data\Zizorz_oAuth.ini"
   ;~ FileAppend, [Imgur: OAuth Endpoints]`n
   ;~ ( LTRIM
      ;~ Request_Token_Endpoint=https://api.imgur.com/oauth2/request_token
      ;~ Authorize_Endpoint=https://api.imgur.com/oauth2/authorize
      ;~ Access_Token_Endpoint=https://api.imgur.com/oauth2/access_token

      ;~ [Imgur: OAuth Tokens]
      ;~ Consumer_Key=b5b38bec220fb96e16fdb7a9e122caa804f625292
      ;~ Consumer_Secret=6be33de189e20ffd33068d8866b3e728
      ;~ Access_Token=
      ;~ Token_Secret=

      ;~ [Script Settings]
   ;~ ), % IniFile

/*
2016 imgur API:
Client ID: 4879223de36cb88
Client secret: b4e667c9972477a2728fb9610644a28dc0bc0577
*/

OAuth_ConsumerKey(        IniRead( IniFile, "Imgur: OAuth Tokens", "Consumer_Key"    ) )
OAuth_ConsumerSecret(     IniRead( IniFile, "Imgur: OAuth Tokens", "Consumer_Secret" ) )
OAuth_TokenSecret(        IniRead( IniFile, "Imgur: OAuth Tokens", "Token_Secret"    ) )
OAuth_Token(              IniRead( IniFile, "Imgur: OAuth Tokens", "Access_Token"    ) )

; If there IS an OAuth token already available, use a simple GET function to test it.
If !OAuth_Token() || !( Account_Name := Imgur_AccountName() )
{
   ; Either there is no existing token, or it's invalid. Either way, we have to get a new token.
   
   ; Acquire a request token.
   If !( Request_Token := OAuth_RequestToken( IniRead( IniFile, "Imgur: OAuth Endpoints", "Request_Token_Endpoint" ) ) )
   {
      MsgBox, 16, Imgur API: Critical Error, % ""
      . "For some reason`, a request token could not be obtained. This script will exit."
      . "`nLast Response: " OAuth_LastResponse()
      Exitapp
   }
   
   ; Open the authorization page in the user's default browser.
   Run, % IniRead( IniFile, "Imgur: OAuth Endpoints", "Authorize_Endpoint" ) "?oauth_token=" Request_Token
   
   ; Display a custom prompt for the user to copy/paste the verifier code after authorizing the script.
   Notify("Zizorz > imgur", "Zizorz will use imgur to upload your image.`nPlease authenticate by following the instructions", 8,, "data\img\Zizorz.ico")
   If !( verifier := OAuth_PromptUserForOOBVerifier() )
      Exitapp ; user cancelled... we're done
   
   ; Acquire an access token
   Access_Token := OAuth_AccessToken( IniRead( IniFile, "Imgur: OAuth Endpoints", "Access_Token_Endpoint" ), verifier )

   If !( Account_Name := Imgur_AccountName() )
   {
      MsgBox, 16, Imgur API: Critical Error, % ""
      . "There was a problem verifying the access token. This script will exit."
      . "`nLast Response: " OAuth_LastResponse()
      Exitapp
   }

   ; Store the token and secret in the config.ini for future use. NOTE: tokens should be encrypted for storage.
   IniWrite, % Access_Token, % IniFile, Imgur: OAuth Tokens, Access_Token
   IniWrite, % OAuth_TokenSecret(), % IniFile, Imgur: OAuth Tokens, Token_Secret
   
   If FileExist(A_Windir "\Media\tada.wav")
	{
		SoundPlay, %A_WinDir%\Media\tada.wav, wait
		Sleep 1000
	}
   StringUpper, Account_Name, Account_Name, T
   Notify("Account added", "Welcome, " Account_Name, 4)
}
StringUpper, Account_Name, Account_Name, T

return ; Finished with oAuthCheck

InstallFiles:
GuiControl,, InstallText, Extracting...
GuiControl, Disable, Sure!
GuiControl, Disable, No thanks!
Traytip, Zizorz:, Extracting files..., 3
   FileCreateDir, Data   
      FileInstall, data\ZizorzSettings_default.ini, data\ZizorzSettings.ini
   FileCreateDir, Data\sounds
      FileInstall, data\sounds\scissors.wav, data\sounds\scissors.wav
      FileInstall, data\sounds\click.wav, data\sounds\click.wav
      FileInstall, data\sounds\drop.wav, data\sounds\drop.wav
   FileCreateDir, Data\img
   FileInstall, data\img\Zizorz.ico, data\img\Zizorz.ico
   FileInstall, data\img\exit.ico, data\img\exit.ico
   FileInstall, data\img\filedir.ico, data\img\filedir.ico
   FileInstall, data\img\key.ico, data\img\key.ico
   FileInstall, data\img\shortcut.ico, data\img\shortcut.ico
   FileInstall, data\img\save.ico, data\img\save.ico
   FileInstall, data\img\save.ico, data\img\settings.ico
   FileInstall, data\img\help.ico, data\img\help.ico
   FileInstall, data\img\feedback.ico, data\img\feedback.ico
   FileInstall, data\img\notification.ico, data\img\notification.ico
   FileInstall, data\img\zizorz_header.jpg, data\img\zizorz_header.jpg
   
Traytip, Zizorz:, Done!, 1
Gui, Install:Submit
return

Exit:
RestoreCursors() ; If unexpected exit
Gdip_Shutdown(pToken)
Sleep 1000
ExitApp
return


;===Functions==========================================================================

/* Non-anonymous upload
Imgur_Upload( image_file ) { ; ---------------------------------------------------------------------
; Uploads one image to the user's Imgur account and returns the URL of the image.
   Static EndPoint := "http://api.imgur.com/3/upload.xml"
   FileGetSize, size, % image_file
   FileRead, data, % "*c " image_file
   headers := OAuth_HeaderAuth( EndPoint, "", "POST" )
   . "`n" . "Content-Length: " size
   . "`n" . "Content-Type: application/octet-stream"
   HTTPRequest( EndPoint, data, headers, "Callback: Imgur_Progress" )
   OAuth_LastResponse( EndPoint ), OAuth_LastResponse( data ), OAuth_LastResponse( headers )
   StringGetPos, pos, data, <hash>
   If !( ErrorLevel )
      Return "http://i.imgur.com/" SubStr( data, pos + 7, Instr( data, "</hash>", 0, pos + 6 ) - pos - 7 ) ".jpg"
   Else Return "" ; error: see response
} ; Imgur_Upload( image_file ) ---------------------------------------------------------------------
*/
Imgur_Upload( image_file, Anonymous_API_Key, byref output_XML="" ) { ; -----------------------------
; Uploads one image file to Imgur via the anonymous API and returns the URL to the image.
; To acquire an anonymous API key, please register at http://imgur.com/register/api_anon.
; This function was written by [VxE] and relies on the HTTPRequest function, also by [VxE].
; HTTPRequest can be found at http://www.autohotkey.com/forum/viewtopic.php?t=73040
   Static Imgur_Upload_Endpoint := "https://api.imgur.com/3/image"
   FileGetSize, size, % image_file
   FileRead, output_XML, % "*c " image_file
   If HTTPRequest( Imgur_Upload_Endpoint, output_XML, Response_Headers := "Authorization: Client-ID " Anonymous_API_Key) ; Option not used "Callback: Progress"
   && ( pos := InStr( output_XML, "<original>" ) )
      Return SubStr( output_XML, pos + 10, Instr( output_XML, "</original>", 0, pos ) - pos - 10 )
   Else Return "" ; error: see response
} ; Imgur_Upload( image_path, Anonymous_API_Key, byref output_XML="" ) -----------------------------


Progress( pct, total ) {
   If ( pct = "" )
      Tooltip
   Else If ( pct < 0 )
      Tooltip, % "Uploading... " Round( 100 * ( pct + 1 ), 1 ) "%", 0, 0
   Else If ( 0 <= pct )
      Tooltip, % "Done!", 0, 0
   return
}

Imgur_AccountName() { ; ----------------------------------------------------------------------------
; Returns the name (url) of the account that has authorized this script.
   Static EndPoint := "http://api.imgur.com/2/account.xml"
   headers := OAuth_HeaderAuth( EndPoint, "", "GET" )
   HTTPRequest( EndPoint, data := "", headers )
   OAuth_LastResponse( EndPoint ), OAuth_LastResponse( data ), OAuth_LastResponse( headers )
   StringGetPos, pos, data, <url>
   If ( ErrorLevel )
      Return "" ; failure
   StringTrimLeft, data, data, pos + 5
   Return SubStr( data, 1, InStr( data, "<" ) - 1 )
} ; Imgur_AccountName() ----------------------------------------------------------------------------


XML_MakePretty( XML, Tab="`t" ) { ; ----------------------------------------------------------------
; Function by [VxE]. Adds newlines and tabs between XML tags to give human-friendly arrangement to
; an XML stream. 'Tab' contains the string to use as an indentation unit (it may be more readable to
; use 2 or 3 spaces instead of a full tab... so it's up to you!).
   oel := ErrorLevel, PrevCloseTag := 0, tabs := "", tablen := StrLen( tab )
   StringLen, pos, XML
   Loop, Parse, XML, <, % "`t`r`n "
      If ( A_Index = 1 )
         VarSetCapacity( XML, pos, 0 )
      Else
      {
         StringGetPos, pos, A_LoopField, >
         StringMid, b, A_LoopField, pos, 1
         StringLeft, a, A_LoopField, 1
         If !( OpenTag := a != "/" ) * ( CloseTag := a = "/" || a = "!" || a = "?" || b = "/" )
            StringTrimRight, tabs, tabs, tablen
         XML .= ( OpenTag || PrevCloseTag ? tabs : "" ) "<" A_LoopField
         If !( PrevCloseTag := CloseTag ) * OpenTag
            tabs := ( tabs = "" ? "`n" : tabs ) tab
      }
   Return XML, ErrorLevel := oel
} ; XML_MakePretty( XML, Tab="`t" ) ----------------------------------------------------------------

RestoreCursors()
{
   SPI_SETCURSORS := 0x57
   DllCall( "SystemParametersInfo", UInt,SPI_SETCURSORS, UInt,0, UInt,0, UInt,0 )
}

SetSystemCursor( Cursor = "", cx = 0, cy = 0 )
{
   BlankCursor := 0, SystemCursor := 0, FileCursor := 0 ; init
   
   SystemCursors = 32512IDC_ARROW,32513IDC_IBEAM,32514IDC_WAIT,32515IDC_CROSS
   ,32516IDC_UPARROW,32640IDC_SIZE,32641IDC_ICON,32642IDC_SIZENWSE
   ,32643IDC_SIZENESW,32644IDC_SIZEWE,32645IDC_SIZENS,32646IDC_SIZEALL
   ,32648IDC_NO,32649IDC_HAND,32650IDC_APPSTARTING,32651IDC_HELP
   
   If Cursor = ; empty, so create blank cursor 
   {
      VarSetCapacity( AndMask, 32*4, 0xFF ), VarSetCapacity( XorMask, 32*4, 0 )
      BlankCursor = 1 ; flag for later
   }
   Else If SubStr( Cursor,1,4 ) = "IDC_" ; load system cursor
   {
      Loop, Parse, SystemCursors, `,
      {
         CursorName := SubStr( A_Loopfield, 6, 15 ) ; get the cursor name, no trailing space with substr
         CursorID := SubStr( A_Loopfield, 1, 5 ) ; get the cursor id
         SystemCursor = 1
         If ( CursorName = Cursor )
         {
            CursorHandle := DllCall( "LoadCursor", Uint,0, Int,CursorID )   
            Break               
         }
      }   
      If CursorHandle = ; invalid cursor name given
      {
         Msgbox,, SetCursor, Error: Invalid cursor name
         CursorHandle = Error
      }
   }   
   Else If FileExist( Cursor )
   {
      SplitPath, Cursor,,, Ext ; auto-detect type
      If Ext = ico 
         uType := 0x1   
      Else If Ext in cur,ani
         uType := 0x2      
      Else ; invalid file ext
      {
         Msgbox,, SetCursor, Error: Invalid file type
         CursorHandle = Error
      }      
      FileCursor = 1
   }
   Else
   {   
      Msgbox,, SetCursor, Error: Invalid file path or cursor name
      CursorHandle = Error ; raise for later
   }
   If CursorHandle != Error 
   {
      Loop, Parse, SystemCursors, `,
      {
         If BlankCursor = 1 
         {
            Type = BlankCursor
            %Type%%A_Index% := DllCall( "CreateCursor"
            , Uint,0, Int,0, Int,0, Int,32, Int,32, Uint,&AndMask, Uint,&XorMask )
            CursorHandle := DllCall( "CopyImage", Uint,%Type%%A_Index%, Uint,0x2, Int,0, Int,0, Int,0 )
            DllCall( "SetSystemCursor", Uint,CursorHandle, Int,SubStr( A_Loopfield, 1, 5 ) )
         }         
         Else If SystemCursor = 1
         {
            Type = SystemCursor
            CursorHandle := DllCall( "LoadCursor", Uint,0, Int,CursorID )   
            %Type%%A_Index% := DllCall( "CopyImage"
            , Uint,CursorHandle, Uint,0x2, Int,cx, Int,cy, Uint,0 )      
            CursorHandle := DllCall( "CopyImage", Uint,%Type%%A_Index%, Uint,0x2, Int,0, Int,0, Int,0 )
            DllCall( "SetSystemCursor", Uint,CursorHandle, Int,SubStr( A_Loopfield, 1, 5 ) )
         }
         Else If FileCursor = 1
         {
            Type = FileCursor
            %Type%%A_Index% := DllCall( "LoadImageA"
            , UInt,0, Str,Cursor, UInt,uType, Int,cx, Int,cy, UInt,0x10 ) 
            DllCall( "SetSystemCursor", Uint,%Type%%A_Index%, Int,SubStr( A_Loopfield, 1, 5 ) )         
         }          
      }
   }   
}

win_Flash(FlashID="", Color="3a90ff") ; Optionally enter Win ID & color (HEX). Default is active window
{
 If (!FlashID)
  WinGet, FlashID, ID, A
 WinGetPos, X, Y, W, H, ahk_id %FlashID%
 Gui, 15: Default ; Arbitrary number
 Gui, Destroy
 Gui, +AlwaysOnTop -caption +Border +ToolWindow +LastFound
 Gui, Color, %Color%
 WinSet, Transparent, 0
 Gui, Show, x%X% y%Y% w%w% h%h%
 
 T := 0  ; We start at 0% opacity, go up to 50% smoothly, then back down
 
 Loop, 25 {
   Sleep 15
   T += 2
   WinSet, Transparent, %T% 
 }
 
 Loop, 25 {
   Sleep 15
   T -= 2
   WinSet, Transparent, %T% 
 }
 
 Gui, Destroy
 return
}


DragBox(ByRef OutX1="", ByRef OutY1="", ByRef OutX2="", ByRef OutY2="", Byref OutW="", ByRef OutH="", Color="FFFFFF") ; By nimda, modified by sumon to add return-object and modifier-color-support
{
   If InStr(OutX1, "Color")
      Color := SubStr(OutX1, -5, 6) ; Get the last 6 digits of Color, format would then be "Color:#80AAE3" f.ex.
   CoordMode Mouse
   MouseGetPos oX, oY
   Gui New
   Gui +alwaysontop -Caption +Border +ToolWindow +LastFound
   
   Gui, Color, %Color%
   If (Color = "0000FF") ; Set no color to make the box transparent
	  WinSet, TransColor, 0000FF 
   else
	 WinSet, Transparent, 50 ; Else Add transparency
   While GetKeyState("LButton", "P")
   {
	  MouseGetPos cX, cY
	  H := abs(oY-cY), W := abs(oX-cX)
	  ,GuiX := oX, GuiY := oY
	  If ( cY < oY )
		 GuiY := cY
	  If ( cX < oX )
		 GuiX := cX
      
      If GetKeyState("LCtrl") AND GetKeyState("LShift") 
         Color := "ff0000", Hotkey := "CtrlShift" ; Warning: Incorrect
      else if GetKeyState("LCtrl") AND GetKeyState("LAlt")
         Color := "ff0000", Hotkey := "CtrlAlt"  ; Warning: Incorrect
      else if GetKeyState("LShift")
         Color := "3A90FF", Hotkey := "Shift" ; Light blue
      else if GetKeyState("LCtrl")
         Color := "2de712", Hotkey := "Ctrl" ; Green
      else if GetKeyState("LAlt")
         Color := "FFCD41", Hotkey := "Alt" ; Yellow
      else
         Color := "FFFFFF", Hotkey := ""
      
      Gui, Color, %Color%
      
	  Gui Show, w%W% h%H% x%GuiX% y%GuiY% NoActivate
   }
   Gui Cancel
   OutX1 := oX < cX ? oX : cX
,	OutY1 := oY < cY ? oY : cY
,	OutX2 := oX > cX ? oX : cX
,	OutY2 := oY > cY ? oY : cY
,	OutW := OutX2 - OutX1
,	OutH := OutY2 - OutY1
,   OutHotkey := Hotkey

   obj := {X1: OutX1, X2: OutX2, Y1: OutY1, Y2: OutY2, W: OutW, H: OutH, Hotkey: OutHotkey} ; Optionally return an object
   return obj
}

IniRead( Filename, Section, Key, Default=" " ) {
   IniRead, OutputVar, % Filename, % Section, % Key, % Default
   Return OutputVar
}