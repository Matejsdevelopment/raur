Raur is a simple and fast Arch User Repository (AUR) helper made in the V programming language.

It is a small project made in two months (while grabbing little free time to code it).
It uses the Meow Argument Parser.

I ported some small parts of the ALPM to Vlang in this project too.
The port is very small and is in the alpmhandling.v file, it is in the dependancyres module, but
feel free to modify the module and use it for your own needs.

To install the V programming language use the following script:
    git clone --depth=1 https://github.com/vlang/v
    cd v
    make

To build Raur use the following script:
    v . --enable-globals
    ./raur
    #if you use fish
    cd ..
    fish_add_path raur

WARNING!:
  This project is nowhere close to Yay or Paru yet, it has many bugs and has unused some functions and maybe even entire files.

The development of Raur will likely continue.
