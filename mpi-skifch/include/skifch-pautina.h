/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */

/* vim: set syntax=c et sw=4 ts=4: */

#ifndef SKIFCH_PAUTINA_H
#define SKIFCH_PAUTINA_H

#include "pcidev.h"
#include "fpgaconf.h"
#include "processid.h"
#include "skifch-misc.h"

typedef struct {
    fpgaconf_t conf;
    int skifch_num;
    pcidev_mmap_t send;
    pcidev_mmap_t recv;
} __SkifCh_Pautina;

#define SENDBAR 2
#define RECVMEM 0

static int SkifCh2_Pautina_Log (size_t len) {
    int res = 0;
    size_t power = 1;
    for (res = 0, power = 1; power != len && power != 0; res++, power<<=1);
    return res;
}

#undef FCNAME
#define FCNAME "SkifCh2_Pautina_Init"
int SkifCh2_Pautina_Init (SkifCh2 * ch, uint8_t aux[SKIFCH_AUX_SIZE], uint8_t dev_num, int skifch_num, netaddr_t * netaddr) {
    if (sizeof(__SkifCh_Pautina) > SKIFCH_AUX_SIZE) {
        PROCESSID_ERROR_CREATE("Constant 'SKIFCH_AUX_SIZE' is too small", ENOMEM);
        goto error_conf;
    }

    fpgaconf_t * conf = &((__SkifCh_Pautina *) aux)->conf;
    int res = fpgaconf_init(conf, dev_num);
    if (res == -1) {
        PROCESSID_ERROR_CONVERT("fpgaconf_init", "FPGA configuration create failed");
        goto error_conf;
    }
    if (0 > skifch_num || skifch_num > conf->pautina.nSkifCh) {
        PROCESSID_ERROR_CONVERT("fpgaconf_init", "Invalid SkifCh number");
        goto error_send;
    }

    ((__SkifCh_Pautina *) aux)->skifch_num = skifch_num;
    update_register(conf->skifchs[skifch_num].state, 0); /* RESET */

    uint64_t down_desc = mmdev_get64(conf->skifchs[skifch_num].down_desc);
    uint64_t up_desc = mmdev_get64(conf->skifchs[skifch_num].up_desc);
    if (down_desc == -1 || up_desc == -1) {
        PROCESSID_ERROR_CONVERT("fpgaconf_init", "Invalid SkifCh configuration");
        goto error_send;
    }
    uint64_t down_addr;
    size_t down_len;
    cc_skifch_fromdesc(down_desc, &down_addr, &down_len);
    uint64_t up_addr;
    size_t up_len;
    cc_skifch_fromdesc(up_desc, &up_addr, &up_len);

    ssize_t bar_len = pcidev_length(dev_num, SENDBAR);
    if (bar_len == -1) {
        PROCESSID_ERROR_CONVERT("pcidev_length", "Devpautina initialization failed");
        goto error_send;
    }
    void * send = pcidev_mmap(&((__SkifCh_Pautina *) aux)->send, dev_num, SENDBAR, down_addr, down_len);
    if (send == MAP_FAILED) {
        PROCESSID_ERROR_CONVERT("pcidev_mmap", "Devpautina initialization failed");
        goto error_send;
    }

    ssize_t mem_len = pcidev_length(PAUTINA_DRIVER_DEV_MEM, RECVMEM);
    if (mem_len == -1) {
        PROCESSID_ERROR_CONVERT("pcidev_length", "Devpautina initialization failed");
        goto error_recv;
    }
    void * recv = pcidev_mmap(&((__SkifCh_Pautina *) aux)->recv, PAUTINA_DRIVER_DEV_MEM, RECVMEM, up_addr & (mem_len-1), up_len);
    if (recv == MAP_FAILED) {
        PROCESSID_ERROR_CONVERT("pcidev_mmap", "Devpautina initialization failed");
        goto error_recv;
    }

    res = SkifCh2_InitInternal(ch,
            ((uint8_t *) send)             , SkifCh2_Pautina_Log(down_len/4),
            ((uint8_t *) send) + down_len/2, SkifCh2_Pautina_Log(down_len/2),
            (uint64_t *)(((uint8_t *) recv) + up_len/4), 1024 /*FIXME*/,
            ((uint8_t *) recv)             , SkifCh2_Pautina_Log(  up_len/4),
            ((uint8_t *) recv) +   up_len/2, SkifCh2_Pautina_Log(  up_len/2),
            (uint64_t *)(((uint8_t *) send) + down_len/4),
            FALSE);
    if (res == -1) {
        goto error;
    }

    update_register(conf->skifchs[skifch_num].state, 1); /* RESET */

    *netaddr = skifch_num; //FIXME
    return 0;

  error:
    pcidev_munmap(&((__SkifCh_Pautina *) aux)->recv);
  error_recv:
    pcidev_munmap(&((__SkifCh_Pautina *) aux)->send);
  error_send:
    fpgaconf_finalize(&((__SkifCh_Pautina *) aux)->conf);
  error_conf:
    return -1;
}

// =====================================================================================================================

int SkifCh_Pautina_Finalize (__attribute__((unused)) SkifCh_Union * ch, uint8_t aux[SKIFCH_AUX_SIZE]) {
    update_register(((__SkifCh_Pautina *) aux)->conf.skifchs[((__SkifCh_Pautina *) aux)->skifch_num].state, 0); /* RESET */
    pcidev_munmap(&((__SkifCh_Pautina *) aux)->recv);
    pcidev_munmap(&((__SkifCh_Pautina *) aux)->send);
    fpgaconf_finalize(&((__SkifCh_Pautina *) aux)->conf);
    return 0;
}

#undef FCNAME
#define FCNAME "SkifCh_Pautina_Init"
int SkifCh_Pautina_Init (SkifCh * skifch, SkifCh_Aux * skifch_aux, uint8_t dev_num, int skifch_num, netaddr_t * netaddr) {
    skifch->tag = SkifCh2_tag;
    skifch_aux->finalize = SkifCh_Pautina_Finalize;
    return SkifCh2_Pautina_Init(&skifch->ch.ch2, skifch_aux->aux, dev_num, skifch_num, netaddr);
}

#endif /* SKIFCH_PAUTINA_H */

/* Local Variables: */
/* c-basic-offset:4 */
/* End: */
