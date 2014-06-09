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
#include <assert.h>
#include <argtable2.h>
#include <sys/wait.h>
#include <pollpull.h>

#include <emu-server.h>
#include <socket-util.h>
#include <bar-defs.h>
#include <emu-common.h>
#include <grp.h>


#define ERROR(status, errnum, ...)                                  \
  do {                                                              \
    error_at_line(status, errnum, __FILE__, __LINE__, __VA_ARGS__); \
  } while(0)

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

struct emu_config_t emu_config = {
  .instanceId = "0",
  .qcapacity = 10, /* ad hoc */
  .colorized_output = 0,
  .tlp_quiet = 0,
  .keep_alive = 0,
  .no_pautina_config = 0,
};

static int dram_shm_fd;

int ghdl_main(int argc, char **argv);
void grt__options__help();


static void *mkshm_exclusive(const char *fname, int *fd, size_t size) {
  umask(0012);
  mode_t mode = 0660;

  *fd = shm_open(fname, O_CREAT | O_EXCL | O_RDWR, mode);

  if(*fd == -1) {
    if(errno == EEXIST) {
#if 0
      printf("shmem segment already exists; trying to re-create...\n");
#endif
      if(-1 == shm_unlink(fname))
        goto failed;

      *fd = shm_open(fname, O_CREAT | O_EXCL | O_RDWR, mode);
        
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
  ERROR(1, errno, "failed to create a new shmem segment");
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

static pid_t pid_pc = 0;

static void exec_pautina_config(const char *instanceId) {
  if(emu_config.no_pautina_config) {
    pid_pc = 0;
    return;
  }

  const pid_t pid = fork();
  if(pid == 0) {
    setenv("EMU", "", 0);
    setenv("EMU_HIDDEN", "", 0);
    setenv("EMU_ID", instanceId, 1);
    const char path[] = "../../fpga-software/bin/pautina-config"; /* FIXME: ad hoc */
    int res = execl(path, path, "-c", "-A", "0x10000000", "-L", "0x10000000", "-p", "1", "-s", "1", (char*)NULL);
    if(-1 == res)
      error(1, errno, "exec failed");
  } else if(pid == -1)
    error(1, errno, "fork() failed");

   pid_pc = pid;
}

static void kill_pautina_config() {
  if(!pid_pc)
    return;

  int res, status;
  res = kill(pid_pc, SIGTERM);
  if(-1 == res)
    error(1, errno, "kill pautina-config failed, pid_pc: %d\n", pid_pc);

  const pid_t pid_cld = wait(&status);
  if(pid_cld != pid_pc)
    error(1, errno, "wait for pautina-config failed, pid_pc: %d, pid_cld: %d\n", pid_pc, pid_cld);
}


int main (int argc, char **argv) {
  /* 0. Parse command line arguments */

  struct arg_lit *help = arg_lit0("h", "help", "print this help and exit");
  struct arg_end *end = arg_end(20);

  struct arg_str *id = arg_str0(NULL, "id", "<ID>", "emu server instance id");
  struct arg_lit *dbg = arg_lit0(NULL, "dbg,debug", "debug mode: do not fork() for cleanup");
  struct arg_rex *color = arg_rex0(NULL, "color", "\\(^never$\\)\\|\\(^always$\\)\\|\\(^auto&\\)", "never|always|auto", 0, "colorized output");
  struct arg_lit *quiet = arg_lit0("q", "quiet", "do not show TLP stream");
  struct arg_lit *keep_alive = arg_lit0(NULL, "keep-alive", "keep running after last client hung up");
  struct arg_lit *no_pautina_config = arg_lit0(NULL, "no-pautina-config", "do not spawn pautina-config on startup");

  void *argtable[] = {id, dbg, color, quiet, keep_alive, no_pautina_config, help, end};

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
      printf("try '%s --help'", argv[0]);
      return 1;
    }

    if(color->count > 0) {
      const char *col_string = color->sval[color->count - 1];
      if(0 == strcmp(col_string, "never"))
        emu_config.colorized_output = 0;
      else if(0 == strcmp(col_string, "always"))
        emu_config.colorized_output = 1;
      else if(0 == strcmp(col_string, "auto"))
        emu_config.colorized_output = isatty(fileno(stdout));
    } else {
      /* auto by default */
      emu_config.colorized_output = isatty(fileno(stdout));
    }

    emu_config.tlp_quiet = quiet->count > 0;
    emu_config.keep_alive = keep_alive->count > 0;
    emu_config.no_pautina_config = no_pautina_config->count > 0;
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

  /* 1. check locks */
  {
    const pid_t pid = getpid();
    pid_t saved_pid;
    FILE *fd = fopen(pid_fname, "r");

    if(fd != NULL) {
      if(fscanf(fd, "%d", &saved_pid) != 1)
        ERROR(1, errno, "unknown stale pidfile %s", pid_fname);

      // check if such process exists
      char proc_pid_fname[100];
      snprintf(proc_pid_fname, 100, "/proc/%d", saved_pid);

      if(access(proc_pid_fname, F_OK) != -1)
        ERROR(1, errno, "an instance of %s seems to be running; pidfile is %s",
              argv[0], pid_fname);

      if(unlink(pid_fname) == -1)
        ERROR(1, errno, "failed to unlink() stale pidfile %s", pid_fname);

      unlink(sock_fname);
    }

    fd = fopen(pid_fname, "w");

    if(fd == NULL)
      ERROR(1, errno, "failed to create a pidfile %s", pid_fname);

    fprintf(fd, "%d\n", pid);
    fclose(fd);
  }

  /* 2. create shared segments */

  void *dram_segstart = mkshm_exclusive(dram_fname, &dram_shm_fd, DRAM_SEGSIZE);

  FILE *fd = fopen(dev_fname, "w");

  const bar_t *b;
  for(b=bars; b<bars+nBars; ++b)
    fprintf(fd, "%X %X %lX\n", b->dev_num, b->bar_num, b->length);

  fclose(fd);

  /* 2.x run client #0: pautina_config */
  exec_pautina_config(instanceId);

  /* 3 sockets */
  /* 3.1 create */
  int srvSock = socket(AF_UNIX, SOCK_STREAM, 0);
  if(srvSock == -1)
    ERROR(1, errno, "socket() failed");

  /* 3.2 bind */
  struct sockaddr_un addr;
  memset(&addr, 0, sizeof(addr));
  addr.sun_family = AF_UNIX;
  strncpy(addr.sun_path, sock_fname, sizeof(addr.sun_path) - 1);
  if (bind(srvSock, (struct sockaddr *) &addr, sizeof(addr)) == -1)
    ERROR(1, errno, "bind() failed");

  /* 3.3 listen */
  if(listen(srvSock, /* FIXME: ad hoc client queue length */10) == -1)
    ERROR(1, errno, "listen() failed");

  size_t srvIdx = pp_alloc(srvSock, PROP_HIDDEN);
  assert(0 == srvIdx);

  /* 3.4 wait for clients */
  printf("Waiting for clients...\n");
  pp_pollin(/* infinite timeout */-1);

  /* 4. init up- and downstream submodules */
  printf("dram_segstart: %p\n", dram_segstart);
  init_tlp_up(dram_segstart, DRAM_SEGSIZE);

  /* 5. run simulator */
  /* 5.1 fork() */
  pid_t pid_sim = dbg->count == 0 ? fork() : 0; /* do not fork() nor cleaup in debug
                                                   mode */
  if(pid_sim == 0) {
    // disable annoying ieee asserts by default
    ghdl_argc++;
    char ** const ghdl_argv_1 = (char**)malloc(sizeof(char*)*ghdl_argc);
    ghdl_argv_1[0] = ghdl_argv[0];
    ghdl_argv_1[1] = "--ieee-asserts=disable";
    int i;
    for(i=2;i<ghdl_argc; ++i)
      ghdl_argv_1[i] = ghdl_argv[i-1];

    return ghdl_main(ghdl_argc, ghdl_argv_1);
  } else if(pid_sim == -1)
    ERROR(1, errno, "fork() failed");

  /* 5.2 wait for child */
  do {
    int status;
    const pid_t pid_cld = wait(&status);
    if(pid_cld == -1)
      ERROR(1, errno, "wait() failed");
    else if(pid_cld == pid_pc) {
      pid_pc = 0;
      printf("ok, pautina_config exited, status: %d, %d\n", status, WEXITSTATUS(status));
    } else if(pid_cld == pid_sim) {
      pid_sim = 0;
      printf("simulator exited, status: %d, %d\n", status, WEXITSTATUS(status));
    } else {
      ERROR(1, 0, "wait(): unknown child %d, status: %d, %d\n", pid_cld, status, WEXITSTATUS(status));
    }
  } while(pid_sim || pid_pc);

  /* 6. finalize */
  {
#if 0
    size_t i;
    for(i=0; i<nSocks; ++i)
      if(close(pollfds[i].fd) == -1)
        ERROR(1, errno, "socket close() failed");
#endif

    if(unlink(sock_fname) == -1)
      ERROR(1, errno, "failed to unlink() unix socket %s", sock_fname);

    unlink(pid_fname);
    munmap(dram_segstart, DRAM_SEGSIZE);
    close(dram_shm_fd);
    shm_unlink(dram_fname);
  }

  return 0/* status */;
}

void acceptClient() {
  int cliSock = accept(pollpull.fds[0].fd, NULL, NULL);

  /* 3. initial negotiation with client */
  int cliProp;
  Socket_RecvValue(cliSock, cliProp);
  Socket_SendValue(cliSock, emu_config.qcapacity);
  Socket_SendValue(cliSock, nBars);

  size_t i;
  for(i=0; i<nBars; ++i)
    Socket_SendValue(cliSock, bars[i]);

  size_t cliIdx = pp_alloc(cliSock, cliProp);
  Socket_SendValue(cliSock, cliIdx);

  printf("A client #%lu connected!\n", cliIdx);
}


__attribute__((destructor))
static void finalize() {
  printf("emu-server finalize\n");
  kill_pautina_config();
}
