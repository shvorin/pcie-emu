/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */

/* vim: set syntax=c et sw=4 ts=4: */

#ifndef SHARED_MEMORY_H
#define SHARED_MEMORY_H

#include <sys/ipc.h>
#include <sys/shm.h>
#include <sys/mman.h>

typedef struct {
    void * addr;
    int id;
} SharedMemory;

void * SharedMemory_Create (SharedMemory * shm, key_t * key, size_t size);

void * SharedMemory_Get (SharedMemory * shm, key_t key, size_t size);

void SharedMemory_MarkToBeDestroyed (SharedMemory * shm);

void SharedMemory_Remove (SharedMemory * shm);

#endif /* SHARED_MEMORY_H */
