/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */

#ifndef AVALON_H
#define AVALON_H

#include <ghdl-bindings.h>
#include <tlp-defs.h>
#include <stdint.h>


typedef struct {
  std_logic dvalid;
  std_logic sop, eop;
  std_logic ej_ready;
} bits_down_t;

typedef struct {
  uint32_t data[8];
  std_logic valid;
  /* NB: vectors reversed by VHDL emu toplevel, so sop[0] in this C-structure is mapped to
     sop(0) in VHDL-structure, and so on */
  std_logic sop[2], eop[2], empty[2];
} ast256_t;

/* multipacket version */
typedef struct {
  struct {
    uint32_t data[4];
    std_logic sop, eop, empty;
  } lo, hi;
  std_logic valid;
} ast256mp_t;

typedef struct {
  std_logic ready;
} ast_bp_t;

typedef struct {
  uint32_t bar_num;
} line_down_scalars_t;

void init_tlp_up(char * dram_segment, size_t _dram_segsize);

void line64_down(bits_down_t *bits, uint32_t arr[2]);
void line64_up(std_logic tx_dvalid, const uint32_t arr[2]);

void line128_down(bits_down_t *bits, uint32_t arr[4]);
void line128_up(std_logic tx_dvalid, const uint32_t arr[4]);

void line256_down(line_down_scalars_t *bar, ast256_t *ast, ast_bp_t *ast_bp);
void line256_up(const ast256_t *ast);

void line256mp_down(line_down_scalars_t *bar, ast256mp_t *ast, ast_bp_t *ast_bp);
void line256mp_up(const ast256mp_t *ast);

typedef struct {
  char * const start;
  const char * const end;
  char *curr;
} streambuf_t;

static void bufrewind(streambuf_t *sbuf) {
  sbuf->curr = sbuf->start;
}

int bufprintf(streambuf_t *sbuf, const char *fmt, ...);
void bufshow_line256(streambuf_t *sbuf, const ast256_t *ast, size_t line_count, size_t payload_qw_end);
void bufshow_tlp_head(streambuf_t *sbuf, size_t nLines, tlp_header head);

#endif /* AVALON_H */
