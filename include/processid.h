/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */

/* vim: set syntax=c et sw=4 ts=4: */

#ifndef PROCESSID_H
#define PROCESSID_H

#include <errno.h>

extern int processid_rank;
extern char * processid_hostname;
extern int processid_verbosity; // 0 - error, 1 - warning, 2 - info, 3 - verbose

#define PROCESSID_MAXLEVEL PROCESSID_VERBOSE // Set to PROCESSID_VERBOSE if you want to see see all sending and receiving packages (decrease message rate)

#define PROCESSID_ERROR 0
#define PROCESSID_WARNING 1
#define PROCESSID_INFO 2
#define PROCESSID_VERBOSE 3

static int processid_check(int level) {
  return level <= PROCESSID_MAXLEVEL && level <= processid_verbosity;
}

#define PROCESSID_DBG_PRINT(level, format, args...)             \
  (processid_check(level) ?                                     \
   printf("DBG%3d%s%s%s: %s: " format "\n", processid_rank,     \
          processid_hostname == NULL ? "" : " (",               \
          processid_hostname == NULL ? "" : processid_hostname, \
          processid_hostname == NULL ? "" : ")",                \
          level == PROCESSID_ERROR ? "Error" :                  \
          level == PROCESSID_WARNING ? "Warning" :              \
          level == PROCESSID_INFO ? "Info" :                    \
          level == PROCESSID_VERBOSE ? "Verbose" : "Unknown",   \
          ##args)                                               \
   : 0)

/* dump no prefix, no '\n' */
#define PROCESSID_DBG_RAWPRINT(level, format, args...)          \
  (level <= PROCESSID_MAXLEVEL && level <= processid_verbosity  \
   ? printf(format, ##args)                                     \
   : 0)
  
void ProcessId_Init (int rank);
void ProcessId_Finalize ();

struct _Error_Description;

typedef struct _Error_Description {
    char * file;
    int line;
    char * message;
    int number;
    struct _Error_Description * next;
} Error_Description;

extern Error_Description * processid_error;

#define PROCESSID_ERROR_ADDERROR(fl, ln, msg, num) { \
    Error_Description * new = malloc(sizeof(Error_Description)); \
    if (new != NULL) { \
        new->file = fl; \
        new->line = ln; \
        new->message = msg; \
        new->number = num; \
        new->next = processid_error; \
        processid_error = new; \
    } \
}

#define PROCESSID_ERROR_CREATE(msg, eno) { errno = eno; PROCESSID_ERROR_ADDERROR(FCNAME, __LINE__, msg, eno); }

#define PROCESSID_ERROR_CONVERT(func, msg) { PROCESSID_ERROR_ADDERROR(func, 0, NULL, errno); PROCESSID_ERROR_MESSAGE(msg); }

#define PROCESSID_ERROR_MESSAGE(msg) PROCESSID_ERROR_ADDERROR(FCNAME, __LINE__, msg, 0)

#endif /* PROCESSID_H */
