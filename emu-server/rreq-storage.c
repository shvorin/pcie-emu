/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */


#include <defines.h>

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <assert.h>

#include <rreq-storage.h>

/* FIXME: The node_t structure is for internal use only [stdlib implementation]. */
typedef struct node {
  char         *key;
  struct node  *llink, *rlink;
} node_t;


void *rreq_root = NULL;

static int rreq_cmp(const void *a, const void *b) {
  rreq_item_t *sa = (rreq_item_t*)a, *sb = (rreq_item_t*)b;

  return sa->token - sb->token;
}

rreq_item_t * rreq_find(token_t token) {
  rreq_item_t key = { .token = token };

  node_t *node = (node_t *)tfind(&key, &rreq_root, rreq_cmp);

  rreq_item_t *result = (rreq_item_t *)(node ? node->key : NULL);
  return result;
}

void rreq_insert(rreq_item_t *val) {
  tsearch(val, &rreq_root, rreq_cmp);
}

void rreq_delete(token_t token) {
 /* FIXME: who is to free memory occupied by deleted item? */

  rreq_item_t key = { .token = token };

  tdelete(&key, &rreq_root, rreq_cmp);
}
