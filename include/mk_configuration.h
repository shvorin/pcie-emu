/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */

/* vim: set syntax=c et sw=4 ts=4: */

#ifndef MK_CONFIGURATION_H
#define MK_CONFIGURATION_H

#include <stdlib.h>
#include <cclasses.h>
#include <ccid-defs.h>
#include <addrspace.h>
#include "processid.h"

static int update_register(uint64_t *ptr, uint64_t v) {
  mock_down_mem64(ptr, v);

  int i;
  for(i=0; i<10; ++i) {
    if(mock_up_mem64(ptr) == v)
      return 0;

    usleep(1);
  }

  fprintf(stderr, "Failed to update a register in FPGA\n");
  errno = EIO;
  return -1;
}

static uint64_t pack_triple(triple_t triple) {
#pragma pack(push,1)

  union {
    uint64_t ival;

    struct {
      unsigned x : 8, y : 8, z : 8;
      uint64_t : 40;
    } sval;
  } u = {.sval = {triple.x, triple.y, triple.z}};

#pragma pack(pop)

  return u.ival;
}

static triple_t unpack_triple(uint64_t v) {
#pragma pack(push,1)

  union {
    uint64_t ival;

    struct {
      unsigned x : 8, y : 8, z : 8;
      uint64_t : 40;
    } sval;
  } u = {.ival = v};

#pragma pack(pop)

  return (triple_t){u.sval.x, u.sval.y, u.sval.z};
}

static cc_desc_t *search(uint64_t ccid, cc_desc_t * cc_desc_begin, cc_desc_t * cc_desc_end) {
  cc_desc_t *i;
  for(i=cc_desc_begin; i<cc_desc_end; ++i)
    if(i->ccid == ccid)
      return i;

  return NULL;
}

/* return code: 0 is ok, -1 is error */
static int FPGA_Configuration_create(FPGA_Configuration *cnf, void * ctrl_storage) {
  /* 0. preset some values */
  {
    cnf->dbg_ilink.len = cnf->dbg_credit.len = cnf->dbg_ivc.len = 0;
  }

  /* 1. check that device is ready; wait for a while if necessary */
  {
    int i;
    for(i=0; i<1000; ++i) {
      uint64_t w = ~0LL;
      mock_up_memcpy(&w, ctrl_storage, sizeof(w));

      if(w != ~0LL)
        goto ctrl_is_ok;

      usleep(1);
    }

    fprintf(stderr, "Failed to read from ctrl BAR\n");
    errno = EIO;
    return -1;

  ctrl_is_ok: ;
  }

  char *ptr[1] = { (char*)ctrl_storage };
  cc_desc_t x;

  /* 2. check the first class is Base */
  {
    x = next_cc(ptr);
    if(x.ccid != CCID_Base) {
      fprintf(stderr, "The very first class is not Base; incompatible firmware\n");
      errno = EIO;
      return -1;
    }
  }

  cc_desc_t cc_desc_begin[100]/* FIXME: fixed size array used */,
    *cc_desc_end = cc_desc_begin;

  /* 3. walk through class list */
  do {
    PROCESSID_DBG_PRINT(PROCESSID_INFO, "0x%lX %s v.%ld", x.ccid, ccid2name(x.ccid) ?: "<unknown>", x.ccver);

    *cc_desc_end++ = x;

    /* FIXME: this should be more specific for each class */
    char buf[x.size];
    mock_up_memcpy(&buf, x.data, sizeof(buf));

    /* TODO: assert x.size is ok for any class */

    switch(x.ccid) {
    case CCID_Control:
      {
        switch(x.ccver) {
        case 4:
          cnf->state = (/* volatile */ uint64_t*)(x.data);
          /* TODO: ensure than OperationMode class presents */
          break;

        case 2:
          cnf->top_mode  = (/* volatile */ uint64_t*)(x.data);
          cnf->state = (/* volatile */ uint64_t*)(x.data) + 1;
          break;

        default:
          fprintf(stderr, "unsupported version of Control\n");
          errno = ENOTSUP;
          return -1;
        }
      } break;

    case CCID_OperationMode:
      {
        cnf->top_mode  = (/* volatile */ uint64_t*)(x.data);
      } break;

    case CCID_PortDesc:
      {
        uint64_t *n0 = (uint64_t *)buf, *n = n0;

        struct channel_hard_t *h;
        struct channel_soft_t *s;

        h = &cnf->down_hard;
        h->seg_logsize = *n++;
        h->head_logcapacity = *n++;
        h->body_logcapacity = *n++;

        s = &cnf->down_soft;
        s->seg_logsize = (/* volatile */ uint64_t*)(x.data + sizeof(uint64_t) * (n++ - n0));
        s->head_logcapacity = (/* volatile */ uint64_t*)(x.data + sizeof(uint64_t) * (n++ - n0));
        s->body_logcapacity = (/* volatile */ uint64_t*)(x.data + sizeof(uint64_t) * (n++ - n0));

        h = &cnf->up_hard;
        h->seg_logsize = *n++;
        h->head_logcapacity = *n++;
        h->body_logcapacity = *n++;

        s =  &cnf->up_soft;
        s->seg_logsize = (/* volatile */ uint64_t*)(x.data + sizeof(uint64_t) * (n++ - n0));
        s->head_logcapacity = (/* volatile */ uint64_t*)(x.data + sizeof(uint64_t) * (n++ - n0));
        s->body_logcapacity = (/* volatile */ uint64_t*)(x.data + sizeof(uint64_t) * (n++ - n0));
      } break;

    case CCID_T3d_Network:
      {
        uint64_t *n0 = (uint64_t *)buf, *n = n0;

        if(x.ccver != 4)
          PROCESSID_DBG_PRINT(PROCESSID_WARNING, "T3d_Network v.4 required; otherwise size3 setting not supported");
        else {

          cnf->size3_ptr = (/* volatile */ uint64_t*)(x.data + sizeof(uint64_t) * (n++ - n0));
          cnf->size3 = unpack_triple(mock_up_mem64(cnf->size3_ptr));

          cnf->ports_perNode = *n++;

          size_t nNodes = cnf->size3.x * cnf->size3.y * cnf->size3.z;

          cnf->my_node_ptr = NULL;

          if(x.ccver >= 2) {
            cnf->nodedir2PHY_o = (dirs_vector *)malloc(sizeof(dirs_vector) * nNodes);
            cnf->nodedir2PHY_i = (dirs_vector *)malloc(sizeof(dirs_vector) * nNodes);

            int node, d;
            for(node = 0; node < nNodes; ++node)
              for(d = 0; d < 6; ++d)
                cnf->nodedir2PHY_o[node][d] = *n++;

            for(node = 0; node < nNodes; ++node)
              for(d = 0; d < 6; ++d)
                cnf->nodedir2PHY_i[node][d] = *n++;
          } else {
            cnf->nodedir2PHY_i = cnf->nodedir2PHY_o = NULL;
          }
        }

        cnf->mode = t3d_network;
      } break;

    case CCID_Channels:
      {
        uint64_t *n = (uint64_t *)buf;

        cnf->nPorts_max = 1 << *n++;
        cnf->nPorts = *n++;
      }
      break;

    case CCID_SkifCh2:
      {
        uint64_t *n = (uint64_t *)buf;
        
        if(x.ccver >= 2) 
          cnf->max_pkt_nBytes = *n++;
        else {
          cnf->max_pkt_nBytes = 128 * 8;
          PROCESSID_DBG_PRINT(PROCESSID_WARNING, "version of class %s is not capable to set max_pkt_nBytes. Set ad hoc to %ld bytes.", ccid2name(x.ccid), cnf->max_pkt_nBytes);
        }

        cnf->skifch2_cell_size = 1 >> *n++;
      } break;
      
      
    case CCID_T3d_Node:
      {
        uint64_t *n0 = (uint64_t *)buf, *n = n0;

        if(x.ccver != 4)
          PROCESSID_DBG_PRINT(PROCESSID_WARNING, "T3d_Node v.4 required; otherwise size3 setting not supported");
        else {

          cnf->size3_ptr = (/* volatile */ uint64_t*)(x.data + sizeof(uint64_t) * (n++ - n0));
          cnf->size3 = unpack_triple(mock_up_mem64(cnf->size3_ptr));

          cnf->ports_perNode = *n++;

          cnf->my_node_ptr = (/* volatile */ uint64_t*)(x.data + sizeof(uint64_t) * (n++ - n0));
          cnf->my_node = unpack_triple(mock_up_mem64(cnf->my_node_ptr));
        }

        cnf->mode = t3d_node;
      } break;

    case CCID_Issue:
      {
        char *url = buf;
        char *rev = url + (strlen(url) + 1 + 7)/8*8;
        char *comment = rev + (strlen(rev) + 1 + 7)/8*8;

        PROCESSID_DBG_PRINT(PROCESSID_INFO, "%.200s", comment);
      } break;

    case CCID_Dbg_ILink:
      {
        uint64_t *n0 = (uint64_t *)buf, *n = n0;

        switch (x.ccver) {
        case 1:
          /* FIXME: Dbg_ILink is expected to be _after_ T3d_Node or T3d_Network */
          cnf->dbg_ilink.len = t3d_network == cnf->mode
            ? FPGA_Configuration_nNodes(cnf) * /* dirs */6
            : /* dirs */6;
          break;

        case 2:
          cnf->dbg_ilink.len = *n++;
          break;

        default:
          fprintf(stderr, "unsupported version of Dbg_ILink: %ld\n", x.ccver);
          errno = ENOTSUP;
          return -1;
        }

        cnf->dbg_ilink.data = (/* volatile */ uint64_t*)(x.data + sizeof(uint64_t) * (n++ - n0));
      } break;

    case CCID_Dbg_IVC:
      {
        uint64_t *n0 = (uint64_t *)buf, *n = n0;

        switch (x.ccver) {
        case 1:
          cnf->dbg_ivc.len = *n++;
          break;

        default:
          fprintf(stderr, "unsupported version of Dbg_ILink: %ld\n", x.ccver);
          errno = ENOTSUP;
          return -1;
        }

        cnf->dbg_ivc.data = (/* volatile */ uint64_t*)(x.data + sizeof(uint64_t) * (n++ - n0));
      } break;

    case CCID_Dbg_Credit:
      {
        uint64_t *n0 = (uint64_t *)buf, *n = n0;

        switch (x.ccver) {
        case 1:
          /* FIXME: Dbg_ILink is expected to be _after_ T3d_Node or T3d_Network */
          cnf->dbg_credit.len = t3d_network == cnf->mode
            ? FPGA_Configuration_nNodes(cnf) * (6 + cnf->ports_perNode)
            : 6 + cnf->ports_perNode;
          break;

        case 2:
          cnf->dbg_credit.len = *n++;
          break;

        default:
          fprintf(stderr, "unsupported version of Dbg_Credit: %ld\n", x.ccver);
          errno = ENOTSUP;
          return -1;
        }

        /* FIXME: Dbg_ILink is expected to be _after_ T3d_Node or T3d_Network */
        cnf->dbg_credit.fresh = (/* volatile */ uint64_t*)(x.data + sizeof(uint64_t) * (n++ - n0));
        cnf->dbg_credit.stale = cnf->dbg_credit.fresh + cnf->dbg_credit.len;
      } break;
    }

#ifdef EMU
    /* FIXME: this tricky workaroud is needed since subBAR #1 is treated by the
       toplevel entity, so is unavalable in EMU mode. */
    switch(x.ccid) {
    case CCID_meta_align_0:
      cnf->top_mode = cnf->state; /* FIXME: may it hurt? */
      goto break_loop;
    }
#endif
  } while((x = next_cc(ptr)).ccid);

 break_loop:

  if(!(search(CCID_Control, cc_desc_begin, cc_desc_end)
       && search(CCID_PortDesc, cc_desc_begin, cc_desc_end)
       && search(CCID_Channels, cc_desc_begin, cc_desc_end)
       && search(CCID_SkifCh2, cc_desc_begin, cc_desc_end)
       && (search(CCID_T3d_Network, cc_desc_begin, cc_desc_end) || search(CCID_T3d_Node, cc_desc_begin, cc_desc_end))))
    {
      fprintf(stderr, "required configuration classes not found\n");
      errno = ENOTSUP;
      return -1;
    }

  return 0;
}


static int FPGA_Configuration_setup(FPGA_Configuration *cnf, triple_t size3, triple_t my_node) {
  switch(cnf->mode) {
  case t3d_node:
    {
      cnf->size3 = size3;
      cnf->my_node = my_node;

      if(update_register(cnf->size3_ptr, pack_triple(size3)) < 0) goto error;
      if(update_register(cnf->my_node_ptr, pack_triple(my_node)) < 0) goto error;
    } break;

  case t3d_network:
    {
      /* cnf->size3 has already been initialized */
      if(pack_triple(cnf->size3) != pack_triple(size3))
        printf("WARNING: the required network size does not match built-in size\n");

      /* my_node ignored */
    } break;
  }

  return 0;

 error:
  return -1;
}


static void FPGA_Configuration_reset(FPGA_Configuration *cnf) {
  mock_down_mem64(cnf->state, 0);
}

#endif /* MK_CONFIGURATION_H */
