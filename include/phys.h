/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */

/* vim: set syntax=c et sw=4 ts=4: */

#ifndef PHYS_H
#define PHYS_H

#include <stdint.h>
#include <stdio.h>
#include "devskif.h"

#define SLOT_COUNT 16
#define PHY_COUNT 6
#define PORT_COUNT 2

/*
 *  0        -- primary port
 *  1        -- redundant port
 *  negative -- error
 *    -1    -- no answer from PCIe
 *    other -- invalid state
 */
static int64_t PHYS_Get_Port (void * base_addr, int phy_num) {
    int64_t reg0 = *(volatile uint64_t *)(base_addr + ((phy_num + 1) << 20 | 0xd0a00));
    if (reg0 == -1)
        return -1;
    reg0 &= 0xffff;
    int64_t reg1 = *(volatile uint64_t *)(base_addr + ((phy_num + 1) << 20 | 0xd0a10));
    if (reg1 == -1)
        return -1;
    reg1 &= 0xffff;
    if ((reg0 == 0x0100) && (reg1 == 0x0302))
        return 0;
    if ((reg0 == 0x0504) && (reg1 == 0x0706))
        return 1;
    return (1ULL << 63) | (reg1 << 16) | reg0;
}

/*
 *  0        -- OK
 *  negative -- error
 *    -1    -- no answer from PCIe
 *    other -- invalid state
 */
static int64_t PHYS_Set_Port (void * base_addr, int phy_num, int port) {
    uint64_t reg0 = 0x0100;
    uint64_t reg1 = 0x0302;
    if (port) {
        reg0 = 0x0504;
        reg1 = 0x0706;
    }
    *(volatile uint64_t *)(base_addr + ((phy_num + 1) << 20 | 0xd0810)) = 0x000f;
    usleep(100);
    *(volatile uint64_t *)(base_addr + ((phy_num + 1) << 20 | 0xd0900)) = reg0;
    usleep(100);
    *(volatile uint64_t *)(base_addr + ((phy_num + 1) << 20 | 0xd0910)) = reg1;
    usleep(100);
    *(volatile uint64_t *)(base_addr + ((phy_num + 1) << 20 | 0xd0800)) = 0x0002;
    usleep(100);
    *(volatile uint64_t *)(base_addr + ((phy_num + 1) << 20 | 0xd0800)) = 0x0000;
    usleep(100);
    *(volatile uint64_t *)(base_addr + ((phy_num + 1) << 20 | 0xd0040)) = port ? 0x0000 : 0xf0ff;
    usleep(100);
    *(volatile uint64_t *)(base_addr + ((phy_num + 1) << 20 | 0xd0050)) = port ? 0xf0ff : 0x0000;
    usleep(100);
    *(volatile uint64_t *)(base_addr + ((phy_num + 1) << 20 | 0xd0030)) = port ? 0x000f : 0x00f0;
    usleep(100);
    int64_t res = PHYS_Get_Port(base_addr, phy_num);
    if (res == port) {
        return 0;
    } else if (res < 0) {
        return res;
    } else {
        return (1ULL << 63) | (1ULL<<32) | res;
    }
}

/*
 *  0        -- OK, link is up
 *  negative -- error
 *    -1    -- no answer from PCIe
 *    other -- invalid state
 */
static int64_t PHYS_Get_Status (void * base_addr, int phy_num) {
    int64_t status;
    int64_t port = PHYS_Get_Port(base_addr, phy_num);
    if (port < 0) {
        return port;
    }
    if (port) {
        status = *(volatile uint64_t *)(base_addr + ((phy_num + 1) << 20 | 0xc0080));
        status = *(volatile uint64_t *)(base_addr + ((phy_num + 1) << 20 | 0xc0080));
    } else {
        status = *(volatile uint64_t *)(base_addr + ((phy_num + 1) << 20 | 0x00080));
        status = *(volatile uint64_t *)(base_addr + ((phy_num + 1) << 20 | 0x00080));
    }
    if ((status & 0xffff) == 0x8000) {
        return 0;
    } else if (status == -1) {
        return -1;
    } else {
        return (1ULL<<63) | (status & 0xffff);
    }
}

static off_t PHYS_Get_Offset (int phy_num) {
    return phy_num * 0x1000000;
}

static void * PHYS_Get_Address (void * base_addr, int phy_num) {
    return base_addr + PHYS_Get_Offset(phy_num);
}

static int64_t PHYS_Get_Slot (void * base_addr) {
    int64_t reg = *(volatile uint64_t *)(base_addr + (1 << 20 | 0x00080));
    if (reg == -1)
        return -1;
    return reg >> 48;
}

static int PHYS_GetSlot () {
    DEVSKIF devskif;
    void * addr = DEVSKIF_BAR_Entire_Init(&devskif, 3, 3, 0);
    if (addr == DEVSKIF_FAILED)
        return -1;
    int64_t res = PHYS_Get_Slot(addr);
    DEVSKIF_Finalise(&devskif);
    return res;
}

typedef struct {
    int16_t * phys;
} PHYS;

#define __PHYS_INT16(slot,phy,port) (((slot&0xF)<<8)|((phy&0xF)<<4)|(port&0xF))
#define __PHYS_SLOT(i) ((i>>8)&0xF)
#define __PHYS_PHY(i)  ((i>>4)&0xF)
#define __PHYS_PORT(i)  (i&0xF)

static void PHYS_Init (PHYS * phys) {
    phys->phys = (int16_t *)malloc(sizeof(int16_t) * 4096);
    memset(phys->phys, 0xFF, sizeof(int16_t) * 4096);
}

static void PHYS_Finalise (PHYS * phys) {
    free(phys->phys);
}

static void PHYS_Set (PHYS * phys, int from_slot, int from_phy, int from_count, int to_slot, int to_phy, int to_count) {
    phys->phys[__PHYS_INT16(from_slot,from_phy,from_count)] = __PHYS_INT16(to_slot,to_phy,to_count); 
}

static void PHYS_Write (PHYS * phys, char * filename) {
    FILE * file = fopen(filename, "w");
    int from_slot, from_phy, from_port;
    for (from_slot = 0; from_slot < SLOT_COUNT; from_slot++) {
        for (from_phy = 0; from_phy < PHY_COUNT; from_phy++) {
            for (from_port = 0; from_port < PORT_COUNT; from_port++) {
                int16_t from = __PHYS_INT16(from_slot, from_phy, from_port);
                int16_t to = phys->phys[from];
                if (to != -1) {
                    fprintf(file, "%03X %03X\n", from, to);
                }
            }
        }
    }
    fclose(file);
}

static void PHYS_Print (PHYS * phys) {
    int from_slot, from_phy, from_port;
    for (from_slot = 0; from_slot < SLOT_COUNT; from_slot++) {
        for (from_phy = 0; from_phy < PHY_COUNT; from_phy++) {
            for (from_port = 0; from_port < PORT_COUNT; from_port++) {
                int16_t from = __PHYS_INT16(from_slot, from_phy, from_port);
                int16_t to = phys->phys[from];
                if (to != -1) {
                    printf("%03X %03X\n", from, to);
                }
            }
        }
    }
}

static void PHYS_InitRead (PHYS * phys, char * filename) {
    phys->phys = (int16_t *)malloc(sizeof(int16_t) * 4096);
    memset(phys->phys, 0xFF, sizeof(int16_t) * 4096);
    FILE * file = fopen(filename, "r");
    char tmp[8];
    for (;;) {
        int32_t from, to;
        if (fscanf(file, "%03X %03X\n", &from, &to) == EOF) {
            break;
        }
        phys->phys[from] = to;
    }
    fclose(file);
}

static int PHYS_FindLink2 (PHYS * phys, int from_slot, int to_slot, int number, int * from_phy_ptr, int * from_port_ptr, int * to_phy_ptr, int * to_port_ptr) {
    int old_number = number;
    int from_phy;
    for (from_phy = 0; ; from_phy++) {
        if (from_phy == PHY_COUNT) {
            if (old_number == number)
                return -1;
            from_phy = 0;
        }
        int from_port;
        for (from_port = 0; from_port < PORT_COUNT; from_port++) {
            int16_t to = phys->phys[__PHYS_INT16(from_slot, from_phy, from_port)];
            if (__PHYS_SLOT(to) == to_slot) {
                if (number == 0) {
                    *from_phy_ptr = from_phy;
                    *from_port_ptr = from_port;
                    *to_phy_ptr = __PHYS_PHY(to);
                    *to_port_ptr = __PHYS_PORT(to);
                    return 0;
                } else {
                    number--;
                }
            }
        }
    }
}

static int PHYS_FindLink (PHYS * phys, int my_slot, int remote_slot, int * send_phy_ptr, int * send_port_ptr, int * recv_phy_ptr, int * recv_port_ptr) {
    int phy, port;
    for (phy = 0; phy < PHY_COUNT; phy++) {
        for (port = 0; port < PORT_COUNT; port++) {
            int16_t data = phys->phys[__PHYS_INT16(my_slot, phy, port)];
            if (__PHYS_SLOT(data) == remote_slot) {
                *send_phy_ptr = phy;
                *send_port_ptr = port;
                phy = 57;
                break;
            }
        }
    }
    if (phy == PHY_COUNT)
        return -1;
    for (phy = 0; phy < PHY_COUNT; phy++) {
        for (port = 0; port < PORT_COUNT; port++) {
            int16_t data = phys->phys[__PHYS_INT16(remote_slot, phy, port)];
            if (__PHYS_SLOT(data) == my_slot) {
                *recv_phy_ptr = __PHYS_PHY(data);
                *recv_port_ptr = __PHYS_PORT(data);
                phy = 57;
                break;
            }
        }
    }
    if (phy == PHY_COUNT)
        return -1;
    return 0;
}

#endif /* PHYS_H */
