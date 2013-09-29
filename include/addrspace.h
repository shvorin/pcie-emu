/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */

/* vim: set syntax=c et sw=4 ts=4: */

#ifndef ADDRSPACE_H
#define ADDRSPACE_H

#include <assert.h>
#include <stdio.h>
#include <stdarg.h>

#include <processid.h>


struct channel_hard_t {
  size_t seg_logsize;
  size_t head_logcapacity, body_logcapacity;
};

struct channel_soft_t {
  /* volatile */ uint64_t *seg_logsize, *head_logcapacity, *body_logcapacity;
};

typedef uint64_t dirs_vector[6];

typedef struct {
  unsigned x, y, z;
} triple_t;

typedef struct {
  enum {t3d_node, t3d_network} mode;

  /* network stuff */

  /* volatile */ uint64_t *size3_ptr;
  triple_t size3;

  dirs_vector *nodedir2PHY_o, *nodedir2PHY_i;

  /* node stuff */
  size_t ports_perNode;

  /* meaningless if mode is t3d_network */
  triple_t my_node;
  /* volatile */ uint64_t *my_node_ptr;

  /* channels (level 0) */
  size_t nPorts; /* valid ports */
  size_t nPorts_max;

  /* channels (level 1): port description */
  struct channel_hard_t down_hard, up_hard;
  struct channel_soft_t down_soft, up_soft;

  /* channels (level 2): SkifCh2  */
  size_t skifch2_cell_size;
  size_t max_pkt_nBytes;

  /* toplevel control */
  /* volatile */ uint64_t *state; /* should be used for reset */

  /* volatile */ uint64_t *top_mode;  /* should be used for top-level firmware
                                         configuration: flash, links-test,
                                         router, etc... */
  /* debug staff */

  struct {
    size_t len;
    uint64_t *data;
  } dbg_ilink, dbg_ivc;

  struct {
    size_t len; /* the length of each array */
    uint64_t *fresh, *stale;
  } dbg_credit;
} FPGA_Configuration;


/* to FPGA */

static size_t fpga_head_fifo(const FPGA_Configuration * cnf, size_t portId) {
  return portId<<cnf->down_hard.seg_logsize;
}

static size_t fpga_body_fifo(const FPGA_Configuration * cnf, size_t portId){
  return fpga_head_fifo(cnf, portId) + (1<<(cnf->down_hard.seg_logsize - 1));
}

static size_t dram_rx(const FPGA_Configuration * cnf, size_t portId) {
  return fpga_head_fifo(cnf, portId) + (1<<(cnf->down_hard.seg_logsize - 2));
}

/* to DRAM */

static size_t dram_head_fifo(const FPGA_Configuration * cnf, size_t portId) {
  return portId<<cnf->up_hard.seg_logsize;
}

static size_t dram_body_fifo(const FPGA_Configuration * cnf, size_t portId) {
  return dram_head_fifo(cnf, portId) + (1<<(cnf->up_hard.seg_logsize - 1));
}

static size_t fpga_rx(const FPGA_Configuration * cnf, size_t portId) {
  return dram_head_fifo(cnf, portId) + (1<<(cnf->up_hard.seg_logsize - 2));
}


static size_t mk_portId(const FPGA_Configuration * cnf, MsgAddress addr) {
  /* FIXME: the following hardcoded constants are to be moved to FPGA_Configuration */
  static const unsigned zMask = 15;
  static const unsigned yMask = 15 << 4;
  static const unsigned xMask = 15 << 8;

  return (((xMask & addr.node) >> 8)
          + cnf->size3.x * (((yMask & addr.node) >> 4)
                          + (zMask & addr.node) * cnf->size3.y)) * cnf->ports_perNode
    + addr.port;
}

static MsgAddress mk_MsgAddress(const FPGA_Configuration * cnf, size_t portId) {
  unsigned node = 0;

  if(t3d_network == cnf->mode) {

    size_t n = portId / cnf->ports_perNode;
    size_t n1 = n / cnf->size3.x;
    size_t n2 = n1 / cnf->size3.y;

    node += n % cnf->size3.x; node <<= 4;
    node += n1 % cnf->size3.y; node <<= 4;
    node += n2;

  } else {
#if 0
    assert(portId < cnf->ports_perNode); /* FIXME */
#endif

    node += cnf->my_node.x; node <<= 4;
    node += cnf->my_node.y; node <<= 4;
    node += cnf->my_node.z;
  }

  return (MsgAddress){portId % cnf->ports_perNode, node};
}

static netaddr_t mk_netaddr(const FPGA_Configuration * cnf, size_t portId) {
  MsgId msgId = { .addr = mk_MsgAddress(cnf, portId) };

  return msgId.id;
}

static triple_t deserial_coord(const FPGA_Configuration * cnf, size_t n) {
  /* Implementation is the same as `function deserial(n : nodeId_range) return
     coord_t` from t3d_topology.vhd */
  size_t n1 = n / cnf->size3.x;
  size_t n2 = n1 / cnf->size3.y;

   return (triple_t)
     {
       .x = n % cnf->size3.x,
       .y = n1 % cnf->size3.y,
       .z = n2
     };
}

static size_t serial_coord(const FPGA_Configuration * cnf, const triple_t *c) {
  return c->x + cnf->size3.x * (c->y + c->z * cnf->size3.y);
}


static void incr(unsigned *v, unsigned modulo) {
  *v = (*v + 1) % modulo;
}

static void decr(unsigned *v, unsigned modulo) {
  *v = (*v + modulo - 1) % modulo;
}

static size_t FPGA_Configuration_nNodes(const FPGA_Configuration *cnf) {
  return cnf->size3.x * cnf->size3.y * cnf->size3.z;
}

static void FPGA_Configuration_show(const FPGA_Configuration *cnf) {
  struct channel_hard_t const * down = &cnf->down_hard, *up = &cnf->up_hard;

  printf("%ux%ux%u, ", cnf->size3.x, cnf->size3.y, cnf->size3.z);

  if(t3d_node == cnf->mode)
    printf("%u:%u:%u", cnf->my_node.x, cnf->my_node.y, cnf->my_node.z);
  else
    printf("-:-:-");

  printf(", ppn: %ld, nPorts: %ld(%ld), max_pkt_nBytes: %ld, top_mode: 0x%lX, ",
         cnf->ports_perNode,
         cnf->nPorts, cnf->nPorts_max,
         cnf->max_pkt_nBytes,
         mock_up_mem64(cnf->top_mode));

  printf("down: %ld %ld %ld, up: %ld %ld %ld\n",
         down->seg_logsize, down->head_logcapacity, down->body_logcapacity, 
         up->seg_logsize, up->head_logcapacity, up->body_logcapacity);

  if(t3d_network == cnf->mode && cnf->nodedir2PHY_o && cnf->nodedir2PHY_i) {
    int node, d;
    for(node = 0; node < FPGA_Configuration_nNodes(cnf); ++node)
      for(d = 0; d < 6; ++d) {
        triple_t c = deserial_coord(cnf, node), c_neighbour = c;

        switch(d) {
        case 0: /* +X */
          incr(&c_neighbour.x, cnf->size3.x);
          break;

        case 1: /* +Y */
          incr(&c_neighbour.y, cnf->size3.y);
          break;

        case 2: /* +Z */
          incr(&c_neighbour.z, cnf->size3.z);
          break;

        case 3: /* -X */
          decr(&c_neighbour.x, cnf->size3.x);
          break;

        case 4: /* -Y */
          decr(&c_neighbour.y, cnf->size3.y);
          break;

        case 5: /* -Z */
          decr(&c_neighbour.z, cnf->size3.z);
          break;
        }

        size_t neighbour = serial_coord(cnf, &c_neighbour);

        int phy_o = cnf->nodedir2PHY_o[node][d], phy_i = cnf->nodedir2PHY_i[neighbour][d];
        assert((phy_o == -1) == (phy_i == -1));

        if(phy_o != -1)
          printf("(%u, %u) -> PHY(%u|%u) -> (%lu, %u)\n", node, d, phy_o, phy_i, neighbour, d);
      }
  }
}


static void FPGA_Configuration_dbg_ilink(const FPGA_Configuration *cnf) {
  int p;
  for(p=0; p<cnf->dbg_ilink.len; ++p) {
    uint64_t val = mock_up_mem64(cnf->dbg_ilink.data + p);
    uint32_t v1 = val << 32 >> 32, v2 = val >> 32;
    
    /* if(val) */
    if(v1 != v2)
      PROCESSID_DBG_PRINT(PROCESSID_WARNING, "p: %d, dbg_ilink: 0x%lX%s", p, val, v1 == v2 ? "" : ", ERROR!");
  }
}


struct my_printf_sbuf {
  size_t size;
  char *buf;
};

static int my_printf(struct my_printf_sbuf *sbuf, char *fmt, ...) {
  int r;

  va_list ap;
  va_start(ap, fmt);

  r = vsnprintf(sbuf->buf, sbuf->size, fmt, ap);

  va_end(ap);

  size_t size_written = r < 0 ? 0 : r >= sbuf->size ? sbuf->size : r;

  sbuf->buf += size_written;
  sbuf->size -= size_written;

  return r;
}

static void FPGA_Configuration_dbg_buffers(const FPGA_Configuration *cnf, int level) {
  if(!processid_check(level))
    return;

  size_t size = 1000;
  char buf[size + 1];
  struct my_printf_sbuf sbuf = {size, buf};

  my_printf(&sbuf, "\ncredit info for %ld buffers: fresh/stale:\n", cnf->dbg_credit.len);

  int p;
  for(p=0; p<cnf->dbg_credit.len; ++p) {
    uint64_t fresh = mock_up_mem64(cnf->dbg_credit.fresh + p),
      stale = mock_up_mem64(cnf->dbg_credit.stale + p);

    my_printf(&sbuf, "%ld/%ld\t", fresh, stale);
  }

  my_printf(&sbuf, "\ntx-rx=size (pktplaces) for %ld IVCs:\n", cnf->dbg_ivc.len);

  for(p=0; p<cnf->dbg_ivc.len; ++p) {
    uint64_t val = mock_up_mem64(cnf->dbg_ivc.data + p);
    uint32_t pkt_tx = val << 32 >> 32, pkt_rx = val >> 32;

    my_printf(&sbuf, "%d-%d=%d\t", pkt_tx, pkt_rx, pkt_tx - pkt_rx);
  }

  my_printf(&sbuf, "\n");
  
  /* TODO: add more debug info about buffers' state */


  PROCESSID_DBG_PRINT(level, "%s", buf);
}

#endif /* ADDRSPACE_H */
