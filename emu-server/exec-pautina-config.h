/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */

#ifndef EXEC_PAUTINA_CONFIG
#define EXEC_PAUTINA_CONFIG

#include <unistd.h>
#include <error.h>


/* do some finalization before exit */
#define ERROR(status, errnum, ...)                                  \
  do {                                                              \
    kill_pautina_config();                                          \
    error_at_line(status, errnum, __FILE__, __LINE__, __VA_ARGS__); \
  } while(0)

extern pid_t pid_pc;

void exec_pautina_config();
void kill_pautina_config();

#endif /* EXEC_PAUTINA_CONFIG */
