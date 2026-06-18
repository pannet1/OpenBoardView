// Minimal HTTP server for testing OpenBoardView WASM build
// Usage: ./wasm_server [port] [root_dir]
#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <string>
#include <fstream>
#include <sstream>
#include <iostream>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <netinet/in.h>
#include <csignal>

const char *mime_type(const char *path) {
    const char *ext = strrchr(path, '.');
    if (!ext) return "application/octet-stream";
    if (strcmp(ext, ".wasm") == 0) return "application/wasm";
    if (strcmp(ext, ".js") == 0)   return "application/javascript";
    if (strcmp(ext, ".html") == 0) return "text/html";
    if (strcmp(ext, ".css") == 0)  return "text/css";
    if (strcmp(ext, ".png") == 0)  return "image/png";
    if (strcmp(ext, ".svg") == 0)  return "image/svg+xml";
    if (strcmp(ext, ".json") == 0) return "application/json";
    if (strcmp(ext, ".ico") == 0)  return "image/x-icon";
    return "application/octet-stream";
}

std::string read_file(const std::string &path, size_t &size) {
    std::ifstream file(path, std::ios::binary | std::ios::ate);
    if (!file) { size = 0; return {}; }
    size = file.tellg();
    file.seekg(0);
    std::string data(size, '\0');
    file.read(&data[0], size);
    return data;
}

std::string status_line(int code) {
    switch (code) {
        case 200: return "200 OK";
        case 404: return "404 Not Found";
        case 405: return "405 Method Not Allowed";
        case 500: return "500 Internal Server Error";
        default:  return "500 Internal Server Error";
    }
}

void send_response(int fd, int code, const char *mime, const std::string &body) {
    std::ostringstream resp;
    resp << "HTTP/1.1 " << status_line(code) << "\r\n"
         << "Content-Type: " << mime << "\r\n"
         << "Content-Length: " << body.size() << "\r\n"
         << "Cross-Origin-Opener-Policy: same-origin\r\n"
         << "Cross-Origin-Embedder-Policy: require-corp\r\n"
         << "Connection: close\r\n"
         << "\r\n"
         << body;
    std::string resp_str = resp.str();
    send(fd, resp_str.data(), resp_str.size(), 0);
}

std::string root_dir;
int server_fd = -1;

void handle_client(int fd) {
    char buf[4096];
    int n = recv(fd, buf, sizeof(buf) - 1, 0);
    if (n <= 0) { close(fd); return; }
    buf[n] = '\0';

    if (strncmp(buf, "GET ", 4) != 0) {
        send_response(fd, 405, "text/plain", "Only GET is supported");
        close(fd);
        return;
    }

    char method[16], path[1024], version[16];
    sscanf(buf, "%15s %1023s %15s", method, path, version);

    // Remove query string
    char *q = strchr(path, '?');
    if (q) *q = '\0';

    // Default to index.html
    std::string file_path = root_dir;
    if (strcmp(path, "/") == 0) {
        file_path += "/index.html";
    } else {
        file_path += path;
    }

    // Prevent directory traversal
    if (file_path.find("..") != std::string::npos) {
        send_response(fd, 404, "text/plain", "Forbidden");
        close(fd);
        return;
    }

    struct stat st;
    if (stat(file_path.c_str(), &st) != 0 || !S_ISREG(st.st_mode)) {
        send_response(fd, 404, "text/html",
            "<html><body><h1>404 Not Found</h1></body></html>");
        close(fd);
        return;
    }

    size_t size;
    std::string body = read_file(file_path, size);
    if (body.empty() && size > 0) {
        send_response(fd, 500, "text/plain", "Failed to read file");
    } else {
        send_response(fd, 200, mime_type(file_path.c_str()), body);
    }
    close(fd);
}

void shutdown_server(int) {
    if (server_fd >= 0) close(server_fd);
    std::cerr << "\nServer stopped." << std::endl;
    exit(0);
}

int main(int argc, char **argv) {
    int port = argc > 1 ? atoi(argv[1]) : 8080;
    root_dir = argc > 2 ? argv[2] : ".";

    signal(SIGINT, shutdown_server);
    signal(SIGTERM, shutdown_server);

    server_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (server_fd < 0) { perror("socket"); return 1; }

    int opt = 1;
    setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    struct sockaddr_in addr{};
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port = htons(port);

    if (bind(server_fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        perror("bind"); return 1;
    }
    if (listen(server_fd, 5) < 0) {
        perror("listen"); return 1;
    }

    std::cerr << "Serving " << root_dir << " at http://localhost:" << port << std::endl;

    while (true) {
        struct sockaddr_in client{};
        socklen_t len = sizeof(client);
        int client_fd = accept(server_fd, (struct sockaddr *)&client, &len);
        if (client_fd < 0) { perror("accept"); continue; }
        handle_client(client_fd);
    }
    return 0;
}
