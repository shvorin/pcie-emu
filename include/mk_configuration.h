/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */

/* vim: set syntax=c et sw=4 ts=4: */

#ifndef MK_CONFIGURATION_H
#define MK_CONFIGURATION_H

#include <cclasses.h>
#include <ccid-defs.h>
#include <addrspace.h>


static FPGA_Configuration mk_FPGA_Configuration(void * ctrl_storage) {
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
    error(1, 0, "Failed to read from ctrl BAR");

  ctrl_is_ok: ;
  }

  char *ptr[1] = { (char*)ctrl_storage };
  cc_desc_t x;

  /* 2. check the first class is Base */
  {
    x = next_cc(ptr);
    if(x.ccid != CCID_Base)
      error(1, 0, "The very first class is not Base; incompatible firmware");
  }


  cc_desc_t cc_desc_begin[100]/* FIXME: fixed size array used */,
    *cc_desc_end = cc_desc_begin;

  cc_desc_t *search(uint64_t ccid) {
    cc_desc_t *i;
    for(i=cc_desc_begin; i<cc_desc_end; ++i)
      if(i->ccid == ccid)
        return i;

    return NULL;
  }

  FPGA_Configuration cnf_new, cnf_old;


  /* 3. walk through class list */
  do {
    printf("0x%llX %s v.%d\n", x.ccid, ccid2name(x.ccid) ?: "<unknown>", x.ccver);

    *cc_desc_end++ = x;

    /* FIXME: this should be more specific for each class */
    char buf[x.size];
    mock_up_memcpy(&buf, x.data, sizeof(buf));

    /* TODO: assert x.size is ok for any class */

    switch(x.ccid) {
    case CCID_Control:
      {
        cnf_new.state = (/* volatile */ uint64_t*)(x.data);
      } break;

    case CCID_PortDesc:
      {
        uint64_t *n0 = (uint64_t *)buf, *n = n0;

        struct channel_hard_t *h;
        struct channel_soft_t *s;

        /* volatile */ uint64_t *next_ptr() {
          return (/* volatile */ uint64_t*)(x.data + sizeof(uint64_t) * (n++ - n0));
        }

        h = &cnf_new.down_hard;
        h->seg_logsize = *n++;
        h->head_logcapacity = *n++;
        h->body_logcapacity = *n++;

        s = &cnf_new.down_soft;
        s->seg_logsize = next_ptr();
        s->head_logcapacity = next_ptr();
        s->body_logcapacity = next_ptr();

        h = &cnf_new.up_hard;
        h->seg_logsize = *n++;
        h->head_logcapacity = *n++;
        h->body_logcapacity = *n++;

        s =  &cnf_new.up_soft;
        s->seg_logsize = next_ptr();
        s->head_logcapacity = next_ptr();
        s->body_logcapacity = next_ptr();
      } break;

    case CCID_T3d_Network:
      {
        uint64_t *n = (uint64_t *)buf;

        cnf_new.ports_perNode = *n++;
        cnf_new.xSize = *n++;
        cnf_new.ySize = *n++;
        cnf_new.zSize = *n++;

        cnf_new.my_node = NULL;
        cnf_new.mode = t3d_network;
      } break;

    case CCID_Channels:
      {
        uint64_t *n = (uint64_t *)buf;

        cnf_new.nPorts_max = 1 << *n++;
        cnf_new.nPorts = *n++;
      }
      break;

    case CCID_SkifCh2:
      {
        uint64_t *n = (uint64_t *)buf;
        
        if(x.ccver >= 2) 
          cnf_new.max_pkt_nBytes = *n++;
        else {
          cnf_new.max_pkt_nBytes = 128 * 8;
          printf("WARNING: version of class %s is not capable to set max_pkt_nBytes. Set ad hoc to %d bytes.\n", ccid2name(x.ccid), cnf_new.max_pkt_nBytes);
        }

        cnf_new.skifch2_cell_size = 1 >> *n++;
      } break;
      
      
    case CCID_T3d_Node:
      {
        uint64_t *n0 = (uint64_t *)buf, *n = n0;

        cnf_new.ports_perNode = *n++;
        cnf_new.xSize = *n++;
        cnf_new.ySize = *n++;
        cnf_new.zSize = *n++;

        cnf_new.my_node = (/* volatile */ uint64_t*)(x.data + sizeof(uint64_t) * (n++ - n0));

        cnf_new.mode = t3d_node;
      } break;

    case CCID_Issue:
      {
        char *url = buf;
        char *rev = url + (strlen(url) + 1 + 7)/8*8;
        char *comment = rev + (strlen(rev) + 1 + 7)/8*8;

        printf("%.200s\n", comment);
      } break;

    case CCID_T3d_OldConf:
      {
#pragma pack(push,1)
        struct {
          /* flit 0 */
          size_t zSize : 5;
          size_t ySize : 5;
          size_t xSize : 5;
          int : 1;
          //
          size_t ports_perNode : 16;
          //
          size_t nPorts : 16;
          //
          size_t max_pktlen: 16;

          /* flit 1 */
          size_t fpga_head_logcapacity : 8;
          size_t fpga_body_logcapacity : 8;
          size_t dram_head_logcapacity : 8;
          size_t dram_body_logcapacity : 8;
          size_t fpga_seg_logsize : 8;
          size_t dram_seg_logsize : 8;
          int : 16;
        } *oldconf = (typeof(oldconf))buf;
        /* NB: sizeof(struct ) must be 16, see r2370 */
#pragma pack(pop)

        cnf_old = (FPGA_Configuration) {
          .xSize = oldconf->xSize,
          .ySize = oldconf->ySize,
          .zSize = oldconf->zSize,
          
          .ports_perNode = oldconf->ports_perNode,
          .nPorts = oldconf->nPorts,

          .nPorts_max = 16,

          .max_pkt_nBytes = oldconf->max_pktlen * (x.ccver >= 2 ? 8 : 1),

          .skifch2_cell_size = 8,
          
          .down_hard = {oldconf->fpga_seg_logsize,
                        oldconf->fpga_head_logcapacity,
                        oldconf->fpga_body_logcapacity},
          .up_hard = {oldconf->dram_seg_logsize,
                      oldconf->dram_head_logcapacity,
                      oldconf->dram_body_logcapacity},
          
          .down_soft = {NULL, NULL, NULL},
          .up_soft = {NULL, NULL, NULL},

          .state = (/* volatile */ uint64_t*)((char*)x.data + sizeof(*oldconf))
        };
      } break;
    }
  } while((x = next_cc(ptr)).ccid);

  int has_new = 0, has_old = 0;

  if(search(CCID_T3d_OldConf))
    has_old = 1;

  if(search(CCID_Control)
     && search(CCID_PortDesc)
     && search(CCID_Channels)
     && search(CCID_SkifCh2)
     && (search(CCID_T3d_Network) || search(CCID_T3d_Node)))
    has_new = 1;

  enum {unknown, t3d_old, t3d_new}
  configured =
#if 1
    /* prefer new config */
    has_new ? t3d_new : has_old ? t3d_old : unknown;
#else
    /* prefer old config */
    has_old ? t3d_old : has_new ? t3d_new : unknown;
#endif

  FPGA_Configuration *cnf;

  switch(configured) {
  case unknown:
    error(1, 0, "configuration classes not found");
    break;

  case t3d_old:
    printf("T3d_OldConf used for configuration\n");
    cnf = &cnf_old;
    break;

  case t3d_new:
    printf("New classes used for configuration\n");
    cnf = &cnf_new;

    break;
  }

  show_FPGA_Configuration(cnf);

  return *cnf;
}


#endif /* MK_CONFIGURATION_H */
