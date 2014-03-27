/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */


#include <defines.h>

#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <error.h>
#include <errno.h>
#include <poll.h>
#include <stdarg.h>

#include <mmdev.h>
#include <socket-util.h>
#include <tlp-defs-old.h>
#include <bar-defs.h>
#include <pautina-driver.h>

typedef uint8_t token_t;

static char instanceId[20];

static size_t nBars;
static bar_t *all_bars;

static const size_t nBars_max = 16;

static size_t clientId;

typedef struct {
  uintptr_t begin, end;
  off_t offset;
  bar_t *bar;
} vmapping_t;

static vmapping_t *vmap_begin, *vmap_end;
static const size_t nVmap_max = 10;

static int sock;

static token_t rreq_token; /* a token being generated for read request */

static void vmap_init() {
  vmap_begin = malloc(sizeof(vmapping_t) * nVmap_max);
  vmap_end = vmap_begin;
}

static void vmap_finalize() {
  free(vmap_begin);
}

static vmapping_t * vmap_find(const void *ptr, int do_check) {
  uintptr_t addr = (uintptr_t)ptr;

  vmapping_t *b = vmap_begin, *e = vmap_end;

  while(e - b > 1) {
    vmapping_t *m = b + (e - b)/2;

    if(addr >= m->begin)
      b = m;
    else
      e = m;
  }

  if(do_check)
    if(!(b->begin <= addr && addr < b->end))
      return NULL;

  return b;
}

static void vmap_insert(void *ptr, size_t length, off_t offset, bar_t *bar) {
  uintptr_t addr = (uintptr_t)ptr;
  size_t nVmap = vmap_end - vmap_begin;

  if(nVmap >= nVmap_max)
    error(1, 0, "too many mappings; implemented only %d", nVmap_max);

  vmapping_t *x;

  if(nVmap == 0) {
    x = vmap_begin;
  } else {
    x = addr < vmap_begin->begin ? vmap_begin : vmap_find(ptr, 0) + 1;
    if(!x)
      error(1, 0, "vmap_insert");
    memmove(x+1, x, (vmap_end - x) * sizeof(vmapping_t));
  }

  *x = (vmapping_t) {
    .begin = addr,
    .end = addr + length,
    .offset = offset,
    .bar = bar,
  };

  ++vmap_end;
}

static void vmap_delete(void *ptr, size_t length) {
#if 1
  fprintf(stderr, "Warning: vmap_delete() not implemented yet\n");
  return;
#endif

  --vmap_end;
}

static void vmap_show() {
  vmapping_t *i;

  printf("vmapping: ");
  for(i=vmap_begin; i<vmap_end; ++i) {
    printf("(%llX %llX) ", i->begin, i->end);
  }
  printf("\n");
}


static bar_t * find_bar(size_t dev_num, size_t bar_num) {
  bar_t *b;

  for(b=all_bars; b<all_bars+nBars_max; ++b)
    if(b->dev_num == dev_num && b->bar_num == bar_num && b->length != 0)
      return b;

  return NULL; /* not found */
}

static int dev_fd = -1, dram_shm_fd = -1;


static void initialize() {
  /* guard from consequent initializations */
  static int initialized = 0;
  if(initialized)
    return;
  initialized = 1;

  /* 1. instance id */
  {
    char *id = getenv("SKIF_EMU_ID");
    snprintf(instanceId, sizeof(instanceId), "%s", id ? id : "0");
  }

  /* 2. open shmem device */
  {
    char dram_fname[100];
    snprintf(dram_fname, sizeof(dram_fname), "/emu.%s.shm-dram", instanceId);

    dram_shm_fd = shm_open(dram_fname, O_RDWR, 0600);

    if(dram_shm_fd == -1)
      error(1, errno, "shm_open() failed");
  }

  vmap_init();

  rreq_token = (token_t)getpid() << 4;
}


static void finalize() {
  close(dram_shm_fd);
  dram_shm_fd = -1;

  free(all_bars);
}

int mmdev_open(const char *pathname, int flags) {
  // arguments ignored

  initialize();

  if(dev_fd != -1)
    return dev_fd;

  char sock_fname[100];
  snprintf(sock_fname, sizeof(sock_fname), "/tmp/emu.%s.sock", instanceId);

  char pid_fname[100];
  snprintf(pid_fname, sizeof(pid_fname), "/tmp/emu.%s.pid", instanceId);

  char dev_fname[100];
  snprintf(dev_fname, sizeof(dev_fname), "/tmp/emu.%s.dev", instanceId);

  size_t qcapacity;

  size_t i;

  // 1. connect to server
  {
    // 1. create
    sock = socket(AF_UNIX, SOCK_STREAM, 0);
    if(sock == -1)
      error(1, errno, "socket() failed");

    // 1.1. reduce size of the socket send buffer
    int wmem = sizeof(TlpPacket);
    if(-1 == setsockopt(sock, SOL_SOCKET, SO_SNDBUF, &wmem, sizeof(wmem)))
      error(1, errno, "setsockopt() failed");

    // 2. connect
    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, sock_fname, sizeof(addr.sun_path) - 1);
    if (connect(sock, (struct sockaddr *) &addr, sizeof(addr)) == -1)
      error(1, errno, "connect() failed");

    // 3. recv
    {
      Socket_RecvValue(sock, qcapacity);

      Socket_RecvValue(sock, nBars);

      printf("nBars: %u\n", nBars);

      all_bars = malloc(nBars * sizeof(bar_t));

      for(i=0; i<nBars; ++i)
        Socket_RecvValue(sock, all_bars[i]);

      Socket_RecvValue(sock, clientId);
    }

#if 0
    // 4. close socket
    if(close(sock) == -1)
      error(1, errno, "close() failed");

#endif

    printf("Connected!\n");
  }

  //  read_bar_lengths(dev_fname);

  dev_fd = open(dev_fname, O_RDONLY);
  if(-1 == dev_fd)
    error(1, errno, "Failed to open %s", dev_fname);

  return dev_fd;
}

int mmdev_close(int fd) {
  if(dev_fd == -1 || fd != dev_fd) {
    errno = EBADF;
    return -1;
  }

#if 0
  close(dev_fd);
  dev_fd = -1;

#endif

  return 0;
}


static void __bput(uint8_t bar_num, uintptr_t addr, const void *src, size_t nBytes) {
  assert(0 == addr >> 32);
  tlpaddr_t tlpaddr = (tlpaddr_t)addr;

  TlpPacket p = {bar_num, writeReq, nBytes, tlpaddr};

  memcpy(p.bdata, src, nBytes);

  Socket_SendValue(sock, p);
}


static void __bget(uint8_t bar_num, void *dst, uintptr_t addr, size_t nBytes) {
  assert(0 == addr >> 32);
  tlpaddr_t tlpaddr = (tlpaddr_t)addr;

  TlpPacket p = {bar_num, readReq, nBytes, tlpaddr};

  p.bdata[0] = (uint64_t)(rreq_token++);
  p.bdata[1] = (uint64_t)clientId;
  p.bdata[2] = (uint64_t)nBytes;

  /* 1. send read request to the server */
  Socket_SendValue(sock, p);

  struct pollfd fd = {.fd = sock, .events = POLLIN};
  int ret = poll(&fd, 1, /* timeout in ms */10000);

  if(0 == ret) {
    /* no event */
    memset(dst, -1, nBytes); /* reset all dst to default value (all ones) */
    return;
  }

  if(-1 == ret || POLLIN != fd.revents)
    error(1, errno, "poll() failed");

  assert(1 == ret);

  Socket_Recv(sock, dst, nBytes);
}

void *mmdev_memcpy(void *dst, const void *src, size_t nBytes) {
  vmapping_t *vm = vmap_find(dst, 1);
  if(vmap_begin <= vm && vm < vmap_end) {
    // down_memcpy
    assert((nBytes & 3) == 0 && ((uintptr_t)dst & 3) == 0); // must be aligned

    uintptr_t dst_int = (uintptr_t)dst;
    assert(vm->begin <= dst_int && dst_int + nBytes <= vm->end);

    uint8_t bar_num = vm->bar->bar_num;

    uint8_t *bdst = (uint8_t *)(vm->bar->ph_addr + vm->offset + ((uintptr_t)dst - vm->begin));
    const uint8_t *bsrc = (const uint8_t *)src;

    while(nBytes > maxBytes_tlpPacket) {
      __bput(bar_num, (uintptr_t)bdst, bsrc, maxBytes_tlpPacket);
      nBytes -= maxBytes_tlpPacket;
      bsrc += maxBytes_tlpPacket;
      bdst += maxBytes_tlpPacket;
    }

    if(nBytes > 0)
      __bput(bar_num, (uintptr_t)bdst, bsrc, nBytes);

    return dst;
  } else {
    // up_memcpy
    vm = vmap_find(src, 1);
    assert(vmap_begin <= vm && vm < vmap_end);

    assert((nBytes & 3) == 0 && ((uintptr_t)src & 3) == 0); // must be aligned

    uintptr_t src_int = (uintptr_t)src;
    assert(vm->begin <= src_int && src_int + nBytes <= vm->end);

    uint8_t bar_num = vm->bar->bar_num;

    uint8_t *bdst = (uint8_t *)dst;
    const uint8_t *bsrc = (uint8_t *)(vm->bar->ph_addr + vm->offset + ((uintptr_t)src - vm->begin));

    while(nBytes > maxBytes_tlpPacket_read) {
      __bget(bar_num, bdst, (uintptr_t)bsrc, maxBytes_tlpPacket_read);
      nBytes -= maxBytes_tlpPacket_read;
      bsrc += maxBytes_tlpPacket_read;
      bdst += maxBytes_tlpPacket_read;
    }

    if(nBytes > 0)
      __bget(bar_num, bdst, (uintptr_t)bsrc, nBytes);

    return dst;

  }
}

void mmdev_put64 (volatile void * ptr, uint64_t value) {
  mmdev_memcpy((void *)ptr, &value, sizeof(value));
}

void mmdev_fence() {}

void *mmdev_memset(void *s, int c, size_t nBytes) {
  /* FIXME: not tested and probably slow */
  
  assert((nBytes & 3) == 0 && ((uintptr_t)s & 3) == 0); // must be aligned

  size_t i;
  
  uint64_t w = c;
  for(i=0; i<7; ++i) {
    w <<= 8;
    w |= (c & 0xFF);
  }

  for(i=0; i<(nBytes>>3); ++i) {
    mmdev_put64((uint64_t*)s + i, w);
  }

  return s;
}

uint64_t mmdev_get64 (volatile void * ptr) {
  uint64_t value;
  mmdev_memcpy(&value, (void *)ptr, sizeof(value));
  return value;
}

static int ioctl_counter = 0;

int mmdev_ioctl(int fd, unsigned long cmd, pautina_driver_ioctl_arg_t arg) {
  assert(fd == dev_fd);
  if (cmd == PAUTINA_DRIVER_BAR) { // return BAR info
    pautina_driver_bardesc_t * bardesc = (pautina_driver_bardesc_t *) arg; 
    bar_t * bar = find_bar(bardesc->dev_num, bardesc->bar_num);
    if(!bar) {
      error(1, 0, "requested BAR %u:%u not found", bardesc->dev_num, bardesc->bar_num);
      errno = ENODEV;
      return -1;
    }
    bardesc->length = bar->length;
    bardesc->write_combining = 0; /* FIXME */
    return 0;
  }
  if (cmd == PAUTINA_DRIVER_NEXT) { // return all BARS, one per ioctl call
    pautina_driver_bardesc_t * bardesc = (pautina_driver_bardesc_t *) arg;
    if (ioctl_counter == nBars) {
      memset(bardesc, 0, sizeof(*bardesc));
      ioctl_counter = 0;
    } else {
      bar_t * bar = all_bars+ioctl_counter;
      bardesc->dev_num = bar->dev_num;
      bardesc->bar_num = bar->bar_num;
      bardesc->length = bar->length;
      bardesc->write_combining = 0; /* FIXME */
      ioctl_counter++;
    }
    return 0;
  }
  if (cmd == PAUTINA_DRIVER_MTRR) { // Set MTRR flag
    pautina_driver_bardesc_t * bardesc = (pautina_driver_bardesc_t *) arg; 
    bar_t * bar = find_bar(bardesc->dev_num, bardesc->bar_num);
    if(!bar) {
      error(1, 0, "requested BAR %u:%u not found", bardesc->dev_num, bardesc->bar_num);
      errno = ENODEV;
      return -1;
    }
    //bar->write_combining = bardesc->write_combining; /* FIXME */
    return 0;
  }
  error(1, 0, "incorrect ioctl %d", cmd);
  errno = ENOTTY;
  return -1;
}

void *mmdev_mmap(void *addr, size_t length, int prot, int flags, int fd, off_t offset) {
  assert(fd == dev_fd);
  assert(prot == PROT_READ | PROT_WRITE);
  assert(flags == MAP_SHARED);
  
  size_t dev_num = PAUTINA_DRIVER_DEV_NUM(offset);
  size_t bar_num = PAUTINA_DRIVER_BAR_NUM(offset);
  off_t off =  PAUTINA_DRIVER_OFFSET(offset); /* local offset in the BAR */

  bar_t *bar = find_bar(dev_num, bar_num);
  if(!bar)
    error(1, 0, "requested BAR %u:%u not found", dev_num, bar_num);

  if(off + length > bar->length)
    error(1, 0, "requested BAR's length is not sufficient");

  void *ptr;

  if(dev_num == PAUTINA_DRIVER_DEV_MEM) {
    if(bar_num != 0)
      error(1, 0, "multiple memory BARs not implemented");

    ptr = mmap(addr, length, PROT_WRITE | PROT_READ, MAP_SHARED, dram_shm_fd, off);
    if(MAP_FAILED == ptr)
      error(1, errno, "failed to mmap() shared dram region");
  } else {
    ptr = mmap(addr, length, PROT_NONE,
               MAP_PRIVATE | MAP_ANONYMOUS | MAP_NORESERVE, -1, 0);

    if(MAP_FAILED == ptr)
      error(1, errno, "'dummy' mmap() failed");

    vmap_insert(ptr, length, off, bar);
  }

#if 0
  printf("mmdev_mmap dev: %d, bar: %d\n", dev_num, bar_num);
  vmap_show();
#endif

  return ptr;
}

int mmdev_munmap(void *addr, size_t length) {
  vmap_delete(addr, length);

  return munmap(addr, length);
}
