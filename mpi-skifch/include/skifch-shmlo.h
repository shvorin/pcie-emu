/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */

/* vim: set syntax=c et sw=4 ts=4: */

#ifndef SKIFCH_SHMLO_H
#define SKIFCH_SHMLO_H

#include <malloc.h>
#include <stdint.h>
#include "processid.h"
#include "skifch-misc.h"

typedef struct {
    void * addr;
} __SkifCh_ShmLo;

int SkifCh_ShmLo_Finalize (__attribute__((unused)) SkifCh_Union * ch, uint8_t aux[SKIFCH_AUX_SIZE]) {
    free(((__SkifCh_ShmLo *) aux)->addr);
    return 0;
}

#undef FCNAME
#define FCNAME "SkifCh_ShmLo_Init"
int SkifCh_ShmLo_Init (SkifCh * skifch, SkifCh_Aux * skifch_aux) {
    if (sizeof(__SkifCh_ShmLo) > SKIFCH_AUX_SIZE) {
        PROCESSID_ERROR_CREATE("Constant 'SKIFCH_AUX_SIZE' is too small", ENOMEM);
        goto error_alloc;
    }
    void * addr = valloc(SkifCh2Shm_Size());
    if (addr == NULL) {
        PROCESSID_ERROR_CONVERT("valloc", "Allocation failed");
        goto error_alloc;
    }
    ((__SkifCh_ShmLo *) skifch_aux->aux)->addr = addr;
    int res = SkifCh_Init(skifch, skifch_aux, SkifCh_ShmLo_Finalize, addr, addr, SkifCh2Shm_tag, 0, 0, 0, 0);
    if (res == -1) {
        goto error;
    }
    return 0;

  error:
    free(addr);
  error_alloc:
    return -1;
}

#endif /* SKIFCH_SHMLO_H */
