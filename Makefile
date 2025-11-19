BUILD = $(shell pwd)/build
SRC = $(shell pwd)/src
EXEC_NAME = minecraft

NASM = nasm
NASM_FLAGS = --gprefix _ -f elf64
LD = ld
LD_FLAGS =

GREEN = \033[0;32m
NC = \033[0m

all: $(BUILD)/minecraft

run: all
	@echo -e "     $(GREEN)Running$(NC) $(EXEC_NAME)" 
	@$(BUILD)/minecraft

$(BUILD)/main.o: $(SRC)/main.asm
	@echo -e "   $(GREEN)Compiling$(NC) main.asm"
	@mkdir -p $(BUILD)
	@(cd $(SRC) && $(NASM) $(NASM_FLAGS) $(SRC)/main.asm -o $(BUILD)/main.o)

$(BUILD)/memory/alloc.o: $(SRC)/memory/alloc.asm
	@echo -e "   $(GREEN)Compiling$(NC) memory/alloc.asm"
	@mkdir -p $(BUILD)/memory
	@(cd $(SRC)/memory && $(NASM) $(NASM_FLAGS) $(SRC)/memory/alloc.asm -o $(BUILD)/memory/alloc.o)

$(BUILD)/error/abort.o: $(SRC)/error/abort.asm
	@echo -e "   $(GREEN)Compiling$(NC) error/abort.asm"
	@mkdir -p $(BUILD)/error
	@(cd $(SRC)/error && $(NASM) $(NASM_FLAGS) $(SRC)/error/abort.asm -o $(BUILD)/error/abort.o)

$(BUILD)/minecraft: $(BUILD)/main.o $(BUILD)/memory/alloc.o $(BUILD)/error/abort.o
	@echo -e "     $(GREEN)Linking$(NC) $(EXEC_NAME)" 
	@$(LD) $(LD_FLAGS) $(BUILD)/main.o $(BUILD)/memory/alloc.o $(BUILD)/error/abort.o -o $(BUILD)/minecraft

clean:
	@echo -e "    $(GREEN)Cleaning$(NC) $(BUILD)"
	@rm -rf $(BUILD)
