/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */

#ifndef EMU_COMMON_H
#define EMU_COMMON_H

#include <stdint.h>

// FIXME: ad hoc
#define maxBytes_tlpPacket 64
#define maxBytes_tlpPacket_read 8

typedef uint32_t tlpaddr_t;

enum pkt_kind {writeReq, readReq, sfence};

typedef struct {
  uint8_t bar_num;
  enum pkt_kind kind;
  size_t nBytes;
  tlpaddr_t addr;
  uint8_t bdata[maxBytes_tlpPacket];
} TlpPacket;

enum {PROP_HIDDEN = 0x1};

#endif /* EMU_COMMON_H */
