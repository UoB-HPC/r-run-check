#!/usr/bin/env bash

set -eu

function checkExistsAndSet() {
    if [[ -f "$1" ]]; then export "$2"="$1"; fi
}

# RPM based systems have tcl/tk stuff in lib64
checkExistsAndSet "/usr/lib64/tclConfig.sh" tclConfig
checkExistsAndSet "/usr/lib64/tkConfig.sh" tkConfig
# Debian based systems have them in lib
checkExistsAndSet "/usr/lib/tclConfig.sh" tclConfig
checkExistsAndSet "/usr/lib/tkConfig.sh" tkConfig

if [ -z ${tclConfig+x} ]; then echo "tclConfig not found" && exit 1; fi
if [ -z ${tkConfig+x} ]; then echo "tkConfig not found" && exit 1; fi

configure_opts=(
    "DEFS='-D_FORTIFY_SOURCE=2'"
    "LIBnn=lib"
    "--enable-R-shlib"
    "--with-tcl-config=$tclConfig"
    "--with-tk-config=$tkConfig"
    "--with-x"
    "--with-blas=yes"
    "--with-lapack=yes"
)

variant="$1"
flavour="$2"
CRAN_rsync=$(readlink -f "$3")
wd=$(readlink -f "$4")
prefix=$(readlink -f "$5")

v=""

case "$variant" in
"gcc")
    compilers=(
        "CC=gcc${v}"
        "CXX=g++${v}"
        "F77=gfortran${v}"
        "FC=gfortran${v}"
        "OBJC=gcc${v}"
        "OBJCXX=gcc${v}"
    )
    ;;
"clang")
    compilers=(
        "CC=clang${v}"
        "CXX=clang++${v}"
        "F77=gfortran${v}"
        "FC=gfortran${v}"
        "OBJC=gcc${v}"
        "OBJCXX=gcc${v}"
    )
    ;;
*)
    echo "Unsupported variant: $variant"
    exit 1
    ;;
esac

case "$flavour" in
r-devel)
    R_source_url="https://cran.r-project.org/src/base-prerelease/R-devel.tar.gz"
    ;;
r-patched)
    R_source_url="https://cran.r-project.org/src/base-prerelease/R-latest.tar.gz"
    ;;
r-prerel)
    R_source_url="https://cran.r-project.org/src/base-prerelease/R-latest.tar.gz"
    ;;
r-release)
    R_source_url="https://cran.r-project.org/src/base/R-latest.tar.gz"
    ;;
esac

echo "=== Building R ==="
echo "Working dir:   $wd"
echo "Prefix:        $prefix"
echo "CRAN:          $CRAN_rsync"
echo "Configuration: ${configure_opts[*]}"
echo "Compiler:      ${variant[*]}"

(# Download R source to $wd/src, clearing old ones first.
    rm -rf "${wd:?}"/* &&
        cd "$wd" && wget -O - --retr-symlinks "$R_source_url" | tar zxmf - &&
        mv "${wd:?}"/* "$wd/src"
) || (echo "Failed to download and untar $R_source_url to src" && exit 1)

# (# Link recommended packages.
#     cd "$wd/src/" &&
#         CRAN_RSYNC="${CRAN_rsync}" ./tools/rsync-recommended
# )

(rm -rf "$prefix" && mkdir "$prefix") || (echo "Cannot clear prefix: $prefix" && exit 1)

(cd "$prefix" && "$wd/src/configure" "${compilers[@]}" "${configure_opts[@]}")

# Try to avoid hard-wiring top-level CRAN master URLs in HTML hrefs from the Texinfo manuals.
if [[ -f "/usr/share/texinfo/htmlxref.cnf" ]]; then
    (
        echo "R = ."
        cat "/usr/share/texinfo/htmlxref.cnf" | grep '^ R-'
    ) >"$prefix/doc/manual/htmlxref.cnf"
fi

(cd "$prefix" && make -j "$(nproc)")
# (cd "$prefix" && make check)
# (cd "$prefix" && make pdf)

# (cd "$prefix/doc/manual" && make fullrefman.pdf)
# (cd "$prefix/doc" && make docs2)
# (cd "$prefix/doc/manual" && make epub)
echo "Done"
