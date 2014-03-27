/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */

/* vim: set syntax=c et sw=4 ts=4: */

#include <sys/time.h>
#include "devpautina.h"
#include "pmi.h"
#include "processid.h"
#include "phys.h"
#include "skifch-lo.h"
#include "skifch-plx.h"
#include "skifch-pmc.h"
#include "skifch-shm.h"
#include "skifch-shmlo.h"
#include "skifch-t3d.h"

#define TRUE 1
#define FALSE 0

static int __skifchinit_size;
static int __skifchinit_myrank;

static char * * __skifchinit_rank2hostname;
static int __skifchinit_maxhost;
static int * __skifchinit_rank2host;

static int __skifchinit_notuseshm;

static SkifCh * * __skifchinit_skifchs;
static SkifCh_Aux * __skifchinit_skifchs_aux;
static int __skifchinit_skifchs_size;

static netaddr_t __skifchinit_mynetaddr;

#undef FCNAME
#define FCNAME "SkifCh_Init"

static void SkifCh_InitRank (char * kvsname, char * key, int key_max_sz, char * val, int val_max_sz) {
    __skifchinit_rank2hostname = malloc(sizeof(char *) * __skifchinit_size);
    {
        char * myhostname = PHYS_GetHostname();
        snprintf(key, key_max_sz, "HOSTNAME%d", __skifchinit_myrank);
        snprintf(val, val_max_sz, "%s", myhostname);
        PMI_KVS_Put(kvsname, key, val);
        free(myhostname);
    }
    PMI_KVS_Commit(kvsname);
    PMI_Barrier();
    int rank;
    for (rank = 0; rank < __skifchinit_size; rank++) {
        snprintf(key, key_max_sz, "HOSTNAME%d", rank);
        PMI_KVS_Get(kvsname, key, val, val_max_sz);
        __skifchinit_rank2hostname[rank] = strdup(val);
    }

    __skifchinit_maxhost = 0;
    __skifchinit_rank2host = malloc(sizeof(int) * __skifchinit_size);
    for (rank = 0; rank < __skifchinit_size; rank++) {
        int rank1;
        for (rank1 = 0; rank1 < rank; rank1++) {
            if (strcmp(__skifchinit_rank2hostname[rank], __skifchinit_rank2hostname[rank1]) == 0) {
                break;
            }
        }
        if (rank1 < rank) {
            __skifchinit_rank2host[rank] = __skifchinit_rank2host[rank1];
        } else {
            __skifchinit_rank2host[rank] = __skifchinit_maxhost;
            __skifchinit_maxhost++;
        }
    }
}

static void SkifCh_FinalizeRank () {
    free(__skifchinit_rank2host);
    free(__skifchinit_rank2hostname);
}

static int SkifCh_IsOnMyHost (int rank) {
    return strcmp(__skifchinit_rank2hostname[rank], __skifchinit_rank2hostname[__skifchinit_myrank]) == 0;
}

static int SkifCh_Rank2Host (int rank) {
    return __skifchinit_rank2host[rank];
}

static void SkifCh_New (SkifCh ** skifch, SkifCh_Aux ** skifch_aux, int rank) {
    *skifch = __skifchinit_skifchs[__skifchinit_skifchs_size];
    *skifch_aux = &__skifchinit_skifchs_aux[__skifchinit_skifchs_size];
    if (rank >= 0) {
        SkifCh_rank2skifch[rank] = *skifch;
    }
    __skifchinit_skifchs_size++;
}

static int SkifChs_ShmLoInit () {
    SkifCh * skifch; SkifCh_Aux * skifch_aux;
    SkifCh_New(&skifch, &skifch_aux, __skifchinit_myrank);
    if (SkifCh_ShmLo_Init(skifch, skifch_aux) == -1) {
        return -1;
    }
    return 0;
}

static int SkifChs_ShmInit (char * kvsname, char * key, int key_max_sz, char * val, int val_max_sz) {
    __skifchinit_notuseshm = SkifCh_GetEnv("SKIFCH_NOSHM", FALSE);
    if (__skifchinit_notuseshm) {
        return 0;
    }
    int rank;
    for (rank = 0; rank < __skifchinit_myrank; rank++) {
        if (SkifCh_IsOnMyHost(rank)) {
            SkifCh * skifch; SkifCh_Aux * skifch_aux;
            SkifCh_New(&skifch, &skifch_aux, rank);
            key_t shmkey = 0;
            if (SkifCh_Shm_Init(skifch, skifch_aux, &shmkey) == -1) {
                return -1;
            }
            snprintf(key, key_max_sz, "SHMKEY%d_%d", __skifchinit_myrank, rank);
            snprintf(val, val_max_sz, "%d", shmkey);
            PMI_KVS_Put(kvsname, key, val);
        }
    }
    PMI_KVS_Commit(kvsname);
    PMI_Barrier();
    for (rank = __skifchinit_myrank + 1; rank < __skifchinit_size; rank++) {
        if (SkifCh_IsOnMyHost(rank)) {
            SkifCh * skifch; SkifCh_Aux * skifch_aux;
            SkifCh_New(&skifch, &skifch_aux, rank);
            snprintf(key, key_max_sz, "SHMKEY%d_%d", rank, __skifchinit_myrank);
            PMI_KVS_Get(kvsname, key, val, val_max_sz);
            key_t shmkey = atoi(val);
            if (SkifCh_Shm_Init(skifch, skifch_aux, &shmkey) == -1) {
                return -1;
            }
        }
    }
    return 0;
}

static int SkifChs_LoInit () {
    if (! __skifchinit_notuseshm) {
        PROCESSID_ERROR_CREATE("SkifCh 'SHM' is enabled", EINVAL);
        return -1;
    }
    SkifCh * skifch; SkifCh_Aux * skifch_aux;
    SkifCh_New(&skifch, &skifch_aux, -1);
    if (SkifCh_Lo_Init(skifch, skifch_aux, (int *) &__skifchinit_mynetaddr) == -1) {
        return -1;
    }
    int rank;
    for (rank = 0; rank < __skifchinit_size; rank++) {
        if (rank != __skifchinit_myrank && (__skifchinit_notuseshm || !SkifCh_IsOnMyHost(rank))) {
            SkifCh_rank2skifch[rank] = skifch;
        }
    }
    return 0;
}

#define NODEID_COUNT 1024

static int SkifChs_PMCInit (char * kvsname, char * key, int key_max_sz, char * val, int val_max_sz) {
    char * phys_filename = getenv("SKIFCH_LINKS");
    if (phys_filename == NULL) {
        PROCESSID_ERROR_CREATE("Environment variable 'SKIFCH_LINKS' is not set", EINVAL);
        return -1;
    }
    int rank;
    int local_number = 0;
    for (rank = 0; rank < __skifchinit_myrank; rank++) {
        if (SkifCh_IsOnMyHost(rank)) {
            local_number++;
        }
    }
    PHYS phys;
    PHYS_InitRead(&phys, phys_filename);
    int nodeid2processes[NODEID_COUNT];
    int nodeid2processes2[NODEID_COUNT];
    int phy2processes[PHY_COUNT];
    int phy2processes2[PHY_COUNT];
    int nodeid;
    for (nodeid = 0; nodeid < NODEID_COUNT; nodeid++) {
        nodeid2processes[nodeid] = 0;
        nodeid2processes2[nodeid] = 0;
    }
    int phy;
    for (phy = 0; phy < PHY_COUNT; phy++) {
        phy2processes[phy] = 0;
        phy2processes2[phy] = 0;
    }
    for (rank = 0; rank < __skifchinit_size; rank++) {
        if (rank != __skifchinit_myrank && (__skifchinit_notuseshm || !SkifCh_IsOnMyHost(rank))) {
            nodeid2processes[SkifCh_Rank2Host(rank)]++;
        }
    }
    for (nodeid = 0; nodeid < NODEID_COUNT; nodeid++) {
        nodeid2processes2[nodeid] = nodeid2processes[nodeid] * local_number;
    }
    for (rank = 0; rank < __skifchinit_size; rank++) {
        if (rank != __skifchinit_myrank && (__skifchinit_notuseshm || !SkifCh_IsOnMyHost(rank))) {
            char * my_hostname = __skifchinit_rank2hostname[__skifchinit_myrank];
            char * remote_hostname = __skifchinit_rank2hostname[rank];
            int remote_phy, remote_port, my_phy, my_port; 
            if (PHYS_FindLink(&phys, remote_hostname, my_hostname, nodeid2processes2[SkifCh_Rank2Host(rank)], &remote_phy, &remote_port, &my_phy, &my_port) == -1) {
                char * errmsg = malloc(64);
                snprintf(errmsg, 64, "No link between host '%s' and host '%s' in links file", remote_hostname, my_hostname);
                PROCESSID_ERROR_CREATE(errmsg, EINVAL);
                return -1;
            }
            nodeid2processes2[SkifCh_Rank2Host(rank)]++;
            phy2processes[my_phy]++;
        }
    }
    for (nodeid = 0; nodeid < NODEID_COUNT; nodeid++) {
        nodeid2processes2[nodeid] = nodeid2processes[nodeid] * local_number;
    }
    for (rank = 0; rank < __skifchinit_size; rank++) {
        if (rank != __skifchinit_myrank && (__skifchinit_notuseshm || !SkifCh_IsOnMyHost(rank))) {
            char * my_hostname = __skifchinit_rank2hostname[__skifchinit_myrank];
            char * remote_hostname = __skifchinit_rank2hostname[rank];
            int remote_phy, remote_port, my_phy, my_port; 
            if (PHYS_FindLink(&phys, remote_hostname, my_hostname, nodeid2processes2[SkifCh_Rank2Host(rank)], &remote_phy, &remote_port, &my_phy, &my_port) == -1) {
                char * errmsg = malloc(64);
                snprintf(errmsg, 64, "No link between host '%s' and host '%s' in links file", remote_hostname, my_hostname);
                PROCESSID_ERROR_CREATE(errmsg, EINVAL);
                return -1;
            }
            snprintf(key, key_max_sz, "FROM_%d_TO_%d_FROM_PHY", rank, __skifchinit_myrank);
            snprintf(val, val_max_sz, "%d", remote_phy);
            PMI_KVS_Put(kvsname, key, val);
            snprintf(key, key_max_sz, "FROM_%d_TO_%d_FROM_PORT", rank, __skifchinit_myrank);
            snprintf(val, val_max_sz, "%d", remote_port);
            PMI_KVS_Put(kvsname, key, val);
            snprintf(key, key_max_sz, "FROM_%d_TO_%d_TO_PHY", rank, __skifchinit_myrank);
            snprintf(val, val_max_sz, "%d", my_phy);
            PMI_KVS_Put(kvsname, key, val);
            snprintf(key, key_max_sz, "FROM_%d_TO_%d_TO_PORT", rank, __skifchinit_myrank);
            snprintf(val, val_max_sz, "%d", my_port);
            PMI_KVS_Put(kvsname, key, val);
            snprintf(key, key_max_sz, "FROM_%d_TO_%d_NUMBER", rank, __skifchinit_myrank);
            snprintf(val, val_max_sz, "%d", local_number*phy2processes[my_phy]+phy2processes2[my_phy]);
            PMI_KVS_Put(kvsname, key, val);
            nodeid2processes2[SkifCh_Rank2Host(rank)]++;
            phy2processes2[my_phy]++;
        }
    }
    PMI_KVS_Commit(kvsname);
    PMI_Barrier();
    for (rank = 0; rank < __skifchinit_size; rank++) {
        if (rank != __skifchinit_myrank && (__skifchinit_notuseshm || !SkifCh_IsOnMyHost(rank))) {
            snprintf(key, key_max_sz, "FROM_%d_TO_%d_FROM_PHY", __skifchinit_myrank, rank);
            PMI_KVS_Get(kvsname, key, val, val_max_sz);
            int send_phy = atoi(val);
            snprintf(key, key_max_sz, "FROM_%d_TO_%d_FROM_PORT", __skifchinit_myrank, rank);
            PMI_KVS_Get(kvsname, key, val, val_max_sz);
            int send_port = atoi(val);
            snprintf(key, key_max_sz, "FROM_%d_TO_%d_NUMBER", __skifchinit_myrank, rank);
            PMI_KVS_Get(kvsname, key, val, val_max_sz);
            int send_number = atoi(val);
            snprintf(key, key_max_sz, "FROM_%d_TO_%d_TO_PHY", rank, __skifchinit_myrank);
            PMI_KVS_Get(kvsname, key, val, val_max_sz);
            int recv_phy = atoi(val);
            snprintf(key, key_max_sz, "FROM_%d_TO_%d_TO_PORT", rank, __skifchinit_myrank);
            PMI_KVS_Get(kvsname, key, val, val_max_sz);
            int recv_port = atoi(val);
            snprintf(key, key_max_sz, "FROM_%d_TO_%d_NUMBER", rank, __skifchinit_myrank);
            PMI_KVS_Get(kvsname, key, val, val_max_sz);
            int recv_number = atoi(val);
            snprintf(key, key_max_sz, "HOSTNAME%d", rank);
            PMI_KVS_Get(kvsname, key, val, val_max_sz);
            char * remote_hostname = val;
            SkifCh * skifch; SkifCh_Aux * skifch_aux;
            SkifCh_New(&skifch, &skifch_aux, rank);
            PROCESSID_DBG_PRINT(PROCESSID_INFO, "SkifCh_PMC from me to remote (rank %d, host %s): send phy: %d, send port: %d, send num: %d, recv phy: %d, recv port: %d, recv num: %d",
                    rank, remote_hostname, send_phy, send_port, send_number, recv_phy, recv_port, recv_number);
            if (SkifCh_PMC_Init(skifch, skifch_aux, send_phy, send_port, send_number, recv_phy, recv_port, recv_number) == -1) {
                return -1;
            }
        }
    }
    PHYS_Finalize(&phys);
    return 0;
}

#ifdef HAVE_PLX
#include "umempci.h"
#endif //HAVE_PLX

static int SkifChs_PLXInit (__attribute__((unused)) char * kvsname, __attribute__((unused)) char * key, __attribute__((unused)) int key_max_sz, __attribute__((unused)) char * val, __attribute__((unused)) int val_max_sz) {
  #ifdef HAVE_PLX
    if (__skifchinit_notuseshm) {
        PROCESSID_ERROR_CREATE("SkifCh 'SHM' is disabled", EINVAL);
        return -1;
    }
    int rank;
    int processes_on_my_node = 0;
    for (rank = 0; rank < __skifchinit_size; rank++) {
        if (SkifCh_IsOnMyHost(rank)) {
            processes_on_my_node++;
        }
    }
    int local_number = 0;
    for (rank = 0; rank < __skifchinit_myrank; rank++) {
        if (SkifCh_IsOnMyHost(rank)) {
            local_number++;
        }
    }
    usleep(local_number*1e5); // For not calling to umempci_init at one time

    int worker = umempci_addworker();
    if (worker == -1) {
        PROCESSID_ERROR_CREATE(NULL, errno);
        PROCESSID_ERROR_CREATE("MEMPCI umempci_addworker error", errno);
        return -1;
    }
    if (umempci_internal_init(__skifchinit_myrank, __skifchinit_size, (const char **)__skifchinit_rank2hostname) == -1) {
        PROCESSID_ERROR_CREATE(NULL, errno);
        PROCESSID_ERROR_CREATE("MEMPCI umempci_internal_init error", errno);
        return -1;
    }
    if (umempci_setworker(worker) == -1) {
        PROCESSID_ERROR_CREATE(NULL, errno);
        PROCESSID_ERROR_CREATE("MEMPCI umempci_setworker error", errno);
        return -1;
    }

    int number_of_skifchs = __skifchinit_size - processes_on_my_node;
    ssize_t total_localsize = umempci_size(__skifchinit_myrank);
    if (total_localsize == -1) {
        PROCESSID_ERROR_CREATE(NULL, errno);
        PROCESSID_ERROR_CREATE("MEMPCI umempci_size error", errno);
        return -1;
    }
    size_t local_size = DEVPAUTINA_Page_Align_Down(total_localsize / number_of_skifchs);
    if (local_size == 0) {
        PROCESSID_ERROR_CREATE("Too many processes", ENOBUFS);
        return -1;
    }
    int q = 0;
    for (rank = 0; rank < __skifchinit_size; rank++) {
        if (! SkifCh_IsOnMyHost(rank)) {
            snprintf(key, key_max_sz, "OFFSET%d_%d", __skifchinit_myrank, rank);
            snprintf(val, val_max_sz, "%ld", local_size * q);
            PMI_KVS_Put(kvsname, key, val);
            q++;
        }
    }
    snprintf(key, key_max_sz, "SIZE%d", __skifchinit_myrank);
    snprintf(val, val_max_sz, "%ld", local_size);
    PMI_KVS_Put(kvsname, key, val);
    PMI_KVS_Commit(kvsname);
    PMI_Barrier();
    for (rank = 0; rank < __skifchinit_size; rank++) {
        if (! SkifCh_IsOnMyHost(rank)) {
            snprintf(key, key_max_sz, "OFFSET%d_%d", __skifchinit_myrank, rank);
            PMI_KVS_Get(kvsname, key, val, val_max_sz);
            off_t local_offset = atol(val);
            snprintf(key, key_max_sz, "OFFSET%d_%d", rank, __skifchinit_myrank);
            PMI_KVS_Get(kvsname, key, val, val_max_sz);
            off_t remote_offset = atol(val);
            snprintf(key, key_max_sz, "SIZE%d", rank);
            PMI_KVS_Get(kvsname, key, val, val_max_sz);
            size_t remote_size = atol(val);
            void * local_address = umempci_mmap(NULL, local_size, PROT_READ | PROT_WRITE, MAP_SHARED, __skifchinit_myrank, local_offset);
            if (local_address == MAP_FAILED) {
                PROCESSID_ERROR_CREATE(NULL, errno);
                PROCESSID_ERROR_CREATE("MEMPCI umempci_mmap error", errno);
                return -1;
            }
            void * remote_address = umempci_mmap(NULL, remote_size, PROT_READ | PROT_WRITE, MAP_SHARED, rank, remote_offset);
            if (remote_address == MAP_FAILED) {
                PROCESSID_ERROR_CREATE(NULL, errno);
                PROCESSID_ERROR_CREATE("MEMPCI umempci_mmap error", errno);
                return -1;
            }
            SkifCh * skifch; SkifCh_Aux * skifch_aux;
            SkifCh_New(&skifch, &skifch_aux, rank);
            if (SkifCh_PLX_Init(skifch, skifch_aux, local_address, local_size, remote_address, remote_size) == -1) {
                return -1;
            }
        }
    }
    return 0;
  #else //HAVE_PLX
    PROCESSID_ERROR_CREATE("SkifCh 'PLX' is not configured (use option --with-plx)", ENODEV);
    return -1;
  #endif //HAVE_PLX
}

static int SkifChs_T3DInit () {
    char * phys_filename = getenv("SKIFCH_LINKS");
    if (phys_filename == NULL) {
        PROCESSID_ERROR_CREATE("Environment variable 'SKIFCH_LINKS' is not set", EINVAL);
        return -1;
    }
    char * coor_filename = getenv("SKIFCH_COORS");
    if (coor_filename == NULL) {
        coor_filename = getenv("SKIFCH_HYDRA_HOST_FILE");
        if (coor_filename == NULL) {
            PROCESSID_ERROR_CREATE("Environment variable 'SKIFCH_COORS' is not set", EINVAL);
            return -1;
        }
    }
    int rank;
    int local_number = 0;
    for (rank = 0; rank < __skifchinit_myrank; rank++) {
        if (SkifCh_IsOnMyHost(rank)) {
            local_number++;
        }
    }
    PHYS coor, phys_input, phys_output;
    COOR_Init(&coor, coor_filename);
    char * my_hostname = processid_hostname;
    triple_t size, xyz;
    if (COOR_GerCoor(&coor, "SIZE", (int *) &size.x, (int *) &size.y, (int *) &size.z) == -1) {
        PROCESSID_ERROR_CREATE("No 'SIZE' in coors file", EINVAL);
        return -1;
    }
    if (COOR_GerCoor(&coor, my_hostname, (int *) &xyz.x, (int *) &xyz.y, (int *) &xyz.z) == -1) {
        char * errmsg = malloc(64);
        snprintf(errmsg, 64, "No coors for host '%s' in coors file", my_hostname);
        PROCESSID_ERROR_CREATE(errmsg, EINVAL);
        return -1;
    }
    PHYS_Init(&phys_output);
    PHYS_InitRead(&phys_input, phys_filename);
    PHYS_Filter(&phys_input, &coor, &phys_output);
    PHYS_Finalize(&phys_input);
    COOR_Finalize(&coor);
    int ports[PHY_COUNT];
    memset(ports, 0xFF, sizeof(ports));
    int i = 0;
    for (;;) {
        char * from_hostname, * to_hostname;
        int from_phy, from_port, to_phy, to_port; 
        if (PHYS_IterLink(&phys_output, &i, &from_hostname, &from_phy, &from_port, &to_hostname, &to_phy, &to_port) == -1) {
            break;
        }
        if (strcmp(my_hostname, from_hostname) == 0) {
            ports[from_phy] = from_port;
        }
        if (strcmp(my_hostname, to_hostname) == 0) {
            ports[to_phy] = to_port;
        }
    }
    PHYS_Finalize(&phys_output);
    SkifCh * skifch; SkifCh_Aux * skifch_aux;
    SkifCh_New(&skifch, &skifch_aux, -1);
    if (SkifCh_T3D_Init(skifch, skifch_aux, size, xyz, local_number, ports, PMI_Barrier, &__skifchinit_mynetaddr) == -1) {
        return -1;
    }
    for (rank = 0; rank < __skifchinit_size; rank++) {
        if (rank != __skifchinit_myrank && (__skifchinit_notuseshm || !SkifCh_IsOnMyHost(rank))) {
            SkifCh_rank2skifch[rank] = skifch;
        }
    }
    return 0;
}

static int SkifChs_NetInit (char * kvsname, char * key, int key_max_sz, char * val, int val_max_sz) {
    __skifchinit_mynetaddr = __skifchinit_myrank;
    int rank;
    for (rank = 0; rank < __skifchinit_size; rank++) {
        if (rank != __skifchinit_myrank && (__skifchinit_notuseshm || !SkifCh_IsOnMyHost(rank))) {
            break;
        }
    }
    if (rank < __skifchinit_size) {
        char * str = getenv("SKIFCH");
      #ifdef HAVE_PLX
        if (str == NULL) {
            str = "PLX";
        }
      #endif
        if (str == NULL) {
            PROCESSID_ERROR_CREATE("Environment variable 'SKIFCH' is not set", EINVAL);
            return -1;
        } else if (strcasecmp(str, "LO") == 0) {
            if (SkifChs_LoInit() == -1) {
                PROCESSID_ERROR_MESSAGE("SkifCh 'Lo' initialization failed");
                return -1;
            }
        } else if (strcasecmp(str, "PMC") == 0) {
            if (SkifChs_PMCInit(kvsname, key, key_max_sz, val, val_max_sz) == -1) {
                PROCESSID_ERROR_MESSAGE("SkifCh 'PMC' initialization failed");
                return -1;
            }
        } else if (strcasecmp(str, "PLX") == 0) {
            if (SkifChs_PLXInit(kvsname, key, key_max_sz, val, val_max_sz) == -1) {
                PROCESSID_ERROR_MESSAGE("SkifCh 'PLX' initialization failed");
                return -1;
            }
        } else if (strcasecmp(str, "T3D") == 0) {
            if (SkifChs_T3DInit() == -1) {
                PROCESSID_ERROR_MESSAGE("SkifCh 'T3D' initialization failed");
                return -1;
            }
        } else {
            char * errmsg = malloc(32);
            snprintf(errmsg, 32, "No such SkifCh '%s'",str);
            PROCESSID_ERROR_CREATE(errmsg, EINVAL);
            return -1;
        }
    }
    return 0;
}

// Set NetAddr and PID
static int SkifChs_SetInit (char * kvsname, char * key, int key_max_sz, char * val, int val_max_sz) {
    {
        snprintf(key, key_max_sz, "NETADDR%d", __skifchinit_myrank);
        snprintf(val, val_max_sz, "%d", __skifchinit_mynetaddr);
        PMI_KVS_Put(kvsname, key, val);
        snprintf(key, key_max_sz, "PID%d", __skifchinit_myrank);
        snprintf(val, val_max_sz, "%d", (int) getpid());
        PMI_KVS_Put(kvsname, key, val);
    }
    PMI_KVS_Commit(kvsname);
    PMI_Barrier();
    int rank;
    for (rank = 0; rank < __skifchinit_size; rank++) {
        snprintf(key, key_max_sz, "NETADDR%d", rank);
        PMI_KVS_Get(kvsname, key, val, val_max_sz);
        SkifCh_rank2netaddr[rank] = atoi(val);
        snprintf(key, key_max_sz, "PID%d", rank);
        PMI_KVS_Get(kvsname, key, val, val_max_sz);
        SkifCh_rank2pid[rank] = atoi(val);
    }
    return 0;
}


int SkifCh_AllInit_Internal (SkifCh * * skifchs, char * kvsname, int * skifchs_size) {
    char * key, * val;
    int key_max_sz, val_max_sz;
    // FIXME: add check
    PMI_KVS_Get_key_length_max(&key_max_sz);
    key_max_sz++;
    key = malloc(key_max_sz);
    PMI_KVS_Get_value_length_max(&val_max_sz);
    val_max_sz++;
    val = malloc(val_max_sz);

    PMI_Get_size(&__skifchinit_size);
    PMI_Get_rank(&__skifchinit_myrank);

    SkifCh_InitRank(kvsname, key, key_max_sz, val, val_max_sz);

    __skifchinit_skifchs = skifchs;
    __skifchinit_skifchs_aux = malloc(sizeof(SkifCh_Aux) * __skifchinit_size);
    __skifchinit_skifchs_size = 0;

    SkifCh_rank2skifch = malloc(sizeof(SkifCh *) * __skifchinit_size);
    SkifCh_rank2netaddr = malloc(sizeof(netaddr_t) * __skifchinit_size);
    SkifCh_rank2pid = malloc(sizeof(pid_t) * __skifchinit_size);

    if (SkifChs_ShmLoInit() == -1) {
        PROCESSID_ERROR_MESSAGE("SkifCh 'ShmLo' initialization failed");
        goto error;
    }
    if (SkifChs_ShmInit(kvsname, key, key_max_sz, val, val_max_sz) == -1) {
        PROCESSID_ERROR_MESSAGE("SkifCh 'Shm' initialization failed");
        goto error;
    }
    if (SkifChs_NetInit(kvsname, key, key_max_sz, val, val_max_sz) == -1) {
        goto error;
    }
    if (SkifChs_SetInit(kvsname, key, key_max_sz, val, val_max_sz) == -1) {
        goto error;
    }

    *skifchs_size = __skifchinit_skifchs_size;

    free(key); free(val);
    return 0;

  error:
    free(key); free(val);
    return -1;
}

int SkifCh_AllFinalize_Internal () {
    free(SkifCh_rank2skifch);
    free(SkifCh_rank2netaddr);
    free(SkifCh_rank2pid);

    free(__skifchinit_skifchs_aux);

    SkifCh_FinalizeRank();

    return 0;
}

#undef FCNAME
#define FCNAME "SkifCh_SlowBarrier"
int SkifCh_SlowBarrier () {
    if (PMI_Barrier() != 0) {
        PROCESSID_ERROR_CREATE(NULL, EIO);
        return -1;
    }
    return 0;
}

static double __SkifCh_WTime () {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return ((double) tv.tv_sec) + ((double) tv.tv_usec) * 1e-6;
}

#undef FCNAME
#define FCNAME "SkifCh_AlltoallTest"
int SkifCh_AlltoallTest () {
    int numprocs = __skifchinit_size;
    int64_t myid = __skifchinit_myrank;
    int send_id = 0;
    int recv_count = 0;
    int recv_id = 0;
    double starttime = __SkifCh_WTime();
    struct iovec iov = { &myid, sizeof(myid) };
    while (recv_count < numprocs) {
        if (send_id < numprocs) {
            int res = SkifCh_Send(SkifCh_SkifCh(send_id), SkifCh_NetAddr(send_id), &iov, 1);
            if (res > 0) {
                PROCESSID_DBG_PRINT(PROCESSID_INFO, "SkifCh_Send to %d", send_id);
                SkifCh_Fence();
                send_id++;
            }
        }
        if (recv_count < numprocs) {
            struct iovec cont[3];
            int cont_count;
            int res = SkifCh_Recv(SkifCh_SkifCh(recv_id), cont, &cont_count);
            if (res > 0) {
                SkifCh_RecvComp(SkifCh_SkifCh(recv_id));
                PROCESSID_DBG_PRINT(PROCESSID_INFO, "SkifCh_Recv from %d", *(int *)cont[0].iov_base);
                recv_count++;
            }
            recv_id = (recv_id + 1) % numprocs;
        }
        if (__SkifCh_WTime() - starttime > 1) {
            PROCESSID_ERROR_CREATE(NULL, ETIME);
            return -1;
        }
    }
    return 0;
}
