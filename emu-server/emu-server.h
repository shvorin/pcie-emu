/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */

#ifndef EMU_SERVER_H
#define EMU_SERVER_H

#include <sys/types.h>


extern struct emu_config_t {
  const char *instanceId;
  size_t qcapacity;
  int colorized_output;
  int tlp_quiet;
  int keep_alive;
#ifdef WITH_INI_CLIENT
  int no_ini_client;
#endif
} emu_config;


#endif /* EMU_SERVER_H */
