FILE = "spec/data/debug.bc"

run_stackvm: stackvm
	bin/stackvm

run_asm: asm
	bin/asm build debug.asm

stackvm:
	mkdir -p bin
	crystal build src/stackvm.cr -o bin/stackvm --error-trace

asm:
	mkdir -p bin
	crystal build src/assembler.cr -o bin/asm --error-trace

clean:
	find . -name "**/.DS_Store" | xargs rm
	find . -name "*.swp" | xargs rm
	find . -name "*.swo" | xargs rm
	rm -rf bin
