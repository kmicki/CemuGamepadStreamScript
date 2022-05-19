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

RestoreCursors()
{
	SPI_SETCURSORS := 0x57
	DllCall( "SystemParametersInfo", UInt,SPI_SETCURSORS, UInt,0, UInt,0, UInt,0 )
}



#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
Coordmode, Mouse, Screen

hmenug := 0

; Shortcut: Win+C
; Move gamepad view to secondary monitor and maximize
; Move Cemu main view to primary monitor and maximize
; Hide title bars and menu
; Set taskbar autohide
; Hide mouse cursor
#c::

	global hmenug

	; Set taskbar autohide
		VarSetCapacity(APPBARDATA, A_PtrSize=4 ? 36:48)
		NumPut(DllCall("Shell32\SHAppBarMessage", "UInt", 4 ; ABM_GETSTATE
												, "Ptr", &APPBARDATA
												, "Int")
		? 1:1, APPBARDATA, A_PtrSize=4 ? 32:40) ; 2 - ABS_ALWAYSONTOP, 1 - ABS_AUTOHIDE
		, DllCall("Shell32\SHAppBarMessage", "UInt", 10 ; ABM_SETSTATE
										   , "Ptr", &APPBARDATA)

	; Hide mouse cursor
	SetSystemCursor()

	Sleep, 50

	SysGet, MonPri, MonitorPrimary
	MonSec := 1
	if(MonPri = 1) {
		MonSec := 2
	}

	; Attempt to move Gamepad to New Window
	SysGet, Mon1, Monitor, %MonSec% ; Get secondary Monitor Info X and Y
	WinGetPos, Padx, Pady, Padw, Padh, GamePad View ; Get the GamePad's Width and Height Probably not necessary as we maximize below
	WinMove, GamePad View,, %Mon1Left%, %Mon1Top%, Padw, Padh ; Move Window to secondary monitor
	WinMaximize, GamePad View ; Maximize window to fill Monitor
	WinSet, Style, -0xC00000, GamePad View  ; Remove the title bar

	; Attempt to move Cemu to New Window
	SysGet, Mon1, Monitor, %MonPri% ; Get primary Monitor Info X and Y
	WinGetPos, Padx, Pady, Padw, Padh, Cemu ; Get the Cemu's Width and Height Probably not necessary as we maximize below
	WinMove, Cemu,, %Mon1Left%, %Mon1Top%, Padw, Padh ; Move Window to primary monitor
	WinMaximize, Cemu ; Maximize window to fill Monitor
	WinSet, Style, -0xC00000, Cemu  ; Remove the title bar

	WinWait Cemu,,2

	; Remove menu bar in Cemu
	if (ErrorLevel = 0) {
		hmenu:=DllCall("GetMenu", uint, WinExist())  ; Get menu bar of "last found window".
		if(hmenu!=0) {
			hmenug := hmenu
		}
		DllCall("SetMenu", uint, WinExist(), uint, 0)  ; Remove menu bar of "last found window".
	}

	return

; Shortcut Win+Z
; Restore size of gamepad view and move to primary monitor
; Restore size of Cemu main view and move to primary monitor
; Restore title bars and menu
; Reset taskbar autohide
; Restore mouse cursor
#z::

	global hmenug

	; reset taskbar autohide
		VarSetCapacity(APPBARDATA, A_PtrSize=4 ? 36:48)
		NumPut(DllCall("Shell32\SHAppBarMessage", "UInt", 4 ; ABM_GETSTATE
												, "Ptr", &APPBARDATA
												, "Int")
		? 2:2, APPBARDATA, A_PtrSize=4 ? 32:40) ; 2 - ABS_ALWAYSONTOP, 1 - ABS_AUTOHIDE
		, DllCall("Shell32\SHAppBarMessage", "UInt", 10 ; ABM_SETSTATE
										   , "Ptr", &APPBARDATA)

	; restore mouse cursor
	RestoreCursors()

	Sleep, 50

	; Restore Gamepad view
	WinRestore, GamePad View

	SysGet, MonPri, MonitorPrimary
	MonSec := 1
	if(MonPri = 1) {
		MonSec := 2
	}

	; Attempt moving Gamepad View back to primary monitor
	SysGet, Mon1, Monitor, %MonPri% ; Get primary Monitor Info X and Y
	WinGetPos, Padx, Pady, Padw, Padh, GamePad View ; Get the GamePad's Width and Height
	WinMove, GamePad View,, %Mon1Left%, %Mon1Top%, Padw, Padh ; Move Window to primary monitor

	WinSet, Style, +0xC00000, GamePad View  ; Restore the title bar

	; Restore Cemu Window
	WinRestore, Cemu

	; Attempt moving Gamepad View back to primary monitor
	WinGetPos, Padx, Pady, Padw, Padh, Cemu ; Get the Cemu's Width and Height
	WinMove, Cemu,, %Mon1Left%, %Mon1Top%, Padw, Padh ; Move Window to primary monitor

	WinSet, Style, +0xC00000, Cemu  ; Restore the title bar

	WinWait Cemu,,2

	; Restore the menu bar in Cemu
	if (ErrorLevel = 0) {
		if(hmenug != 0) {
			DllCall("SetMenu", uint, WinExist(), uint, hmenug)  ; Restoree menu bar of "last found window".
		}

	}
	hmenug := 0

	return

; Shortcut Win+P
; Move mouse cursor to primary monitor (Cemu main view)
#p::
	Coordmode, Mouse, Screen
	SendMode Event

	SysGet, MonPri, MonitorPrimary
	MonSec := 1
	if(MonPri = 1) {
		MonSec := 2
	}

	SysGet, Mon1, Monitor, %MonPri% ; Get primary Monitor Info X and Y
	GoX := Mon1Left+100
	GoY := Mon1Top+100

	MouseMove %GoX%, %GoY%
	SendMode Input

	return

; Shortcut Win+O
; Move mouse cursor to secondary monitor (Gamepad view)
#o::
	Coordmode, Mouse, Screen
	SendMode Event

	SysGet, MonPri, MonitorPrimary
	MonSec := 1
	if(MonPri = 1) {
		MonSec := 2
	}
	SendMode Input

	SysGet, Mon1, Monitor, %MonSec% ; Get second Monitor Info X and Y
	GoX := Mon1Left+100
	GoY := Mon1Top+100

	MouseMove %GoX%, %GoY%

	return