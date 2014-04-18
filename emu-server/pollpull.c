/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */

#include <defines.h>

#include <stdlib.h>
#include <stdio.h>
#include <poll.h>
#include <errno.h>
#include <error.h>

#include <pollpull.h>
#include <tlp-defs-old.h>


struct pollpull_t pollpull = {0}; /* NB: nullify! */

ssize_t pp_alloc(int sock, int prop) {
  if(!(prop & PROP_HIDDEN))
    ++pollpull.nAlive;

  size_t i;
  for(i=0; i<pollpull.nPolled; ++i)
    if(-1 == pollpull.fds[i].fd)
      goto allocated;

  if(pollpull.nPolled < pollpull.nTotal) {
    ++pollpull.nPolled;
    goto allocated;
  }

  size_t nTotal = 10 + 2 * pollpull.nTotal;
  struct pollfd *fds = realloc(pollpull.fds, nTotal * sizeof(struct pollfd));
  int *props = realloc(pollpull.fds, nTotal * sizeof(int));

  if(!fds || !props)
    return -1;

  size_t j;
  for(j=i; j<nTotal; ++j) {
    fds[j].fd = -1;
    props[j] = 0;
  }

  pollpull = (struct pollpull_t) {
    .fds = fds,
    .props = props,
    .nTotal = nTotal,
    .nPolled = i+1,
    .nAlive = pollpull.nAlive,
  };

 allocated:
  pollpull.fds[i] = (struct pollfd){
    .fd = sock,
    .events = POLLIN,
    .revents = 0,
  };
  pollpull.props[i] = prop;

  return i;
}

void pp_free(size_t idx) {
  /* assert(i < pollpull.nPolled); */
  pollpull.fds[idx] = (struct pollfd){
    .fd = -1,
    .events = POLLIN,
    .revents = 0,
  };
}

int pollin_revent(size_t i) {
  const short revent = pollpull.fds[i].revents;
  if(revent & POLLERR)
    error(1, 0, "POLLERR in poll()", revent);

  if(revent & POLLHUP) {
    printf("client #%d hung up\n", i);
    pp_free(i);
    if(!(pollpull.props[i] & PROP_HIDDEN))
      if(0 == --pollpull.nAlive) {
        printf("no more alive clients, going to exit\n");
        exit(0);
      }

    return -1;
  }

  if(0 == revent)
    return 0;

  if(POLLIN == revent)
    return 1;

  error(1, 0, "unexpected result in poll()");
  return 0;
}


int pp_pollin(int timeout) {
  static int nEvents = 0; /* number of events returned by poll() to be elaborated */
  static size_t hp = 1;
  size_t selected = hp;

  while(nEvents > 0) {
    switch(pollin_revent(selected)) {
    case 1:
      --nEvents;
      hp = selected < pollpull.nPolled - 1 ? selected + 1 : 1;
      return pollpull.fds[selected].fd;

    case -1:
      --nEvents;
      break;
    }

    selected = selected < pollpull.nPolled - 1 ? selected + 1 : 1;
  }

  nEvents = poll(pollpull.fds, pollpull.nPolled, timeout);

  switch(nEvents) {
  case -1:
    error(1, errno, "poll() failed");

  case 0:
    break;

  default:
    if(pollin_revent(0)) {
      acceptClient();
    
      --nEvents;
      return -1;
    }
  }

  return -1;
}

__attribute__((destructor))
static void destroy_pollfd() {
  free(pollpull.fds);
  free(pollpull.props);
  pollpull = (struct pollpull_t){0};
}
