# Common makefile skeleton
#
# Copyright (C) 2021 Dennis May
# First Published 2021
#
# This file is part of 68000 Software Suite.
#
# 68000 Software Suite is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# 68000 Software Suite is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with 68000 Software Suite.  If not, see <https://www.gnu.org/licenses/>.
#

all: $(PROGNAME).bin

include $(COMMON_DIR)/build_host.mak

LINK_SCRIPT:=$(if $(LINK_SCRIPT),$(LINK_SCRIPT),$(COMMON_DIR)/common.sct)
ENTRY:=$(if $(ENTRY),$(ENTRY),START)

clean:
	$(call buildhost_rm, $(PROGNAME).o)
	$(call buildhost_rm, $(PROGNAME).elf)
	$(call buildhost_rm, $(PROGNAME).lst)
	$(call buildhost_rm, $(PROGNAME).bin)

$(PROGNAME).bin: $(PROGNAME).elf
	m68k-elf-objcopy -O binary $< $@

$(PROGNAME).elf: $(LINK_SCRIPT) $(PROGNAME).o
	m68k-elf-ld -T $< --entry=$(ENTRY) -o $@ $(word 2,999,$^)

$(PROGNAME).o: $(PROGNAME).s makefile
	m68k-elf-as -mcpu=68000 --register-prefix-optional --bitwise-or -acglms=$(@:.o=.lst) -o $@ $<
