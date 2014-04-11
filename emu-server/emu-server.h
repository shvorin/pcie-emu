/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */

#ifndef EMU_SERVER_H
#define EMU_SERVER_H

#include <sys/types.h>
#include <sys/socket.h>
#include <poll.h>


#define NSOCKS_MAX 10

extern struct pollfd pollfds[NSOCKS_MAX];
extern size_t nSocks;

void acceptClient();


#endif /* EMU_SERVER_H */
