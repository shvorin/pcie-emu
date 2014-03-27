/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */

/* vim: set syntax=c et sw=4 ts=4: */

#ifndef SKIFCH_H
#define SKIFCH_H

#include <sys/uio.h>
#include "netaddr.h"

typedef struct SkifCh_t SkifCh;

int SkifCh_AllInit (int * argc, char *** argv);
int SkifCh_AllInit_Internal (SkifCh * * skifchs, char * kvsname, int * skifchs_size);
int SkifCh_AllFinalize ();
int SkifCh_AllFinalize_Internal ();
int SkifCh_SlowBarrier ();
int SkifCh_AlltoallTest ();

int SkifCh_MyRank ();
int SkifCh_Size ();

netaddr_t SkifCh_NetAddr (int rank);
SkifCh * SkifCh_SkifCh (int rank);
pid_t SkifCh_PID (int rank);

ssize_t SkifCh_Send (SkifCh * skifch, netaddr_t dst_netaddr, const struct iovec * iov, int iov_count);
ssize_t SkifCh_Recv (SkifCh * skifch, struct iovec cont[3], int * cont_count);
int SkifCh_RecvComp (SkifCh * skifch);
ssize_t SkifCh_MPI_SendShort (SkifCh * skifch, netaddr_t dst_netaddr, int src_rank, const void * data, size_t size); // Only for size <= 56 bytes!!!
ssize_t SkifCh_MPI_Send (SkifCh * skifch, netaddr_t dst_netaddr, int src_rank, struct iovec * iov, int iov_count, int * iov_offset);
ssize_t SkifCh_MPI_Send2 (SkifCh * skifch, netaddr_t dst_netaddr, int src_rank, struct iovec * iov, int iov_count, int * iov_offset, size_t size);
ssize_t SkifCh_MPI_Recv (SkifCh * skifch, int * src_rank, struct iovec cont[3], int * cont_count);
int SkifCh_MPI_RecvComp (SkifCh * skifch);
int SkifCh_Fence ();

#endif /* SKIFCH_H */
