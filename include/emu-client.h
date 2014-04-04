/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */

/* vim: set syntax=c et sw=4 ts=4: */

#ifndef EMU_CLIENT_H
#define EMU_CLIENT_H

#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <fcntl.h>
#include <stdint.h>
#include <unistd.h>
#include "pautina-driver.h"

#ifdef __cplusplus
extern "C" {
#endif

extern int emuc_open (const char * pathname, int flags);
extern int emuc_close (int fd);
extern int emuc_ioctl (int fd, unsigned long request, pautina_driver_ioctl_arg_t arg);
extern void * emuc_mmap (void * addr, size_t length, int prot, int flags, int fd, off_t offset);
extern int emuc_munmap (void * addr, size_t length);

extern void * emuc_memcpy (void * dst, const void * src, size_t n);
extern void emuc_put64 (volatile void * ptr, uint64_t value);
extern uint64_t emuc_get64 (volatile void * ptr);
extern void emuc_fence();

#ifdef __cplusplus
}
#endif

#endif /* EMU_CLIENT_H */
