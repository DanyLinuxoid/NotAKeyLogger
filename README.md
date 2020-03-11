# NotAKeyLogger

Small (for now) and simply implemented keylogger written in masm32

For now is capable of:
1) Creating dll file (this contains captured keys) and during startup moves itself together with dll in other folder, located on C drive
2) Can capture all number/character keys and capslock+shift keys, writes them to dll file
3) Is able to write himself in registry, for autostartup
4) Is able to stay as launched process as long as it is needed
