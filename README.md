# NotAKeyLogger

Beta 0.1

Small (for now) and simply implemented keylogger written in MASM32 with minimum set of macros, because author likes "Visual Studio" and MASM is the only compatible with it :) 
This small malware consists of two .exe files, both are MOSTLY standalone.

--- First program is "NotAKeyLogger" (temporary name), core program.
Writes itself in registry(autostartup), then intercepts user pressed keys and writes them to file with .dll extension.
--- Second program is "KeyLoggerMonitor", manager/monitor for "NotAKeyLogger". 
This program mostly is needed to watch after "NotAKeyLogger", so it would remain in active state (launched).
Soon will be able to send .dll file with it's contents to remote server (will be implemented soon).

Things to be done (In progress):
1. Possibility to send .dll file on remote server through sockets (requires server to be installed), currently in progress.
2. For "KeyLoggerMonitor" - in case if "NotAKeyLogger" is not existing on machine, then download it from server and launch it.
3. (QUESTIONABLE) Self encryption + .dll contents encryption and polymorphic code (to be less detectable)
4. Signature, filename change, icon change (Disguise)
5. Perfomance improvements

Fun Fact: Currently "Kaspersky" with highest security settings detects both programms as "HEUR:Trojan.Win32.Generic"
