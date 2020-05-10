# NotAKeyLogger

Beta 0.5

Simply implemented keylogger written in MASM32 with minimum set of macros, because author likes "Visual Studio" and MASM is the only compatible with it :) 
This small malware consists of two .exe files, both are MOSTLY standalone.

--- First program is "NotAKeyLogger" (temporary name), core program.
Writes itself in registry(autostartup), then intercepts user pressed keys and writes them to file with .dll extension, during application startup sends file with intercepted keys to server via sockets.
--- Second program is "KeyLoggerMonitor", manager/monitor for "NotAKeyLogger". 
This program is needed to watch after "NotAKeyLogger", so it would remain in active state (launched) and there would be no duplicate processes.

Things to be done (In progress):
1. For "KeyLoggerMonitor" - in case if "NotAKeyLogger" is not existing on machine, then download it from server and launch it.
2. (QUESTIONABLE) Self encryption + .dll contents encryption and polymorphic code (to be less detectable)
3. Signature, filename change, icon change (Disguise)

Fun Fact: Currently "Kaspersky" with highest security settings detects both programms as "HEUR:Trojan.Win32.Generic"
