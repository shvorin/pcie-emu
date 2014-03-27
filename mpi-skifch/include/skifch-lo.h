/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */

/* vim: set syntax=c et sw=4 ts=4: */

#ifndef SKIFCH_LO_H
#define SKIFCH_LO_H

#include <stdint.h>
#include "devpautina.h"
#include "processid.h"
#include "skifch-misc.h"

#define __SKIFCH1_LO_ORDER 14
#define __SKIFCH2_LO_CTRL_ORDER 12
#define __SKIFCH2_LO_DATA_ORDER 13

typedef struct {
    DEVPAUTINA send;
    DEVPAUTINA recv;
} __SkifCh_Lo;

int SkifCh_Lo_Finalize (__attribute__((unused)) SkifCh_Union * ch, uint8_t aux[SKIFCH_AUX_SIZE]) {
    DEVPAUTINA_Finalise(&((__SkifCh_Lo *) aux)->recv);
    DEVPAUTINA_Finalise(&((__SkifCh_Lo *) aux)->send);
    return 0;
}

#undef FCNAME
#define FCNAME "SkifCh_Lo_Init"
int SkifCh_Lo_Init (SkifCh * skifch, SkifCh_Aux * skifch_aux, int * rank) {
    if (sizeof(__SkifCh_Lo) > SKIFCH_AUX_SIZE) {
        PROCESSID_ERROR_CREATE("Constant 'SKIFCH_AUX_SIZE' is too small", ENOMEM);
        goto error_send;
    }
    if (*rank != 0 && *rank != 1) {
        PROCESSID_ERROR_CREATE("Too many processes", EINVAL);
        goto error_send;
    }
    SkifCh_Tag tag = SkifCh2f_tag;
    int order = __SKIFCH1_LO_ORDER, ctrl_order = __SKIFCH2_LO_CTRL_ORDER, data_order = __SKIFCH2_LO_DATA_ORDER;
    size_t max_msg_size = -1;
    ssize_t size = SkifCh_GetTagAndSize(&tag, &order, &ctrl_order, &data_order, &max_msg_size);
    if (size < 0) {
        goto error_send;
    }
    int dev = SkifCh_GetEnv("SKIFCH_DEV", SKIF_DRIVER_DEV_MEM);
    void * send = DEVPAUTINA_BAR_Init(&((__SkifCh_Lo *) skifch_aux->aux)->send, dev, 0, *rank == 0 ? 0 : size, size);
    if (send == DEVPAUTINA_FAILED) {
        PROCESSID_ERROR_CONVERT("DEVPAUTINA_BAR_Init", "Devpautina initialization failed");
        goto error_send;
    }
    void * recv = DEVPAUTINA_MEM_Init(&((__SkifCh_Lo *) skifch_aux->aux)->recv,      0, *rank == 0 ? size : 0, size);
    if (recv == DEVPAUTINA_FAILED) {
        PROCESSID_ERROR_CONVERT("DEVPAUTINA_MEM_Init", "Devpautina initialization failed");
        goto error_recv;
    }
    int res = SkifCh_Init(skifch, skifch_aux, SkifCh_Lo_Finalize, send, recv, tag, order, ctrl_order, data_order, max_msg_size);
    if (res == -1) {
        goto error;
    }
    return 0;

  error:
    DEVPAUTINA_Finalise(&((__SkifCh_Lo *) skifch_aux->aux)->recv);
  error_recv:
    DEVPAUTINA_Finalise(&((__SkifCh_Lo *) skifch_aux->aux)->send);
  error_send:
    return -1;
}

#undef __SKIFCH1_LO_ORDER
#undef __SKIFCH2_LO_CTRL_ORDER
#undef __SKIFCH2_LO_DATA_ORDER

#endif /* SKIFCH_LO_H */
