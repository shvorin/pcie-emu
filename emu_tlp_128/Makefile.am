# Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
# Academy of Science). See COPYING in top-level directory.


bin_PROGRAMS = emu_tlp_io

GHDL_LINKER_FLAGS = -Wl,-L$(EMU_PATH) -Wl,-lemu-server -Wl,-largtable2 -Wl,-lrt -o emu_tlp_io

GENERIC_DIR = $(top_srcdir)/generic
MKVERSION = $(top_srcdir)/tools/mkversion
QSF_PATH = $(top_srcdir)/$(QSF_FILE)

emu_tlp_io: work-obj93.cf $(VHDL_EMU_SOURCES) $(EMU_PATH)/libemu-server.a
	$(GHDL) -m $(GHDLFLAGS) $(GHDL_LINKER_FLAGS) emu_tlp_io
# FIXME: GHDL's make is not sensitive to lib changes
	$(GHDL) -e $(GHDLFLAGS) $(GHDL_LINKER_FLAGS) emu_tlp_io

work-obj93.cf: $(QSF) $(top_srcdir)/svnversion.vhd
	$(GHDL) -i $(VHDL_EMU_SOURCES)

$(top_srcdir)/svnversion.vhd: svnversion

.PHONY: map fit asm sta quartus

include Makefile.svnversion

map fit asm sta quartus:
	$(MAKE) -f Makefile.quartus SOURCE_FILES="$(VHDL_QUARTUS_SOURCES)" PROJECT="$(PACKAGE_NAME)" $%

quartus-clean:
	$(MAKE) -f Makefile.quartus SOURCE_FILES="$(VHDL_QUARTUS_SOURCES)" PROJECT="$(PACKAGE_NAME)" clean
