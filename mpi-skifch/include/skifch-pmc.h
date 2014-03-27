/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */

/* vim: set syntax=c et sw=4 ts=4: */

#ifndef SKIFCH_PMC_H
#define SKIFCH_PMC_H

#include <stdint.h>
#include "devpautina.h"
#include "phys.h"
#include "processid.h"
#include "skifch-misc.h"

#define __SKIFCH1_PMC_ORDER 14
#define __SKIFCH2_PMC_CTRL_ORDER 12
#define __SKIFCH2_PMC_DATA_ORDER 13

typedef struct {
    DEVPAUTINA ctrl;
    DEVPAUTINA send;
    DEVPAUTINA recv;
} __SkifCh_PMC;

int SkifCh_PMC_Finalize (__attribute__((unused)) SkifCh_Union * ch, uint8_t aux[SKIFCH_AUX_SIZE]) {
    DEVPAUTINA_Finalise(&((__SkifCh_PMC *) aux)->recv);
    DEVPAUTINA_Finalise(&((__SkifCh_PMC *) aux)->send);
    DEVPAUTINA_Finalise(&((__SkifCh_PMC *) aux)->ctrl);
    return 0;
}

#undef FCNAME
#define FCNAME "SkifCh_PMC_Init"
int SkifCh_PMC_Init (SkifCh * skifch, SkifCh_Aux * skifch_aux, int send_phy, int send_port, int send_number, int recv_phy, int recv_port, int recv_number) {
    if (sizeof(__SkifCh_PMC) > SKIFCH_AUX_SIZE) {
        PROCESSID_ERROR_CREATE("Constant 'SKIFCH_AUX_SIZE' is too small", ENOMEM);
        goto error_ctrl;
    }
    SkifCh_Tag tag = SkifCh2f_tag;
    int order = __SKIFCH1_PMC_ORDER, ctrl_order = __SKIFCH2_PMC_CTRL_ORDER, data_order = __SKIFCH2_PMC_DATA_ORDER;
    size_t max_msg_size = -1;
    ssize_t size = SkifCh_GetTagAndSize(&tag, &order, &ctrl_order, &data_order, &max_msg_size);
    if (size < 0) {
        goto error_ctrl;
    }
    void * ctrl = DEVPAUTINA_BAR_Entire_Init(&((__SkifCh_PMC *) skifch_aux->aux)->ctrl, 3, 3, 0);
    if (ctrl == DEVPAUTINA_FAILED) {
        PROCESSID_ERROR_CONVERT("DEVPAUTINA_BAR_Entire_Init", "Devpautina initialization failed");
        goto error_ctrl;
    }
    void * send = DEVPAUTINA_BAR_Entire_Init(&((__SkifCh_PMC *) skifch_aux->aux)->send, 3, 0, 0);
    if (send == DEVPAUTINA_FAILED) {
        PROCESSID_ERROR_CONVERT("DEVPAUTINA_BAR_Entire_Init", "Devpautina initialization failed");
        goto error_send;
    }
    void * recv = DEVPAUTINA_MEM_Entire_Init(&((__SkifCh_PMC *) skifch_aux->aux)->recv, 0, 0);
    if (recv == DEVPAUTINA_FAILED) {
        PROCESSID_ERROR_CONVERT("DEVPAUTINA_MEM_Entire_Init", "Devpautina initialization failed");
        goto error_recv;
    }
    int64_t res = PHYS_SetPort(ctrl, send_phy, send_port);
    if (res != 0) {
        char * errmsg = malloc(64);
        snprintf(errmsg, 64, "Unable to set phy %d to port %d (res: 0x%lX)!", send_phy, send_port, res);
        PROCESSID_ERROR_CONVERT("PHYS_SetPort", errmsg);
        goto error;
    }
    res = PHYS_SetPort(ctrl, recv_phy, recv_port);
    if (res != 0) {
        char * errmsg = malloc(64);
        snprintf(errmsg, 64, "Unable to set phy %d to port %d (res: 0x%lX)!", recv_phy, recv_port, res);
        PROCESSID_ERROR_CONVERT("PHYS_SetPort", errmsg);
        goto error;
    }
    send = ((uint8_t *) PHYS_Get_Address(send, send_phy)) + send_number*size;
    recv = ((uint8_t *) PHYS_Get_Address(recv, recv_phy)) + recv_number*size;
    int res2 = SkifCh_Init(skifch, skifch_aux, SkifCh_PMC_Finalize, send, recv, tag, order, ctrl_order, data_order, max_msg_size);
    if (res2 == -1) {
        goto error;
    }
    return 0;

  error:
    DEVPAUTINA_Finalise(&((__SkifCh_PMC *) skifch_aux->aux)->recv);
  error_recv:
    DEVPAUTINA_Finalise(&((__SkifCh_PMC *) skifch_aux->aux)->send);
  error_send:
    DEVPAUTINA_Finalise(&((__SkifCh_PMC *) skifch_aux->aux)->ctrl);
  error_ctrl:
    return -1;
}

#undef __SKIFCH1_PMC_ORDER
#undef __SKIFCH2_PMC_CTRL_ORDER
#undef __SKIFCH2_PMC_DATA_ORDER

#endif /* SKIFCH_PMC_H */
