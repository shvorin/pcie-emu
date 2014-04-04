/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */

#ifndef SOCKET_UTIL_H
#define SOCKET_UTIL_H

#include <sys/types.h>
#include <sys/socket.h>


static void Socket_Recv(int sock, void *data, size_t len) {
  char * buf = (char *)data;
  while (len != 0) {
    ssize_t out = recv(sock, buf, len, 0);
    if (out == -1)
      error(1, errno, "socket recv() failed");

    buf += out;
    len -= out;
  }
}

#define Socket_RecvValue(sock, val) ((void)Socket_Recv(sock, &(val), sizeof(val)))

static void Socket_Send(int sock, const void *data, size_t len) {
  const char * buf = (const char *)data;
  while (len != 0) {
    ssize_t out = send(sock, buf, len, 0);
    if (out == -1)
      error(1, errno, "socket send() failed");

    buf += out;
    len -= out;
  }
}

#define Socket_SendValue(sock, val) ((void)Socket_Send(sock, &(val), sizeof(val)))


#endif /* SOCKET_UTIL_H */
