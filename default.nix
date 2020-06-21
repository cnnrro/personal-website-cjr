with import <nixpkgs> { config.allowUnfree = true; };

let
	unstable = import (fetchTarball "channel:nixos-unstable") { config = config; };
in stdenv.mkDerivation {
	name = "env";
	buildInputs = [
		bashInteractive
		devd
		jq
		moreutils
		yq-go
		pandoc
		gnumake
		# gomplate
		image_optim
		unstable.minify
		sass sassc # sass compiler
	];
}
