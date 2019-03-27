include ../../py/mkenv.mk

X86 = 0
ARM_NONE = 0
RISCV64 = 1
DEBUG=1

J = $(shell cat /proc/cpuinfo | grep processor | wc -l)
LIBS_DIR = .libs
K210_LD = sdk/lds/kendryte.ld

# qstr definitions (must come before including py.mk)
QSTR_DEFS = qstrdefsport.h

# include py core make definitions
include $(TOP)/py/py.mk

ifeq ($(ARM_NONE), 1)
CROSS_COMPILE = /opt/gcc-arm-none-eabi/bin/arm-none-eabi-
endif

ifeq ($(RISCV64), 1)
CROSS_COMPILE = /opt/kendryte-toolchain/bin/riscv64-unknown-elf-
endif

INC += -I.
INC += -I$(TOP)
INC += -I$(BUILD)
INC += -I$(PWD)/ArduinoCore-k210/cores/k210/
INC += -I$(PWD)/ArduinoCore-k210/variants/k210/
INC += -I$(PWD)/sdk/lib/bsp/include/
INC += -I$(PWD)/sdk/lib/drivers/include/
INC += -I$(PWD)/sdk/lib/freertos/conf/
INC += -I$(PWD)/sdk/lib/freertos/include/
INC += -I$(PWD)/sdk/lib/freertos/portable/
INC += -I$(PWD)/sdk/lib/utils/include/


ifeq ($(ARM_NONE), 1)
DFU = $(TOP)/tools/dfu.py
PYDFU = $(TOP)/tools/pydfu.py
CFLAGS_CORTEX_M4 = -mthumb -mtune=cortex-m4 -mabi=aapcs-linux -mcpu=cortex-m4 -mfpu=fpv4-sp-d16 -mfloat-abi=hard -fsingle-precision-constant -Wdouble-promotion
CFLAGS = $(INC) -Wall -Werror -std=c99 -nostdlib $(CFLAGS_CORTEX_M4) $(COPT)
LDFLAGS = -nostdlib -T stm32f405.ld -Map=$@.map --cref --gc-sections
endif

ifeq ($(X86), 1)
LD = gcc
CFLAGS = -m32 $(INC) -Wall -Werror -std=c99 $(COPT)
LDFLAGS = -m32 -Wl,-Map=$@.map,--cref -Wl,--gc-sections
endif

ifeq ($(RISCV64),1)
BOTH = \
		-DCONFIG_LOG_LEVEL=LOG_VERBOSE \
		-DCONFIG_LOG_ENABLE \
		-DCONFIG_LOG_COLORS \
		-DLOG_KERNEL \
		-D__riscv64 \
		-DLV_CONF_INCLUDE_SIMPLE \
		-mcmodel=medany \
		-mabi=lp64f \
		-march=rv64imafc \
		-fno-common \
		-ffunction-sections \
		-fdata-sections \
		-fstrict-volatile-bitfields \
		-fno-zero-initialized-in-bss \
		-Os \
		-ggdb \
		-Wall \
		-Werror=all \
		-Wno-error=unused-function \
		-Wno-error=unused-but-set-variable \
		-Wno-error=unused-variable \
		-Wno-error=deprecated-declarations \
		-Wextra \
		-Werror=frame-larger-than=65536 \
		-Wno-unused-parameter \
		-Wno-sign-compare \
		-Wno-error=missing-braces \
		-Wno-error=return-type \
		-Wno-error=pointer-sign \
		-Wno-missing-braces \
		-Wno-strict-aliasing \
		-Wno-implicit-fallthrough \
		-Wno-missing-field-initializers \
		-Wno-int-to-pointer-cast \
		-Wno-error=comment \
		-Wno-error=logical-not-parentheses \
		-Wno-error=duplicate-decl-specifier \
		-Wno-error=parentheses
CFLAGS = \
	$(BOTH) \
	$(INC) \
	-std=gnu11 \
	-Wno-pointer-to-int-cast \
	-Wno-old-style-declaration

CXXFLAGS = \
	$(BOTH) \
	$(INC) \
	-std=gnu++17

LDFLAGS = \
	-g   \
	-nostartfiles \
	-static \
	-Wl,--gc-sections \
	-Wl,-static \
	-Wl,--start-group \
	-Wl,--whole-archive \
	-Wl,--no-whole-archive \
	-Wl,--end-group \
	-Wl,-EL \
	-Wl,--no-relax \
	-T $(K210_LD) \
	"/opt/kendryte-toolchain/lib/gcc/riscv64-unknown-elf/8.2.0/crti.o" \
	"/opt/kendryte-toolchain/lib/gcc/riscv64-unknown-elf/8.2.0/crtbegin.o" \
	"/opt/kendryte-toolchain/lib/gcc/riscv64-unknown-elf/8.2.0/crtn.o" \
	/opt/kendryte-toolchain/lib/gcc/riscv64-unknown-elf/8.2.0/crtend.o

LDDD = \
	-Wl,--start-group \
	-lgcc \
	-lm \
	-lc \
	-Wl,--whole-archive \
	.libs/lib/libkendryte.a \
	.libs/libarduino.a  \
	libmicropython.a \
	-Wl,--no-whole-archive \
	-Wl,--end-group -lstdc++ -lm 

endif
# Tune for Debugging or Optimization
# ifeq ($(DEBUG), 1)
# CFLAGS += -O0 -ggdb
# else
# CFLAGS += -Os -DNDEBUG
# CFLAGS += -fdata-sections -ffunction-sections
# endif

SRC_C = \
	lib/utils/stdout_helpers.c \
	lib/utils/pyexec.c \
	lib/mp-readline/readline.c \
	$(BUILD)/_frozen_mpy.c \

OBJ = $(PY_CORE_O) $(addprefix $(BUILD)/, $(SRC_C:.c=.o)) 

USER_SRC_CPP = \
	main.cpp
	
USER_SRC_C_OBJ := $(USER_SRC_C:.c=.o)
USER_SRC_CXX_OBJ := $(USER_SRC_CPP:.cpp=.o)

$(USER_SRC_CXX_OBJ):%.o:%.cpp
	@mkdir build || true
	@echo @$(CXX)  -o build/$@ -c $< $(INCLUDE) $(CXXFLAGS) -lstdc++
	@$(CXX)  -o build/$@ -c $< $(INCLUDE) $(CXXFLAGS) -lstdc++

$(USER_SRC_C_OBJ):%.o:%.c
	@mkdir build || true
	@$(CC)  -o build/$@ -c $< $(INCLUDE)  $(CFLAGS) -lstdc++

USER_OBJ =  $(addprefix $(BUILD)/, $(USER_SRC_CPP:.cpp=.o)) 
USER_OBJ += $(addprefix $(BUILD)/, $(USER_SRC_C:.cpp=.o)) 

all: micropython.bin

k210_libs:
	@echo pass
	#mkdir $(LIBS_DIR) || true && cd $(LIBS_DIR) && cmake ../sdk -DPROJ=ArduinoCore-k210 -DTOOLCHAIN=/opt/kendryte-toolchain/bin -DLIBARDUINO=1 && make -j $(J) VERBOSE=1

micropython.bin: micropython
	$(SIZE) micropython
	$(OBJCOPY) --output-format=binary micropython micropython.bin

micropython: $(USER_SRC_C_OBJ) $(USER_SRC_CXX_OBJ) k210_libs  lib $(LIBMICROPYTHON) $(BUILD)/_frozen_mpy.c
	@echo @$(CC) $(CFLAGS)  $(USER_SRC_C_OBJ) $(USER_OBJ)  -o $@ $(LDFLAGS) $(LDDD)
	@$(CC)  $(CFLAGS) -Wl,-Map=micropython.map $(USER_SRC_C_OBJ) $(USER_OBJ)   -o $@ $(LDFLAGS) $(LDDD)

$(BUILD)/_frozen_mpy.c: frozentest.mpy $(BUILD)/genhdr/qstrdefs.generated.h
	$(ECHO) "MISC freezing bytecode"
	$(Q)$(TOP)/tools/mpy-tool.py -f -q $(BUILD)/genhdr/qstrdefs.preprocessed.h -mlongint-impl=none $< > $@

include $(TOP)/py/mkrules.mk
