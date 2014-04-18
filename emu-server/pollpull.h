/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */

#ifndef POLLPULL_H
#define POLLPULL_H

#include <stdlib.h>
#include <sys/types.h>
#include <poll.h>


extern struct pollpull_t {
  struct pollfd *fds;
  int *props;
  size_t nTotal; /* qty of mem-allocated elements */
  size_t nPolled; /* qty of elements being polled */
  size_t nAlive; /* qty of alive elements except hidden */
} pollpull;

/* returns index of the new element */
size_t pp_alloc(int sock, int prop);
void pp_free(size_t idx);

void acceptClient();

/* returns file descriptor with POLLIN event or -1 if no event found */
int pp_pollin(int timeout);

#endif /* POLLPULL_H */
