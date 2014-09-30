# Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
# Academy of Science). See COPYING in top-level directory.

bin_PROGRAMS = emu_top

# FIXME: $(EMU_PATH) must be configured before running this makefile
SUBDIRS = $(EMU_PATH)

GHDL_LINKER_FLAGS = -Wl,-L$(EMU_PATH) -Wl,-lemu-server -Wl,-largtable2 -Wl,-lrt -o emu_top

VHDL_EMU_SOURCES = ../../hdllib/emu/emu_top256.vhd					\
	../../hdllib/emu/clock_gen.vhd ../../hdllib/emu/wrap_emu.vhd	\
	../../hdllib/emu/emu_top_cfg.vhd ../../hdllib/common/types.vhd	\
	../../hdllib/common/util.vhd ../../hdllib/common/vdata.vhd		\
	../../hdllib/common/ast256.vhd

emu: emu_top$(EXEEXT)

emu_top$(EXEEXT): work-obj93.cf $(VHDL_EMU_SOURCES) $(EMU_PATH)/libemu-server.a
	$(MAKE) -C $(EMU_PATH)
	$(GHDL) -m $(GHDLFLAGS) $(GHDL_LINKER_FLAGS) emu_top_cfg
# FIXME: GHDL's make is not sensitive to lib changes
	$(GHDL) -e $(GHDLFLAGS) $(GHDL_LINKER_FLAGS) emu_top_cfg

work-obj93.cf: Makefile.am # NB: source list are in this file
	$(GHDL) -i $(VHDL_EMU_SOURCES)

.PHONY: emu map fit asm sta quartus

map fit asm sta quartus:
	$(MAKE) -f Makefile.quartus SOURCE_FILES="$(VHDL_QUARTUS_SOURCES)" PROJECT="$(PACKAGE_NAME)" $@

quartus-clean:
	quartus_sh --clean "$(PACKAGE_NAME)"
	$(MAKE) -f Makefile.quartus SOURCE_FILES="$(VHDL_QUARTUS_SOURCES)" PROJECT="$(PACKAGE_NAME)" clean
