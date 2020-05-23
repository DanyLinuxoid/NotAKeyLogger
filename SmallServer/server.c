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

// Errors Section Start
const char* Error_Socket_Accept_Failed = "Accept failed\n";
const char* Error_Socket_Creation_Failed = "Socket creation throwed error more than 10 times\n";
const char* Error_Socket_Option_Set_Failed = "Failed setting up options for socket\n";
const char* Error_Socket_Port_Bind_Failed = "Bind failed to port";
const char* Error_Socket_Listen_Failed = "Listen failed\n";
const char* Error_File_Open_Failed = "Failed to open file\n";
const char* Error_File_Read_Into_Buffer_Failed = "Failed to read file into buffer\n";
const char* Error_File_Write_Into_FD_Failed = "Failed to write buffer into file desciptor\n";
const char* Error_Malloc_Failed = "Memory allocation failed\n";
//Errors Section End

// Define Section Start
#ifndef SOL_TCP
    #define SOL_TCP 6  // socket options TCP level
#endif
#ifndef TCP_USER_TIMEOUT
    #define TCP_USER_TIMEOUT 10  // socket timeout
#endif

#define MAX_FILE_BUFFERSIZE (1024 * 1024) * 8 // 8MB 
#define MAX_EXE_BUFFERSIZE 1024 * 1024 // 1MB
#define MAX_MESSAGE_BUFFERSIZE 128
#define BINDED_SUCCESS break
#define DROP_CONNECTION break
#define ERROR_ENCOUNTERED break
#define SERVER_IS_UP 1
#define CONNECTION_IS_UP 1
#define SOCKET_IS_UP 1
#define ERROR_OCCURED 1
#define SEND 1
#define ANYPORT 0
#define TRUE 0
#define RECEIVE 0
#define INVALID_SOCKET -1
#define INVALID_FILE -1
#define FALSE -1
// Define Section End

// Prototype Section Start
char* GetFileNameWithPathBasedOnCurrentTime();
char* ConcatTwoStrings(const char *s1, const char *s2, char* buffer);
char* GetCurrentTime();
int BindSocket(int sockfd);
int AcceptConnection(int max_connection_count, int master_socket, int client_sockets[], struct sockaddr_in address, int addrlen);
int Prepare_Master_Sockets(int* master_socket, struct sockaddr_in* address, int port);
void DisplayTime();
void PrintCustomErrorMessage(int error_code, char* text, char* optionalArgs);
void WriteToLog(int error_code, const char* message);
void HandleError(int error_code, const char* message);
void Reset_Client_Sockets(int client_sockets[], int max_connection_count);
void RemoveFinishedConnections(int client_sockets[], int max_connection_count, int receive_socket, int send_socket);
int SendOrReceiveFile(int socket_for_send, int option);
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
    int socket_for_receive;
    int socket_for_send;

    struct sockaddr_in receive_address; 
    struct sockaddr_in send_address;

    while (SERVER_IS_UP)
    {        
        if (Prepare_Master_Sockets(&socket_for_receive, &receive_address, 7145) == TRUE &&
            Prepare_Master_Sockets(&socket_for_send, &send_address, 7146) == TRUE)
        {
            //clear the socket set  
            Reset_Client_Sockets(client_sockets, max_connection_count);
            FD_ZERO(&readfds); 

            int addrlen_receive = sizeof(receive_address); 
            int addrlen_send = sizeof(send_address);

            while(SOCKET_IS_UP)
            {
                //add socket to set 
                FD_SET(socket_for_receive, &readfds);  
                FD_SET(socket_for_send, &readfds); 
                int max_socket_desc = socket_for_send;   
                    
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
                
                //If something happened on the 'receive' socket, then it's an incoming connection (receive) 
                int receive_socket_to_clean = 0;
                if (FD_ISSET(socket_for_receive, &readfds))   
                {   
                    int new_socket = AcceptConnection(max_connection_count, socket_for_receive, client_sockets, receive_address, addrlen_receive);
                    if (new_socket != INVALID_SOCKET)
                    {
                        receive_socket_to_clean = new_socket; // saving client so later we will remove him from list
                        int recv_size = SendOrReceiveFile(new_socket, RECEIVE);
                        if (recv_size != ERROR_OCCURED)
                        {
                            printf("Received file (%d bytes)\n", recv_size);   
                        }
                    }

                    close(new_socket);
                }   

                //or if something happened on the 'send' socket, then client wants to download something (send)
                int send_socket_to_clean = 0;
                if (FD_ISSET(socket_for_send, &readfds))
                {
                    int new_socket = AcceptConnection(max_connection_count, socket_for_send, client_sockets, send_address, addrlen_send);
                    if (new_socket != INVALID_SOCKET)
                    {
                        send_socket_to_clean = new_socket; // saving client so later we will remove him from list
                        if(SendOrReceiveFile(new_socket, SEND) != ERROR_OCCURED)
                        {
                            printf("Sended file\n");   
                        }
                    }

                    close(new_socket);
                }

                if (send_socket_to_clean != 0 || receive_socket_to_clean != 0) // if there was no errors during accept
                {
                    RemoveFinishedConnections(client_sockets, max_connection_count, receive_socket_to_clean, send_socket_to_clean);
                }
            }

            printf("Restarting server...\n");
        }

        close(socket_for_receive);
        close(socket_for_send);
    }
}

// Preparing master socket
int Prepare_Master_Sockets(int* master_socket, struct sockaddr_in* address, int port)
{
    address->sin_family = AF_INET;   
    address->sin_addr.s_addr = INADDR_ANY;   
    address->sin_port = htons(port); 

    if ((*master_socket = socket(AF_INET, SOCK_STREAM, 0)) == 0)   
    {   
        HandleError(errno, Error_Socket_Creation_Failed);
        return FALSE;
    }     

    int opt = 1;
    int timeout = 10000;
    if (setsockopt(*master_socket, SOL_SOCKET, SO_REUSEADDR, (int*)&opt, sizeof(int)) &&
        setsockopt(*master_socket, SOL_SOCKET, TCP_USER_TIMEOUT, (char*)&timeout, sizeof(timeout)) < 0)
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

// Accepts incoming connection 
int AcceptConnection(int max_connection_count, int master_socket, int client_sockets[], struct sockaddr_in address, int addrlen)
{
    int new_socket;
    if ((new_socket = accept(master_socket, (struct sockaddr*)&address, (socklen_t*)&addrlen)) < 0)   
    {   
        HandleError(errno, Error_Socket_Accept_Failed);
        close(new_socket);
        return INVALID_SOCKET;
    }   
    
    printf("NEW connection, socket: %d, IP: %s, PORT: %d\n", 
            new_socket, inet_ntoa(address.sin_addr), ntohs(address.sin_port));   
                    
    //add new socket to array of sockets  
    for (int i = 0; i < max_connection_count; i++)   
    {   
        //if position is empty  
        if (client_sockets[i] == 0)   
        {   
            client_sockets[i] = new_socket;   
            break;
        }   
    }   

    return new_socket;
}

// After accepting connections we need to exclude them from list
void RemoveFinishedConnections(int client_sockets[], int max_connections, int receive_socket, int send_socket)
{
    int client_count = 0; 
    for (int i = 0; i < max_connections; i++)
    {
        int potential_client_to_remove = client_sockets[i];
        if (receive_socket == potential_client_to_remove || send_socket == potential_client_to_remove)
        {
            client_sockets[i] = 0;
        }

        if (client_sockets[i] != 0)
        {
            client_count++;
        }
    }

    printf("Connection count: %d\n", client_count);
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

// Handles file receiving and sending 
int SendOrReceiveFile(int accepted_socket, int option)
{
    size_t bytesRed = 0;
    int file_size = 0;
    int error_encountered = 0;
    int cycle_count = 1;

    if (option == RECEIVE)
    {
        char* file_buffer = malloc(MAX_FILE_BUFFERSIZE);
        if (file_buffer == NULL)
        {
            HandleError(errno, Error_Malloc_Failed);
            return 1; // error 
        }

        int filefd = open(GetFileNameWithPathBasedOnCurrentTime(), O_WRONLY | O_CREAT | O_TRUNC, S_IRUSR | S_IWUSR);
        if (filefd == INVALID_FILE)
        {
            HandleError(errno, Error_File_Open_Failed);
            return 1; // error
        }

        // Receiving option
        do 
        {
            bytesRed = read(accepted_socket, file_buffer, MAX_FILE_BUFFERSIZE);
            if (cycle_count == 1)
            {
                file_size = (int)bytesRed;
            }

            if (bytesRed < 0)
            {
                error_encountered = 1;
                HandleError(errno, Error_File_Read_Into_Buffer_Failed);
                ERROR_ENCOUNTERED;
            }

            if (write(filefd, file_buffer, bytesRed) == INVALID_FILE)
            {
                error_encountered = 1;
                HandleError(errno, Error_File_Write_Into_FD_Failed);
                ERROR_ENCOUNTERED;
            }
            
            cycle_count++;
        }
        while(bytesRed > 0);
    
        if (error_encountered)
        {
            printf("Errors during file receive\n");
        }

        close(filefd);
        free(file_buffer);
    }
    else
    {
        char* file_buffer = malloc(MAX_EXE_BUFFERSIZE);
        if (file_buffer == NULL)
        {
            HandleError(errno, Error_Malloc_Failed);
            return 1;
        }

        char* exePath = "/home/lin/Desktop/server/executable/NotAKeyLogger.exe"; 
        FILE* filefd = fopen(exePath, "rb");
        if (filefd == NULL)
        {
            HandleError(errno, Error_File_Open_Failed);
            return 1;
        }     

        // Sending option
        fseek(filefd, 0L, SEEK_END);
        int size = ftell(filefd);
        rewind(filefd);

        size_t read_result = fread(file_buffer, 1, size, filefd);
        if (read_result <= 0)
        {
            error_encountered = 1;
            HandleError(errno, Error_File_Read_Into_Buffer_Failed);
        }
        else
        {
            while(size > 0)
            {
                int sent = write(accepted_socket, file_buffer, size); 
                if (sent < 0) 
                {
                    error_encountered = 1;
                    HandleError(errno, Error_File_Write_Into_FD_Failed);
                    ERROR_ENCOUNTERED;
                }

                size -= sent;
            }
        }
        
        close(filefd);
        free(file_buffer);
    }    
    
    return error_encountered == 0 ? file_size : error_encountered;
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
    char* path = "/home/lin/Desktop/server/client_files/"; //  SET YOUR DESIRED FILE PATH 
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
    FILE* filefd = fopen("/home/lin/Desktop/server/serverlog.txt", "a"); //  SET YOUR DESIRED FILE PATH 
    if (filefd == NULL)
    {
        perror("Failed to open/create file\n");
        return;
    }

    char message_to_write[MAX_MESSAGE_BUFFERSIZE];
    sprintf(message_to_write, "%s: %s, %s\n", GetCurrentTime(), strerror(error_code), message);
    if (fputs(message_to_write, filefd) == INVALID_FILE)
    {
        perror(Error_File_Write_Into_FD_Failed);
        return;
    }

    fclose(filefd);
}

// Small method for error handling, consists of two methods, that are being used often
void HandleError(int error_code, const char* message)
{
    perror(message);
    WriteToLog(error_code, message);
}