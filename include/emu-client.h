/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */


#ifndef EMU_CLIENT_H
#define EMU_CLIENT_H

#include <sys/types.h>


#ifdef __cplusplus
extern "C" {
#endif

  /* (Nearly) the same prototypes as standard functions have. */

  extern int emuc_open(const char *pathname, int flags);
  extern int emuc_close(int fd);

  extern int emuc_ioctl(int fd, unsigned long cmd, ...);

  extern void *emuc_mmap(void *addr, size_t length, int prot, int flags, int fd, off_t offset);
  extern int emuc_munmap(void *addr, size_t length);

  extern void emuc_fence();

  extern void *emuc_down_memcpy(void *dst, const void *src, size_t nBytes);
  extern void *emuc_up_memcpy(void *dst, const void *src, size_t nBytes);
  extern void emuc_down_mem64 (void * ptr, uint64_t value);
  extern uint64_t emuc_up_mem64 (void * ptr);

  extern void *emuc_memset(void *s, int c, size_t nBytes);
  
#ifdef __cplusplus
}
#endif

#endif /* EMU_CLIENT_H */
