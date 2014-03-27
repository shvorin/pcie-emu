/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */

/* vim: set syntax=c et sw=4 ts=4: */

#include <stdint.h>
#include <string.h>
#include "mmdev.h"
#include "phys.h"
#include "processid.h"
#include "skifch-misc.h"

void * mmdevr_memcpy (void * dst, const void * src, size_t n) {
  #if defined(__ICC) || defined(_INTEL_COMPILER)
    #warning "MEMPCY: Using for-loop for icc."
    int64_t * dst1 = (int64_t *) dst;
    const int64_t * src1 = (const int64_t *) src;
    int n1 = n/sizeof(int64_t);
    while (n1 > 0) {
        *dst1 = *src1;
        dst1++;
        src1++;
        n1--;
    }
    return dst;
  #else
    #warning "MEMPCY: Using memcpy for gcc."
    return memcpy(dst, src, n);
  #endif
}

void mmdevr_put64 (volatile void * ptr, uint64_t value) {
    *(volatile uint64_t *)ptr = value;
}

uint64_t mmdevr_get64 (volatile void * ptr) {
    return *(volatile uint64_t *)ptr;
}

int processid_rank = 0;
char * processid_hostname = NULL;
int processid_verbosity = 0; // 0 - error, 1 - warning, 2 - info, 3 - verbose

void ProcessId_Init (int rank) {
    processid_rank = rank;
    processid_hostname = PHYS_GetHostname();
    processid_verbosity = SkifCh_GetEnv("SKIFCH_VERBOSITY", PROCESSID_ERROR);
}

void ProcessId_Finalize () {
    free(processid_hostname);
}

Error_Description * processid_error = NULL;
