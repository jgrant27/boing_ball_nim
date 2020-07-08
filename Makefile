NIMBLE_PATH := 'nimble'
BIN_OUT_DIR	:= 'build'
BINARY      := 'boing_ball'

all: clean compile

clean:
	rm -fr $(BIN_OUT_DIR)/$(BINARY)

compile:
	$(NIMBLE_PATH) build --gc:orc -d:release --nimcache:$(BIN_OUT_DIR) --out:$(BINARY) --checks:on
	@mv $(BINARY) $(BIN_OUT_DIR)/$(BINARY)

run: compile
	$(BIN_OUT_DIR)/$(BINARY)
