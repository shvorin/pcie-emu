/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */

/* vim: set syntax=c et sw=4 ts=4: */

#ifndef SKIFCH1_H
#define SKIFCH1_H

#include <stdint.h>
#include <string.h>
#include "iov.h"
#include "fifo.h"

#define __SKIFCH1_CASHE_LINE_SIZE 64

typedef struct {
    FIFO send;
    FIFO recv;
    size_t max_msg_size;
} SkifCh1;

static inline size_t SkifCh1_Size (int order) {
    return FIFO_Size(order) + 2 * __SKIFCH1_CASHE_LINE_SIZE;
}

static inline int SkifCh1_InitInternal (SkifCh1 * skifch, void * send, int send_order, uint32_t * send_rx, uint32_t * send_tx, size_t max_msg_size, void * recv, int recv_order, uint32_t * recv_rx, uint32_t * recv_tx) {
    *send_rx = 0;
    *recv_tx = 0;
    if (FIFO_Init(&skifch->send, send, send_order, send_rx, send_tx) == -1 ||
        FIFO_Init(&skifch->recv, recv, recv_order, recv_rx, recv_tx) == -1) {
        return -1;
    }
    skifch->max_msg_size = FIFO_GetMaxMessageSize(&skifch->send, max_msg_size);
    return 0;
}

static inline int SkifCh1_Init (SkifCh1 * skifch, void * send, int send_order, size_t max_msg_size, void * recv, int recv_order) {
    uint32_t * recv_rx = (uint32_t *)(((uint8_t *) send) + FIFO_Size(send_order));
    uint32_t * send_tx = (uint32_t *)(((uint8_t *) send) + FIFO_Size(send_order) + __SKIFCH1_CASHE_LINE_SIZE);
    uint32_t * send_rx = (uint32_t *)(((uint8_t *) recv) + FIFO_Size(recv_order));
    uint32_t * recv_tx = (uint32_t *)(((uint8_t *) recv) + FIFO_Size(recv_order) + __SKIFCH1_CASHE_LINE_SIZE);
    return SkifCh1_InitInternal(skifch, send, send_order, send_rx, send_tx, max_msg_size, recv, recv_order, recv_rx, recv_tx);
}

static inline ssize_t SkifCh1_Send (SkifCh1 * skifch, netaddr_t dst_netaddr, const struct iovec * iov, int iov_count) {
    struct iovec cont[2];
    int cont_count;
    size_t size = IOV_Size(iov, iov_count);
    if (size > skifch->max_msg_size)
        size = skifch->max_msg_size;
    ssize_t res = FIFO_Send(&skifch->send, dst_netaddr, size, -1, cont, &cont_count);
    if (res <= 0)
        return res;
    IOV_CopyToPCI(cont, cont_count, iov, iov_count);
    FIFO_SendComp(&skifch->send);
    return res;
}

static inline ssize_t SkifCh1_Recv (SkifCh1 * skifch, struct iovec cont[2], int * cont_count) {
    int src_rank;
    return FIFO_Recv(&skifch->recv, &src_rank, cont, cont_count);
}

static inline int SkifCh1_RecvComp (SkifCh1 * skifch) {
    return FIFO_RecvComp(&skifch->recv);
}

// Only for size <= 56 bytes!!!
static inline ssize_t SkifCh1_MPI_SendShort (SkifCh1 * skifch, netaddr_t dst_netaddr, int src_rank, const void * data, size_t size) {
    struct iovec cont[2];
    int cont_count;
    ssize_t res = FIFO_Send(&skifch->send, dst_netaddr, size, src_rank, cont, &cont_count);
    if (res <= 0)
        return res;
    memcpy(cont[0].iov_base, data, cont[0].iov_len);
    FIFO_SendComp(&skifch->send);
    return size;
}

static inline ssize_t SkifCh1_MPI_Send2 (SkifCh1 * skifch, netaddr_t dst_netaddr, int src_rank, struct iovec * iov, int iov_count, int * iov_offset, size_t size) {
    struct iovec cont[2];
    int cont_count;
    if (size > skifch->max_msg_size)
        size = skifch->max_msg_size;
    ssize_t res = FIFO_Send(&skifch->send, dst_netaddr, size, src_rank, cont, &cont_count);
    if (res <= 0)
        return res;
    IOV_MPI_CopyToPCI(cont, cont_count, iov, iov_count, iov_offset);
    FIFO_SendComp(&skifch->send);
    return res;
}

static inline ssize_t SkifCh1_MPI_Send (SkifCh1 * skifch, netaddr_t dst_netaddr, int src_rank, struct iovec * iov, int iov_count, int * iov_offset) {
    return SkifCh1_MPI_Send2(skifch, dst_netaddr, src_rank, iov, iov_count, iov_offset, IOV_MPI_Size(iov, iov_count, *iov_offset));
}  


static inline ssize_t SkifCh1_MPI_Recv (SkifCh1 * skifch, int * src_rank, struct iovec cont[2], int * cont_count) {
    return FIFO_Recv(&skifch->recv, src_rank, cont, cont_count);
}

static inline int SkifCh1_MPI_RecvComp (SkifCh1 * skifch) {
    return FIFO_RecvComp(&skifch->recv);
}

#undef __SKIFCH1_CASHE_LINE_SIZE

#endif /* SKIFCH1_H */
