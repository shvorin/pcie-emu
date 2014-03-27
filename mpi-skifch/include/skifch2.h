/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */

/* vim: set syntax=c et sw=4 ts=4: */

#ifndef SKIFCH2PCI_H
#define SKIFCH2PCI_H

#include <stdint.h>
#include <string.h>
#include "afifo.h"
#include "iov.h"
#include "msg-header.h"
#include "processid.h"

#define __SKIFCH2_CASHE_LINE_SIZE 64

typedef struct {
    AFIFO send;
    AFIFO recv;
    size_t max_msg_size;
    int use_fence;
} SkifCh2;

static inline size_t SkifCh2_Size (int ctrl_order, int data_order) {
    return AFIFO_Size(ctrl_order) + AFIFO_Size(data_order) + __SKIFCH2_CASHE_LINE_SIZE;
}

static inline void SkifCh2_Print (SkifCh2 * skifch) {
    __AFIFO_PrintInfo(&skifch->send, "Send queue: ");
    __AFIFO_PrintInfo(&skifch->recv, "Recv queue: ");
}

static inline int SkifCh2_InitInternal (SkifCh2 * skifch, void * send_ctrl, int send_ctrl_order, void * send_data, int send_data_order, uint64_t * send_rx, size_t max_msg_size, void * recv_ctrl, int recv_ctrl_order, void * recv_data, int recv_data_order, uint64_t * recv_rx, int use_fence) {
    memset(recv_ctrl, 0xFF, AFIFO_Size(recv_ctrl_order));
    *send_rx = 0;
    if (AFIFO_Init(&skifch->send, send_ctrl, send_ctrl_order, send_data, send_data_order, send_rx) == -1 ||
        AFIFO_Init(&skifch->recv, recv_ctrl, recv_ctrl_order, recv_data, recv_data_order, recv_rx) == -1) {
        return -1;
    }
    skifch->max_msg_size = AFIFO_GetMaxMessageSize(&skifch->send, max_msg_size);
    skifch->use_fence = use_fence;
    PROCESSID_DBG_PRINT(PROCESSID_INFO, "SkifCh2 send queue parameters: %d %d %ld (%ld), recv queue parameters: %d %d, fence: %s", send_ctrl_order, send_data_order, skifch->max_msg_size, max_msg_size, recv_ctrl_order, recv_data_order, use_fence ? "yes" : "no");
    return 0;
}

static inline int SkifCh2_Init (SkifCh2 * skifch, void * send, int send_ctrl_order, int send_data_order, size_t max_msg_size, void * recv, int recv_ctrl_order, int recv_data_order, int use_fence) {
    void * send_data = send;
    void * send_ctrl = ((uint8_t *) send) + AFIFO_Size(send_data_order);
    uint64_t * recv_rx = (uint64_t *)(((uint8_t *) send) + AFIFO_Size(send_data_order) + AFIFO_Size(send_ctrl_order));
    void * recv_data = recv;
    void * recv_ctrl = ((uint8_t *) recv) + AFIFO_Size(recv_data_order);
    uint64_t * send_rx = (uint64_t *)(((uint8_t *) recv) + AFIFO_Size(recv_data_order) + AFIFO_Size(recv_ctrl_order));
    return SkifCh2_InitInternal(skifch, send_ctrl, send_ctrl_order, send_data, send_data_order, send_rx, max_msg_size, recv_ctrl, recv_ctrl_order, recv_data, recv_data_order, recv_rx, use_fence);
}

#define __SKIFCH2_MKHDR(dst_netaddr, header) (((((uint32_t) dst_netaddr) & 0xFFFF) << 16) | ((uint32_t) header))

static inline ssize_t SkifCh2_Send (SkifCh2 * skifch, netaddr_t dst_netaddr, const struct iovec * iov, int iov_count) {
    struct iovec cont[3];
    int cont_count;
    AFIFO_SendHeader sendhdr;
    size_t size = IOV_Size(iov, iov_count);
    if (size > skifch->max_msg_size)
        size = skifch->max_msg_size;
    ssize_t res = AFIFO_Send(&skifch->send, size, cont, &cont_count, &sendhdr);
    if (res <= 0)
        return res;
    IOV2_CopyToPCI(cont, cont_count, iov, iov_count, __SKIFCH2_MKHDR(dst_netaddr, sendhdr.header), skifch->use_fence);
    return res;
}

static inline ssize_t SkifCh2_Recv (SkifCh2 * skifch, struct iovec cont[3], int * cont_count) {
    ssize_t res = AFIFO_Recv(&skifch->recv, cont, cont_count);
    if (res <= 0)
        return res;
    *cont_count = IOV_Count(cont, res);
    return res;
}

static inline int SkifCh2_RecvComp (SkifCh2 * skifch) {
    return AFIFO_RecvComp(&skifch->recv);
}

#define __SKIFCH2_DBG_STRING_SIZE 1024

static char skifch2_dbg_string[__SKIFCH2_DBG_STRING_SIZE];

static char * __SkifCh2_DBG_Dump (const struct iovec * iov, int iov_count, int iov_offset, size_t size) {
    char * str = skifch2_dbg_string;
    int str_len = __SKIFCH2_DBG_STRING_SIZE - 8;
    for ( ; iov_offset < iov_count; iov_offset++) {
        unsigned char * buf = iov[iov_offset].iov_base;
        size_t len = iov[iov_offset].iov_len;
        unsigned int j;
        for (j = 0; j < len; j++) {
            if (size > 0 && str_len > 0) {
                int res = sprintf(str, "%s%02X", str == skifch2_dbg_string ? "" : " ", buf[j]);
                size -= 1;
                str_len -= res; 
                str += res;
            } else {
                goto end;
            }
        } 
    }
  end:
    *str = 0;
    return skifch2_dbg_string;
}

static char * __SkifCh2_DBG_Dump2 (const void * data, size_t size) {
    struct iovec iov;
    iov.iov_base = (void *) data;
    iov.iov_len = size;
    return __SkifCh2_DBG_Dump(&iov, 1, 0, size);
}


// Only for size <= 56 bytes!!!
static inline ssize_t SkifCh2_MPI_SendShort (SkifCh2 * skifch, netaddr_t dst_netaddr, int src_rank, const void * data, size_t size) {
    struct iovec cont[3];
    int cont_count;
    AFIFO_SendHeader sendhdr;
    ssize_t res = AFIFO_SendShort(&skifch->send, size + sizeof(int), cont, &cont_count, &sendhdr);
    if (res <= 0)
        return res;
    res -= sizeof(int);
    PROCESSID_DBG_PRINT(PROCESSID_VERBOSE, "SendShort: size=%ld dst_netaddr=0x%X data=<%s>", res, dst_netaddr, __SkifCh2_DBG_Dump2(data, res));
    IOV2_MPI_Copy64ToPCI(cont[0].iov_base, data, size, src_rank, __SKIFCH2_MKHDR(dst_netaddr, sendhdr.header));
    return res;
}

static inline ssize_t SkifCh2_MPI_Send2 (SkifCh2 * skifch, netaddr_t dst_netaddr, int src_rank, struct iovec * iov, int iov_count, int * iov_offset, size_t size) {
    struct iovec cont[3];
    int cont_count;
    AFIFO_SendHeader sendhdr;
    size += sizeof(int);
    if (size > skifch->max_msg_size)
        size = skifch->max_msg_size;
    ssize_t res = AFIFO_Send(&skifch->send, size, cont, &cont_count, &sendhdr);
    if (res <= 0)
        return res;
    res -= sizeof(int);
    cont[cont_count - 1].iov_len -= sizeof(int);
    PROCESSID_DBG_PRINT(PROCESSID_VERBOSE, "SendShort: size=%ld dst_netaddr=0x%X data=<%s>", res, dst_netaddr, __SkifCh2_DBG_Dump(iov, iov_count, *iov_offset, res));
    IOV2_MPI_CopyToPCI(cont, cont_count, iov, iov_count, iov_offset, src_rank, __SKIFCH2_MKHDR(dst_netaddr, sendhdr.header), skifch->use_fence);
    return res;
}

static inline ssize_t SkifCh2_MPI_Send (SkifCh2 * skifch, netaddr_t dst_netaddr, int src_rank, struct iovec * iov, int iov_count, int * iov_offset) {
    return SkifCh2_MPI_Send2(skifch, dst_netaddr, src_rank, iov, iov_count, iov_offset, IOV_MPI_Size(iov, iov_count, *iov_offset));
}

static inline ssize_t SkifCh2_MPI_Recv (SkifCh2 * skifch, int * src_rank, struct iovec cont[3], int * cont_count) {
    ssize_t res = AFIFO_Recv(&skifch->recv, cont, cont_count);
    if (res <= 0)
        return res;
    res -= sizeof(int);
    *cont_count = IOV2_MPI_Count(cont, res, (uint32_t *)src_rank);
    PROCESSID_DBG_PRINT(PROCESSID_VERBOSE, "Recv: size=%ld src_rank=%d data=<%s>", res, *src_rank, __SkifCh2_DBG_Dump(cont, *cont_count, 0, res));
    return res;
}

static inline int SkifCh2_MPI_RecvComp (SkifCh2 * skifch) {
    PROCESSID_DBG_PRINT(PROCESSID_VERBOSE, "RecvComp");
    return AFIFO_RecvComp(&skifch->recv);
}

#undef __SKIFCH2_CASHE_LINE_SIZE
#undef __SKIFCH2_MKHDR

#endif /* SKIFCH2PCI_H */
