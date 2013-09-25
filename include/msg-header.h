/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */

/* vim: set syntax=c et sw=4 ts=4: */

#ifndef MSG_HEADER_H
#define MSG_HEADER_H

#include "netaddr.h"

#pragma pack(push,1)

typedef struct {
    unsigned int port : 4;
    unsigned int node : 12;
} MsgAddress;

typedef union {
    MsgAddress addr;
    netaddr_t id : 16;
} MsgId;

/* See definition of `msg_head_t` in msg_flit.vhd . This structure represents
   lower 32 bits of `msg_head_t`. So sizeof(MsgHeader) == 4. */
/* NB: this version of structure is NOT compatible with previous versions of
   msg design (prior r1691 of msg-t3d branch) since fields order changed. */
typedef struct {
    size_t len : 15;
    int parity: 1;
    MsgId dst;
} MsgHeader;

#pragma pack(pop)

#endif /* MSG_HEADER_H */
