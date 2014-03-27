/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */

/* vim: set syntax=c et sw=4 ts=4: */

#ifndef SKIFCH_SHM_H
#define SKIFCH_SHM_H

#include <stdint.h>
#include "processid.h"
#include "shared-memory.h"
#include "skifch-misc.h"

typedef struct {
    SharedMemory shm;
} __SkifCh_Shm;


int SkifCh_Shm_Finalize (__attribute__((unused)) SkifCh_Union * ch, uint8_t aux[SKIFCH_AUX_SIZE]) {
    SharedMemory_Remove(&((__SkifCh_Shm *) aux)->shm);
    return 0;
}

#undef FCNAME
#define FCNAME "SkifCh_Shm_Init"
int SkifCh_Shm_Init (SkifCh * skifch, SkifCh_Aux * skifch_aux, key_t * key) {
    if (sizeof(__SkifCh_Shm) > SKIFCH_AUX_SIZE) {
        PROCESSID_ERROR_CREATE("Constant SKIFCH_AUX_SIZE is too small", ENOMEM);
        goto error_shm;
    }
    SharedMemory * shm = &((__SkifCh_Shm *) skifch_aux->aux)->shm;
    if (*key == 0) {
        void * addr = SharedMemory_Create(shm, key, 2*SkifCh2Shm_Size());
        if (addr == SHARED_MEMORY_FAILED) {
            PROCESSID_ERROR_CONVERT("SharedMemory_Create", "Shared memory initialization failed");
            goto error_shm;
        }
        int res = SkifCh_Init(skifch, skifch_aux, SkifCh_Shm_Finalize, ((uint8_t *) addr) + SkifCh2Shm_Size(), addr, SkifCh2Shm_tag, 0, 0, 0, 0);
        if (res == -1) {
            goto error;
        }
    } else {
        void * addr = SharedMemory_Get(shm, *key, 2*SkifCh2Shm_Size());
        if (addr == SHARED_MEMORY_FAILED) {
            PROCESSID_ERROR_CONVERT("SharedMemory_Get", "Shared memory initialization failed");
            goto error_shm;
        }
        int res = SkifCh_Init(skifch, skifch_aux, SkifCh_Shm_Finalize, addr, ((uint8_t *) addr) + SkifCh2Shm_Size(), SkifCh2Shm_tag, 0, 0, 0, 0);
        if (res == -1) {
            goto error;
        }
        SharedMemory_MarkToBeDestroyed(shm);
    }
    return 0;

  error:
    SharedMemory_Remove(shm);
  error_shm:
    return -1;
}

#endif /* SKIFCH_SHM_H */
