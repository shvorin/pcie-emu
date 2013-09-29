/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */

/* vim: set syntax=c et ts=4 sw=4: */

#ifndef SOCKET_H
#define SOCKET_H

#include <sys/socket.h>
#include <sys/types.h>
#include <sys/un.h>
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>

#define TRUE 1
#define FALSE 0

#define SOCKET_FAILED -1

#define __SOCKET_PATH "/tmp/fpga-emulator"

typedef struct {
    int sock;
    int is_bind;
} Socket;

static int Socket_Create (Socket * sock) {
    sock->sock = socket(AF_UNIX, SOCK_STREAM, 0);
    sock->is_bind = FALSE;
    return sock->sock == -1 ? SOCKET_FAILED : 0;
}

static int Socket_Accept (Socket * sock, Socket * listner) {
    sock->sock = accept(listner->sock, NULL, NULL);
    sock->is_bind = FALSE;
    return sock->sock == -1 ? SOCKET_FAILED : 0;
}

static int Socket_Register (Socket * sock) {
    if (fcntl(sock->sock, F_SETFL, O_ASYNC) == -1)
        return SOCKET_FAILED;
    if (fcntl(sock->sock, F_SETOWN, getpid()) == -1)
        return SOCKET_FAILED;
    return 0;
}

static int Socket_Check (Socket * sock, short * events) {
    struct pollfd pfd;
    pfd.fd = sock->sock;
    pfd.events = *events;
    for (;;) {
        int res = poll(&pfd, 1, 0);
        if (res != -1)
            break;
        if (errno != EINTR)
            return SOCKET_FAILED;
    }
    *events = pfd.revents;
    return 0;
}

// Bind it to __SOCKET_PATH
static int Socket_Bind (Socket * sock) {
    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, __SOCKET_PATH, sizeof(addr.sun_path) - 1);
    if (bind(sock->sock, (struct sockaddr *) &addr, sizeof(addr)) == -1)
        return SOCKET_FAILED;
    sock->is_bind = TRUE;
    if (listen(sock->sock, 1) == -1) {
        unlink(__SOCKET_PATH);
        return SOCKET_FAILED;
    }
    return 0;
}

// Connect it to __SOCKET_PATH
static int Socket_Connect (Socket * sock) {
    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, __SOCKET_PATH, sizeof(addr.sun_path) - 1);
    if (connect(sock->sock, (struct sockaddr *) &addr, sizeof(addr)) == -1)
        return SOCKET_FAILED;
    return 0;
}

// Send one int
static int Socket_Send (Socket * sock, int i) {
    uint8_t * buf = (uint8_t *) &i;
    size_t len = sizeof(i);
    while (len != 0) {
        ssize_t out = send(sock->sock, buf, len, 0);
        if (out == -1)
            return SOCKET_FAILED;
        buf += out;
        len -= out;
    }
    return 0;
}

// Receive one int
static int Socket_Receive (Socket * sock, int * i) {
    uint8_t * buf = (uint8_t *) i;
    size_t len = sizeof(int);
    while (len != 0) {
        ssize_t out = recv(sock->sock, buf, len, 0);
        if (out == -1)
            return SOCKET_FAILED;
        buf += out;
        len -= out;
    }
    return 0;
}

// Close socket
static void Socket_Close (Socket * sock) {
    if (sock->is_bind)
        unlink(__SOCKET_PATH);
    close(sock->sock);
};

#undef __SOCKET_PATH

#endif /* SOCKET_H */
