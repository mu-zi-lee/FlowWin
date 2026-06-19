APP_NAME := FlowWin
SRC := $(wildcard Sources/FlowWin/*.m)
HEADERS := $(wildcard Sources/FlowWin/*.h)
BUILD_DIR := .build
BIN_DIR := $(BUILD_DIR)/release
BIN := $(BIN_DIR)/$(APP_NAME)

CFLAGS := -O2 -fobjc-arc -ObjC -Wall -Wextra -Wno-deprecated-declarations -mmacosx-version-min=12.3
FRAMEWORKS := -framework Cocoa -framework CoreGraphics -framework ApplicationServices -framework QuartzCore -framework Carbon -framework ScreenCaptureKit -framework CoreMedia -framework CoreVideo -framework CoreImage

.PHONY: all run check clean app

all: $(BIN)

$(BIN): $(SRC) $(HEADERS)
	mkdir -p $(BIN_DIR)
	clang $(CFLAGS) $(SRC) $(FRAMEWORKS) -o $(BIN)

run: $(BIN)
	$(BIN)

check: $(BIN)
	$(BIN) --preflight
	$(BIN) --automation-help >/dev/null
	$(BIN) --list-windows >/dev/null

app:
	./scripts/build-app.sh

clean:
	rm -rf $(BUILD_DIR)
