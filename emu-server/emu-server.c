/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */


#include <defines.h>

#include <stdlib.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <stdio.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <error.h>
#include <errno.h>
#include <argtable2.h>
#include <sys/wait.h>
#include <poll.h>

#include <emu-server.h>
#include <socket-util.h>
#include <bar-defs.h>

void init_tlp_up(char * dram_segment, size_t _dram_segsize);

/* Hardcoded BARs declaration. TODO: make configurable BARs (use config file,
   etc). */

#define DRAM_SEGSIZE (1<<28)

static const bar_t bars[] = {
  {0x1, 0, .length=1<<24, .ph_addr=0xf6000000},
  {0x1, 2, .length=1<<26, .ph_addr=0xf0000000},
  {0xF, 0, .length=DRAM_SEGSIZE, .ph_addr=0x10000000}
};

static const size_t nBars = sizeof(bars)/sizeof(bar_t);

// config parameters
const size_t qcapacity = 10;

int stdout_isatty;

static int dram_shm_fd;

struct pollfd pollfds[NSOCKS_MAX];
size_t nSocks;

int ghdl_main(int argc, char **argv);
void grt__options__help();


static void *mkshm_exclusive(const char *fname, int *fd, size_t size) {
  *fd = shm_open(fname, O_CREAT | O_EXCL | O_RDWR, 0600);

  if(*fd == -1) {
    if(errno == EEXIST) {
#if 0
      printf("shmem segment already exists; trying to re-create...\n");
#endif
      if(-1 == shm_unlink(fname))
        goto failed;

      *fd = shm_open(fname, O_CREAT | O_EXCL | O_RDWR, 0600);
        
      if(*fd == -1)
        goto failed;
    } else
      goto failed;
  }

  ftruncate(*fd, size);

  void *addr = mmap(NULL, size, PROT_WRITE | PROT_READ, MAP_SHARED, *fd, 0);

  if((void*)-1 == addr)
    goto failed;

  // reset region
  memset(addr, 0, size);

  return addr;

 failed:
  error(1, errno, "failed to create a new shmem segment");
  return NULL;
}


static void usage(void **argtable, const char *progname) {
  /* general usage */
  printf("Usage: %s [ghdl options] [-- ", progname);
  arg_print_syntaxv(stdout, argtable, "");
  printf("]\n");

  /* synopsis */
  printf("Starts emulator of VHDL design with TLP_IO interface. This is server side.\n");

  /* GHDL simulator */
  printf("\n*** GHDL simulator section\n");
  grt__options__help();

  /* emu server itself */
  printf("\n*** Emu server section\n");
  arg_print_glossary(stdout, argtable,"  %-25s %s\n");
}


int main (int argc, char **argv) {
  /* 0. Parse command line arguments */

  struct arg_lit *help = arg_lit0("h", "help", "print this help and exit");
  struct arg_end *end = arg_end(20);

  struct arg_str *id = arg_str0(NULL, "id", "<ID>", "emu server instance id");
  struct arg_lit *dbg = arg_lit0(NULL, "dbg,debug", "debug mode: do not fork() for cleanup");

  void *argtable[] = {id, dbg, help, end};

  /* 0.0. Check for '--help' global option */
  {
    struct arg_lit *gen_help = arg_lit0("h", "help", "print this help and exit");
    struct arg_end *gen_end = arg_end(20);
    void *gen_argtable[] = {gen_help, gen_end};

    arg_parse(argc, argv, gen_argtable); /* ignore any error */

    int show_usage = gen_help->count > 0;

    arg_freetable(gen_argtable, sizeof(gen_argtable)/sizeof(gen_argtable[0]));

    if(show_usage) {
      usage(/* NB: emu server's argtable, not gen_argtable */argtable, argv[0]);
      return 0;
    }
  }
  
  /* 0.1. Split args into two lists: for ghdl and for emu server itself */
  char ** const ghdl_argv = argv;
  int ghdl_argc;

  for(ghdl_argc=1; ghdl_argc<argc; ++ghdl_argc)
    if(strcmp("--", argv[ghdl_argc]) == 0) {
      break;
    }

  char ** const emus_argv = argv + ghdl_argc; /* starting from "--" */
  int emus_argc = argc - ghdl_argc;

  /* 0.2. Parse emu server args */
  {
    /* set default values */
    id->sval[0] = "0";
    
    int nerrors = arg_parse(emus_argc, emus_argv, argtable);

    /* special case: '--help' takes precedence over error reporting */
    if(help->count > 0) {
      usage(argtable, argv[0]);
      return 0;
    }

    if(nerrors > 0) {
      /* Display the error details contained in the arg_end struct.*/
      arg_print_errors(stdout, end, argv[0]);
      error(1, 0, "try '%s --help'", argv[0]);
    }
  }

  /* 0.3. make aliases */
  const char * const instanceId = id->sval[0];

  /* ... */

  arg_freetable(argtable, sizeof(argtable)/sizeof(argtable[0]));

  char pid_fname[100];
  snprintf(pid_fname, sizeof(pid_fname), "/tmp/emu.%s.pid", instanceId);

  char sock_fname[100];
  snprintf(sock_fname, sizeof(sock_fname), "/tmp/emu.%s.sock", instanceId);

  char dev_fname[100];
  snprintf(dev_fname, sizeof(dev_fname), "/tmp/emu.%s.dev", instanceId);

  char dram_fname[100];
  snprintf(dram_fname, sizeof(dram_fname), "/emu.%s.shm-dram", instanceId);

  nSocks = 1; // only a server

  stdout_isatty = isatty(fileno(stdout));

  // 1. check locks
  {
    pid_t pid = getpid(), saved_pid;
    FILE *fd = fopen(pid_fname, "r");

    if(fd != NULL) {
      if(fscanf(fd, "%d", &saved_pid) != 1)
        error(1, errno, "unknown stale pidfile %s", pid_fname);

      // check if such process exists
      char proc_pid_fname[100];
      snprintf(proc_pid_fname, 100, "/proc/%d", saved_pid);

      if(access(proc_pid_fname, F_OK) != -1)
        error(1, errno, "an instance of %s seems to be running; pidfile is %s",
              argv[0], pid_fname);

      if(unlink(pid_fname) == -1)
        error(1, errno, "failed to unlink() stale pidfile %s", pid_fname);

      unlink(sock_fname);
    }

    fd = fopen(pid_fname, "w");

    if(fd == NULL)
      error(1, errno, "failed to create a pidfile %s", pid_fname);

    fprintf(fd, "%d\n", pid);
    fclose(fd);
  }

  // 2. create shared segments

  void *dram_segstart = mkshm_exclusive(dram_fname, &dram_shm_fd, DRAM_SEGSIZE);

  FILE *fd = fopen(dev_fname, "w");

  const bar_t *b;
  for(b=bars; b<bars+nBars; ++b)
    fprintf(fd, "%X %X %lX\n", b->dev_num, b->bar_num, b->length);

  fclose(fd);

  // 3. wait for clients
  printf("Waiting for clients...\n");

  // 1. create
  int srvSock = socket(AF_UNIX, SOCK_STREAM, 0);
  if(srvSock == -1)
    error(1, errno, "socket() failed");

  // 2. bind
  struct sockaddr_un addr;
  memset(&addr, 0, sizeof(addr));
  addr.sun_family = AF_UNIX;
  strncpy(addr.sun_path, sock_fname, sizeof(addr.sun_path) - 1);
  if (bind(srvSock, (struct sockaddr *) &addr, sizeof(addr)) == -1)
    error(1, errno, "bind() failed");

  // 3. listen
  if(listen(srvSock, NSOCKS_MAX - 1) == -1)
    error(1, errno, "listen() failed");

  pollfds[0].fd = srvSock;
  pollfds[0].events = POLLIN;

  printf("going to accept...\n");
  // wait
  if(-1 == poll(pollfds, nSocks, -1))
    error(1, errno, "poll() failed");
  printf("done\n");

  acceptClient();

  printf("dram_segstart: %p\n", dram_segstart);
  // 4. init up- and downstream submodules
  init_tlp_up(dram_segstart, DRAM_SEGSIZE);

  // 5.1 run simulator
  pid_t pid = dbg->count == 0 ? fork() : 0; /* do not fork() nor cleaup in debug
                                               mode */
  if(pid == 0) {
    // disable annoying ieee asserts by default
    ghdl_argc++;
    char ** const ghdl_argv_1 = (char**)malloc(sizeof(char*)*ghdl_argc);
    ghdl_argv_1[0] = ghdl_argv[0];
    ghdl_argv_1[1] = "--ieee-asserts=disable";
    int i;
    for(i=2;i<ghdl_argc; ++i)
      ghdl_argv_1[i] = ghdl_argv[i-1];

    return ghdl_main(ghdl_argc, ghdl_argv_1);
  } else if(pid == -1)
    error(1, errno, "fork() failed");

  // 5.2 parent process case; wait for child
  int status;
  if(-1 == wait(&status))
    error(1, errno, "wait() failed");

  printf("simulator exited, status: %d, %d\n", status, WEXITSTATUS(status));

  // 6. finalize
  {
    size_t i;

    for(i=0; i<nSocks; ++i)
      if(close(pollfds[i].fd) == -1)
        error(1, errno, "socket close() failed");

    if(unlink(sock_fname) == -1)
      error(1, errno, "failed to unlink() unix socket %s", sock_fname);

    unlink(pid_fname);

    munmap(dram_segstart, DRAM_SEGSIZE);

    close(dram_shm_fd);

    shm_unlink(dram_fname);
  }

  //return retval;
  return 0;
}


void acceptClient() {
  if(nSocks >= NSOCKS_MAX)
    error(1, 0, "too many clients");

  // 4. accept
  int cliSock = accept(pollfds[0].fd, NULL, NULL);

  // 5. send
  Socket_SendValue(cliSock, qcapacity);

  Socket_SendValue(cliSock, nBars);

  size_t i;
  for(i=0; i<nBars; ++i)
    Socket_SendValue(cliSock, bars[i]);

  pollfds[nSocks].fd = cliSock;
  pollfds[nSocks].events = POLLIN;

  Socket_SendValue(cliSock, nSocks);

  printf("A client #%lu connected!\n", nSocks);
  ++nSocks;
}
