/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */

/* vim: set syntax=c et sw=4 ts=4: */

#ifndef SKIFCH_RANK_H
#define SKIFCH_RANK_H

#include <sys/types.h>
#include <unistd.h>
#include "netaddr.h"
#include "skifch-t.h"

netaddr_t SkifCh_NetAddr (int rank);
SkifCh * SkifCh_SkifCh (int rank);
pid_t SkifCh_PID (int rank);

#endif /* SKIFCH_RANK_H */
