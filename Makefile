TOOLCHAIN    := $(OO_PS4_TOOLCHAIN)
PROJDIR      := source
INTDIR       := build
STUBDIR      := $(INTDIR)/stubs
LIBDIR       := $(INTDIR)/libs
INCLUDEDIR   := include
COMMONDIR    := common
DEBUGFLAGS   := 0

TARGETSTUB   := $(STUBDIR)/libGoldHEN_Hook.so
TARGET       := $(LIBDIR)/libGoldHEN_Hook.prx
TARGETSTATIC := $(LIBDIR)/libGoldHEN_Hook.a

TARGETCRT    := $(INTDIR)/crtprx.o
CRTSTUB      := $(STUBDIR)/crtprx.o.stub

LIBS         := -lSceLibcInternal -lkernel -lSceSysmodule

LOG_TYPE     = -D__USE_KLOG__
DEBUG_FLAGS  = -DDEBUG=0

ifeq ($(PRINTF),1)
    LOG_TYPE = -D__USE_PRINTF__
endif

ifeq ($(DEBUGFLAGS),1)
    DEBUG_FLAGS = -DDEBUG=1
endif

EXTRAFLAGS   := $(DEBUG_FLAGS) $(LOG_TYPE)

CFILES       := $(wildcard $(PROJDIR)/*.c)
CPPFILES     := $(wildcard $(PROJDIR)/*.cpp)
COMMONFILES  := $(wildcard $(COMMONDIR)/*.cpp)

OBJS         := $(patsubst $(PROJDIR)/%.c,$(INTDIR)/%.o,$(CFILES)) \
                $(patsubst $(PROJDIR)/%.cpp,$(INTDIR)/%.o,$(CPPFILES)) \
                $(patsubst $(COMMONDIR)/%.cpp,$(INTDIR)/%.o,$(COMMONFILES))

STUBOBJS     := $(patsubst $(PROJDIR)/%.c,$(STUBDIR)/%.o.stub,$(CFILES)) \
                $(patsubst $(PROJDIR)/%.cpp,$(STUBDIR)/%.o.stub,$(CPPFILES)) \
                $(patsubst $(COMMONDIR)/%.cpp,$(STUBDIR)/%.o.stub,$(COMMONFILES))

PRX_OBJS     := $(patsubst $(PROJDIR)/%.c,$(INTDIR)/prx_%.o,$(filter-out $(PROJDIR)/crtprx.c,$(CFILES))) \
                $(patsubst $(PROJDIR)/%.cpp,$(INTDIR)/prx_%.o,$(CPPFILES)) \
                $(patsubst $(COMMONDIR)/%.cpp,$(INTDIR)/prx_%.o,$(COMMONFILES))

CFLAGS       := --target=x86_64-pc-freebsd12-elf -fPIC -funwind-tables -c $(EXTRAFLAGS) \
                -isysroot $(TOOLCHAIN) -isystem $(TOOLCHAIN)/include -I$(PROJDIR) -I$(INCLUDEDIR) -I$(COMMONDIR)

CXXFLAGS     := $(CFLAGS) -isystem $(TOOLCHAIN)/$(INCLUDEDIR)/c++/v1

LDFLAGS      := -m elf_x86_64 -pie --script $(TOOLCHAIN)/link.x -e _init --eh-frame-hdr -L$(TOOLCHAIN)/lib $(LIBS)

UNAME_S      := $(shell uname -s)
ifeq ($(UNAME_S),Linux)
	CC       := clang
	CCX      := clang++
	LD       := ld.lld
	CDIR     := linux
	AR       := llvm-ar
endif
ifeq ($(UNAME_S),Darwin)
	CC       := /usr/local/opt/llvm/bin/clang
	CCX      := /usr/local/opt/llvm/bin/clang++
	LD       := /usr/local/opt/llvm/bin/ld.lld
	CDIR     := macos
	AR       := /usr/local/opt/llvm/bin/llvm-ar
endif

.PHONY: dirs
dirs:
	mkdir -p $(INTDIR) $(STUBDIR) $(LIBDIR)

# Build PRX objects
$(INTDIR)/prx_%.o: $(PROJDIR)/%.c | dirs
	$(CC) $(CFLAGS) -DMAKE_STATIC=1 -o $@ $<

$(INTDIR)/prx_%.o: $(PROJDIR)/%.cpp | dirs
	$(CCX) $(CXXFLAGS) -DMAKE_STATIC=1 -o $@ $<

# CRT object
$(TARGETCRT): $(PROJDIR)/crtprx.c | dirs
	$(CC) $(CFLAGS) -DMAKE_STATIC=1 -o $@ $<

# Build final PRX
$(TARGET): dirs $(PRX_OBJS) $(TARGETCRT)
	$(LD) $(PRX_OBJS) $(TARGETCRT) -o $(INTDIR)/$(PROJDIR).elf $(LDFLAGS)
	$(TOOLCHAIN)/bin/$(CDIR)/create-fself -in=$(INTDIR)/$(PROJDIR).elf \
		-out=$@ --lib=$@ --paid 0x3800000000000011

# Build static library
$(TARGETSTATIC): dirs $(OBJS) $(TARGETCRT)
	$(AR) --format=bsd rcs $@ $(TARGETCRT) $(OBJS)

# Build shared stub
$(TARGETSTUB): dirs $(STUBOBJS)
	$(CC) $(STUBOBJS) -o $@ -target x86_64-pc-linux-gnu \
	      -shared -fuse-ld=lld -ffreestanding -nostdlib -fno-builtin -L$(TOOLCHAIN)/lib $(LIBS)
	strip $@

# Stub for CRT
$(STUBDIR)/crtprx.o.stub: $(PROJDIR)/crtprx.c | dirs
	$(CC) -target x86_64-pc-linux-gnu -ffreestanding -nostdlib -fno-builtin -fPIC \
	      -D__STUB__ -isysroot $(TOOLCHAIN) -isystem $(TOOLCHAIN)/include -I$(PROJDIR) -I$(INCLUDEDIR) -I$(COMMONDIR) \
	      -c -o $@ $<

# Generic object build
$(INTDIR)/%.o: $(PROJDIR)/%.c | dirs
	$(CC) $(CFLAGS) -o $@ $<

$(INTDIR)/%.o: $(PROJDIR)/%.cpp | dirs
	$(CCX) $(CXXFLAGS) -o $@ $<

# Generic stub build
$(STUBDIR)/%.o.stub: $(PROJDIR)/%.c | dirs
	$(CC) -target x86_64-pc-linux-gnu -ffreestanding -nostdlib -fno-builtin -fPIC \
	      -isysroot $(TOOLCHAIN) -isystem $(TOOLCHAIN)/include -I$(PROJDIR) -I$(INCLUDEDIR) -I$(COMMONDIR) \
	      -D__STUB__ -c -o $@ $<

$(STUBDIR)/%.o.stub: $(PROJDIR)/%.cpp | dirs
	$(CCX) -target x86_64-pc-linux-gnu -ffreestanding -nostdlib -fno-builtin -fPIC \
	      -isysroot $(TOOLCHAIN) -isystem $(TOOLCHAIN)/include -I$(PROJDIR) -I$(INCLUDEDIR) -I$(COMMONDIR) \
	      -D__STUB__ -c -o $@ $<

clean:
	rm -rf $(INTDIR)

.PHONY: all clean dirs
.DEFAULT_GOAL := all

all: dirs $(TARGETCRT) $(STUBOBJS) $(OBJS) $(TARGETSTATIC) $(TARGETSTUB) $(TARGET) 

install: clean all
	@echo Copying...
	@cp -frv include/* $(OO_PS4_TOOLCHAIN)/include/
	@cp -frv $(TARGETSTATIC) $(OO_PS4_TOOLCHAIN)/lib
	@cp -frv $(TARGETCRT) $(OO_PS4_TOOLCHAIN)/lib
	@echo Done!
