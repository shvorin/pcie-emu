/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */


#ifndef EMU_CLIENT_H
#define EMU_CLIENT_H

#include <sys/types.h>


#ifdef __cplusplus
extern "C" {
#endif

/* (Nearly) the same prototypes as standard functions have. */

int emuc_open(const char *pathname, int flags);

int emuc_close(int fd);

int emuc_ioctl(int fd, unsigned long cmd, ...);

void *emuc_mmap(void *addr, size_t length, int prot, int flags, int fd, off_t offset);

int emuc_munmap(void *addr, size_t length);

void emuc_fence();

void *emuc_down_memcpy(void *dst, const void *src, size_t nBytes);

void *emuc_up_memcpy(void *dst, const void *src, size_t nBytes);

#ifdef __cplusplus
}
#endif

#endif /* EMU_CLIENT_H */
