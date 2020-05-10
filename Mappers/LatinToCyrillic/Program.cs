using System;
using System.IO;

namespace QwertyToCyrilic
{
    // Maps Text from Latin To Cyrillic (Example: 'qwerty' is mapped to 'йцукен' and so on)
    // Perfomance - maps 7MB file with text in less than second, but takes 9 seconds to display everything in console
    class Program
    {
        static void Main(string[] args)
        {
            if (args.Length == 0)
            {
                PrintHelpAndExit();
            }

            if (args.Length > 2)
            {
                Console.WriteLine("Argument count was more than 2");
                PrintHelpAndExit();
            }

            string text = string.Empty;
            if (args[0] == "-p")
            {
                string pathArgument = args[1];
                string path = pathArgument.Trim('"');
                if (Path.GetExtension(path) != ".txt")
                {
                    Console.WriteLine("File extension must be .txt");
                    Environment.Exit(0);
                }

                try
                {
                    text = File.ReadAllText(path);
                }
                catch(DirectoryNotFoundException e)
                {
                    Console.WriteLine("\n" + e.Message);
                    Console.WriteLine("Please check if your path is correct");
                    Environment.Exit(0);
                }
            }
            else if (args[0] == "-t")
            {
                text = args[1];
            }
            else
            {
                Console.WriteLine("Unknown First Argument");
                PrintHelpAndExit();
            }

            int stringLength = text.Length;
            if (stringLength == 0)
            {
                if (args[0] == "p")
                {
                    Console.WriteLine("Error reading text from file, check your path");
                    PrintHelpAndExit();
                }
                else
                {
                    Console.WriteLine("Error reading text as argument, size of text was 0, perhaps you forgot quotes?");
                    PrintHelpAndExit();
                }
            }

            char[] buffer = new char[stringLength]; 
            for (int i = 0; i < stringLength; i++)
            {
                switch (text[i])
                {
                    case 'q':
                        buffer[i] = ('й');
                        continue;
                    case 'w':
                        buffer[i] = ('ц');
                        continue;
                    case 'e':
                        buffer[i] = ('у');
                        continue;
                    case 'r':
                        buffer[i] = ('к');
                        continue;
                    case 't':
                        buffer[i] = ('е');
                        continue;
                    case 'y':
                        buffer[i] = ('н');
                        continue;
                    case 'u':
                        buffer[i] = ('г');
                        continue;
                    case 'i':
                        buffer[i] = ('ш');
                        continue;
                    case 'o':
                        buffer[i] = ('щ');
                        continue;
                    case 'p':
                        buffer[i] = ('з');
                        continue;
                    case 'a':
                        buffer[i] = ('ф');
                        continue;
                    case '[':
                        buffer[i] = ('х');
                        continue;
                    case ']':
                        buffer[i] = ('ъ');
                        continue;
                    case 's':
                        buffer[i] = ('ы');
                        continue;
                    case 'd':
                        buffer[i] = ('в');
                        continue;
                    case 'f':
                        buffer[i] = ('а');
                        continue;
                    case 'g':
                        buffer[i] = ('п');
                        continue;
                    case 'h':
                        buffer[i] = ('р');
                        continue;
                    case 'j':
                        buffer[i] = ('о');
                        continue;
                    case 'k':
                        buffer[i] = ('л');
                        continue;
                    case 'l':
                        buffer[i] = ('д');
                        continue;
                    case ';':
                        buffer[i] = ('ж');
                        continue;
                    case '\'':
                        buffer[i] = ('э');
                        continue;
                    case 'z':
                        buffer[i] = ('я');
                        continue;
                    case 'x':
                        buffer[i] = ('ч');
                        continue;
                    case 'c':
                        buffer[i] = ('с');
                        continue;
                    case 'v':
                        buffer[i] = ('м');
                        continue;
                    case 'b':
                        buffer[i] = ('и');
                        continue;
                    case 'n':
                        buffer[i] = ('т');
                        continue;
                    case 'm':
                        buffer[i] = ('ь');
                        continue;
                    case ',':
                        buffer[i] = ('б');
                        continue;
                    case '.':
                        buffer[i] = ('ю');
                        continue;
                    case '/':
                        buffer[i] = ('.');
                        continue;
                    default:
                        buffer[i] = text[i];
                        continue;
                }
            }

            Console.WriteLine(new string(buffer));
            Console.WriteLine("\n\nDONE\n\n");
        }

        static void PrintHelpAndExit()
        {
            Console.WriteLine("\nFirst argument must be '-t' with text provided as next argument, or 'p' with provided path to file with text contents");
            Console.WriteLine("Example 1: -t \"this text must be in double quotes\" \nExample 2: -p \"this/path/must be/in double quotes\"");
            Environment.Exit(0);
        }
    }
}