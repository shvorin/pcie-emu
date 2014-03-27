/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */

/* vim: set syntax=c et sw=4 ts=4: */

#ifndef SKIFCH2SHM_H
#define SKIFCH2SHM_H

#include <stdint.h>
#include <string.h>
#include <unistd.h>
//#include <numa.h>
#include "afifo-shm.h"
#include "iov.h"
#include "msg-header.h"

typedef struct {
    AFIFO_Shm send;
    AFIFO_Shm recv;
} SkifCh2Shm;

static inline size_t SkifCh2Shm_Size () {
    return AFIFO_Shm_Size() + sysconf(_SC_PAGE_SIZE);
}

//static void numa_revert (struct bitmask *nodemask) {
//    int i;
//    for (i = 0; i < numa_num_configured_nodes(); i++) {
//        if (numa_bitmask_isbitset(nodemask, i)) {
//            numa_bitmask_clearbit(nodemask, i);
//        } else {
//            numa_bitmask_setbit(nodemask, i);
//        }
//    }
//}

static inline int SkifCh2Shm_Init (SkifCh2Shm * skifch, void * send, void * recv) {
    //int i;
    //struct bitmask * cpumask = numa_allocate_cpumask();
    //numa_node_to_cpus(0, cpumask);
    //for (i = 0; i < 4; i++) {
    //    printf ("numa %d - %d\n", i, numa_bitmask_isbitset(cpumask, i));
    //}
    //struct bitmask * x = numa_get_run_node_mask();
    //numa_revert(x);
    //int MPIDI_CH3I_Process_MyRank = send > recv ? 1 : 0;
    //for (i = 0; i < numa_num_configured_nodes(); i++) {
    //    printf ("%d: numa %d - %d\n", MPIDI_CH3I_Process_MyRank, i, numa_bitmask_isbitset(x, i));
    //}
    //printf ("-----\n");
    //numa_tonodemask_memory(recv, SkifCh2Shm_Size(), x);
    //numa_free_nodemask(x);
    memset(recv, 0xFF, AFIFO_Shm_Size());
    *(uint64_t *)(((uint8_t *) recv) + AFIFO_Shm_Size()) = 0;
    if (AFIFO_Shm_Init(&skifch->send, send, (uint64_t *) (((uint8_t *) recv) + AFIFO_Shm_Size())) == -1 ||
        AFIFO_Shm_Init(&skifch->recv, recv, (uint64_t *) (((uint8_t *) send) + AFIFO_Shm_Size())) == -1) {
        return -1;
    }
    return 0;
}

static inline ssize_t SkifCh2Shm_Send (SkifCh2Shm * skifch, __attribute__((unused)) netaddr_t dst_netaddr, const struct iovec * iov, int iov_count) {
    struct iovec cont[3];
    int cont_count;
    AFIFO_Shm_SendHeader sendhdr;
    ssize_t res = AFIFO_Shm_Send(&skifch->send, IOV_Size(iov, iov_count), cont, &cont_count, &sendhdr);
    if (res <= 0)
        return res;
    IOV_Copy(cont, cont_count, iov, iov_count);
    AFIFO_Shm_SendComp(&skifch->send, &sendhdr);
    return res;
}

static inline ssize_t SkifCh2Shm_Recv (SkifCh2Shm * skifch, struct iovec cont[3], int * cont_count) {
    ssize_t res = AFIFO_Shm_Recv(&skifch->recv, cont, cont_count);
    if (res <= 0)
        return res;
    *cont_count = IOV_Count(cont, res);
    return res;
}

static inline int SkifCh2Shm_RecvComp (SkifCh2Shm * skifch) {
    return AFIFO_Shm_RecvComp(&skifch->recv);
}

// Only for size <= 56 bytes!!!
static inline ssize_t SkifCh2Shm_MPI_SendShort (SkifCh2Shm * skifch, __attribute__((unused)) netaddr_t dst_netaddr, int src_rank, const void * data, size_t size) {
    struct iovec cont[3];
    int cont_count;
    AFIFO_Shm_SendHeader sendhdr;
    ssize_t res = AFIFO_Shm_SendShort(&skifch->send, size + sizeof(int), cont, &cont_count, &sendhdr);
    if (res <= 0)
        return res;
    memcpy(cont[0].iov_base, data, size);
    *(int *)(((uint8_t *) cont[0].iov_base) + cont[0].iov_len - sizeof(int)) = src_rank;
    AFIFO_Shm_SendComp(&skifch->send, &sendhdr);
    return res - sizeof(int);
}

static inline ssize_t SkifCh2Shm_MPI_Send2 (SkifCh2Shm * skifch, __attribute__((unused)) netaddr_t dst_netaddr, int src_rank, struct iovec * iov, int iov_count, int * iov_offset, size_t size) {
    struct iovec cont[3];
    int cont_count;
    AFIFO_Shm_SendHeader sendhdr;
    ssize_t res = AFIFO_Shm_Send(&skifch->send, size + sizeof(int), cont, &cont_count, &sendhdr);
    if (res <= 0)
        return res;
    cont[cont_count - 1].iov_len -= sizeof(int);
    int cont_offset = 0;
    IOV_MPI_Copy(cont, cont_count, &cont_offset, iov, iov_count, iov_offset);
    *(int *)(((uint8_t *) cont[cont_count - 1].iov_base) + cont[cont_count - 1].iov_len) = src_rank;
    AFIFO_Shm_SendComp(&skifch->send, &sendhdr);
    return res - sizeof(int);
}

static inline ssize_t SkifCh2Shm_MPI_Send (SkifCh2Shm * skifch, netaddr_t dst_netaddr, int src_rank, struct iovec * iov, int iov_count, int * iov_offset) {
    return SkifCh2Shm_MPI_Send2(skifch, dst_netaddr, src_rank, iov, iov_count, iov_offset, IOV_MPI_Size(iov, iov_count, *iov_offset));
}

static inline ssize_t SkifCh2Shm_MPI_Recv (SkifCh2Shm * skifch, int * src_rank, struct iovec cont[3], int * cont_count) {
    ssize_t res = AFIFO_Shm_Recv(&skifch->recv, cont, cont_count);
    if (res <= 0)
        return res;
    *src_rank = *(int *)(((uint8_t *) cont[*cont_count - 1].iov_base) + cont[*cont_count - 1].iov_len - sizeof(int));
    res -= sizeof(int);
    *cont_count = IOV_Count(cont, res);
    return res;
}

static inline int SkifCh2Shm_MPI_RecvComp (SkifCh2Shm * skifch) {
    return AFIFO_Shm_RecvComp(&skifch->recv);
}

#endif /* SKIFCH2SHM_H */
