/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */

#include <defines.h>

#include <stdio.h>
#include <stdarg.h>

#include <avalon.h>

int bufprintf(streambuf_t *sbuf, const char *fmt, ...) {
  const int size = sbuf->end - sbuf->curr;
  if(size < 0) return 0;

  va_list ap;
  va_start(ap, fmt);
  const int res = vsnprintf(sbuf->curr, size, fmt, ap);
  va_end(ap);

  if(res < 0) return res;

  sbuf->curr += (res >= size ? size : res);
  return res;
}


void bufshow_line256(streambuf_t *sbuf, const ast256_t *ast, size_t line_count, size_t payload_qw_end) {
  char *fmt;
  int i;
  for(i=0;i<4;++i) {
    const size_t payload_qw_cnt = line_count * 4 + i;
    if (payload_qw_cnt < 2 && stdout_isatty) {
      /* TLP head */
      fmt = "\e[0;31m%016lX \e[0m";
    } else if(payload_qw_cnt < payload_qw_end && stdout_isatty) {
      /* TLP payload  */
      fmt = "\e[0;32m%016lX \e[0m";
    } else {
      fmt = "%016lX ";
    }

    bufprintf(sbuf, fmt, *((uint64_t*)(ast->data+2*i)));
  }
}

void bufshow_tlp_head(streambuf_t *sbuf, size_t nLines, tlp_header head) {
  const int len = head.rw.dw0.s.len & 0x3FF; /* len:10 */
  const int bc = len << 2; /* byte count */

  switch(parse_type(head)) {
  case tlp_kind_write:
    bufprintf(sbuf, "kind_write, nLines: %lu, addr: 0x%08lX+%X" /* NB: 32-bit addr is usually used */,
                 nLines, head.rw.rawaddr, bc);
    break;

  case tlp_kind_cpl:
    bufprintf(sbuf, "kind_cpl, nLines: %lu, low_addr: 0x%02X+%X, cpl_tag: 0x%02X",
           nLines, head.cpl.dw2.s.low_addr & 0x7F, bc, head.cpl.dw2.s.tag & 0xFF);
    break;

  case tlp_kind_read:
    bufprintf(sbuf, "kind_read, nLines: %lu, addr: 0x%08lX+%X, cpl_tag: 0x%02X",
           nLines, head.rw.rawaddr, bc, head.rw.dw1.s.tag & 0xFF);
    break;

  default:
    bufprintf(sbuf, "kind_unknown");
  }

  bufprintf(sbuf, " ");
}
