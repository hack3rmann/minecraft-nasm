BUILD = build
SRC = src
EXEC_NAME = minecraft

NASM = nasm
NASM_FLAGS = --gprefix _ -f elf64
LD = ld
LD_FLAGS =

all: $(BUILD)/minecraft

$(BUILD):
	@mkdir -p $(BUILD)

$(BUILD)/main.o: $(SRC)/main.asm
	@echo "Building main.asm"
	@$(NASM) $(NASM_FLAGS) $(SRC)/main.asm -o $(BUILD)/main.o

$(BUILD)/minecraft: $(BUILD)/main.o
	@echo "Linking minecraft"
	@$(LD) $(LD_FLAGS) $(BUILD)/main.o -o $(BUILD)/minecraft

clean:
	@echo "Cleaning up"
	@rm -rf $(BUILD)
