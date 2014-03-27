/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */

#ifndef RREQ_STORAGE_H
#define RREQ_STORAGE_H

#include <search.h>

typedef uint8_t token_t; /* tag in TLP-header is 8 bits width, see in tlp-defs.h */

typedef struct {
  token_t token; /* this is key */
  size_t clientId;
  size_t nBytes;
} rreq_item_t;

rreq_item_t * rreq_find(token_t token);
void rreq_insert(rreq_item_t *val);
void rreq_delete(token_t token);


#endif /* RREQ_STORAGE_H */
