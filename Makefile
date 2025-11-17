BUILD = build
SRC = src
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

$(BUILD):
	@mkdir -p $(BUILD)

$(BUILD)/main.o: $(SRC)/main.asm
	@echo -e "   $(GREEN)Compiling$(NC) main.asm"
	@$(NASM) $(NASM_FLAGS) $(SRC)/main.asm -o $(BUILD)/main.o

$(BUILD)/minecraft: $(BUILD)/main.o
	@echo -e "     $(GREEN)Linking$(NC) $(EXEC_NAME)" 
	@$(LD) $(LD_FLAGS) $(BUILD)/main.o -o $(BUILD)/minecraft

clean:
	@echo "Cleaning up"
	@rm -rf $(BUILD)
