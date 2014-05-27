/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */

#include <defines.h>

#include <stdio.h>
#include <stdint.h>
#include <assert.h>
#include <string.h>
#include <stdlib.h>
#include <error.h>
#include <errno.h>

#include <emu-common.h>
#include <tlp-defs.h>
#include <emu-server.h>
#include <rreq-storage.h>
#include <ghdl-bindings.h>
#include <socket-util.h>
#include <pollpull.h>
#include <avalon.h>

#define sfence() asm volatile ("sfence":::"memory")

static const uint64_t dram_addr_segment = 0x10000000;
static char *offset;
static size_t dram_segsize;

void init_tlp_up(char * dram_segment, size_t _dram_segsize) {
  offset = dram_segment - dram_addr_segment;
  dram_segsize = _dram_segsize;
}

#if 0
static const tlpaddr_t dram_addr_segment = 0x40000000;
static uint64_t const length_mask = ~(~0LL << 9);

static char * offset;
static size_t dram_segsize;

void init_tlp_up(char * dram_segment, size_t _dram_segsize) {
  offset = dram_segment - dram_addr_segment;
  dram_segsize = _dram_segsize;
  reset();
}
#endif

void line256mp_up(const ast256mp_t *ast) {
  if(std_logic_eq(ast->valid, stdl_0))
    return;

  static size_t count = 0;
  static size_t nLines;

  static char p_bdata[1024]; // FIXME: ad hoc
  static tlp_header head;
  static size_t payload_qw_end;

  static char yyy[1024];
  static streambuf_t streambuf = {.start = yyy, .end = yyy + sizeof(yyy)};

  ++count;

  if(1 == count) /* header arrived */{
    bufrewind(&streambuf);

    memcpy(&head, ast->lo.data, sizeof(head));

    /* aligned data expected  */
    assert((head.rw.dw0.s.len & 1) == 0);

    /* hhhhdddd, dddddddd, ... */
    nLines = (head.rw.dw0.s.len + 3)/8 + 1;

    bufshow_tlp_head(&streambuf, nLines, head);

    /* payload */
    memcpy(p_bdata, ast->hi.data, 16);

    switch(parse_type(head)) {
    case tlp_kind_write:
    case tlp_kind_cpl:
      payload_qw_end = (head.rw.dw0.s.len >> 1) + 2;
      break;

    default:
      payload_qw_end = 0;
    }
  } else {
    /* payload */
    memcpy(p_bdata + 16 + 32 * (count - 2), ast->lo.data, 16);
    memcpy(p_bdata + 32 + 32 * (count - 2), ast->hi.data, 16);
  }

  bufshow_line256mp(&streambuf, ast, count - 1, payload_qw_end);

  if(nLines == count) /* tail arriverd */ {
    if(!emu_config.tlp_quiet)
      printf("UP: %s\n", streambuf.start);

    size_t p_nBytes = head.rw.dw0.s.len * 4;

    switch(parse_type(head)) {
    case tlp_kind_write:
      memcpy(offset + parse_addr(head.rw.rawaddr, is_4dw(head)), p_bdata, p_nBytes);
      sfence();
      break;

    case tlp_kind_cpl:
      {
        token_t token = head.cpl.dw2.s.tag & 0xFF;
        rreq_item_t *item = rreq_find(token);
        if(NULL == item)
          error(1, 0, "a reply to an unknown read request");

        assert(item->nBytes == p_nBytes);
        size_t clientId = (size_t)item->clientId;
        /* TODO: the send may fail since client's timeout exhausted */
        /* Socket_Send(pollfds[clientId].fd, p_bdata, p_nBytes); */
        Socket_Send(pollpull.fds[clientId].fd, p_bdata, p_nBytes);

        rreq_delete(token);
        free(item);
      }
      break;

    default:
      error(1, 0, "packet kind not implemented");
    }

    count = 0;
  }
}

void line256_up(const ast256_t *ast) {
  if(std_logic_eq(ast->valid, stdl_0))
    return;

  static size_t count = 0;
  static size_t nLines;

  static char p_bdata[1024]; // FIXME: ad hoc
  static tlp_header head;
  static size_t payload_qw_end;

  static char yyy[1024];
  static streambuf_t streambuf = {.start = yyy, .end = yyy + sizeof(yyy)};

  ++count;

  if(1 == count) /* header arrived */{
    bufrewind(&streambuf);

    memcpy(&head, ast->data, sizeof(head));

    /* aligned data expected  */
    assert((head.rw.dw0.s.len & 1) == 0);

    /* hhhhdddd, dddddddd, ... */
    nLines = (head.rw.dw0.s.len + 3)/8 + 1;

    bufshow_tlp_head(&streambuf, nLines, head);

    /* payload */
    memcpy(p_bdata, ast->data + 4, 16);

    switch(parse_type(head)) {
    case tlp_kind_write:
    case tlp_kind_cpl:
      payload_qw_end = (head.rw.dw0.s.len >> 1) + 2;
      break;

    default:
      payload_qw_end = 0;
    }
  } else {
    /* payload */
    memcpy(p_bdata + 16 + 32 * (count - 2), ast->data, 32);
  }

  bufshow_line256mp(&streambuf, ast, count - 1, payload_qw_end);

  if(nLines == count) /* tail arriverd */ {
    if(!emu_config.tlp_quiet)
      printf("UP: %s\n", streambuf.start);

    size_t p_nBytes = head.rw.dw0.s.len * 4;

    switch(parse_type(head)) {
    case tlp_kind_write:
      memcpy(offset + parse_addr(head.rw.rawaddr, is_4dw(head)), p_bdata, p_nBytes);
      sfence();
      break;

    case tlp_kind_cpl:
      {
        token_t token = head.cpl.dw2.s.tag & 0xFF;
        rreq_item_t *item = rreq_find(token);
        if(NULL == item)
          error(1, 0, "a reply to an unknown read request");

        assert(item->nBytes == p_nBytes);
        size_t clientId = (size_t)item->clientId;
        /* TODO: the send may fail since client's timeout exhausted */
        /* Socket_Send(pollfds[clientId].fd, p_bdata, p_nBytes); */
        Socket_Send(pollpull.fds[clientId].fd, p_bdata, p_nBytes);

        rreq_delete(token);
        free(item);
      }
      break;

    default:
      error(1, 0, "packet kind not implemented");
    }

    count = 0;
  }
}

void line64_up(std_logic tx_dvalid, const uint32_t arr[2]) {
  error(1, 0, "line64_up() not implemented");
}

void line128_up(std_logic tx_dvalid, const uint32_t arr[4]) {
  error(1, 0, "line128_up() not implemented");
}
