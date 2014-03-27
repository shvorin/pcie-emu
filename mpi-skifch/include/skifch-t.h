/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */

/* vim: set syntax=c et sw=4 ts=4: */

#ifndef SKIFCH_T_H
#define SKIFCH_T_H

#include <stdint.h>
#include "skifch.h"
#include "skifch1.h"
#include "skifch2.h"
#include "skifch2shm.h"

extern netaddr_t * SkifCh_rank2netaddr;
extern SkifCh ** SkifCh_rank2skifch;
extern pid_t * SkifCh_rank2pid;
//extern SkifCh ** skifchs;

typedef enum {
    SkifCh1_tag,
    SkifCh2_tag,
    SkifCh2f_tag,
    SkifCh2Shm_tag,
} SkifCh_Tag;

typedef union {
    SkifCh1 ch1; // tag = SkifCh1_tag
    SkifCh2 ch2; // tag = SkifCh2_tag or tag = SkifCh2f_tag
    SkifCh2Shm ch2shm; // tag = SkifCh2Shm_tag
} SkifCh_Union;

struct SkifCh_t {
    SkifCh_Tag tag;
    SkifCh_Union ch;
};

#endif /* SKIFCH_T_H */
