# Makefile utilities dependent on build host operating system
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

PATH_ECHO_RESULT:=$(shell echo $$PATH)
IS_UNIX_SHELL:=
ifneq ($(PATH_ECHO_RESULT),$$PATH)
IS_UNIX_SHELL:=1
endif

IS_WINDOWS_OS:=$(if $(filter Windows%,$(OS)),1,)

ifneq ($(IS_UNIX_SHELL),)
    NULL:=/dev/null
else
    NULL:=nul
endif

# Utilities for build hosts running Windows
ifeq ($(IS_UNIX_SHELL),)

define buildhost_mkdir_all_target
	-@if not exist $@ (echo Creating directory $(subst /,\,$@) && mkdir $(subst /,\,$@))

endef

define buildhost_rm
	@if exist $(1) (echo Deleting file $(subst /,\,$(1)) && del /f $(subst /,\,$(1)) >nul 2>nul)

endef

define buildhost_force_copy
	copy /y $(subst /,\,$(1)) $(subst /,\,$(2))

endef

# arg 1 = text to echo
define buildhost_echo
	@echo $(1)
endef

endif

# Utilities for build hosts running Linux
ifeq ($(IS_UNIX_SHELL),1)

define buildhost_mkdir_all_target
	@if [ ! -d $@ ]; then echo 'Creating directory $@' && mkdir -p $@ ; fi

endef

define buildhost_rm
	@if [ -f $(1) ]; then echo 'Deleting file $(1)' && rm -f $(1) ; fi

endef

define buildhost_force_copy
	cp -f $(1) $(2)

endef

# arg 1 = text to echo
define buildhost_echo
	@echo '$(1)'
endef
endif

test_buildhost_os_determination:
	$(call do_echo,PATH_ECHO_RESULT=$(PATH_ECHO_RESULT))
	$(call do_echo,OS=$(OS))
	$(call do_echo,IS_UNIX_SHELL=$(IS_UNIX_SHELL))
	$(call do_echo,IS_WINDOWS_OS=$(IS_WINDOWS_OS))

