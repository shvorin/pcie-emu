/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */

/* vim: set syntax=c et sw=4 ts=4: */

#ifndef SHARED_MEMORY_H
#define SHARED_MEMORY_H

#include <sys/ipc.h>
#include <sys/shm.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <errno.h>

#define SHARED_MEMORY_FAILED ((void*)-1)

static int __shared_memory_create_segment (key_t * key, size_t size) {
    static key_t global_key = 0;
    int id;
    for (;;) {
        global_key++;
        id = shmget(global_key, size, IPC_CREAT | IPC_EXCL | S_IRUSR | S_IWUSR);
        if (id != -1) {
            *key = global_key;
            return id;
        }
        else if (errno != EEXIST)
            return -1;
        else
            errno = 0;
    }
}

static int __shared_memory_get_segment (key_t key, size_t size) {
    return shmget(key, size, S_IRUSR | S_IWUSR);
}

static void __shared_memory_remove_segment (int id) {
    shmctl(id, IPC_RMID, 0);
}

static void * __shared_memory_get_address (int id) {
    return shmat(id, 0, 0);
}

static void __shared_memory_remove_address (const void * addr) {
    shmdt(addr);
}

typedef struct {
    void * addr;
    int id;
} SharedMemory;

static void * SharedMemory_Create (SharedMemory * shm, key_t * key, size_t size) {
    shm->id = __shared_memory_create_segment(key, size);
    if (shm->id == -1)
        return SHARED_MEMORY_FAILED;
    shm->addr = __shared_memory_get_address(shm->id);
    if (shm->addr == SHARED_MEMORY_FAILED) {
        __shared_memory_remove_segment(shm->id);
        return SHARED_MEMORY_FAILED;
    }
    return shm->addr;
}

static void * SharedMemory_Get (SharedMemory * shm, key_t key, size_t size) {
    shm->id = __shared_memory_get_segment(key, size);
    if (shm->id == -1)
        return SHARED_MEMORY_FAILED;
    shm->addr = __shared_memory_get_address(shm->id);
    if (shm->addr == SHARED_MEMORY_FAILED) {
        __shared_memory_remove_segment(shm->id);
        return SHARED_MEMORY_FAILED;
    }
    return shm->addr;
}

static void SharedMemory_MarkToBeDestroyed (SharedMemory * shm) {
    __shared_memory_remove_segment(shm->id);
}

static void SharedMemory_Remove (SharedMemory * shm) {
    __shared_memory_remove_address(shm->addr);
    __shared_memory_remove_segment(shm->id);
}

#endif /* SHARED_MEMORY_H */
