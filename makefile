
clean:
	rm callyouback.dll callyouback.exe
build: callyouback.c leak.lisp
	gcc -shared -o callyouback.dll -fPIC callyouback.c
run: build
	LD_LIBRARY_PATH=./ sbcl leak.lisp
run-c: build
	gcc -pthread -o callyouback callyouback.c
	./callyouback
