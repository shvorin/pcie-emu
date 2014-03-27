/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */

/* vim: set syntax=c et sw=4 ts=4: */

#ifndef IOV_H
#define IOV_H

#include <stdint.h>
#include <string.h>
#include <sys/uio.h>
#include "mmdev.h"

#define TRUE 1
#define FALSE 0

// FIXME: Not thread safe!
static uint8_t __IOV_TMP[64 + 8];
static size_t __IOV_TMPSize;

static inline size_t __IOV_MIN (size_t x, size_t y) {
    if (x < y) return x; else return y;
}

static inline int __IOV_Adjust (const struct iovec * iov, int iov_count, int * iov_offset_ptr, void * * iov_buf_ptr, size_t * iov_len_ptr, size_t size) {
    *iov_buf_ptr = ((uint8_t *) *iov_buf_ptr) + size;
    (*iov_len_ptr) -= size;
    if (*iov_len_ptr == 0) {
        (*iov_offset_ptr)++;
        if (*iov_offset_ptr == iov_count) {
            return TRUE;
        } else {
            *iov_buf_ptr = iov[*iov_offset_ptr].iov_base;
            *iov_len_ptr = iov[*iov_offset_ptr].iov_len;
            return FALSE;
        }
    } else {
        return FALSE;
    }
}

// ===================================================== IOV_Size ======================================================

static inline size_t IOV_MPI_Size (const struct iovec * iov, int iov_count, int iov_offset) {
    size_t size = 0;
    for ( ; iov_offset < iov_count; iov_offset++)
        size += iov[iov_offset].iov_len;
    return size;
}

static inline size_t IOV_Size (const struct iovec * iov, int iov_count) {
    return IOV_MPI_Size(iov, iov_count, 0);
}

// ===================================================== IOV_Count =====================================================

// Must be 0 < size <= IOV_Size(cont, infinity)
// It can be rewrite to use knowledge abount container:
//   cont_count < 2
//   cont[0..cont_count-2].iov_len = 64k
//   cont[cont_count-1].iov_len = 60
static inline int IOV_Count (struct iovec cont[3], size_t size) {
    int cont_offset;
    ssize_t ssize = size;
    for (cont_offset = 0; ssize > 0; cont_offset++)
        ssize -= cont[cont_offset].iov_len;
    cont[cont_offset - 1].iov_len += ssize;
    return cont_offset;
}

// Must be 0 < size <= IOV_Size(cont, infinity) - 4
// It can be rewrite to use knowledge abount container:
//   cont_count < 2
//   cont[0..cont_count-2].iov_len = 64k
//   cont[cont_count-1].iov_len = 60
static inline int IOV2_MPI_Count (struct iovec cont[3], size_t size, uint32_t * src_rank) {
    int cont_offset;
    ssize_t ssize = size;
    for (cont_offset = 0; ssize > 0; cont_offset++)
        ssize -= cont[cont_offset].iov_len;
    cont[cont_offset - 1].iov_len += ssize;
    if (ssize == 0) {
        memcpy(src_rank, cont[cont_offset].iov_base, 4);
    } else if (ssize > -4) {
        memcpy(src_rank, ((uint8_t *) cont[cont_offset - 1].iov_base) + cont[cont_offset - 1].iov_len, -ssize);
        memcpy(((uint8_t *) src_rank) - ssize, cont[cont_offset].iov_base, 4 + ssize);
    } else {
        memcpy(src_rank, ((uint8_t *) cont[cont_offset - 1].iov_base) + cont[cont_offset - 1].iov_len, 4);
    }
    return cont_offset;
}

// ===================================================== IOV_Copy ======================================================

static inline void __IOV_Copy (const struct iovec * dst, int dst_count, int * dst_offset_ptr, void * * dst_buf_ptr, size_t * dst_len_ptr,
                               const struct iovec * src, int src_count, int * src_offset_ptr, void * * src_buf_ptr, size_t * src_len_ptr) {
    int dst_res = FALSE;
    int src_res = FALSE;
    while (!dst_res && !src_res) {
        size_t s = __IOV_MIN(*dst_len_ptr, *src_len_ptr);
        memcpy(*dst_buf_ptr, *src_buf_ptr, s);
        dst_res = __IOV_Adjust(dst, dst_count, dst_offset_ptr, dst_buf_ptr, dst_len_ptr, s);
        src_res = __IOV_Adjust(src, src_count, src_offset_ptr, src_buf_ptr, src_len_ptr, s);
    }
}

static inline int __IOV_Copy8ToTMP (size_t size, const struct iovec * src, int src_count, int * src_offset_ptr, void ** src_buf_ptr, size_t * src_len_ptr) {
    void * dst_buf = __IOV_TMP;
    size_t dst_len = size;
    int src_res = FALSE;
    while (dst_len > 0 && !src_res) {
        size_t s = __IOV_MIN(dst_len, *src_len_ptr);
        memcpy(dst_buf, *src_buf_ptr, s);
        dst_buf = ((uint8_t *) dst_buf) + s;
        dst_len -= s;
        src_res = __IOV_Adjust(src, src_count, src_offset_ptr, src_buf_ptr, src_len_ptr, s);
    }
    __IOV_TMPSize = size - dst_len;
    return src_res;
}

static inline void IOV_Copy (const struct iovec * dst, int dst_count, const struct iovec * src, int src_count) {
    int dst_offset = 0;
    void * dst_buf = dst[0].iov_base;
    size_t dst_len = dst[0].iov_len;
    int src_offset = 0;
    void * src_buf = src[0].iov_base;
    size_t src_len = src[0].iov_len;
    __IOV_Copy(dst, dst_count, &dst_offset, &dst_buf, &dst_len, src, src_count, &src_offset, &src_buf, &src_len);
}

static inline void IOV_MPI_Copy (struct iovec * dst, int dst_count, int * dst_offset_ptr, struct iovec * src, int src_count, int * src_offset_ptr) {
    void * dst_buf = dst[*dst_offset_ptr].iov_base;
    size_t dst_len = dst[*dst_offset_ptr].iov_len;
    void * src_buf = src[*src_offset_ptr].iov_base;
    size_t src_len = src[*src_offset_ptr].iov_len;
    __IOV_Copy(dst, dst_count, dst_offset_ptr, &dst_buf, &dst_len, src, src_count, src_offset_ptr, &src_buf, &src_len);
    if (*dst_offset_ptr < dst_count) {
        dst[*dst_offset_ptr].iov_base = dst_buf;
        dst[*dst_offset_ptr].iov_len = dst_len;
    }
    if (*src_offset_ptr < src_count) {
        src[*src_offset_ptr].iov_base = src_buf;
        src[*src_offset_ptr].iov_len = src_len;
    }
}

// =================================================== IOV_CopyToPCI ===================================================

// cont_len must divide 8
static inline void __IOV_CopyToPCI (const struct iovec cont[3], int cont_count, int * cont_offset_ptr, void * * cont_buf_ptr, size_t * cont_len_ptr,
                                    const struct iovec * iov, int iov_count, int * iov_offset_ptr, void * * iov_buf_ptr, size_t * iov_len_ptr) {
    int cont_res = FALSE;
    int iov_res = FALSE;
    while (!cont_res && !iov_res) {
        size_t s = __IOV_MIN(*cont_len_ptr, *iov_len_ptr);
        if (s >= 8) {
            s = s & (~0x7);
            mmdev_memcpy(*cont_buf_ptr, *iov_buf_ptr, s);
            cont_res = __IOV_Adjust(cont, cont_count, cont_offset_ptr, cont_buf_ptr, cont_len_ptr, s);
            iov_res = __IOV_Adjust(iov, iov_count, iov_offset_ptr, iov_buf_ptr, iov_len_ptr, s);
        } else {
            iov_res = __IOV_Copy8ToTMP(8, iov, iov_count, iov_offset_ptr, iov_buf_ptr, iov_len_ptr);
            mmdev_memcpy(*cont_buf_ptr, __IOV_TMP, 8);
            cont_res = __IOV_Adjust(cont, cont_count, cont_offset_ptr, cont_buf_ptr, cont_len_ptr, 8);
            __IOV_TMPSize = 0;
        }
    }
    mmdev_memcpy(*cont_buf_ptr, __IOV_TMP, *cont_len_ptr);
}

static inline void IOV_CopyToPCI (const struct iovec * cont, int cont_count, const struct iovec * iov, int iov_count) {
    int cont_offset = 0;
    void * cont_buf = cont[0].iov_base;
    size_t cont_len = cont[0].iov_len;
    int iov_offset = 0;
    void * iov_buf = iov[0].iov_base;
    size_t iov_len = iov[0].iov_len;
    __IOV_CopyToPCI(cont, cont_count, &cont_offset, &cont_buf, &cont_len, iov, iov_count, &iov_offset, &iov_buf, &iov_len);
}

static inline void IOV_MPI_CopyToPCI (const struct iovec * cont, int cont_count, struct iovec * iov, int iov_count, int * iov_offset_ptr) {
    int cont_offset = 0;
    void * cont_buf = cont[0].iov_base;
    size_t cont_len = cont[0].iov_len;
    void * iov_buf = iov[*iov_offset_ptr].iov_base;
    size_t iov_len = iov[*iov_offset_ptr].iov_len;
    __IOV_CopyToPCI(cont, cont_count, &cont_offset, &cont_buf, &cont_len, iov, iov_count, iov_offset_ptr, &iov_buf, &iov_len);
    if (*iov_offset_ptr < iov_count) {
        iov[*iov_offset_ptr].iov_base = iov_buf;
        iov[*iov_offset_ptr].iov_len = iov_len;
    }
}

// ================================================== IOV2_CopyToPCI ===================================================

static inline int __IOV2_AdjustCont (const struct iovec * cont, int cont_count, int * cont_offset_ptr, void * * cont_buf_ptr, size_t * cont_len_ptr, size_t size, int use_fence) {
    *cont_buf_ptr = ((uint8_t *) *cont_buf_ptr) + size;
    (*cont_len_ptr) -= size;
    if (*cont_len_ptr == 0) {
        (*cont_offset_ptr)++;
        if (use_fence && *cont_offset_ptr == cont_count-1) {
            mmdev_fence();
        }
        if (*cont_offset_ptr == cont_count) {
            return TRUE;
        } else {
            *cont_buf_ptr = cont[*cont_offset_ptr].iov_base;
            *cont_len_ptr = cont[*cont_offset_ptr].iov_len;
            return FALSE;
        }
    } else {
        return FALSE;
    }
}

// cont_len (except last) must divide 8
static inline void __IOV2_CopyToPCI (const struct iovec cont[3], int cont_count, int * cont_offset_ptr, void * * cont_buf_ptr, size_t * cont_len_ptr,
                                     const struct iovec * iov, int iov_count, int * iov_offset_ptr, void * * iov_buf_ptr, size_t * iov_len_ptr, int use_fence) {
    int cont_res = FALSE;
    int iov_res = FALSE;
    while (!cont_res && !iov_res) {
        size_t s = __IOV_MIN(*cont_len_ptr, *iov_len_ptr);
        if (s >= 8) {
            s = s & (~0x7);
            mmdev_memcpy(*cont_buf_ptr, *iov_buf_ptr, s);
            cont_res = __IOV2_AdjustCont(cont, cont_count, cont_offset_ptr, cont_buf_ptr, cont_len_ptr, s, use_fence);
            iov_res = __IOV_Adjust(iov, iov_count, iov_offset_ptr, iov_buf_ptr, iov_len_ptr, s);
        } else {
            if (*cont_len_ptr < 8) { // cont_offset = cont_size -1
                __IOV_Copy8ToTMP(s, iov, iov_count, iov_offset_ptr, iov_buf_ptr, iov_len_ptr);
                return;
            }
            iov_res = __IOV_Copy8ToTMP(8, iov, iov_count, iov_offset_ptr, iov_buf_ptr, iov_len_ptr);
            if (__IOV_TMPSize == 8) {
                mmdev_memcpy(*cont_buf_ptr, __IOV_TMP, 8);
                cont_res = __IOV2_AdjustCont(cont, cont_count, cont_offset_ptr, cont_buf_ptr, cont_len_ptr, 8, use_fence);
                __IOV_TMPSize = 0;
            }
        }
    }
}

// cont does not include header
static inline void IOV2_CopyToPCI (const struct iovec cont[3], int cont_count, const struct iovec * iov, int iov_count, uint32_t header, int use_fence) {
    int cont_offset = 0;
    void * cont_buf = cont[0].iov_base;
    size_t cont_len = cont[0].iov_len;
    int iov_offset = 0;
    void * iov_buf = iov[0].iov_base;
    size_t iov_len = iov[0].iov_len;
    __IOV2_CopyToPCI(cont, cont_count, &cont_offset, &cont_buf, &cont_len, iov, iov_count, &iov_offset, &iov_buf, &iov_len, use_fence);
    if (cont_offset == cont_count - 2) { // cont_len == 8
        memcpy(__IOV_TMP + 8 + 64 - 4, &header, 4);
        mmdev_memcpy(cont_buf, __IOV_TMP, 8);
        if (use_fence) {
            mmdev_fence();
        }
        mmdev_memcpy(cont[cont_count - 1].iov_base, __IOV_TMP + 8, 64);
    } else {
        memcpy(__IOV_TMP + cont_len, &header, 4);
        mmdev_memcpy(cont_buf, __IOV_TMP, cont_len + 4);
    }
    __IOV_TMPSize = 0;
}

// cont does not include src_rank and header
static inline void IOV2_MPI_CopyToPCI (const struct iovec cont[3], int cont_count,
                                       struct iovec * iov, int iov_count, int * iov_offset_ptr, uint32_t src_rank, uint32_t header, int use_fence) {
    int cont_offset = 0;
    void * cont_buf = cont[0].iov_base;
    size_t cont_len = cont[0].iov_len;
    void * iov_buf = iov[*iov_offset_ptr].iov_base;
    size_t iov_len = iov[*iov_offset_ptr].iov_len;
    __IOV2_CopyToPCI(cont, cont_count, &cont_offset, &cont_buf, &cont_len, iov, iov_count, iov_offset_ptr, &iov_buf, &iov_len, use_fence);
    if (*iov_offset_ptr < iov_count) {
        iov[*iov_offset_ptr].iov_base = iov_buf;
        iov[*iov_offset_ptr].iov_len = iov_len;
    }
    if (cont_offset == cont_count - 2) { // cont_len == 8
        memcpy(__IOV_TMP + __IOV_TMPSize, &src_rank, 4);
        memcpy(__IOV_TMP + 8 + 64 - 4, &header, 4);
        mmdev_memcpy(cont_buf, __IOV_TMP, 8);
        if (use_fence) {
            mmdev_fence();
        }
        mmdev_memcpy(cont[cont_count - 1].iov_base, __IOV_TMP + 8, 64);
    } else if (cont_len == 0) { // Optimization for size == 64k+56 (cont_offset == cont_count)
        mmdev_put64(cont_buf, (((uint64_t) header) << 32) | ((uint64_t) src_rank));
    } else {
        memcpy(__IOV_TMP + __IOV_TMPSize, &src_rank, 4);
        memcpy(__IOV_TMP + cont_len + 4, &header, 4);
        mmdev_memcpy(cont_buf, __IOV_TMP, cont_len + 8);
    }
    __IOV_TMPSize = 0;
}

// ================================================== IOV2_Copy64ToPCI ===================================================

// Only for size <= 60 bytes!!!
static inline void IOV2_Copy64ToPCI (void * cont, const void * data, size_t size, uint32_t header) {
    size_t s = size & (~0x7);
    memcpy(__IOV_TMP, ((uint8_t *) data) + s, size - s);
    memcpy(__IOV_TMP + 64 - s - 4, &header, 4);
    mmdev_memcpy(cont, data, s);
    mmdev_memcpy(((uint8_t *) cont) + s, __IOV_TMP, 64 - s);
}

// Only for size <= 56 bytes!!!
static inline void IOV2_MPI_Copy64ToPCI (void * cont, const void * data, size_t size, uint32_t src_rank, uint32_t header) {
    if (size == 56) { // Optimization for size == 56 == 7 * sizeof(uint64_t)
        mmdev_memcpy(cont, data, 56);
        mmdev_put64(((uint8_t *) cont) + 56, (((uint64_t) header) << 32) | ((uint64_t) src_rank));
    } else {
        size_t s = size & (~0x7);
        memcpy(__IOV_TMP, ((uint8_t *) data) + s, size - s);
        memcpy(__IOV_TMP + size - s, &src_rank, 4);
        memcpy(__IOV_TMP + 64 - s - 4, &header, 4);
        mmdev_memcpy(cont, data, s);
        mmdev_memcpy(((uint8_t *) cont) + s, __IOV_TMP, 64 - s);
    }
}

#endif /* IOV_H */
