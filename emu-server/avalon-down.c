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

#include <tlp-defs-old.h>
#include <tlp-defs.h>
#include <emu-server.h>
#include <ghdl-bindings.h>
#include <socket-util.h>
#include <avalon.h>
#include <rreq-storage.h>

static int pollin_revent(short revent) {
  if(revent & POLLERR)
    error(1, 0, "POLLERR in poll()", revent);

  if(revent & POLLHUP)
    error(1, 0, "client hangup; cleanup not implemented", revent);

  if(0 == revent)
    return 0;

  if(POLLIN == revent)
    return 1;

  error(1, 0, "unexpected result in poll()");
  return 0;
}

void line256_down(line_down_scalars_t *bar, ast256_t *ast, ast_bp_t *ast_bp) {
  ast->empty[0] = ast->empty[1] = stdl_0; /* FIXME */

  // first, take care of ej_ready; TODO: enhance
#if 0
  ast_bp->ready = lrand48() % 2 == 1 ? stdl_1 : stdl_0;
#else
  ast_bp->ready = drand48() > .01 ? stdl_1 : stdl_0;
#endif

  static TlpPacket p;
  static size_t hp = 1;
  static size_t count = 0;
  static size_t nLines = /* some meaningless value */-1;
  static size_t payload_qw_end;
  static uint32_t hash = 0;

  if(count == 0) {
    char * buf = (char *)&p;
    size_t len = sizeof(TlpPacket);

    int nSocks0 = nSocks;
    int res = poll(pollfds, nSocks, 0);

    if(-1 == res)
      error(1, errno, "poll() failed");

    if(pollin_revent(pollfds[0].revents)) {
      acceptClient();

      --res;
      --nSocks0;
    }

    if(0 == res) {
      ast->valid = ast->sop = ast->eop = stdl_0;
      return;
    }

    size_t selected;
    for(selected = hp; selected <= nSocks0; ++selected)
      if(pollin_revent(pollfds[selected].revents))
        goto selected_found;

    for(selected = 1; selected < hp ; ++selected)
      if(pollin_revent(pollfds[selected].revents))
        goto selected_found;

    assert(0);

  selected_found:
    Socket_Recv(pollfds[selected].fd, buf, len);
    hp = selected < nSocks ? selected + 1 : 1;
  }

  bar->bar_num = p.bar_num;

  tlp_header head;

  if(count == 0) {
    /* issue header */
    ++hash;
    payload_qw_end = 0; /* no payload by default */

    switch(p.kind) {
    case writeReq:
      head = mk_w32_header(p.addr, p.nBytes);
      /* aligned data expected  */
      assert((head.rw.dw0.s.len & 1) == 0);

      /* hhhhdddd, dddddddd, ... */
      nLines = (head.rw.dw0.s.len + 3)/8 + 1;

      payload_qw_end = (head.rw.dw0.s.len >> 1) + 2;
      break;

    case readReq:
      {
        static int token_counter = 0;
        const uint64_t clientId = p.bdata[0];
        token_t token = ((clientId << 4) & 0xFF) | (token_counter++ & 0xF);
        rreq_item_t item = {.token = token,
                            .clientId = clientId,
                            .nBytes = p.bdata[1]};

        rreq_item_t *ptr_item = malloc(sizeof(rreq_item_t));
        *ptr_item = item;

        rreq_insert(ptr_item);

        head = mk_r32_header(p.addr, p.nBytes, token);
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
    memcpy(ast->data + 4, p.bdata, 16);

    show_tlp_head("DN", hash, nLines, head);
  } else {
    /* payload */
    memcpy(ast->data, p.bdata + 16 + 32 * (count - 1), 32);
  }

  ast->valid = stdl_1;
  ast->sop = count == 0 ? stdl_1 : stdl_0;

  show_line256("DN", hash, ast, count, payload_qw_end);

  ++count;

  if(count == nLines) {
    count = 0;
    ast->eop = stdl_1;
  } else {
    ast->eop = stdl_0;
  }
}

void line128_down(bits_down_t *bits, uint32_t arr[4]) {
  error(1, 0, "line128_down() not implemented");
}

void line64_down(bits_down_t *bits, uint32_t arr[2]) {
  error(1, 0, "line64_down() not implemented");
}
