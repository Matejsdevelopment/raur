# raur

raur is a simple and fast Arch User Repository (AUR) helper made in the V programming language.
It is a small project made in two months while grabbing little free time to code it.

It uses the Meow Argument Parser.

I ported some small parts of ALPM to Vlang in this project too, the port is very small and lives in
`dependancyres/alpmhandling.v`, feel free to use or modify it for your own needs.

## Warning

This project is nowhere close to Yay or Paru yet, it has many bugs and has some unused functions and maybe even entire files.
The development of raur will likely continue.

## Installing V

```sh
git clone --depth=1 https://github.com/vlang/v
cd v
make
```

## Building raur

```sh
v . --enable-globals
./raur
```

If you use fish:

```sh
cd ..
fish_add_path raur
```

## Using Raur

```sh
raur -S package   # install a package
raur -s package   # search for a package
raur -R package   # remove a package (pacman is better for this)
raur -d           # debug mode
```
