/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */

/* vim: set syntax=c et sw=4 ts=4: */

#ifndef AFIFO_SHM_H
#define AFIFO_SHM_H

#include <stdint.h>
#include <sys/uio.h>

#ifndef MPIDI_DBG_PRINTF
#define MPIDI_DBG_PRINTF
#endif

#define TRUE 1

#define __AFIFO_SHM_CELL_SIZE 64 // Must be >= CASHE_LINE_SIZE (64 bytes)
#define __AFIFO_SHM_CTRL_SIZE (1ULL<<12) // Must be power of 2 and >= PAGE_SIZE (4096 bytes)
#define __AFIFO_SHM_DATA_SIZE (1ULL<<18) // Must be power of 2 and >= PAGE_SIZE (4096 bytes)
#define __AFIFO_SHM_MAX_MESSAGE_SIZE ((1ULL<<13)+__AFIFO_SHM_CELL_SIZE-__AFIFO_SHM_HEADER_SIZE)
#define __AFIFO_SHM_GET_MESSAGE_SIZE_IN_DATA(x) (((x)+__AFIFO_SHM_HEADER_SIZE-1)&(~(__AFIFO_SHM_CELL_SIZE-1)))

#define __AFIFO_SHM_HEADER_SIZE sizeof(uint32_t)
#define __AFIFO_SHM_MAKE_HEADER(s) (((0xFF&((uint32_t)(__AFIFO_SHM_GET_PARITY())))<<24)|(0xFFFFFFF&((uint32_t)(s))))
#define __AFIFO_SHM_CHECK_HEADER(h) ((0xFF&(((uint32_t)(h))>>24))==(__AFIFO_SHM_GET_PARITY()))
#define __AFIFO_SHM_GET_PARITY() (0x1&((fifo->ctrl.main)>>12)) // Power must be equal to log(__AFIFO_SHM_CTRL_SIZE)
#define __AFIFO_SHM_GET_SIZE(h) (0xFFFFFF&((uint32_t)(h)))

#define __AFIFO_SHM_GET_HEADER_ADDRESS() ((uint32_t*)((__AFIFO_SHM_GET_ADDRESS(ctrl))+__AFIFO_SHM_CELL_SIZE-__AFIFO_SHM_HEADER_SIZE))
#define __AFIFO_SHM_GET_ADDRESS(q) (((uint8_t*)fifo->q.memory)+((fifo->q.main)&(__afifo_shm_size.q-1)))
#define __AFIFO_SHM_GET_ADDRESS_0(q) (fifo->q.memory)
#define __AFIFO_SHM_GET_SPACE(q) ((__afifo_shm_size.q)-((fifo->q.main)&(__afifo_shm_size.q-1)))
#define __AFIFO_SHM_GET_FREE_SPACE(q) ((fifo->q.aux)-(fifo->q.main))
#define __AFIFO_SHM_INCREMENT(q,d) ((fifo->q.main)+=(d))

static const struct {
    uint32_t ctrl;
    uint32_t data;
} __afifo_shm_size = { __AFIFO_SHM_CTRL_SIZE, __AFIFO_SHM_DATA_SIZE };

typedef struct {
    void * memory;
    uint32_t main; // tx for writer, rx for reader
    uint32_t aux;  // (rx+size) for writer, rx_old for reader
} __AFIFO_Shm;

typedef struct {
    __AFIFO_Shm ctrl;
    __AFIFO_Shm data;
    volatile uint64_t * head_ptr;
} AFIFO_Shm;

typedef struct {
    uint32_t * addr;
    uint32_t header;
} AFIFO_Shm_SendHeader;

static inline void __AFIFO_Shm_PrintInfo (AFIFO_Shm * fifo, const char * str) {
    MPIDI_DBG_PRINTF((50, "__AFIFO_Shm_PrintInfo", "%s: Channel Ctrl: size: %d, main: %d, aux: %d, memory: %p.", str, __afifo_shm_size.ctrl, fifo->ctrl.main, fifo->ctrl.aux, fifo->ctrl.memory));
    MPIDI_DBG_PRINTF((50, "__AFIFO_Shm_PrintInfo", "%s: Channel Data: size: %d, main: %d, aux: %d, memory: %p.", str, __afifo_shm_size.data, fifo->data.main, fifo->data.aux, fifo->data.memory));
}

static inline void __AFIFO_Shm_PrintHeader (uint32_t header, const char * str) {
    MPIDI_DBG_PRINTF((50, "__AFIFO_Shm_PrintHeader", "%s: Header: 0x%X, size: %d", str, header, __AFIFO_SHM_GET_SIZE(header)));
}

static inline void __AFIFO_Shm_PrintContainer (size_t size, struct iovec cont[3], const char * str) {
    MPIDI_DBG_PRINTF((50, "__AFIFO_Shm_PrintContainer", "%s: Container %d: %d %d %d", str, size, cont[0].iov_len, cont[1].iov_len, cont[2].iov_len));
}

static inline int __AFIFO_Shm_Init (__AFIFO_Shm * fifo, void * memory) {
    fifo->memory = memory;
    fifo->main = 0;
    fifo->aux = 0;
    return 0;
}

static inline void __AFIFO_Shm_UpdateHead (AFIFO_Shm * fifo) {
    uint64_t tmp = *fifo->head_ptr;
    fifo->ctrl.aux = ((tmp & 0x00000000FFFFFFFF)) + __afifo_shm_size.ctrl;
    fifo->data.aux = ((tmp & 0xFFFFFFFF00000000) >> 32) + __afifo_shm_size.data;
}

static inline void __AFIFO_Shm_WriteHead (AFIFO_Shm * fifo) {
    *fifo->head_ptr = (((uint64_t) fifo->data.main) << 32) | ((uint64_t) fifo->ctrl.main);
}

static inline int __AFIFO_Shm_HasFreeCell (AFIFO_Shm * fifo) {
    if (__AFIFO_SHM_GET_FREE_SPACE(ctrl) > 0)
        return TRUE;
    __AFIFO_Shm_UpdateHead(fifo);
    return __AFIFO_SHM_GET_FREE_SPACE(ctrl) > 0;
}

static inline int __AFIFO_Shm_HasFreeCellAndSize (AFIFO_Shm * fifo, uint32_t size) {
    if ((__AFIFO_SHM_GET_FREE_SPACE(ctrl) > 0) && (__AFIFO_SHM_GET_FREE_SPACE(data) >= size))
        return TRUE;
    __AFIFO_Shm_UpdateHead(fifo);
    return (__AFIFO_SHM_GET_FREE_SPACE(ctrl) > 0) && (__AFIFO_SHM_GET_FREE_SPACE(data) >= size);
}

static inline int __AFIFO_Shm_HasUsedCell (AFIFO_Shm * fifo) {
    return __AFIFO_SHM_CHECK_HEADER(*(volatile uint32_t *)__AFIFO_SHM_GET_HEADER_ADDRESS());
}

static inline size_t AFIFO_Shm_Size () {
    return __AFIFO_SHM_CTRL_SIZE + __AFIFO_SHM_DATA_SIZE;
}

// Address memory must be aligned
static inline int AFIFO_Shm_Init (AFIFO_Shm * fifo, void * memory, uint64_t * head_ptr) {
    if (__AFIFO_Shm_Init(&fifo->ctrl, memory) == -1 ||
        __AFIFO_Shm_Init(&fifo->data, ((uint8_t *) memory) + __AFIFO_SHM_CTRL_SIZE) == -1) {
        return -1;
    }
    fifo->head_ptr = head_ptr;
    __AFIFO_Shm_PrintInfo(fifo, "Init");
    return 0;
}

// Only for size <= 60 bytes!!!
static inline ssize_t AFIFO_Shm_SendShort (AFIFO_Shm * fifo, size_t size, struct iovec cont[3], int * cont_count, AFIFO_Shm_SendHeader * sendhdr) {
    if (! __AFIFO_Shm_HasFreeCell(fifo))
        return 0;
    __AFIFO_Shm_PrintInfo(fifo, "SendShort");
    __AFIFO_Shm_PrintHeader(__AFIFO_SHM_MAKE_HEADER(size), "SendShort");
    cont[0].iov_base = __AFIFO_SHM_GET_ADDRESS(ctrl);
    cont[0].iov_len = __AFIFO_SHM_CELL_SIZE - __AFIFO_SHM_HEADER_SIZE;
    *cont_count = 1;
    __AFIFO_Shm_PrintContainer(size, cont, "SendShort");
    sendhdr->addr = __AFIFO_SHM_GET_HEADER_ADDRESS();
    sendhdr->header = __AFIFO_SHM_MAKE_HEADER(size);
    __AFIFO_SHM_INCREMENT(ctrl, __AFIFO_SHM_CELL_SIZE);
    return size;
}

static inline ssize_t AFIFO_Shm_Send (AFIFO_Shm * fifo, size_t size, struct iovec cont[3], int * cont_count, AFIFO_Shm_SendHeader * sendhdr) {
    if (size <= __AFIFO_SHM_CELL_SIZE - __AFIFO_SHM_HEADER_SIZE)
        return AFIFO_Shm_SendShort(fifo, size, cont, cont_count, sendhdr);
    if (size > __AFIFO_SHM_MAX_MESSAGE_SIZE)
        size = __AFIFO_SHM_MAX_MESSAGE_SIZE;
    uint32_t data_size = __AFIFO_SHM_GET_MESSAGE_SIZE_IN_DATA(size);
    if (! __AFIFO_Shm_HasFreeCellAndSize(fifo, data_size))
        return 0;
    __AFIFO_Shm_PrintInfo(fifo, "Send");
    __AFIFO_Shm_PrintHeader(__AFIFO_SHM_MAKE_HEADER(size), "Send");
    uint32_t data_space = __AFIFO_SHM_GET_SPACE(data);
    if (data_size <= data_space) {
        cont[0].iov_base = __AFIFO_SHM_GET_ADDRESS(data);
        cont[0].iov_len = data_size;
        cont[1].iov_base = __AFIFO_SHM_GET_ADDRESS(ctrl);
        cont[1].iov_len = __AFIFO_SHM_CELL_SIZE - __AFIFO_SHM_HEADER_SIZE;
        *cont_count = 2;
    } else {
        cont[0].iov_base = __AFIFO_SHM_GET_ADDRESS(data);
        cont[0].iov_len = data_space;
        cont[1].iov_base = __AFIFO_SHM_GET_ADDRESS_0(data);
        cont[1].iov_len = data_size - data_space;
        cont[2].iov_base = __AFIFO_SHM_GET_ADDRESS(ctrl);
        cont[2].iov_len = __AFIFO_SHM_CELL_SIZE - __AFIFO_SHM_HEADER_SIZE;
        *cont_count = 3;
    }
    __AFIFO_SHM_INCREMENT(data, data_size);
    __AFIFO_Shm_PrintContainer(size, cont, "Send");
    sendhdr->addr = __AFIFO_SHM_GET_HEADER_ADDRESS();
    sendhdr->header = __AFIFO_SHM_MAKE_HEADER(size);
    __AFIFO_SHM_INCREMENT(ctrl, __AFIFO_SHM_CELL_SIZE);
    return size;
}

static inline int AFIFO_Shm_SendComp (AFIFO_Shm * fifo, AFIFO_Shm_SendHeader * sendhdr) {
    *sendhdr->addr = sendhdr->header;
    __AFIFO_Shm_PrintInfo(fifo, "SendComp");
    return 0;
}

static inline ssize_t AFIFO_Shm_Recv (AFIFO_Shm * fifo, struct iovec cont[3], int * cont_count) {
    if (! __AFIFO_Shm_HasUsedCell(fifo))
        return 0;
    __AFIFO_Shm_PrintInfo(fifo, "Recv");
    __AFIFO_Shm_PrintHeader(*__AFIFO_SHM_GET_HEADER_ADDRESS(), "Recv");
    uint32_t size = __AFIFO_SHM_GET_SIZE(*__AFIFO_SHM_GET_HEADER_ADDRESS());
    uint32_t data_size = __AFIFO_SHM_GET_MESSAGE_SIZE_IN_DATA(size);
    if (data_size == 0) {
        cont[0].iov_base = __AFIFO_SHM_GET_ADDRESS(ctrl);
        cont[0].iov_len = __AFIFO_SHM_CELL_SIZE - __AFIFO_SHM_HEADER_SIZE;
        *cont_count = 1;
    } else {
        uint32_t data_space = __AFIFO_SHM_GET_SPACE(data);
        if (data_size <= data_space) {
            cont[0].iov_base = __AFIFO_SHM_GET_ADDRESS(data);
            cont[0].iov_len = data_size;
            cont[1].iov_base = __AFIFO_SHM_GET_ADDRESS(ctrl);
            cont[1].iov_len = __AFIFO_SHM_CELL_SIZE - __AFIFO_SHM_HEADER_SIZE;
            *cont_count = 2;
        } else {
            cont[0].iov_base = __AFIFO_SHM_GET_ADDRESS(data);
            cont[0].iov_len = data_space;
            cont[1].iov_base = __AFIFO_SHM_GET_ADDRESS_0(data);
            cont[1].iov_len = data_size - data_space;
            cont[2].iov_base = __AFIFO_SHM_GET_ADDRESS(ctrl);
            cont[2].iov_len = __AFIFO_SHM_CELL_SIZE - __AFIFO_SHM_HEADER_SIZE;
            *cont_count = 3;
        }
        __AFIFO_SHM_INCREMENT(data, data_size);
    }
    __AFIFO_Shm_PrintContainer(size, cont, "Recv");
    __AFIFO_SHM_INCREMENT(ctrl, __AFIFO_SHM_CELL_SIZE);
    return size;
}

static inline int AFIFO_Shm_RecvComp (AFIFO_Shm * fifo) {
    if ( ((fifo->ctrl.main - fifo->ctrl.aux) > (__afifo_shm_size.ctrl/4)) ||
         ((fifo->data.main - fifo->data.aux) > (__afifo_shm_size.data/4)) ) {
        __AFIFO_Shm_WriteHead(fifo);
        fifo->ctrl.aux = fifo->ctrl.main;
        fifo->data.aux = fifo->data.main;
    }
    __AFIFO_Shm_PrintInfo(fifo, "RecvComp");
    return 0;
}

#undef __AFIFO_SHM_CELL_SIZE
#undef __AFIFO_SHM_CTRL_SIZE
#undef __AFIFO_SHM_DATA_SIZE
#undef __AFIFO_SHM_MAX_MESSAGE_SIZE
#undef __AFIFO_SHM_GET_MESSAGE_SIZE_IN_DATA

#undef __AFIFO_SHM_HEADER_SIZE
#undef __AFIFO_SHM_MAKE_HEADER
#undef __AFIFO_SHM_CHECK_HEADER
#undef __AFIFO_SHM_GET_PARITY
#undef __AFIFO_SHM_GET_SIZE

#undef __AFIFO_SHM_GET_HEADER_ADDRESS
#undef __AFIFO_SHM_GET_ADDRESS
#undef __AFIFO_SHM_GET_ADDRESS_0
#undef __AFIFO_SHM_GET_SPACE
#undef __AFIFO_SHM_GET_FREE_SPACE
#undef __AFIFO_SHM_INCREMENT

#endif /* AFIFO_SHM_H */
