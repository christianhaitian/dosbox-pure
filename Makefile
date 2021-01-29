#
#  Copyright (C) 2020 Bernhard Schelling
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License along
#  with this program; if not, write to the Free Software Foundation, Inc.,
#  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#

ifeq ($(ISWIN),)
ISWIN      := $(findstring :,$(firstword $(subst \, ,$(subst /, ,$(abspath .)))))
endif

ifeq ($(ISMAC),)
ISMAC      := $(wildcard /Applications)
endif

PIPETONULL := $(if $(ISWIN),>nul 2>nul,>/dev/null 2>/dev/null)
PROCCPU    := $(if $(ISWIN),GenuineIntel Intel sse sse2,$(if $(ISMAC),Unknown,$(shell cat /proc/cpuinfo)))

SOURCES := \
	*.cpp       \
	src/*.cpp   \
	src/*/*.cpp \
	src/*/*/*.cpp

OUTNAME := dosbox_pure_libretro.so

CPUFLAGS := -Ofast -march=armv8-a+crc+fp+simd -mcpu=cortex-a35 -flto -DUSE_RENDER_THREAD -DNO_ASM -DARM_ASM -frename-registers -ftree-vectorize
CXX := g++-9
BUILD    := RELEASE
BUILDDIR := release
CFLAGS   := -DNDEBUG -Ofast -fno-ident
LDFLAGS  += -Ofast -fno-ident
CFLAGS  += $(CPUFLAGS) -fpic -fomit-frame-pointer -fno-exceptions -fno-non-call-exceptions -Wno-psabi -Wno-format
CFLAGS  += -fvisibility=hidden -ffunction-sections
CFLAGS  += -pthread -D__LIBRETRO__ -Iinclude
LDFLAGS += $(CPUFLAGS) -lpthread -Wl,--gc-sections -shared

.PHONY: all clean
all: $(OUTNAME)

$(info Building $(OUTNAME) with $(BUILD) configuration (obj files stored in build/$(BUILDDIR)) ...)
SOURCES := $(wildcard $(SOURCES))
$(if $(findstring ~,$(SOURCES)),$(error SOURCES contains a filename with a ~ character in it - Unable to continue))
$(if $(wildcard build),,$(shell mkdir "build"))
$(if $(wildcard build/$(BUILDDIR)),,$(shell mkdir "build/$(BUILDDIR)"))
OBJS := $(addprefix build/$(BUILDDIR)/,$(subst /,~,$(patsubst %,%.o,$(SOURCES))))
-include $(OBJS:%.o=%.d)
$(foreach F,$(OBJS),$(eval $(F): $(subst ~,/,$(patsubst build/$(BUILDDIR)/%.o,%,$(F))) ; $$(call COMPILE,$$@,$$<)))

clean:
	$(info Removing all build files ...)
	@$(if $(wildcard build/$(BUILDDIR)),$(if $(ISWIN),rmdir /S /Q,rm -rf) "build/$(BUILDDIR)" $(PIPETONULL))

$(OUTNAME) : $(OBJS)
	$(info Linking $@ ...)
	$(CXX) $(LDFLAGS) -o $@ $^
	@-strip --strip-all $@ $(PIPETONULL);true #others
	@-strip -xS $@ $(PIPETONULL);true #mac

define COMPILE
	$(info Compiling $2 ...)
	@$(CXX) $(CFLAGS) -MMD -MP -o $1 -c $2
endef
