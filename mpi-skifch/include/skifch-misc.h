/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */

/* vim: set syntax=c et sw=4 ts=4: */

#ifndef SKIFCH_IMPL_H
#define SKIFCH_IMPL_H

#include <stdlib.h>
#include "pcidev.h"
#include "processid.h"
#include "skifch.h"
#include "skifch-t.h"
#include "skifch1.h"
#include "skifch2.h"
#include "skifch2shm.h"

#define SKIFCH_AUX_SIZE 256

typedef int (*SkifCh_Finalize_fn) (SkifCh_Union * ch, uint8_t aux[SKIFCH_AUX_SIZE]);

typedef struct {
    SkifCh_Finalize_fn finalize;
    uint8_t aux[SKIFCH_AUX_SIZE];
} SkifCh_Aux;

static __attribute__((unused)) int SkifCh_Finalize (SkifCh * skifch, SkifCh_Aux * skifch_aux) {
    return skifch_aux->finalize(&skifch->ch, skifch_aux->aux);
}

static __attribute__((unused)) long SkifCh_GetEnv (const char * key, long value) {
    char * val = getenv(key);
    if (val != NULL) {
        return strtol(val, NULL, 0);
    }
    return value;
}

#undef FCNAME
#define FCNAME "SkifCh_GetTagAndSize"
static __attribute__((unused)) ssize_t SkifCh_GetTagAndSize (SkifCh_Tag * tag, int * order, int * ctrl_order, int * data_order, size_t * max_msg_size) {
    *order = SkifCh_GetEnv("SKIFCH1_ORDER", *order);
    *ctrl_order = SkifCh_GetEnv("SKIFCH2_CTRL_ORDER", *ctrl_order);
    *data_order = SkifCh_GetEnv("SKIFCH2_DATA_ORDER", *data_order);
    *max_msg_size = SkifCh_GetEnv("SKIFCH_MAX_MESSAGE_SIZE", *max_msg_size);
    int type = SkifCh_GetEnv("SKIFCH_TYPE", 0);
    switch (type) {
        case 0:
            if (getenv("SKIFCH2_CTRL_ORDER") != NULL || getenv("SKIFCH2_DATA_ORDER") != NULL) {
                *tag = SkifCh2_tag;
            } else if (getenv("SKIFCH1_ORDER") != NULL) {
                *tag = SkifCh1_tag;
            }
            break;
        case 1: *tag = SkifCh1_tag; break;
        case 2: *tag = SkifCh2_tag; break;
        case 3: *tag = SkifCh2f_tag; break;
        default: PROCESSID_ERROR_CREATE("Environment variable 'SKIFCH_TYPE' has invalid value", EINVAL); return -1;
    }
    switch (*tag) {
        case SkifCh1_tag:
            return pcidev_page_align_up(SkifCh1_Size(*order));
        case SkifCh2_tag:
        case SkifCh2f_tag:
            return pcidev_page_align_up(SkifCh2_Size(*ctrl_order, *data_order));
        default: PROCESSID_ERROR_CREATE("Variable 'tag' has invalid value", EINVAL); return -1;
    }
}

#undef FCNAME
#define FCNAME "SkifCh_Init2"
static __attribute__((unused)) int SkifCh_Init2 (SkifCh * skifch, SkifCh_Aux * skifch_aux, SkifCh_Finalize_fn SkifCh_Finalize, void * send, void * recv, SkifCh_Tag tag, int send_order, int recv_order, int send_ctrl_order, int send_data_order, int recv_ctrl_order, int recv_data_order, size_t max_msg_size) {
    switch (tag) {
        case SkifCh1_tag:
            PROCESSID_DBG_PRINT(PROCESSID_INFO, "Using SkifCh1"); break;
        case SkifCh2_tag:
            PROCESSID_DBG_PRINT(PROCESSID_INFO, "Using SkifCh2"); break;
        case SkifCh2f_tag:
            PROCESSID_DBG_PRINT(PROCESSID_INFO, "Using SkifCh2f"); break;
        case SkifCh2Shm_tag:
            PROCESSID_DBG_PRINT(PROCESSID_INFO, "Using SkifCh2Shm"); break;
    }
    skifch->tag = tag;
    skifch_aux->finalize = SkifCh_Finalize;
    switch (tag) {
        case SkifCh1_tag:
            return SkifCh1_Init(&skifch->ch.ch1, send, send_order, max_msg_size, recv, recv_order);
        case SkifCh2_tag:
            return SkifCh2_Init(&skifch->ch.ch2, send, send_ctrl_order, send_data_order, max_msg_size, recv, recv_ctrl_order, recv_data_order, FALSE);
        case SkifCh2f_tag:
            return SkifCh2_Init(&skifch->ch.ch2, send, send_ctrl_order, send_data_order, max_msg_size, recv, recv_ctrl_order, recv_data_order, TRUE);
        case SkifCh2Shm_tag:
            return SkifCh2Shm_Init(&skifch->ch.ch2shm, send, recv);
        default: PROCESSID_ERROR_CREATE("Argument 'tag' has invalid value", EINVAL); return -1;
    }
}

static __attribute__((unused)) int SkifCh_Init (SkifCh * skifch, SkifCh_Aux * skifch_aux, SkifCh_Finalize_fn SkifCh_Finalize, void * send, void * recv, SkifCh_Tag tag, int order, int ctrl_order, int data_order, size_t max_msg_size) {
    return SkifCh_Init2(skifch, skifch_aux, SkifCh_Finalize, send, recv, tag, order, order, ctrl_order, data_order, ctrl_order, data_order, max_msg_size);
}

#endif /* SKIFCH_IMPL_H */
