/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */

/* vim: set syntax=c et sw=4 ts=4: */

#ifndef ADDRSPACE_H
#define ADDRSPACE_H


struct channel_hard_t {
  size_t seg_logsize;
  size_t head_logcapacity, body_logcapacity;
};

struct channel_soft_t {
  /* volatile */ uint64_t *seg_logsize, *head_logcapacity, *body_logcapacity;
};

typedef struct {
  enum {t3d_node, t3d_network} mode;

  /* network staff */
  size_t xSize, ySize, zSize;

  /* node staff */
  size_t ports_perNode;
  /* volatile */ uint64_t *my_node; /* meaningless if mode is t3d_network */

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
} FPGA_Configuration;


static void show_FPGA_Configuration(FPGA_Configuration *cnf) {
  struct channel_hard_t *down = &cnf->down_hard, *up = &cnf->up_hard;

  printf("%ldx%ldx%ld, ppn: %ld, nPorts: %ld(%ld), max_pkt_nBytes: %d, ",
         cnf->xSize, cnf->ySize, cnf->zSize,
         cnf->ports_perNode,
         cnf->nPorts, cnf->nPorts_max,
         cnf->max_pkt_nBytes);

  printf("down: %ld %ld %ld, up: %ld %ld %ld\n",
         down->seg_logsize, down->head_logcapacity, down->body_logcapacity, 
         up->seg_logsize, up->head_logcapacity, up->body_logcapacity);
}


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
          + cnf->xSize * (((yMask & addr.node) >> 4)
                          + (zMask & addr.node) * cnf->ySize)) * cnf->ports_perNode
    + addr.port;
}

static MsgAddress mk_MsgAddress(const FPGA_Configuration * cnf, size_t portId) {
  size_t n = portId / cnf->ports_perNode;
  size_t n1 = n / cnf->xSize;
  size_t n2 = n1 / cnf->ySize;

  unsigned node = 0;

  node += n % cnf->xSize; node <<= 4;
  node += n1 % cnf->ySize; node <<= 4;
  node += n2;

  MsgAddress addr = {portId % cnf->ports_perNode, node};

  return addr;
}

static netaddr_t mk_netaddr(const FPGA_Configuration * cnf, size_t portId) {
  MsgId msgId = { .addr = mk_MsgAddress(cnf, portId) };

  return msgId.id;
}

#endif /* ADDRSPACE_H */
