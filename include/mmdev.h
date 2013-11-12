/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */

/* vim: set syntax=c et sw=4 ts=4: */

#ifndef DEVPAUTINA_H
#define DEVPAUTINA_H

#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "pautina-driver.h"

#define DEVPAUTINA_FAILED ((void*)-1)

#ifdef EMU

#include <emu-client.h>

#define mock_open emuc_open
#define mock_close emuc_close
#define mock_ioctl emuc_ioctl
#define mock_mmap emuc_mmap
#define mock_munmap emuc_munmap

#define mock_down_memcpy emuc_down_memcpy
#define mock_up_memcpy emuc_up_memcpy
#define mock_down_mem64 emuc_down_mem64
#define mock_up_mem64 emuc_up_mem64
#define mock_fence emuc_fence

#else /* EMU */

#define mock_open open
#define mock_close close
#define mock_ioctl ioctl
#define mock_mmap mmap
#define mock_munmap munmap
#define mock_fence() asm volatile ("sfence":::"memory")

#define mock_down_memcpy real_memcpy
#define mock_up_memcpy real_memcpy
#define mock_down_mem64 real_down_mem64
#define mock_up_mem64 real_up_mem64

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

static __attribute__((unused)) off_t DEVPAUTINA_Page_Align_Up (off_t size) {
    off_t page_size = sysconf(_SC_PAGE_SIZE);
    return (size + page_size - 1) & (~(page_size - 1));
}

static __attribute__((unused)) off_t DEVPAUTINA_Page_Align_Down (off_t size) {
    off_t page_size = sysconf(_SC_PAGE_SIZE);
    return size & (~(page_size - 1));
}

typedef struct DEVPAUTINA_t {
    void * pa_address;
    size_t pa_length;
    int fd;
} DEVPAUTINA;

#define FILENAMESIZE 128
static int __devpautina_open (const char * name, int prot) {
    char filename[FILENAMESIZE];
    snprintf(filename, FILENAMESIZE, "/dev/pautina/%s", name);
    int flags = 0;
    if ((prot & PROT_READ) && (prot & PROT_WRITE)) {
        flags = O_RDWR;
    } else if (prot & PROT_READ) {
        flags = O_RDONLY;
    } else if (prot & PROT_WRITE) {
        flags = O_WRONLY;
    }
    return mock_open(filename, flags);
}

static void __devpautina_close (int fd) {
    mock_close(fd);
}

static ssize_t __devpautina_get_bar_length (int fd, uint8_t dev_num, uint8_t bar_num) {
    BARDesc bardesc;
    bardesc.dev_num = dev_num;
    bardesc.bar_num = bar_num;
    int res = mock_ioctl(fd, PAUTINA_DRIVER_GET_BARLENGTH, &bardesc);
    if (res == -1)
        return -1;
    return bardesc.length;
}

static ssize_t __devpautina_get_length (int fd) {
    size_t length;
    int res = mock_ioctl(fd, PAUTINA_DRIVER_GET_LENGTH, &length);
    if (res == -1)
        return -1;
    return length;
}

static void * __devpautina_mmap (DEVPAUTINA * devpautina, off_t mmaparg, size_t len, int prot) {
    off_t pa_mmaparg = DEVPAUTINA_Page_Align_Down(mmaparg);
    devpautina->pa_length = (mmaparg - pa_mmaparg) + len;
    //fprintf(stderr, "devpautina.h: mmap: mmaparg: 0x%lX, length: 0x%lX\n", mmaparg, len);
    //fprintf(stderr, "devpautina.h: mmap: pa_mmaparg: 0x%lX, pa_length: 0x%lX\n", pa_mmaparg, devpautina->pa_length);
    devpautina->pa_address = mock_mmap(NULL, devpautina->pa_length, prot & (PROT_READ | PROT_WRITE), MAP_SHARED, devpautina->fd, pa_mmaparg);
    if (devpautina->pa_address == MAP_FAILED)
        return DEVPAUTINA_FAILED;
    void * addr = ((uint8_t *) devpautina->pa_address) + (mmaparg - pa_mmaparg);
    //fprintf(stderr, "devpautina.h: mmap: pa_address: 0x%lX, address: 0x%lX\n", devpautina->pa_address, addr);
    return addr;
}

static void __devpautina_munmap (DEVPAUTINA * devpautina) {
    mock_munmap(devpautina->pa_address, devpautina->pa_length);
}

static __attribute__((unused)) ssize_t DEVPAUTINA_BAR_Length (uint8_t dev_num, uint8_t bar_num) {
    int fd = __devpautina_open("admin", PROT_READ);
    if (fd == -1)
        return -1;
    ssize_t length = __devpautina_get_bar_length(fd, dev_num, bar_num);
    __devpautina_close(fd);
    return length;
}

static __attribute__((unused)) ssize_t DEVPAUTINA_MEM_Length (uint8_t mem_num) {
    return DEVPAUTINA_BAR_Length(PAUTINA_DRIVER_DEV_MEM, mem_num);
}

static __attribute__((unused)) void * DEVPAUTINA_BAR_Init (DEVPAUTINA * devpautina, uint8_t dev_num, uint8_t bar_num, off_t off, size_t len) {
    devpautina->fd = __devpautina_open("admin", PROT_READ | PROT_WRITE);
    if (devpautina->fd == -1)
        return DEVPAUTINA_FAILED;
    void * res = __devpautina_mmap(devpautina, PAUTINA_DRIVER_MMAPARG(dev_num, bar_num, off), len, PROT_READ | PROT_WRITE);
    if (res == DEVPAUTINA_FAILED)
        goto error;
    return res;
  error:
    __devpautina_close(devpautina->fd);
    return DEVPAUTINA_FAILED;
}

static __attribute__((unused)) void * DEVPAUTINA_MEM_Init (DEVPAUTINA * devpautina, uint8_t mem_num, off_t off, size_t len) {
    return DEVPAUTINA_BAR_Init(devpautina, PAUTINA_DRIVER_DEV_MEM, mem_num, off, len);
}

static __attribute__((unused)) void * DEVPAUTINA_BAR_Entire_Init (DEVPAUTINA * devpautina, uint8_t dev_num, uint8_t bar_num, size_t * len) {
    ssize_t length; void * res;
    devpautina->fd = __devpautina_open("admin", PROT_READ | PROT_WRITE);
    if (devpautina->fd == -1)
        return DEVPAUTINA_FAILED;
    length = __devpautina_get_bar_length(devpautina->fd, dev_num, bar_num);
    if (length == -1)
        goto error;
    if (len != 0)
        *len = length;
    res = __devpautina_mmap(devpautina, PAUTINA_DRIVER_MMAPARG(dev_num, bar_num, 0), length, PROT_READ | PROT_WRITE);
    if (res == DEVPAUTINA_FAILED)
        goto error;
    return res;
  error:
    __devpautina_close(devpautina->fd);
    return DEVPAUTINA_FAILED;
}

static __attribute__((unused)) void * DEVPAUTINA_MEM_Entire_Init (DEVPAUTINA * devpautina, uint8_t mem_num, size_t * len) {
    return DEVPAUTINA_BAR_Entire_Init(devpautina, PAUTINA_DRIVER_DEV_MEM, mem_num, len);
}

// prot - PROT_READ or PROT_WRITE or both
static __attribute__((unused)) void * DEVPAUTINA_Init (DEVPAUTINA * devpautina, const char * name, int prot, size_t * len) {
    ssize_t length; void * res;
    devpautina->fd = __devpautina_open(name, prot);
    if (devpautina->fd == -1)
        return DEVPAUTINA_FAILED;
    length = __devpautina_get_length(devpautina->fd);
    if (length == -1)
        goto error;
    if (len != 0)
        *len = length;
    res = __devpautina_mmap(devpautina, 0, length, prot);
    if (res == DEVPAUTINA_FAILED)
        goto error;
    return res;
  error:
    __devpautina_close(devpautina->fd);
    return DEVPAUTINA_FAILED;
}

static __attribute__((unused)) void DEVPAUTINA_Finalise (DEVPAUTINA * devpautina) {
    __devpautina_munmap(devpautina);
    __devpautina_close(devpautina->fd);
}

#endif /* DEVPAUTINA_H */
