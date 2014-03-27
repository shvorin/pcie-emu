/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */

/* vim: set syntax=c et sw=4 ts=4: */

#ifndef SKIFCH_PLX_H
#define SKIFCH_PLX_H

#include <stdint.h>
#include "processid.h"
#include "skifch-misc.h"

#define __SKIFCH1_PLX_MIN_ORDER 12
#define __SKIFCH2_PLX_CTRL_ORDER 12
#define __SKIFCH2_PLX_DATA_MIN_ORDER 12

int SkifCh_PLX_Finalize (__attribute__((unused)) SkifCh_Union * ch, __attribute__((unused)) uint8_t aux[SKIFCH_AUX_SIZE]) {
    return 0;
}

int SkifCh1_GetOrder (size_t size, int * order) {
    if (*order == 0) {
        for (*order = __SKIFCH1_PLX_MIN_ORDER; SkifCh1_Size((*order) + 1) <= size && ((*order) + 1) < 32; (*order)++);
    }
    if (SkifCh1_Size(*order) <= size) {
        return 0;
    } else {
        return -1;
    }
}

int SkifCh2_GetOrder (size_t size, int * ctrl_order, int * data_order) {
    if (*ctrl_order == 0) {
        *ctrl_order = __SKIFCH2_PLX_CTRL_ORDER;
    }
    if (*data_order == 0) {
        for (*data_order = __SKIFCH2_PLX_DATA_MIN_ORDER; SkifCh2_Size(*ctrl_order, (*data_order) + 1) <= size && ((*data_order) + 1) < 32; (*data_order)++);
    }
    if (SkifCh2_Size(*ctrl_order, *data_order) <= size) {
        return 0;
    } else {
        return -1;
    }
}

#undef FCNAME
#define FCNAME "SkifCh_PLX_Init"
int SkifCh_PLX_Init (SkifCh * ch, SkifCh_Aux * skifch_aux, void * local_address, size_t local_size, void * remote_address, size_t remote_size) {
    SkifCh_Tag tag = SkifCh2f_tag;
    int order = 0, ctrl_order = 0, data_order = 0;
    size_t max_msg_size = -1;
    if (SkifCh_GetTagAndSize(&tag, &order, &ctrl_order, &data_order, &max_msg_size) < 0) {
        return -1;
    };
    int local_order = order, remote_order = order;
    if (tag == SkifCh1_tag && (SkifCh1_GetOrder(local_size, &local_order) == -1 || SkifCh1_GetOrder(remote_size, &remote_order) == -1)) {
        PROCESSID_ERROR_CREATE("Arguments 'local_size' or 'remote_size' have incorrect value", EINVAL);
        return -1;
    }
    int local_ctrl_order = ctrl_order, local_data_order = data_order;
    int remote_ctrl_order = ctrl_order, remote_data_order = data_order;
    if ((tag == SkifCh2_tag || tag == SkifCh2f_tag) && (SkifCh2_GetOrder(local_size, &local_ctrl_order, &local_data_order) == -1 || SkifCh2_GetOrder(remote_size, &remote_ctrl_order, &remote_data_order) == -1)) {
        PROCESSID_ERROR_CREATE("Arguments 'local_size' or 'remote_size' have incorrect value", EINVAL);
        return -1;
    }
    return SkifCh_Init2(ch, skifch_aux, SkifCh_PLX_Finalize, remote_address, local_address, tag, remote_order, local_order, remote_ctrl_order, remote_data_order, local_ctrl_order, local_data_order, max_msg_size);
}

#endif /* SKIFCH_PLX_H */
