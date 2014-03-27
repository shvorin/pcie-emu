/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */

/* vim: set syntax=c et sw=4 ts=4: */

#ifndef FIFO_H
#define FIFO_H

#include <errno.h>
#include <stdint.h>
#include <sys/uio.h>
#include "mmdev.h"
#include "msg-header.h"

#ifdef MPIU_Assert
#define __FIFO_ASSERT(x) MPIU_Assert(x)
#else
#define __FIFO_ASSERT(x)
#endif

#ifndef MPIDI_DBG_PRINTF
#define MPIDI_DBG_PRINTF
#endif

#define __FIFO_CELL_SIZE 64 // Must be >= __FIFO_CELL_SIZE (64 bytes)

#define __FIFO_MPIMSGHEADER_SIZE (sizeof(MPIMsgHeader)) // Must be == 8!
#define __FIFO_ROUND_DOWN_CELL_SIZE(x) ((x)&(~(__FIFO_CELL_SIZE-1)))
#define __FIFO_ROUND_UP_CELL_SIZE(x) (__FIFO_ROUND_DOWN_CELL_SIZE((x)+__FIFO_CELL_SIZE-1))
#define __FIFO_GET_MESSAGE_SIZE(x) (__FIFO_ROUND_UP_CELL_SIZE((x)+__FIFO_MPIMSGHEADER_SIZE)-__FIFO_MPIMSGHEADER_SIZE)

#define __FIFO_GET_ADDRESS(q) (((uint8_t*)fifo->memory)+((fifo->q)&(fifo->size-1)))
#define __FIFO_GET_ADDRESS_0() (fifo->memory)
#define __FIFO_GET_SPACE(q) (fifo->size-((fifo->q)&(fifo->size-1)));
#define __FIFO_INCREMENT(q,d) ((fifo->q)=((fifo->q)+(d)))
#define __FIFO_INCREMENT_ROUNDUP(q,d) ((fifo->q)=(((fifo->q)+(d))&(2*fifo->size-1)))

typedef struct {
    MsgHeader header;
    int src_rank;
} MPIMsgHeader;

typedef struct {
    void * memory;
    volatile uint32_t * head_ptr;
    volatile uint32_t * tail_ptr;
    uint32_t size;
    uint32_t head;
    uint32_t head_old;
    uint32_t tail;
} FIFO;

static inline void __FIFO_PrintInfo (FIFO * fifo, const char * str) {
    MPIDI_DBG_PRINTF((50, "__FIFO_PrintInfo", "%s: Channel: size: %ld, head: %d, tail: %d, head_ptr: %d, tail_ptr: %d.\n", str, fifo->size, fifo->head, fifo->tail, /*-1, -1*/  *(uint64_t *)fifo->head_ptr, *(uint64_t *)fifo->tail_ptr));
}

static inline void __FIFO_PrintHeader (MPIMsgHeader header, const char * str) {
    MPIDI_DBG_PRINTF((50, "__FIFO_PrintHeader", "%s: Header: to: %d, from: %d, len: %d.\n", str, header.header.dst, header.src_rank, header.header.len));
}

static inline uint32_t __FIFO_GetFreeSize (FIFO * fifo) {
    fifo->head = __FIFO_ROUND_DOWN_CELL_SIZE(*fifo->head_ptr);
    return (fifo->head - fifo->tail + fifo->size) & (2*fifo->size-1);
}

static inline uint32_t __FIFO_GetUsedSize (FIFO * fifo) {
    fifo->tail = __FIFO_ROUND_DOWN_CELL_SIZE(*fifo->tail_ptr);
    uint32_t size = (fifo->tail - fifo->head) & (2*fifo->size-1);
    if (size != 0 && (__FIFO_MPIMSGHEADER_SIZE + ((uint32_t)((MPIMsgHeader *)__FIFO_GET_ADDRESS(head))->header.len) > size))
        return 0;
    return size;
}

static inline size_t FIFO_Size (int order) {
    return 1ULL<<order;
}

// Address memory must be aligned
static inline int FIFO_Init (FIFO * fifo, void * memory, int order, uint32_t * head_ptr, uint32_t * tail_ptr) {
    __FIFO_ASSERT(__FIFO_MPIMSGHEADER_SIZE == 8);
    fifo->memory = memory;
    fifo->head_ptr = head_ptr;
    fifo->tail_ptr = tail_ptr;
    fifo->size = 1ULL<<order;
    fifo->head = 0;
    fifo->head_old = 0;
    fifo->tail = 0;
    __FIFO_PrintInfo(fifo, "Init");
    if (fifo->size / 4 < __FIFO_CELL_SIZE) {
        errno = EINVAL;
        return -1;
    }
    return 0;
}

static inline size_t FIFO_GetMaxMessageSize (FIFO * fifo, size_t msg_size) {
    if (msg_size > 0x7FFF) // Only 15 bits in header for size
        msg_size = 0x7FFF;
    if (msg_size > fifo->size / 4) // Max message size must not be too large
        msg_size = fifo->size / 4;
    if (msg_size < __FIFO_CELL_SIZE) // Max message size must not be too small
        msg_size = __FIFO_CELL_SIZE;
    return __FIFO_ROUND_DOWN_CELL_SIZE(msg_size + __FIFO_MPIMSGHEADER_SIZE) - __FIFO_MPIMSGHEADER_SIZE; // Max message size must be (__FIFO_CELL_SIZE*n-__FIFO_MPIMSGHEADER_SIZE)
}

static inline ssize_t FIFO_Send (FIFO * fifo, netaddr_t dst_netaddr, size_t size, int src_rank, struct iovec cont[2], int * cont_count) {
    if (__FIFO_GetFreeSize(fifo) < size + __FIFO_MPIMSGHEADER_SIZE)
        return 0;
    MPIMsgHeader mpi_header;
    mpi_header.header.dst.id = dst_netaddr;
    mpi_header.header.len = size;
    mpi_header.src_rank = src_rank;
    __FIFO_PrintInfo(fifo, "Send");
    __FIFO_PrintHeader(mpi_header, "Send");
    mmdev_memcpy(__FIFO_GET_ADDRESS(tail), &mpi_header, __FIFO_MPIMSGHEADER_SIZE);
    __FIFO_INCREMENT(tail, __FIFO_MPIMSGHEADER_SIZE);
    uint32_t msg_size = __FIFO_GET_MESSAGE_SIZE(size);
    uint32_t space = __FIFO_GET_SPACE(tail);
    if (msg_size <= space) {
        cont[0].iov_base = __FIFO_GET_ADDRESS(tail);
        cont[0].iov_len = msg_size;
        cont[1].iov_base = 0;
        cont[1].iov_len = 0;
        *cont_count = 1;
    } else {
        cont[0].iov_base = __FIFO_GET_ADDRESS(tail);
        cont[0].iov_len = space;
        cont[1].iov_base = __FIFO_GET_ADDRESS_0();
        cont[1].iov_len = msg_size - space;
        *cont_count = 2;
    }
    __FIFO_INCREMENT_ROUNDUP(tail, msg_size);
    return size;
}

static inline int FIFO_SendComp (FIFO * fifo) {
    mmdev_fence();
    mmdev_put64(fifo->tail_ptr, fifo->tail);
    mmdev_fence();
    __FIFO_PrintInfo(fifo, "SendComp");
    return 0;
}

static inline ssize_t FIFO_Recv (FIFO * fifo, int * src_rank, struct iovec cont[2], int * cont_count) {
    if (__FIFO_GetUsedSize(fifo) == 0)
        return 0;
    MPIMsgHeader mpi_header = *(MPIMsgHeader *)__FIFO_GET_ADDRESS(head);
    __FIFO_PrintInfo(fifo, "Recv");
    __FIFO_PrintHeader(mpi_header, "Recv");
    *src_rank = mpi_header.src_rank;
    uint32_t size = mpi_header.header.len;
    __FIFO_INCREMENT(head, __FIFO_MPIMSGHEADER_SIZE);
    uint32_t msg_size = __FIFO_GET_MESSAGE_SIZE(size);
    uint32_t space = __FIFO_GET_SPACE(head);
    if (msg_size <= space) {
        cont[0].iov_base = __FIFO_GET_ADDRESS(head);
        cont[0].iov_len = msg_size;
        cont[1].iov_base = 0;
        cont[1].iov_len = 0;
        *cont_count = 1;
    } else {
        cont[0].iov_base = __FIFO_GET_ADDRESS(head);
        cont[0].iov_len = space;
        cont[1].iov_base = __FIFO_GET_ADDRESS_0();
        cont[1].iov_len = msg_size - space;
        *cont_count = 2;
    }
    __FIFO_INCREMENT_ROUNDUP(head, msg_size);
    return size;
}

static inline int FIFO_RecvComp (FIFO * fifo) {
    if (((fifo->head - fifo->head_old) & (2*fifo->size-1)) > (fifo->size/4)) {
        mmdev_put64(fifo->head_ptr, fifo->head);
        mmdev_fence();
        fifo->head_old = fifo->head;
    }
    __FIFO_PrintInfo(fifo, "RecvComp");
    return 0;
}

#undef __FIFO_ASSERT

#undef __FIFO_CELL_SIZE

#undef __FIFO_MPIMSGHEADER_SIZE
#undef __FIFO_ROUND_DOWN_CELL_SIZE
#undef __FIFO_ROUND_UP_CELL_SIZE
#undef __FIFO_GET_MESSAGE_SIZE

#undef __FIFO_GET_ADDRESS
#undef __FIFO_GET_ADDRESS_0
#undef __FIFO_GET_SPACE
#undef __FIFO_INCREMENT
#undef __FIFO_INCREMENT_ROUNDUP

#endif /* FIFO_H */
