# R-run-check

 **Work In Progress**

This repo contains tools and scripts for building and checking *all* CRAN (and some Bioconductor) packages, to the extent possible, on Linux.

The objective is to setup a build-and-check server like the ones listed on [CRAN Package Check Results](https://cran.r-project.org/web/checks/check_summary.html) in a documented and reproducible way.

This repo could useful for R users looking to install packages with non-trivial dependencies, ones that aren't normally included in Linux mainstream distros.
**However, please consult CRAN's list of distro-specific instructions on using CRAN packages first:**

* [Fedora, RHEL, CentOS, AlmaLinux, RockyLinux](https://cran.r-project.org/bin/linux/fedora/)
* [Debian](https://cran.r-project.org/bin/linux/debian/)
* [Ubuntu](https://cran.r-project.org/bin/linux/ubuntu/)
* [SUSE](https://cran.r-project.org/bin/linux/suse/README.html)

In any case, binaries for R packages in Linux is distro dependent.

## What's in the repo?

This repo contains the following:

 1. A [shell script](sync_contrib.sh) for pulling all CRAN and Bioconductor packages required for a complete CRAN build.
 2. A set of mostly distro-independent shell scripts (`install_*.sh`) for building select non-trivial dependencies needed by R packages from source.
 3. Docker images with packages installed and configured for building everything in CRAN, along with R itself and parts of Bioconductor.
    * [AlmaLinux 8 (i.e. CentOS/Rocky Linux 8)](./Dockerfile.almalinux)
    * [Ubuntu 22.04 LTS](./Dockerfile.ubuntu)

## Credit

Most of the script heavily references the original check script `check-R-ng`, along with the dependent files, available at <https://svn.r-project.org/R-dev-web/trunk>.
Many workarounds for existing packages are implemented referencing <https://www.stats.ox.ac.uk/pub/bdr>.

Projects with a similar scope include:

* <https://github.com/Enchufa2/cran2copr>
* <https://copr.fedorainfracloud.org/coprs/iucar/cran/>
