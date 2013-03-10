/* Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
 * Academy of Science). See COPYING in top-level directory. */


#ifndef SKIF_DRIVER_H
#define SKIF_DRIVER_H

#include <linux/ioctl.h>

// Аргумент функции mmap, по которому происходит обращение, интерпретируется следующим образом:
// 1) Младшие 40 бит (39..0) - cмещение в BAR'е
// 2) Следующие 4 бита (43..40) показывают на номер BAR'а
// 3) Следующие 4 бита (47..44) показывают на номер устройства или память (0xF - память):
#define SKIF_DRIVER_OFFSET(off) ((((uint64_t)(off))>> 0)&0xFFFFFFFFFF)
#define SKIF_DRIVER_BAR_NUM(off) ((((uint64_t)(off))>>40)&0xF)
#define SKIF_DRIVER_DEV_NUM(off) ((((uint64_t)(off))>>44)&0xF)
#define SKIF_DRIVER_MMAPARG(dev,bar,off) (((((uint64_t)dev)&0xF)<<44)|((((uint64_t)bar)&0xF)<<40)|(((uint64_t)off)&0xFFFFFFFFFF))
#define SKIF_DRIVER_DEV_MEM 0xF

// Номер устройства для порождения номеров ioctl команд
#define SKIF_DRIVER_MAGIC 0x3D
// ioctl команда: чтение длины сегмента
#define SKIF_DRIVER_GET_LENGTH _IOR(SKIF_DRIVER_MAGIC,0,size_t)
#define SKIF_DRIVER_GET_BARLENGTH _IOWR(SKIF_DRIVER_MAGIC,1,BARDesc)
#define SKIF_DRIVER_GET_BARDESC _IOR(SKIF_DRIVER_MAGIC,2,BARDesc)
#define SKIF_DRIVER_GET_BARREGDESC _IOR(SKIF_DRIVER_MAGIC,3,BARRegDesc)
#define SKIF_DRIVER_SET_BARREGDESC _IOW(SKIF_DRIVER_MAGIC,4,BARRegDesc)
#define SKIF_DRIVER_SET_MTRR _IO(SKIF_DRIVER_MAGIC,5)

// Структура для передачи информации про BAR из драйвера в пользовательскую программу (через ioctl с SKIF_DRIVER_GET_BARDESC)
typedef struct BARDesc_t {
	uint8_t dev_num;
	uint8_t bar_num;
	size_t length;
} BARDesc;

// Структура для передачи информации про BARReg из пользовательской программы в драйвер и обратно (через ioctl с SKIF_DRIVER_GET_BARREGDESC и SKIF_DRIVER_SET_BARREGDESC)
typedef struct BARRegDesc_t {
	int minor;
	uint8_t dev_num;
	uint8_t bar_num;
	off_t offset;
	size_t length;
} BARRegDesc;

#endif /* SKIF_DRIVER_H */
