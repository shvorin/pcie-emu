/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */

#include <defines.h>

#include <stdlib.h>
#include <unistd.h>
#include <error.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/wait.h>

pid_t pid_pc = 0;

void exec_pautina_config() {
  const pid_t pid = fork();
  if(pid == 0) {
    setenv("EMU", "", 0);
    const char path[] = "../../fpga-software/bin/pautina-config"; /* FIXME: ad hoc */
    int res = execl(path, path, "-c", "-a", "0x10000000", "-l", "0x10000000", (char*)NULL);
    if(-1 == res)
      error(1, errno, "exec failed");
  } else if(pid == -1)
    error(1, errno, "fork() failed");

   pid_pc = pid;
}

void kill_pautina_config() {
  if(!pid_pc)
    return;

  const int errno_saved = errno;
  int res, status;
  res = kill(pid_pc, SIGTERM);
  if(-1 == res) {
    error(0, errno, "kill pautina-config failed, pid_pc: %d\n", pid_pc);
    goto end;
  }

  const pid_t pid_cld = wait(&status);
  if(pid_cld != pid_pc) {
    error(0, errno, "wait for pautina-config failed, pid_pc: %d, pid_cld: %d\n", pid_pc, pid_cld);
    goto end;
  }

 end:
  errno = errno_saved;
}
