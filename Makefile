FILE = "spec/data/debug.bc"

run: stackvm
	bin/stackvm

stackvm:
	mkdir -p bin
	crystal build src/stackvm.cr -o bin/stackvm --error-trace

clean:
	find . -name "**/.DS_Store" | xargs rm
	find . -name "*.swp" | xargs rm
	find . -name "*.swo" | xargs rm
	rm -rf bin
