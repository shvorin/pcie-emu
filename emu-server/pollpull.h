/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */

#ifndef POLLPULL_H
#define POLLPULL_H

#include <stdlib.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <poll.h>
#include <errno.h>
#include <error.h>


extern struct pollpull_t {
  struct pollfd *fds;
  nfds_t nTotal;
  nfds_t nActive;
} pollpull;

static ssize_t alloc_pollfd(int sock) {
  size_t i;
  for(i=0; i<pollpull.nActive; ++i)
    if(-1 == pollpull.fds[i].fd)
      goto allocated;

  if(pollpull.nActive < pollpull.nTotal) {
    ++pollpull.nActive;
    goto allocated;
  }

  size_t nTotal = 10 + 2 * pollpull.nTotal;
  struct pollfd *fds = realloc(pollpull.fds, nTotal * sizeof(struct pollfd));

  if(!fds)
    return -1;

  size_t j;
  for(j=i; j<nTotal; ++j)
    fds[j].fd = -1;

  pollpull = (struct pollpull_t) {
    .fds = fds,
    .nTotal = nTotal,
    .nActive = i+1,
  };

 allocated:
  pollpull.fds[i] = (struct pollfd){
    .fd = sock,
    .events = POLLIN,
  };
  return i;
}

static void free_pollfd(size_t i) {
  /* assert(i < pollpull.nActive); */
  pollpull.fds[i].fd = -1;
}

static int poll_pollfd(int timeout) {
  return poll(pollpull.fds, pollpull.nActive, timeout);
}

void acceptClient();

static int pollin_revent(size_t i) {
  const short revent = pollpull.fds[i].revents;
  if(revent & POLLERR)
    error(1, 0, "POLLERR in poll()", revent);

  if(revent & POLLHUP) {
    printf("client #%d hung up\n", i);
    pollpull.fds[i].fd = -1;
    return -1;
  }

  if(0 == revent)
    return 0;

  if(POLLIN == revent)
    return 1;

  error(1, 0, "unexpected result in poll()");
  return 0;
}


static ssize_t select_pollfd(int timeout) {
  static int nEvents = 0; /* number of events returned by poll() to be elaborated */
  static size_t hp = 1;
  size_t selected = hp;

  while(nEvents > 0) {
    switch(pollin_revent(selected)) {
    case 1:
      --nEvents;
      hp = selected < pollpull.nActive - 1 ? selected + 1 : 1;
      return selected;

    case -1:
      --nEvents;
      break;
    }

    selected = selected < pollpull.nActive - 1 ? selected + 1 : 1;
  }

  nEvents = poll_pollfd(timeout);

  switch(nEvents) {
  case -1:
    error(1, errno, "poll() failed");

  case 0:
    break;

  default:
    if(pollin_revent(0)) {
      acceptClient();
    
      --nEvents;
      return 0;
    }
  }

  return -1;
}

#endif /* POLLPULL_H */
