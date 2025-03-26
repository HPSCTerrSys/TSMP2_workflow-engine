BUILD_DIR = ./_build

all: doc

doc:
	jupyter-book build -W -n --keep-going .

.PHONY: clean

clean:
	jupyter-book clean .
