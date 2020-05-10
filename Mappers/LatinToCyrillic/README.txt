Maps Latin characters to Cyrilic characters based on QWERTY keyboard layout.
Example: 'qwerty' will be mapped to 'йцукен'
Perfomance: Maps 7MB txt file in 10 seconds (9 seconds to display in console)

NOTE: DON'T LAUNCH EXE FROM POWERSHELL, launch from CMD instead, otherwise it behaves incorrectly.

How to use: 
first argument must be '-t' (stands for text) or '-p' (stands for path)
If u have chosen -p, then next argument must be full path to your .txt file ENCLOSED IN DOUBLE QUOTES
If u have chosen -t, then next argument must be any text ENCLOSED IN DOUBLE QUOTES

Example 1: QwertyToCyrilic -t "This is some text to translate to cyrillic"
Example 2: QwertyToCyrilic -p "path\to\your\txtfile\withlatinchars"