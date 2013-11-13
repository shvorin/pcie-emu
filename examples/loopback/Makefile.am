# Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
# Academy of Science). See COPYING in top-level directory.


bin_PROGRAMS = emu_top

GHDL_LINKER_FLAGS = -Wl,-L$(EMU_PATH) -Wl,-lemu-server -Wl,-largtable2 -Wl,-lrt -o emu_top

QSF_PATH = $(top_srcdir)/$(QSF_FILE)

emu: emu_top$(EXEEXT)

emu_top$(EXEEXT): work-obj93.cf $(VHDL_EMU_SOURCES) $(EMU_PATH)/libemu-server.a
	$(MAKE) -C $(EMU_PATH)
	$(GHDL) -m $(GHDLFLAGS) $(GHDL_LINKER_FLAGS) emu_conf
# FIXME: GHDL's make is not sensitive to lib changes
	$(GHDL) -e $(GHDLFLAGS) $(GHDL_LINKER_FLAGS) emu_conf

work-obj93.cf: $(QSF)
	$(GHDL) -i $(VHDL_EMU_SOURCES)

.PHONY: emu map fit asm sta quartus

map fit asm sta quartus:
	$(MAKE) -f Makefile.quartus SOURCE_FILES="$(VHDL_QUARTUS_SOURCES)" PROJECT="$(PACKAGE_NAME)" $@

quartus-clean:
	$(MAKE) -f Makefile.quartus SOURCE_FILES="$(VHDL_QUARTUS_SOURCES)" PROJECT="$(PACKAGE_NAME)" clean