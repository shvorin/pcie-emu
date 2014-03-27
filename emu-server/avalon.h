/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */

#ifndef AVALON_H
#define AVALON_H

#include <ghdl-bindings.h>

typedef struct {
  std_logic dvalid;
  std_logic sop, eop;
  std_logic ej_ready;
} bits_down_t;

typedef struct {
  uint32_t data[8];
  std_logic valid, sop, eop;
  std_logic empty[2];
} ast256_t;

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

#endif /* AVALON_H */
