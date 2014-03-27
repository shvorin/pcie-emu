/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */

/* vim: set syntax=c et sw=4 ts=4: */

#include "mmdev.h"
#include "skifch.h"
#include "skifch-t.h"
#include "skifch1.h"
#include "skifch2.h"
#include "skifch2shm.h"

netaddr_t * SkifCh_rank2netaddr;
SkifCh ** SkifCh_rank2skifch;
pid_t * SkifCh_rank2pid;

netaddr_t SkifCh_NetAddr (int rank) {
    return SkifCh_rank2netaddr[rank];
}

SkifCh * SkifCh_SkifCh (int rank) {
    return SkifCh_rank2skifch[rank];
}

pid_t SkifCh_PID (int rank) {
    return SkifCh_rank2pid[rank];
}

ssize_t SkifCh_Send (SkifCh * skifch, netaddr_t dst_netaddr, const struct iovec * iov, int iov_count) {
    switch (skifch->tag) {
        case SkifCh1_tag: return SkifCh1_Send(&skifch->ch.ch1, dst_netaddr, iov, iov_count);
        case SkifCh2_tag:
        case SkifCh2f_tag: return SkifCh2_Send(&skifch->ch.ch2, dst_netaddr, iov, iov_count);
        case SkifCh2Shm_tag: return SkifCh2Shm_Send(&skifch->ch.ch2shm, dst_netaddr, iov, iov_count);
        default: return -1;
    }
}

ssize_t SkifCh_Recv (SkifCh * skifch, struct iovec cont[3], int * cont_count) {
    switch (skifch->tag) {
        case SkifCh1_tag: return SkifCh1_Recv(&skifch->ch.ch1, cont, cont_count);
        case SkifCh2_tag:
        case SkifCh2f_tag: return SkifCh2_Recv(&skifch->ch.ch2, cont, cont_count);
        case SkifCh2Shm_tag: return SkifCh2Shm_Recv(&skifch->ch.ch2shm, cont, cont_count);
        default: return -1;
    }
}

int SkifCh_RecvComp (SkifCh * skifch) {
    switch (skifch->tag) {
        case SkifCh1_tag: return SkifCh1_RecvComp(&skifch->ch.ch1);
        case SkifCh2_tag:
        case SkifCh2f_tag: return SkifCh2_RecvComp(&skifch->ch.ch2);
        case SkifCh2Shm_tag: return SkifCh2Shm_RecvComp(&skifch->ch.ch2shm);
        default: return -1;
    }
}

// Only for size <= 56 bytes!!!
ssize_t SkifCh_MPI_SendShort (SkifCh * skifch, netaddr_t dst_netaddr, int src_rank, const void * data, size_t size) {
    switch (skifch->tag) {
        case SkifCh1_tag: return SkifCh1_MPI_SendShort(&skifch->ch.ch1, dst_netaddr, src_rank, data, size);
        case SkifCh2_tag:
        case SkifCh2f_tag: return SkifCh2_MPI_SendShort(&skifch->ch.ch2, dst_netaddr, src_rank, data, size);
        case SkifCh2Shm_tag: return SkifCh2Shm_MPI_SendShort(&skifch->ch.ch2shm, dst_netaddr, src_rank, data, size);
        default: return -1;
    }
}

ssize_t SkifCh_MPI_Send (SkifCh * skifch, netaddr_t dst_netaddr, int src_rank, struct iovec * iov, int iov_count, int * iov_offset) {
    switch (skifch->tag) {
        case SkifCh1_tag: return SkifCh1_MPI_Send(&skifch->ch.ch1, dst_netaddr, src_rank, iov, iov_count, iov_offset);
        case SkifCh2_tag:
        case SkifCh2f_tag: return SkifCh2_MPI_Send(&skifch->ch.ch2, dst_netaddr, src_rank, iov, iov_count, iov_offset);
        case SkifCh2Shm_tag: return SkifCh2Shm_MPI_Send(&skifch->ch.ch2shm, dst_netaddr, src_rank, iov, iov_count, iov_offset);
        default: return -1;
    }
}

ssize_t SkifCh_MPI_Send2 (SkifCh * skifch, netaddr_t dst_netaddr, int src_rank, struct iovec * iov, int iov_count, int * iov_offset, size_t size) {
    switch (skifch->tag) {
        case SkifCh1_tag: return SkifCh1_MPI_Send2(&skifch->ch.ch1, dst_netaddr, src_rank, iov, iov_count, iov_offset, size);
        case SkifCh2_tag:
        case SkifCh2f_tag: return SkifCh2_MPI_Send2(&skifch->ch.ch2, dst_netaddr, src_rank, iov, iov_count, iov_offset, size);
        case SkifCh2Shm_tag: return SkifCh2Shm_MPI_Send2(&skifch->ch.ch2shm, dst_netaddr, src_rank, iov, iov_count, iov_offset, size);
        default: return -1;
    }
}

ssize_t SkifCh_MPI_Recv (SkifCh * skifch, int * src_rank, struct iovec cont[3], int * cont_count) {
    switch (skifch->tag) {
        case SkifCh1_tag: return SkifCh1_MPI_Recv(&skifch->ch.ch1, src_rank, cont, cont_count);
        case SkifCh2_tag:
        case SkifCh2f_tag: return SkifCh2_MPI_Recv(&skifch->ch.ch2, src_rank, cont, cont_count);
        case SkifCh2Shm_tag: return SkifCh2Shm_MPI_Recv(&skifch->ch.ch2shm, src_rank, cont, cont_count);
        default: return -1;
    }
}

int SkifCh_MPI_RecvComp (SkifCh * skifch) {
    switch (skifch->tag) {
        case SkifCh1_tag: return SkifCh1_MPI_RecvComp(&skifch->ch.ch1);
        case SkifCh2_tag:
        case SkifCh2f_tag: return SkifCh2_MPI_RecvComp(&skifch->ch.ch2);
        case SkifCh2Shm_tag: return SkifCh2Shm_MPI_RecvComp(&skifch->ch.ch2shm);
        default: return -1;
    }
}

int SkifCh_Fence () {
    mmdev_fence();
    return 0;
}
