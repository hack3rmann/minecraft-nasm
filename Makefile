BUILD = $(shell pwd)/build
SRC = $(shell pwd)/src
EXEC_NAME = minecraft

NASM = nasm
NASM_FLAGS = --gprefix _ -f elf64 -DDEBUG
NASM_FLAGS_DEBUG = -F dwarf -g
NASM_FLAGS_RELEASE = -O3
LD = ld
LD_FLAGS = -nostdlib
LD_FLAGS_DEBUG =
LD_FLAGS_RELEASE = -s

NASM_FLAGS += $(NASM_FLAGS_DEBUG)
LD_FLAGS += $(LD_FLAGS_DEBUG)

GREEN = \033[0;32m
NC = \033[0m

ASM_SRCS = $(shell find $(SRC) -name '*.asm')
OBJS = $(patsubst $(SRC)/%.asm,$(BUILD)/%.o,$(ASM_SRCS))

.PHONY: all
all: $(BUILD)/$(EXEC_NAME)

.PHONY: run
run: all
	@echo -e "     $(GREEN)Running$(NC) $(EXEC_NAME)" 
	@$(BUILD)/$(EXEC_NAME)

.SECONDEXPANSION:
$(BUILD)/%.o: $(SRC)/%.asm $$(shell mk/deps $(SRC)/%.asm)
	@echo -e "   $(GREEN)Compiling$(NC) $*.asm"
	@mkdir -p $(dir $@)
	@(cd $(dir $<) && $(NASM) $(NASM_FLAGS) $(notdir $<) -o $@)

$(BUILD)/$(EXEC_NAME): $(OBJS)
	@echo -e "     $(GREEN)Linking$(NC) $(EXEC_NAME)" 
	@$(LD) $(LD_FLAGS) $(OBJS) -o $(BUILD)/$(EXEC_NAME)

.PHONY: clean
.ONESHELL: clean
clean:
	@BUILD_SIZE=$$((du -h ./build 2>/dev/null || echo 0B) | tail -1 | rg '\d+\w' -o)
	@echo -e "    $(GREEN)Cleaning$(NC) $(BUILD)"
	@rm -rf $(BUILD)
	@echo -e "     $(GREEN)Removed$(NC) $$BUILD_SIZE" 

.PHINY: xnasm
xnasm: $(BUILD)/xnasm
	@$(BUILD)/xnasm

$(BUILD)/xnasm.o: xnasm.asm
	@$(NASM) $(NASM_FLAGS) xnasm.asm -o $(BUILD)/xnasm.o

$(BUILD)/xnasm: $(BUILD)/xnasm.o
	@$(LD) $(LD_FLAGS) $(BUILD)/xnasm.o -o $(BUILD)/xnasm
