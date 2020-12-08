# **NotAKeyLogger**

Beta 0.6

Simply implemented keylogger written in MASM32 with minimum set of macros and other helper programs.
Why MASM32 - This is the only one that is fully integrated in Visual Studio (IMO best IDE).
This small malware consists of two .exe files, both are MOSTLY standalone.

## PROCESS:
---- First program is "NotAKeyLogger" (temporary name), core program.
- Is able to check if duplicate processes exist, if exists, then it self-terminates.
- During application startup sends file with intercepted keys to server via sockets.
- Writes itself in registry(autostartup)
- Then intercepts user pressed keys and writes them to file with .dll extension

---- Second program is "KeyLoggerMonitor", manager/monitor for "NotAKeyLogger". 
- This is the one, that must be launched by user (would be best option)
- Checks if file presents on computer in specific path, if not, then it downloads file from socket server on required path and launches it.
- Able to write itself in registry as well during startup
- After launch, watches after main KeyLogger so it would remain in active/launched state.
- During runtime checks for duplicate "NotAKeyLogger" processes, not to launch multiple/multiple times.

## USAGE
**IF you just want to use**
1. You have to setup server in online (public network/globally available), or leave it as it is (private netwotk).
2. You have to change IP and PORT address so you would be able to connect to server in KeyLoggerMonitor and NotAKeyLogger, this can be easily found in code by comments.
3. **YOU HAVE TO TEST IF IT WORKS FOR YOU AND RUN IT ON SOME TEST ENVIRONMENT** 
4. Then you can just send KeyLoggerMonitor.exe to victim.

**IF you're a developer and want to change things**
Some MASM32 and 'C' basics required. 
Code is commented, so you can dig your way through and change it as you wish.

## DISADVANTAGES:
1. Currently program will write only Latin intercepted characters based on QWERTY layout, even if user is using russian layout, for this case there was Mapper program created. 
There will be no possibility implemented for keylogger to determine language on computer and write characters to file based on choosen language (this will decrease perfomance + requires A LOT of code space for junky character sets and comparisons)! Use Mappers or create your own for other languages. 
2. Currently, if Windows language is set to any other than English, program will be unable to construct path for files and will not work properly (because in code it has English hardcoded path parts). This can be solved by hardcoding path parts for other languages as well and then based on Windows language use needed parts.

Things to be done:
1. (QUESTIONABLE) Self encryption + .dll contents encryption and polymorphic code (to be less detectable)
2. Signature, filename change, icon change (Disguise)

Fun Fact: Currently "Kaspersky" with highest security settings detects both programms as "HEUR:Trojan.Win32.Generic"
