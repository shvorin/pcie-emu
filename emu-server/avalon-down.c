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
#include <ghdl-bindings.h>
#include <socket-util.h>
#include <pollpull.h>
#include <avalon.h>
#include <rreq-storage.h>

#if 1
void line256mp_down(line_down_scalars_t *bar, ast256mp_t *ast, ast_bp_t *ast_bp) {
  ast->half[0].empty = ast->half[1].empty = stdl_0; /* FIXME */

  /* default values */
  ast->half[0].sop = ast->half[0].eop = stdl_0;
  ast->half[1].sop = ast->half[1].eop = stdl_0;
  ast->valid = stdl_0;

  // first, take care of ej_ready; TODO: enhance
#if 0
  ast_bp->ready = lrand48() % 2 == 1 ? stdl_1 : stdl_0;
#else
  ast_bp->ready = drand48() > .01 ? stdl_1 : stdl_0;
#endif

  static TlpPacket pkt;
  static size_t nSublines = /* some meaningless value */-1;
  static size_t payload_qw_end;
  static tlp_header head;

  static char yyy[1024];
  static streambuf_t streambuf = {.start = yyy, .end = yyy + sizeof(yyy)};

  int recv_packet() {
    /* capture TLP packet from client */
    {
      char * buf = (char *)&pkt;
      size_t len = sizeof(TlpPacket);

      int cliSock = pp_pollin(/* zero timeout */0);

      if(-1 == cliSock) {
        return 0;
      } else {
        Socket_Recv(cliSock, buf, len);
      }
    }

    size_t nLines = -1;

    /* issue header */
    bufrewind(&streambuf);
    payload_qw_end = 0; /* no payload by default */

    switch(pkt.kind) {
    case writeReq:
      head = mk_w32_header(pkt.addr, pkt.nBytes);
      /* aligned data expected  */
      assert((head.rw.dw0.s.len & 1) == 0);

      /* hhhhdddd, dddddddd, ... */
      nSublines = (head.rw.dw0.s.len + 3)/4 + 1;
      nLines = (head.rw.dw0.s.len + 3)/8 + 1;

      payload_qw_end = (head.rw.dw0.s.len >> 1) + 2;
      break;

    case readReq:
      {
        static int token_counter = 0;
        const uint64_t clientId = pkt.bdata[0];
        token_t token = ((clientId << 4) & 0xFF) | (token_counter++ & 0xF);
        rreq_item_t item = {.token = token,
                            .clientId = clientId,
                            .nBytes = pkt.bdata[1]};

        rreq_item_t *ptr_item = malloc(sizeof(rreq_item_t));
        *ptr_item = item;

        rreq_insert(ptr_item);

        head = mk_r32_header(pkt.addr, pkt.nBytes, token);
        /* aligned data expected  */
        assert((head.rw.dw0.s.len & 1) == 0);

        nSublines = 1;
        nLines = 1;
      }
      break;

    default:
      error(1, 0, "not implemented packet kind");
    }

    bufshow_tlp_head(&streambuf, nLines, head);

    return 1;
  }

  static size_t count = 0;

  int k;
  for(k=0; k<2; ++k) {
    if(count == 0) {
      if(!recv_packet()) {
        /* no event found */
        ast->valid = k ? stdl_1 : stdl_0;
        bar->bar_num = pkt.bar_num; /* NB: keep old bar_num value */
        return;
      }

      /* tlp header */
      memcpy(ast->half[k].data, &head, sizeof(head));
    } else {
      /* payload */
      memcpy(ast->half[k].data, pkt.bdata + 16 * (count - 1), 16);
    }

    if(0 == count)
      ast->half[k].sop = stdl_1;
    if(nSublines - 1 == count) {
      ast->half[k].eop = stdl_1;
      ast->half[k].empty = head.rw.dw0.s.len & 2 ? stdl_1 : stdl_0;
    }

    //    if(k==0)
    bufshow_line256mp(&streambuf, ast->half[k].data, count, payload_qw_end);

    ++count;

    if(count == nSublines) {
      count = 0;

      if(!emu_config.tlp_quiet)
        printf("DN: %s\n", streambuf.start);
    }
  }

  ast->valid = stdl_1;
  bar->bar_num = pkt.bar_num;
}

#else

void line256mp_down(line_down_scalars_t *bar, ast256mp_t *ast, ast_bp_t *ast_bp) {
  ast->half[0].empty = ast->half[1].empty = stdl_0; /* FIXME */

  /* default values */
  ast->half[0].sop = ast->half[0].eop = stdl_0;
  ast->half[1].sop = ast->half[1].eop = stdl_0;
  ast->valid = stdl_0;

  // first, take care of ej_ready; TODO: enhance
#if 0
  ast_bp->ready = lrand48() % 2 == 1 ? stdl_1 : stdl_0;
#else
  ast_bp->ready = drand48() > .01 ? stdl_1 : stdl_0;
#endif

  static TlpPacket pkt;
  static size_t count = 0;
  static size_t nLines = /* some meaningless value */-1, nSublines;
  static size_t payload_qw_end;

  static char yyy[1024];
  static streambuf_t streambuf = {.start = yyy, .end = yyy + sizeof(yyy)};

  int recv_packet() {
    /* capture TLP packet from client */
    {
      char * buf = (char *)&pkt;
      size_t len = sizeof(TlpPacket);

      int cliSock = pp_pollin(/* zero timeout */0);

      if(-1 == cliSock) {
        return 0;
      } else {
        Socket_Recv(cliSock, buf, len);
      }
    }

    /* issue header */
    bufrewind(&streambuf);
    payload_qw_end = 0; /* no payload by default */

    tlp_header head;

    switch(pkt.kind) {
    case writeReq:
      head = mk_w32_header(pkt.addr, pkt.nBytes);
      /* aligned data expected  */
      assert((head.rw.dw0.s.len & 1) == 0);

      /* hhhhdddd, dddddddd, ... */
      nLines = (head.rw.dw0.s.len + 3)/8 + 1;
      nSublines = (head.rw.dw0.s.len + 3)/4 + 1;

      payload_qw_end = (head.rw.dw0.s.len >> 1) + 2;
      break;

    case readReq:
      {
        static int token_counter = 0;
        const uint64_t clientId = pkt.bdata[0];
        token_t token = ((clientId << 4) & 0xFF) | (token_counter++ & 0xF);
        rreq_item_t item = {.token = token,
                            .clientId = clientId,
                            .nBytes = pkt.bdata[1]};

        rreq_item_t *ptr_item = malloc(sizeof(rreq_item_t));
        *ptr_item = item;

        rreq_insert(ptr_item);

        head = mk_r32_header(pkt.addr, pkt.nBytes, token);
        /* aligned data expected  */
        assert((head.rw.dw0.s.len & 1) == 0);

        nLines = 1;
        nSublines = 1;
      }
      break;

    default:
      error(1, 0, "not implemented packet kind");
    }

    /* tlp header */
    memcpy(ast->half[0].data, &head, sizeof(head));

    /* payload */
    memcpy(ast->half[1].data, pkt.bdata, 16);

    bufshow_tlp_head(&streambuf, nLines, head);

    return 1;
  }

  if(count == 0) {
    if(!recv_packet()) {
      /* no event found, just skip the line */
      return;
    }
  } else {
    /* payload */
    memcpy(ast->half[0].data, pkt.bdata + 16 + 32 * (count - 1), 16);
    memcpy(ast->half[1].data, pkt.bdata + 32 + 32 * (count - 1), 16);
  }

  ast->valid = stdl_1;
  bar->bar_num = pkt.bar_num;

  if(0 == count)
    ast->half[0].sop = stdl_1;
  if(nLines - 1 == count)
    ast->half[nSublines & 1 ? 0 : 1].eop = stdl_1;

  bufshow_line256mp(&streambuf, ast, count, payload_qw_end);

  ++count;

  if(count == nLines) {
    if(!emu_config.tlp_quiet)
      printf("DN: %s\n", streambuf.start);

    count = 0;
  }
}
#endif

void line256_down(line_down_scalars_t *bar, ast256_t *ast, ast_bp_t *ast_bp) {
  ast->empty[0] = ast->empty[1] = stdl_0; /* FIXME */
  ast->sop[1] = ast->eop[1] = stdl_0; /* unused yet */

  // first, take care of ej_ready; TODO: enhance
#if 0
  ast_bp->ready = lrand48() % 2 == 1 ? stdl_1 : stdl_0;
#else
  ast_bp->ready = drand48() > .01 ? stdl_1 : stdl_0;
#endif

  static TlpPacket pkt;
  static size_t count = 0;
  static size_t nLines = /* some meaningless value */-1;
  static size_t payload_qw_end;

  static char yyy[1024];
  static streambuf_t streambuf = {.start = yyy, .end = yyy + sizeof(yyy)};

  int recv_packet() {
    /* capture TLP packet from client */
    {
      char * buf = (char *)&pkt;
      size_t len = sizeof(TlpPacket);

      int cliSock = pp_pollin(/* zero timeout */0);

      if(-1 == cliSock) {
        return 0;
      } else {
        Socket_Recv(cliSock, buf, len);
      }
    }

    /* issue header */
    bufrewind(&streambuf);
    payload_qw_end = 0; /* no payload by default */

    tlp_header head;

    switch(pkt.kind) {
    case writeReq:
      head = mk_w32_header(pkt.addr, pkt.nBytes);
      /* aligned data expected  */
      assert((head.rw.dw0.s.len & 1) == 0);

      /* hhhhdddd, dddddddd, ... */
      nLines = (head.rw.dw0.s.len + 3)/8 + 1;

      payload_qw_end = (head.rw.dw0.s.len >> 1) + 2;
      break;

    case readReq:
      {
        static int token_counter = 0;
        const uint64_t clientId = pkt.bdata[0];
        token_t token = ((clientId << 4) & 0xFF) | (token_counter++ & 0xF);
        rreq_item_t item = {.token = token,
                            .clientId = clientId,
                            .nBytes = pkt.bdata[1]};

        rreq_item_t *ptr_item = malloc(sizeof(rreq_item_t));
        *ptr_item = item;

        rreq_insert(ptr_item);

        head = mk_r32_header(pkt.addr, pkt.nBytes, token);
        /* aligned data expected  */
        assert((head.rw.dw0.s.len & 1) == 0);

        nLines = 1;
      }
      break;

    default:
      error(1, 0, "not implemented packet kind");
    }

    /* tlp header */
    memcpy(ast->data, &head, sizeof(head));

    /* payload */
    memcpy(ast->data + 4, pkt.bdata, 16);

    bufshow_tlp_head(&streambuf, nLines, head);

    return 1;
  }

  if(count == 0) {
    if(!recv_packet()) {
      /* no event found, just skip the line */
      ast->valid = ast->sop[0] = ast->eop[0] = stdl_0;
      return;
    }
  } else {
    /* payload */
    memcpy(ast->data, pkt.bdata + 16 + 32 * (count - 1), 32);
  }

  ast->valid = stdl_1;
  ast->sop[0] = count == 0 ? stdl_1 : stdl_0;
  bar->bar_num = pkt.bar_num;

  bufshow_line256(&streambuf, ast, count, payload_qw_end);

  ++count;

  if(count == nLines) {
    if(!emu_config.tlp_quiet)
      printf("DN: %s\n", streambuf.start);

    count = 0;
    ast->eop[0] = stdl_1;
  } else {
    ast->eop[0] = stdl_0;
  }
}

void line128_down(bits_down_t *bits, uint32_t arr[4]) {
  error(1, 0, "line128_down() not implemented");
}

void line64_down(bits_down_t *bits, uint32_t arr[2]) {
  error(1, 0, "line64_down() not implemented");
}
