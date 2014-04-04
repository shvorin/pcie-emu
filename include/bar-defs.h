/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */

#ifndef BAR_DEFS_H
#define BAR_DEFS_H

#include <stddef.h>
#include <stdint.h>


typedef struct {
  uint8_t dev_num, bar_num;
  size_t length;
  uintptr_t ph_addr;
} bar_t;


#endif /* BAR_DEFS_H */
