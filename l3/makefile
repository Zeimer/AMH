all:
	ghc -O2 Genetic.hs -hidir bin -odir bin -o main > bin/compilation_log.txt 2>&1

clean:
	rm bin/*
	rm main


run: all
	./main
