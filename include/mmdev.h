/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */

/* vim: set syntax=c et sw=4 ts=4: */

#ifndef MMDEV_H
#define MMDEV_H

#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <fcntl.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>
//#include <stdio.h>
//#include <stdlib.h>

#if 0

int mmdev_open (const char * pathname, int flags);
int mmdev_close (int fd);
int mmdev_ioctl (int d, int request, ...);
void * mmdev_mmap (void * addr, size_t length, int prot, int flags, int fd, off_t offset);
int mmdev_munmap (void * addr, size_t length);

void * mmdev_down_memcpy (void * dst, const void * src, size_t n);
void * mmdev_up_memcpy (void * dst, const void * src, size_t n);
void mmdev_down_mem64 (void * ptr, uint64_t value);
uint64_t mmdev_up_mem64 (const void * ptr);
void mmdev_fence ();

#endif

#ifdef EMU

#include <emu-client.h>

#define mmdev_open emuc_open
#define mmdev_close emuc_close
#define mmdev_ioctl emuc_ioctl
#define mmdev_mmap emuc_mmap
#define mmdev_munmap emuc_munmap

#define mmdev_down_memcpy emuc_down_memcpy
#define mmdev_up_memcpy emuc_up_memcpy
#define mmdev_down_mem64 emuc_down_mem64
#define mmdev_up_mem64 emuc_up_mem64
#define mmdev_fence emuc_fence

#else /* EMU */

#define mmdev_open open
#define mmdev_close close
#define mmdev_ioctl ioctl
#define mmdev_mmap mmap
#define mmdev_munmap munmap

#define mmdev_down_memcpy real_memcpy
#define mmdev_up_memcpy real_memcpy
#define mmdev_down_mem64 real_down_mem64
#define mmdev_up_mem64 real_up_mem64
#define mmdev_fence() asm volatile ("sfence":::"memory")

#ifdef UNSAFE_FPGA_MEMOPS

static void * real_memcpy (void * dst, const void * src, size_t n) { return memcpy(dst, src, n); }
static void real_down_mem64 (void * ptr, uint64_t value) { *(uint64_t*)ptr = value; }
static uint64_t real_up_mem64 (void * ptr) { return *(uint64_t*)ptr; }

#else /* UNSAFE_FPGA_MEMOPS */
/* those declared functions must be defined somewhere else */

#ifdef __cplusplus
extern "C" {
#endif

    extern void * real_memcpy (void * dst, const void * src, size_t n);
    extern void real_down_mem64 (void * ptr, uint64_t value);
    extern uint64_t real_up_mem64 (void * ptr);

#ifdef __cplusplus
}
#endif

#endif /* not UNSAFE_FPGA_MEMOPS */
#endif /* not EMU */
#endif /* MMDEV_H */
