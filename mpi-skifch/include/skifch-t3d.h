/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */

/* vim: set syntax=c et sw=4 ts=4: */

#ifndef SKIFCH_T3D_H
#define SKIFCH_T3D_H

#include <stdint.h>
#include "addrspace.h"
#include "devpautina.h"
#include "mk_configuration.h"
#include "msg-header.h"
#include "processid.h"
#include "skifch-misc.h"

#define FALSE 0
#define TRUE 1

typedef struct {
    DEVPAUTINA send;
    DEVPAUTINA recv;
} __SkifCh_T3D;

typedef int Barrier_fn (void);

// ======================================================== MSG ========================================================

#define __SKIFCH1_MSG_SEND_ORDER 13
#define __SKIFCH1_MSG_RECV_ORDER 20
#define __SKIFCH1_MSG_MAX_PKTLEN 1024

const size_t __SkifCh1_Msg_ports_perNode = 2;
const size_t __SkifCh1_Msg_xSize = 3;
const size_t __SkifCh1_Msg_ySize = 2;
const size_t __SkifCh1_Msg_zSize = 1;
const unsigned __SkifCh1_Msg_zMask = 15;
const unsigned __SkifCh1_Msg_yMask = 15 << 4;
const unsigned __SkifCh1_Msg_xMask = 15 << 8;

unsigned __SkifCh1_Msg_deserial(size_t n) {
    size_t n1 = n / __SkifCh1_Msg_xSize;
    size_t n2 = n1 / __SkifCh1_Msg_ySize;
    unsigned result = 0;
    result += n % __SkifCh1_Msg_xSize; result <<= 4;
    result += n1 % __SkifCh1_Msg_ySize; result <<= 4;
    result += n2;
    return result;
}

#undef FCNAME
#define FCNAME "SkifCh1_Msg_Init"
int SkifCh1_Msg_Init (SkifCh1 * ch, uint8_t aux[SKIFCH_AUX_SIZE], netaddr_t * netaddr) {
    if (sizeof(__SkifCh_T3D) > SKIFCH_AUX_SIZE) {
        PROCESSID_ERROR_CREATE("Constant 'SKIFCH_AUX_SIZE' is too small", ENOMEM);
        goto error_send;
    }
    if (*netaddr > 15) {
        PROCESSID_ERROR_CREATE("Too many processes", EINVAL);
        goto error_send;
    }
    uint8_t * send = (uint8_t *) DEVPAUTINA_BAR_Entire_Init(&((__SkifCh_T3D *) aux)->send, 5, 0, 0);
    if (send == DEVPAUTINA_FAILED) {
        PROCESSID_ERROR_CONVERT("DEVPAUTINA_BAR_Entire_Init", "Devpautina initialization failed");
        goto error_send;
    }
    uint8_t * recv = (uint8_t *) DEVPAUTINA_MEM_Entire_Init(&((__SkifCh_T3D *) aux)->recv,    0, 0);
    if (recv == DEVPAUTINA_FAILED) {
        PROCESSID_ERROR_CONVERT("DEVPAUTINA_MEM_Entire_Init", "Devpautina initialization failed");
        goto error_recv;
    }
    __attribute__((unused)) uint64_t reset = *(volatile uint64_t *) send;
    int res = SkifCh1_InitInternal(ch, send + ((*netaddr)<<__SKIFCH1_MSG_SEND_ORDER), __SKIFCH1_MSG_SEND_ORDER, (uint32_t *) (recv + (16<<__SKIFCH1_MSG_RECV_ORDER) + (1<<7) + ((*netaddr)<<3)), (uint32_t *) (send + (16<<__SKIFCH1_MSG_SEND_ORDER) + ((*netaddr)<<3)), __SKIFCH1_MSG_MAX_PKTLEN,
                                       recv + ((*netaddr)<<__SKIFCH1_MSG_RECV_ORDER), __SKIFCH1_MSG_RECV_ORDER, (uint32_t *) (send + (16<<__SKIFCH1_MSG_SEND_ORDER) + (1<<7) + ((*netaddr)<<3)), (uint32_t *) (recv + (16<<__SKIFCH1_MSG_RECV_ORDER) + ((*netaddr)<<3)));
    if (res == -1) {
        goto error;
    }
    MsgId msgid;
    msgid.addr.port = (*netaddr)%__SkifCh1_Msg_ports_perNode;
    msgid.addr.node = __SkifCh1_Msg_deserial((*netaddr)/__SkifCh1_Msg_ports_perNode);
    *netaddr = msgid.id;
    return 0;

  error:
    DEVPAUTINA_Finalise(&((__SkifCh_T3D *) aux)->recv);
  error_recv:
    DEVPAUTINA_Finalise(&((__SkifCh_T3D *) aux)->send);
  error_send:
    return -1;
}

#undef __SKIFCH1_MSG_SEND_ORDER
#undef __SKIFCH1_MSG_RECV_ORDER
#undef __SKIFCH1_MSG_MAX_PKTLEN

// ======================================================== T3D ========================================================

int __t3d_fpga_configuration_enable = FALSE;
FPGA_Configuration __t3d_fpga_configuration;

#undef FCNAME
#define FCNAME "SkifCh2_T3D_Init"
int SkifCh2_T3D_Init (SkifCh2 * ch, uint8_t aux[SKIFCH_AUX_SIZE], triple_t size, triple_t xyz, int p, int ports[PHY_COUNT], Barrier_fn barrier_fn, netaddr_t * netaddr) {
    if (sizeof(__SkifCh_T3D) > SKIFCH_AUX_SIZE) {
        PROCESSID_ERROR_CREATE("Constant 'SKIFCH_AUX_SIZE' is too small", ENOMEM);
        goto error_send;
    }
    void * send = DEVPAUTINA_BAR_Entire_Init(&((__SkifCh_T3D *) aux)->send, 3, 0, 0);
    if (send == DEVPAUTINA_FAILED) {
        PROCESSID_ERROR_CONVERT("DEVPAUTINA_BAR_Entire_Init", "Devpautina initialization failed");
        goto error_send;
    }
    void * recv = DEVPAUTINA_MEM_Entire_Init(&((__SkifCh_T3D *) aux)->recv,    0, 0);
    if (recv == DEVPAUTINA_FAILED) {
        PROCESSID_ERROR_CONVERT("DEVPAUTINA_MEM_Entire_Init", "Devpautina initialization failed");
        goto error_recv;
    }
    DEVPAUTINA devpautina_fpga_conf;
    void * fpga_conf = DEVPAUTINA_BAR_Entire_Init(&devpautina_fpga_conf, 3, 2, 0);
    if (fpga_conf == DEVPAUTINA_FAILED) {
        PROCESSID_ERROR_CONVERT("DEVPAUTINA_BAR_Entire_Init", "Devpautina initialization failed");
        goto error_fpga_conf;
    }
    DEVPAUTINA devpautina_phy_conf;
    void * phy_conf = DEVPAUTINA_BAR_Entire_Init(&devpautina_phy_conf, 3, 3, 0);
    if (phy_conf == DEVPAUTINA_FAILED) {
        PROCESSID_ERROR_CONVERT("DEVPAUTINA_BAR_Entire_Init", "Devpautina initialization failed");
        goto error_phy_conf;
    }
    SkifCh_Tag tag = SkifCh1_tag;
    int order = 0, ctrl_order = 0, data_order = 0;
    size_t max_msg_size = -1;
    SkifCh_GetTagAndSize(&tag, &order, &ctrl_order, &data_order, &max_msg_size);
    if(FPGA_Configuration_create(&__t3d_fpga_configuration, fpga_conf) < 0) {
        PROCESSID_ERROR_CONVERT("FPGA_Configuration_create", "FPGA initialization failed");
        goto error;
    }
    __t3d_fpga_configuration_enable = TRUE;
    if (p == 0) {
        if(FPGA_Configuration_setup(&__t3d_fpga_configuration, size, xyz) < 0) {
            PROCESSID_ERROR_CONVERT("FPGA_Configuration_setup", "FPGA initialization failed");
        }
        if (PROCESSID_INFO <= processid_verbosity) {
            FPGA_Configuration_show(&__t3d_fpga_configuration);
        }
        int phy;
        for (phy = 0; phy < PHY_COUNT; phy++) {
            if (ports[phy] != -1) {
                PROCESSID_DBG_PRINT(PROCESSID_INFO, "Setting phy %d to port %d", phy, ports[phy]);
                uint64_t res = PHYS_SetPort(phy_conf, phy, ports[phy]);
                if (res != 0) {
                    char * errmsg = malloc(64);
                    snprintf(errmsg, 64, "Unable to set phy %d to port %d (res: 0x%lX)!", phy, ports[phy], res);
                    PROCESSID_ERROR_CONVERT("PHYS_SetPort", errmsg);
                    goto error;
                }
            }
        }
        FPGA_Configuration_reset(&__t3d_fpga_configuration);
    }
    barrier_fn();
    if (max_msg_size > __t3d_fpga_configuration.max_pkt_nBytes) {
        max_msg_size = __t3d_fpga_configuration.max_pkt_nBytes;
    }
    int res = SkifCh2_InitInternal(ch,
            ((uint8_t *) send) + fpga_head_fifo(&__t3d_fpga_configuration, p), __t3d_fpga_configuration.down_hard.head_logcapacity,
            ((uint8_t *) send) + fpga_body_fifo(&__t3d_fpga_configuration, p), __t3d_fpga_configuration.down_hard.body_logcapacity,
            (uint64_t *)(((uint8_t *) recv) + fpga_rx(&__t3d_fpga_configuration, p)), max_msg_size,
            ((uint8_t *) recv) + dram_head_fifo(&__t3d_fpga_configuration, p), __t3d_fpga_configuration.up_hard.head_logcapacity,
            ((uint8_t *) recv) + dram_body_fifo(&__t3d_fpga_configuration, p), __t3d_fpga_configuration.up_hard.body_logcapacity,
            (uint64_t *)(((uint8_t *) send) + dram_rx(&__t3d_fpga_configuration, p)),
            FALSE);
    if (res == -1) {
        goto error;
    }
    *netaddr = mk_netaddr(&__t3d_fpga_configuration, p);
    //barrier_fn();
    //usleep(1000);
    //barrier_fn();
    //if (p == 0) {
    //    PHYS_OpenPorts(phy_conf);
    //    PROCESSID_DBG_PRINT(PROCESSID_INFO, "PHYS_OpenPorts done.");
    //}
    //barrier_fn();
    //usleep(1000);
    //barrier_fn();
    PROCESSID_DBG_PRINT(PROCESSID_INFO, "Size %dx%dx%d, coor %dx%dx%dx%d, netaddr %X", size.x, size.y, size.z, xyz.x, xyz.y, xyz.z, p, *netaddr);
    DEVPAUTINA_Finalise(&devpautina_phy_conf);
    //DEVPAUTINA_Finalise(&devpautina_fpga_conf);
    return 0;

  error:
    DEVPAUTINA_Finalise(&devpautina_phy_conf);
  error_phy_conf:
    DEVPAUTINA_Finalise(&devpautina_fpga_conf);
  error_fpga_conf:
    DEVPAUTINA_Finalise(&((__SkifCh_T3D *) aux)->recv);
  error_recv:
    DEVPAUTINA_Finalise(&((__SkifCh_T3D *) aux)->send);
  error_send:
    return -1;
}

int SkifCh2_T3D_Check () {
    if (__t3d_fpga_configuration_enable) {
        FPGA_Configuration_dbg_ilink(&__t3d_fpga_configuration);
        FPGA_Configuration_dbg_buffers(&__t3d_fpga_configuration, PROCESSID_WARNING);
    }
    return 0;
}

// =====================================================================================================================

int SkifCh_T3D_Finalize (__attribute__((unused)) SkifCh_Union * ch, uint8_t aux[SKIFCH_AUX_SIZE]) {
    DEVPAUTINA_Finalise(&((__SkifCh_T3D *) aux)->recv);
    DEVPAUTINA_Finalise(&((__SkifCh_T3D *) aux)->send);
    return 0;
}

#undef FCNAME
#define FCNAME "SkifCh_T3D_Init"
int SkifCh_T3D_Init (SkifCh * skifch, SkifCh_Aux * skifch_aux, triple_t size, triple_t xyz, int p, int ports[PHY_COUNT], Barrier_fn barrier_fn, netaddr_t * netaddr) {
    SkifCh_Tag tag = SkifCh2_tag;
    int order, ctrl_order, data_order;
    size_t max_msg_size;
    SkifCh_GetTagAndSize(&tag, &order, &ctrl_order, &data_order, &max_msg_size);
    skifch->tag = tag;
    skifch_aux->finalize = SkifCh_T3D_Finalize;
    switch (tag) {
        case SkifCh1_tag: return SkifCh1_Msg_Init(&skifch->ch.ch1, skifch_aux->aux, netaddr);
        case SkifCh2_tag: return SkifCh2_T3D_Init(&skifch->ch.ch2, skifch_aux->aux, size, xyz, p, ports, barrier_fn, netaddr);
        default: PROCESSID_ERROR_CREATE("Variable 'tag' has invalid value", EINVAL); return -1;
    }
}

#endif /* SKIFCH_T3D_H */

/* Local Variables: */
/* c-basic-offset:4 */
/* End: */
