# Host build + test for the SubFlow native core (no Android SDK required).
# Used in CI and by `npm run subflow:test:native` from the workspace root.
CXX      ?= g++
CXXSTD   ?= -std=c++17
OPT      ?= -O2
WARN     := -Wall -Wextra -Wpedantic -Wshadow -Wconversion -Wno-sign-conversion
CORE_DIR := ../../android/app/src/main/cpp
INC      := -I$(CORE_DIR)
SRC      := $(wildcard $(CORE_DIR)/core/*.cpp) test_main.cpp
HDR      := $(wildcard $(CORE_DIR)/core/*.h) sf_test.h
BIN      := build/sf_core_tests
SAN_BIN  := build/sf_core_tests_sanitized

.PHONY: all test test-asan check-jni clean

all: $(BIN)

$(BIN): $(SRC) $(HDR)
	@mkdir -p build
	$(CXX) $(CXXSTD) $(OPT) $(WARN) $(INC) $(SRC) -o $(BIN)

test: $(BIN)
	@./$(BIN)

# Memory / UB verification: the same suite under ASan + UBSan.
test-asan: $(SRC) $(HDR)
	@mkdir -p build
	$(CXX) $(CXXSTD) -O1 -g $(WARN) -fsanitize=address,undefined \
		-fno-omit-frame-pointer $(INC) $(SRC) -o $(SAN_BIN)
	@./$(SAN_BIN)

# Syntax-only check of the JNI bridge against a stub jni.h. The real NDK header
# is only available inside the Android build, but this still catches C++ errors.
check-jni:
	$(CXX) $(CXXSTD) -fsyntax-only -Wall -Wextra -I$(CORE_DIR) -I$(CORE_DIR)/core -Istub \
		$(CORE_DIR)/jni/sf_jni.cpp && echo "jni syntax OK"

clean:
	rm -rf build
