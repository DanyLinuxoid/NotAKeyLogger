# **NotAKeyLogger**

Beta 0.65

Simply implemented keylogger written in MASM32 with minimum set of macros and other helper programs.
Why MASM32 - This is the only one that is fully integrated in Visual Studio (IMO best IDE).
This small malware consists of two .exe files, both are MOSTLY standalone.

## PROCESS:
---- First program is "NotAKeyLogger" (temporary name), core program.
- Is able to check if duplicate processes exist, if exists, then it self-terminates.
- During application startup sends file with intercepted keys to server via sockets.
- Writes itself in registry(autostartup)
- Then intercepts user pressed keys, encrypts them and writes to file with .dll extension

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

## PERFOMANCE
Although there are a lot of readings in google about keylogger/ings with windows LowKeyHooks(poor and detectable method compared with .dll method) are slow as hell, this keylogger after 0.5 BETA had perfomance improvement in main key listener loop. Currently on I5-7300HQ processor and SSD-256 hard drive, during logging, 90% of time task manager is showing 0% in CPU tag and sometimes it rises up to 0.3%, quite decent for keylogger which listens for all key hooks :)

**IF you're a developer and want to change things**
Some MASM32 and 'C' basics required. 
Code is commented, so you can dig your way through and change it as you wish.

## DISADVANTAGES:
1. Currently program will write only Latin intercepted characters based on QWERTY layout, even if user is using russian layout, for this case there was Mapper program created. 
There will be no possibility implemented for keylogger to determine language on computer and write characters to file based on choosen language (this will decrease perfomance + requires A LOT of code space for junky character sets and comparisons)! Use Mappers or create your own for other languages.

## TODO:
1. Polymorphic code
2. Signature, filename change, icon change, process name change

Fun Fact: Currently "Kaspersky" with highest security settings detects both programms as "HEUR:Trojan.Win32.Generic"
