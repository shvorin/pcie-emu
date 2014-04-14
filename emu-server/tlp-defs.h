/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */

#ifndef TLP_DEFS_H
#define TLP_DEFS_H

#include <stdint.h>

/* FIXME: actual endian for i386 and amd64 is big (not little!); it seems to be
 * a bug in gcc libs */
#if !(defined(__BYTE_ORDER__) && __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__)
#  error unsupported endian
#endif

#pragma pack(push,1)

/* common dword #0 for nearly all TLP packets */
typedef union {
  struct {
    int len : 10,
      at : 2,
      attr : 2,
      ep : 1,
      td : 1,
      /* reserved */ : 4,
      tc : 3,
      /* reserved */ : 1,
      typ : 5,
      fmt : 3;
  } s;
  uint32_t r;
} tlp_dw0;

/* dword #1 for read and write request */
typedef union {
  struct {
    int be_lst : 4,
      be_fst : 4,
      tag : 8,
      req_id : 16;
  } s;
  uint32_t r;
} tlp_dw1;

/* dword #1 for read completion */
typedef union {
  struct {
    int bc : 12,
      b : 1,
      status : 3,
      cpl_id : 16;
  } s;
  uint32_t r;
} tlp_cpldw1;

/* dword #2 for read completion */
typedef union {
  struct {
    int low_addr : 7,
      /* reserved */ : 1,
      tag : 8,
      req_id : 16;
  } s;
  uint32_t r;
} tlp_cpldw2;

typedef union {
  /* read or write request */
  struct {
    tlp_dw0 dw0;
    tlp_dw1 dw1;
    uint64_t rawaddr;
  } rw;

  /* read completion */
  struct {
    tlp_dw0 dw0;
    tlp_cpldw1 dw1;
    tlp_cpldw2 dw2;
    uint32_t reserved;
  } cpl;

  uint32_t r[4];
} tlp_header;

typedef struct {
  uint32_t r[4];
} tlp_rawdata;

#pragma pack(pop)

static uint64_t combine_addr(uint64_t addr, int is_4dw) {
  /* TODO: check this */
  return is_4dw ? (addr >> 32) | (addr << 32) : addr; 
}

static uint64_t parse_addr(uint64_t rawaddr, int is_4dw) {
  /* TODO: check this */
  return is_4dw ? (rawaddr >> 32) | (rawaddr << 32) : rawaddr; 
}

static tlp_header mk_r32_header(uint64_t addr, int bc, int tag) {
  if(bc % 4 != 0)
    error(1, 0, "not implemented");

  tlp_header header = {.r = {0,0,0,0}};

  header.rw.dw0.s = (typeof(header.rw.dw0.s)) {
    .len = bc/4,
    .typ = 0,
    .fmt = 0,
  };

  header.rw.dw1.s = (typeof(header.rw.dw1.s)) {
    .be_lst = ~0,
    .be_fst = ~0,
    .tag = tag,
    .req_id = ~0, /* req_id (requester's PCI id) is unused */
  };

  header.rw.rawaddr = combine_addr(addr, 0);

  return header;
}

static tlp_header mk_w32_header(uint64_t addr, int bc) {
  if(bc % 4 != 0)
    error(1, 0, "not implemented");

  tlp_header header = {.r = {0,0,0,0}};

  header.rw.dw0.s = (typeof(header.rw.dw0.s)) {
    .len = bc/4,
    .typ = 0,
    .fmt = 2,
  };

  header.rw.dw1.s = (typeof(header.rw.dw1.s)) {
    .be_lst = ~0,
    .be_fst = ~0,
  };

  header.rw.rawaddr = combine_addr(addr, 0);

  return header;
}

enum tlp_kind_t {tlp_kind_read, tlp_kind_write, tlp_kind_cpl, tlp_kind_unknown};

static enum tlp_kind_t parse_type(tlp_header head) {
  /* read completion */
  if(head.rw.dw0.s.fmt == 2 && head.rw.dw0.s.typ == 0xA)
    return tlp_kind_cpl;

  if(head.rw.dw0.s.typ == 0) {
    switch(head.rw.dw0.s.fmt) {
    case 0:
    case 1:
      return tlp_kind_read;

    case 2:
    case 3:
      return tlp_kind_write;
    }
  }

  return tlp_kind_unknown;
}

static int is_4dw(tlp_header head) {
  return head.rw.dw0.s.fmt & 1;
}

static void show_tlp_head(const char *prefix, uint32_t hash, size_t nLines, tlp_header head) {
  const int len = head.rw.dw0.s.len & 0x3FF; /* len:10 */
  const int bc = len << 2; /* byte count */

  switch(parse_type(head)) {
  case tlp_kind_write:
    printf("%s-%08x: kind_write, nLines: %lu, addr: 0x%08lX+%X\n" /* NB: 32-bit addr is usually used */,
           prefix, hash, nLines, head.rw.rawaddr, bc);
    break;

  case tlp_kind_cpl:
    printf("%s-%08x: kind_cpl, nLines: %lu, low_addr: 0x%02X+%X, cpl_tag: 0x%02X\n",
           prefix, hash, nLines, head.cpl.dw2.s.low_addr & 0x7F, bc, head.cpl.dw2.s.tag & 0xFF);
    break;

  case tlp_kind_read:
    printf("%s-%08x: kind_read, nLines: %lu, addr: 0x%08lX+%X, cpl_tag: 0x%02X\n",
           prefix, hash, nLines, head.rw.rawaddr, bc, head.rw.dw1.s.tag & 0xFF);
    break;

  default:
    printf("%s kind_unknown\n", prefix);
  }
}

#endif /* TLP_DEFS_H */
