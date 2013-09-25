/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */

/* vim: set syntax=c et sw=4 ts=4: */

#ifndef PHYS_H
#define PHYS_H

#include <ctype.h>
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define HOSTNAME_SIZE 64
#define SLOT_COUNT 16
#define PHY_COUNT 6
#define PORT_COUNT 2

#define __PHYS_PHYS_COUNT 1024
#define __PHYS_LINE_SIZE 1024
#define __PHYS_TRY_COUNT 5
#define __PHYS_TRY_SLEEP 1000

static int64_t __PHYS_GetPort (void * base_addr, int phy_num) {
    int64_t reg0 = *(volatile uint64_t *)(((uint8_t *) base_addr) + ((phy_num + 1) << 20 | 0xd0a00));
    if (reg0 == -1) {
        return -1;
    }
    reg0 &= 0xffff;
    int64_t reg1 = *(volatile uint64_t *)(((uint8_t *) base_addr) + ((phy_num + 1) << 20 | 0xd0a10));
    if (reg1 == -1) {
        return -1;
    }
    reg1 &= 0xffff;
    if ((reg0 == 0x0100) && (reg1 == 0x0302)) {
        return 0;
    }
    if ((reg0 == 0x0504) && (reg1 == 0x0706)) {
        return 1;
    }
    return (1ULL << 63) | (1ULL << 32) | (reg1 << 16) | reg0;
}

/*
 *  0        -- primary port
 *  1        -- redundant port
 *  negative -- error
 *    -1    -- no answer from PCIe
 *    other -- invalid state
 */
static __attribute__((unused)) int64_t PHYS_GetPort (void * base_addr, int phy_num) {
    int64_t res;
    int i;
    for (i = 0; i < __PHYS_TRY_COUNT; i++) {
        res = __PHYS_GetPort(base_addr, phy_num);
        if (res >=0) {
            return res;
        }
        usleep(__PHYS_TRY_SLEEP);
    }
    if (res == -1) {
        errno = EAGAIN;
    } else {
        errno = EIO;
    }
    return res;
}

static int64_t __PHYS_GetStatus (void * base_addr, int phy_num, int port) {
    int64_t status;
    if (port) {
        status = *(volatile uint64_t *)(((uint8_t *) base_addr) + ((phy_num + 1) << 20 | 0xc0080));
        status = *(volatile uint64_t *)(((uint8_t *) base_addr) + ((phy_num + 1) << 20 | 0xc0080));
    } else {
        status = *(volatile uint64_t *)(((uint8_t *) base_addr) + ((phy_num + 1) << 20 | 0x00080));
        status = *(volatile uint64_t *)(((uint8_t *) base_addr) + ((phy_num + 1) << 20 | 0x00080));
    }
    if (status == -1) {
        return -1;
    }
    status &= 0xffff;
    if (status == 0x8000) {
        return 0;
    }
    return (1ULL<<63) | (2ULL << 32) | status;
}

/*
 *  0        -- OK, link is up
 *  negative -- error
 *    -1    -- no answer from PCIe
 *    other -- invalid state
 */
static __attribute__((unused)) int64_t PHYS_GetStatus (void * base_addr, int phy_num) {
    int64_t port = PHYS_GetPort(base_addr, phy_num);
    if (port < 0) {
        return port;
    }
    int64_t res;
    int i;
    for (i = 0; i < __PHYS_TRY_COUNT; i++) {
        res = __PHYS_GetStatus(base_addr, phy_num, port);
        if (res >=0) {
            return res;
        }
        usleep(__PHYS_TRY_SLEEP);
    }
    if (res == -1) {
        errno = EAGAIN;
    } else {
        errno = EIO;
    }
    return res;
}

static __attribute__((unused)) void __PHYS_SetPort (void * base_addr, int phy_num, int port) {
    uint64_t reg0 = 0x0100;
    uint64_t reg1 = 0x0302;
    if (port) {
        reg0 = 0x0504;
        reg1 = 0x0706;
    }
    *(volatile uint64_t *)(((uint8_t *) base_addr) + ((phy_num + 1) << 20 | 0xd0810)) = 0x000f;
    usleep(100);
    *(volatile uint64_t *)(((uint8_t *) base_addr) + ((phy_num + 1) << 20 | 0xd0900)) = reg0;
    usleep(100);
    *(volatile uint64_t *)(((uint8_t *) base_addr) + ((phy_num + 1) << 20 | 0xd0910)) = reg1;
    usleep(100);
    *(volatile uint64_t *)(((uint8_t *) base_addr) + ((phy_num + 1) << 20 | 0xd0800)) = 0x0002;
    usleep(100);
    *(volatile uint64_t *)(((uint8_t *) base_addr) + ((phy_num + 1) << 20 | 0xd0800)) = 0x0000;
    usleep(100);
    *(volatile uint64_t *)(((uint8_t *) base_addr) + ((phy_num + 1) << 20 | 0xd0040)) = port ? 0x0000 : 0xf0ff;
    usleep(100);
    *(volatile uint64_t *)(((uint8_t *) base_addr) + ((phy_num + 1) << 20 | 0xd0050)) = port ? 0xf0ff : 0x0000;
    usleep(100);
    *(volatile uint64_t *)(((uint8_t *) base_addr) + ((phy_num + 1) << 20 | 0xd0030)) = port ? 0x000f : 0x00f0;
    usleep(100);
}

/*
 *  0        -- OK
 *  negative -- error
 *    -1    -- no answer from PCIe
 *    other -- invalid state
 */
static __attribute__((unused)) int64_t PHYS_SetPort (void * base_addr, int phy_num, int port) {
    int64_t res;
    int i;
    for (i = 0; i < __PHYS_TRY_COUNT; i++) {
        __PHYS_SetPort(base_addr, phy_num, port);
        res = PHYS_GetPort(base_addr, phy_num);
        if (res < 0) {
            return res;
        }
        if (res == port) {
            return 0;
        }
        usleep(__PHYS_TRY_SLEEP);
    }
    errno = EIO;
    return (1ULL << 63) | (3ULL << 32) | res;
}

static __attribute__((unused)) void * PHYS_Get_Address (void * base_addr, int phy_num) {
    return ((uint8_t *) base_addr) + (phy_num * 0x1000000);
}

static __attribute__((unused)) int64_t PHYS_Get_Slot (void * base_addr) {
    int64_t reg = *(volatile uint64_t *)(((uint8_t *) base_addr) + (1 << 20 | 0x00080));
    if (reg == -1) {
        errno = EAGAIN;
        return -1;
    }
    return reg >> 48;
}

static __attribute__((unused)) void PHYS_OpenPorts (void * base_addr) {
    *(volatile uint64_t *)(((uint8_t *) base_addr) + 0x40) = 0;
}

static __attribute__((unused)) void PHYS_Broadcast (void * base_addr, int phy_num) {
    *(volatile uint64_t *)(((uint8_t *) base_addr) + (phy_num)*256+16) = 0;
}

// Allocate memory and set hostname to it
static __attribute__((unused)) char * PHYS_GetHostname () {
    char * hostname = malloc(HOSTNAME_SIZE * sizeof(char));
    gethostname(hostname, HOSTNAME_SIZE);
    int i;
    for (i = 0; i < HOSTNAME_SIZE; i++) {
        if (i == (HOSTNAME_SIZE - 1) || hostname[i] == 0 /*|| hostname[i] == '.'*/) {
            hostname[i] = 0;
            break;
        }
    }
    return hostname;
}

typedef struct {
    char * from_hostname;
    char * to_hostname;
    int8_t from_phy;
    int8_t from_port;
    int8_t to_phy;
    int8_t to_port;
} PHYS_Entry;

typedef struct {
    PHYS_Entry * entries;
} PHYS;

static PHYS_Entry * __PHYS_FindFree (PHYS * phys) {
    int i;
    for (i = 0; i < __PHYS_PHYS_COUNT; i++) {
        if (phys->entries[i].from_hostname == NULL) {
            return &(phys->entries[i]);
        }
    }
    return NULL;
}

static PHYS_Entry * __PHYS_FindNext (PHYS * phys, int * i) {
    for (; *i < __PHYS_PHYS_COUNT; (*i)++) {
        if (phys->entries[*i].from_hostname != NULL) {
            PHYS_Entry * entry = &(phys->entries[*i]);
            (*i)++;
            return entry;
        }
    }
    return NULL;
}

static __attribute__((unused)) void PHYS_Init (PHYS * phys) {
    phys->entries = (PHYS_Entry *)malloc(__PHYS_PHYS_COUNT * sizeof(PHYS_Entry));
    memset(phys->entries, 0, __PHYS_PHYS_COUNT * sizeof(PHYS_Entry));
}

static __attribute__((unused)) void PHYS_Finalize (PHYS * phys) {
    int i = 0;
    for (;;) {
        PHYS_Entry * entry = __PHYS_FindNext(phys, &i);
        if (entry == NULL) {
            break;
        }
        free(entry->from_hostname);
        free(entry->to_hostname);
    }
    free(phys->entries);
}

static __attribute__((unused)) void PHYS_Add (PHYS * phys, char * from_hostname, int from_phy, int from_port, char * to_hostname, int to_phy, int to_port) {
    PHYS_Entry * entry = __PHYS_FindFree(phys);
    if (entry == NULL) {
        return;
    }
    entry->from_hostname = strdup(from_hostname);
    entry->from_phy = from_phy;
    entry->from_port = from_port;
    entry->to_hostname = strdup(to_hostname);
    entry->to_phy = to_phy;
    entry->to_port = to_port;
}

static __attribute__((unused)) void PHYS_Write (PHYS * phys, char * filename) {
    FILE * file = fopen(filename, "w");
    int i = 0;
    for (;;) {
        PHYS_Entry * entry1 = __PHYS_FindNext(phys, &i);
        if (entry1 == NULL) {
            break;
        }
        int j = i;
        for (;;) {
            PHYS_Entry * entry2 = __PHYS_FindNext(phys, &j);
            if (entry2 == NULL) {
                break;
            }
            if (strcmp(entry1->from_hostname, entry2->to_hostname) == 0 && entry1->from_phy == entry2->to_phy && entry1->from_port == entry2->to_port &&
                    strcmp(entry2->from_hostname, entry1->to_hostname) == 0 && entry2->from_phy == entry1->to_phy && entry2->from_port == entry1->to_port) {
                if (strcmp(entry1->from_hostname, entry2->from_hostname) < 0 || 
                        (strcmp(entry1->from_hostname, entry2->from_hostname) == 0 && entry1->from_phy < entry2->from_phy) || 
                        (strcmp(entry1->from_hostname, entry2->from_hostname) == 0 && entry1->from_phy == entry2->from_phy && entry1->from_port < entry2->from_port)) { 
                    entry2 = entry1;
                }
                fprintf(file, "%s %d %d   %s %d %d\n", entry2->from_hostname, entry2->from_phy, entry2->from_port, entry2->to_hostname, entry2->to_phy, entry2->to_port);
                break;
            }
        }
    }
    fclose(file);
}

static __attribute__((unused)) void PHYS_InitRead (PHYS * phys, char * filename) {
    PHYS_Init(phys);
    FILE * file = fopen(filename, "r");
    if (file == NULL) {
        return;
    }
    char from_hostname[HOSTNAME_SIZE];
    char to_hostname[HOSTNAME_SIZE];
    for (;;) {
        int from_phy, from_port, to_phy, to_port;
        if (fscanf(file, "%255s %d %d %255s %d %d\n", from_hostname, &from_phy, &from_port, to_hostname, &to_phy, &to_port) == EOF) {
            break;
        }
        PHYS_Add(phys, from_hostname, from_phy, from_port, to_hostname, to_phy, to_port);
        if (strcmp(from_hostname, to_hostname) != 0 || from_phy != to_phy || from_port != to_port) {
            PHYS_Add(phys, to_hostname, to_phy, to_port, from_hostname, from_phy, from_port);
        }
    }
    fclose(file);
}

static __attribute__((unused)) int PHYS_IterLink (PHYS * phys, int * i, char ** from_hostname_ptr, int * from_phy_ptr, int * from_port_ptr, char ** to_hostname_ptr, int * to_phy_ptr, int * to_port_ptr) {
    PHYS_Entry * entry = __PHYS_FindNext(phys, i);
    if (entry == NULL) {
        return -1;
    }
    *from_hostname_ptr = entry->from_hostname;
    *from_phy_ptr = entry->from_phy;
    *from_port_ptr = entry->from_port;
    *to_hostname_ptr = entry->to_hostname;
    *to_phy_ptr = entry->to_phy;
    *to_port_ptr = entry->to_port;
    return 0;
}

static __attribute__((unused)) int PHYS_FindLink (PHYS * phys, char * from_hostname, char * to_hostname, int number, int * from_phy_ptr, int * from_port_ptr, int * to_phy_ptr, int * to_port_ptr) {
    int old_number = number;
    int i = 0;
    for (;;) {
        PHYS_Entry * entry = __PHYS_FindNext(phys, &i);
        if (entry == NULL) {
            if (old_number == number) {
                return -1;
            }
            i = 0;
            continue;
        }
        if (strcmp(entry->from_hostname, from_hostname) == 0 && strcmp(entry->to_hostname, to_hostname) == 0) {
            if (number == 0) {
                *from_phy_ptr = entry->from_phy;
                *from_port_ptr = entry->from_port;
                *to_phy_ptr = entry->to_phy;
                *to_port_ptr = entry->to_port;
                return 0;
            } else {
                number--;
            }
        }
    }
}

static __attribute__((unused)) int PHYS_FindPHYs (PHYS * phys, char * my_hostname, char * remote_hostname, int * send_phy_ptr, int * send_port_ptr, int * recv_phy_ptr, int * recv_port_ptr) {
    int tmp, res;
    res = PHYS_FindLink(phys, my_hostname, remote_hostname, 0, send_phy_ptr, send_port_ptr, &tmp, &tmp);
    if (res == -1) {
        return -1;
    }
    res = PHYS_FindLink(phys, remote_hostname, my_hostname, 0, &tmp, &tmp, recv_phy_ptr, recv_port_ptr);
    if (res == -1) {
        return -1;
    }
    return 0;
}

static __attribute__((unused)) void COOR_Init (PHYS * phys, char * filename) {
    PHYS_Init(phys);
    FILE * file = fopen(filename, "r");
    if (file == NULL) {
        return;
    }
    char fullline[__PHYS_LINE_SIZE];
    for (;;) {
        char * line = fgets(fullline, __PHYS_LINE_SIZE, file);
        //printf("LINE: %s", fullline);
        if (line == NULL) {
            break;
        }
        while (isspace(*line)) {
            line++;
        }
        if (*line == 0) {
            continue;
        }
        char * hostname, * comment;
        if (*line == '#') {
            hostname = NULL;
            comment = line + 1;
        } else {
            hostname = strtok(line, "#");
            if (hostname == NULL) {
                continue;
            }
            int i;
            for (i = 0; hostname[i] != 0 && hostname[i] != ':' && !isspace(hostname[i]); i++);
            hostname[i] = 0;
            comment = strtok(NULL, "#");
            if (comment == NULL) {
                continue;
            }
        }
        //printf("hostname: '%s'\n", hostname);
        //printf("comment: '%s'\n", comment);
        char * tmp = strtok(comment, " ");
        if (tmp == NULL) {
            continue;
        }
        if (hostname == 0 && strcmp(tmp, "SIZE") == 0) {
            hostname = "SIZE";
        } else if (hostname == 0 || strcmp(tmp, "COOR") != 0) {
            continue;
        }
        tmp = strtok(NULL, " ");
        if (tmp == NULL) {
            continue;
        }
        int x = strtol(tmp, NULL, 0);
        tmp = strtok(NULL, " ");
        if (tmp == NULL) {
            continue;
        }
        int y = strtol(tmp, NULL, 0);
        tmp = strtok(NULL, " ");
        if (tmp == NULL) {
            continue;
        }
        int z = strtol(tmp, NULL, 0);
        //printf("RES: %s: %d %d %d\n", hostname,x,y,z);
        PHYS_Add(phys, hostname, x, y, "", z, 0);
    }
    fclose(file);
}

static __attribute__((unused)) int COOR_GerCoor (PHYS * phys, char * hostname, int * x, int * y, int * z) {
    int i = 0;
    for (;;) {
        PHYS_Entry * entry = __PHYS_FindNext(phys, &i);
        if (entry == NULL) {
            return -1;
        }
        if (strcmp(entry->from_hostname, hostname) == 0) {
            *x = entry->from_phy;
            *y = entry->from_port;
            *z = entry->to_phy;
            return 0;
        }
    }
}

static __attribute__((unused)) void COOR_Finalize (PHYS * phys) {
    PHYS_Finalize(phys);
}

static __attribute__((unused)) int PHYS_Filter (PHYS * input, PHYS * coors, PHYS * output) {
    int res;
    int size_x = 0, size_y = 0, size_z = 0;
    res = COOR_GerCoor(coors, "SIZE", &size_x, &size_y, &size_z);
    if (res != 0) {
        return -1;
    }

    char * from_hostname;
    int from_phy;
    int from_port;
    char * to_hostname;
    int to_phy;
    int to_port;
    int i = 0;
    for (;;) {
        res = PHYS_IterLink(input, &i, &from_hostname, &from_phy, &from_port, &to_hostname, &to_phy, &to_port);
        if (res != 0) {
            break;
        }
        int from_x = 0, from_y = 0, from_z = 0;
        int to_x = 0, to_y = 0, to_z = 0;
        res = COOR_GerCoor(coors, from_hostname, &from_x, &from_y, &from_z);
        if (res != 0) {
            continue;
        }
        res = COOR_GerCoor(coors, to_hostname, &to_x, &to_y, &to_z);
        if (res != 0) {
            continue;
        }
        int d_x = (to_x - from_x + size_x) % size_x;
        int d_y = (to_y - from_y + size_y) % size_y;
        int d_z = (to_z - from_z + size_z) % size_z;
        if ((d_y + d_z == 0 && ((from_phy == 0 && d_x == 1) || (from_phy == 1 && d_x == size_x - 1))) ||
            (d_x + d_z == 0 && ((from_phy == 2 && d_y == 1) || (from_phy == 3 && d_y == size_y - 1))) ||
            (d_x + d_y == 0 && ((from_phy == 4 && d_z == 1) || (from_phy == 5 && d_z == size_z - 1))) ||
            strcmp(from_hostname, to_hostname) == 0) {
            PHYS_Add(output, from_hostname, from_phy, from_port, to_hostname, to_phy, to_port);
        }
    }
    return 0;
}

#undef __PHYS_PHYS_COUNT
#undef __PHYS_LINE_SIZE
#undef __PHYS_TRY_COUNT
#undef __PHYS_TRY_SLEEP

#endif /* PHYS_H */
