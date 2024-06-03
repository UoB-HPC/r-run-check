options(show.error.locations = TRUE)

options(error = quote({
    dump.frames(to.file = T, dumpto = "last.dump")
    load("last.dump.rda")
    print(last.dump)
    q()
}))

R_scripts_dir <- normalizePath(file.path("~", "src", "lib", "R", "Scripts"))

## Set as needed.
check_repository_root <- "/srv/R/Repositories"
## Set as needed.
libdir <- na.fail(Sys.getenv("_CHECK_CRAN_REGULAR_LIBRARY_DIR_", NA))
build_dir <- na.fail(Sys.getenv("_CHECK_CRAN_REGULAR_BUILD_DIR_", NA))
scriptdir <- na.fail(Sys.getenv("_SCRIPT_DIR_", NA))
Ncpus_i <- Ncpus_c <- na.fail(Sys.getenv("_N_JOBS_", NA))


source(file.path(scriptdir, "stoplist.R"))


verbose <- TRUE

xvfb_run <- "xvfb-run -d --server-args='-screen 0 1280x1024x24'"

Sys.setenv("R_GC_MEM_GROW" = "2")

## <FIXME>
## Need OMP thread limit as 3 instead of 4 when using OpenBLAS.
Sys.setenv(
    "OMP_NUM_THREADS" = 3, # 4?
    "OMP_THREAD_LIMIT" = 3, # 4?
    "RCPP_PARALLEL_NUM_THREADS" = 4,
    "POCL_KERNEL_CACHE" = 0,
    "OMPI_MCA_btl_base_warn_component_unused" = 0
)
## Or maybe instead just
Sys.setenv("OPENBLAS_NUM_THREADS" = 1)
## ???
## </FIXME>

Sys.setenv(
    "_R_CHECK_FORCE_SUGGESTS_" = "false",
    "_R_CHECK_SUGGESTS_ONLY_" = "true"
)

Sys.setenv(
    "_R_CHECK_SCREEN_DEVICE_" = "warn",
    "_R_CHECK_SUPPRESS_RANDR_MESSAGE_" = "true"
)

## For experimenting only ...
if (Sys.getenv("_R_S3_METHOD_LOOKUP_REPORT_SEARCH_PATH_USES_") == "true") {
    Sys.setenv("_R_S3_METHOD_LOOKUP_BASEENV_AFTER_GLOBALENV_" = "false")
} else {
    Sys.setenv("_R_S3_METHOD_LOOKUP_BASEENV_AFTER_GLOBALENV_" = "true")
}

## For experimenting only ...
Sys.setenv("_R_BIND_S3_DISPATCH_FORCE_IDENTICAL_METHODS_" = "false")

## <NOTE>
## This is set in the check environment file used, but the load check
## really happens at install time, hence needs special treatment for
## two-stage installs ...
Sys.setenv("_R_CHECK_INSTALL_DEPENDS_" = "true")
## </NOTE>

## <FIXME>
## Remove eventually ...
Sys.setenv("_R_STOP_ON_XTFRM_DATA_FRAME_" = "true")
## </FIXME>


## Compute repository URLs to be used as repos option for checking,
## assuming local CRAN and BioC mirrors rooted at dir.
## Local Omegahat mirrors via rsync are no longer possible.
check_repository_URLs <- function(dir) {
    ## Could make this settable to smooth transitions ...
    # BioC_version <- if (is.function(tools:::.BioC_version_associated_with_R_version)) {
    #     tools:::.BioC_version_associated_with_R_version()
    # } else {
    #     tools:::.BioC_version_associated_with_R_version
    # }
    BioC_version <- "3.16"

    BioC_names <- c("BioCsoft", "BioCann", "BioCexp")
    BioC_paths <- c("bioc", "data/annotation", "data/experiment")
    ## Assume that all needed src/contrib directories really exist.
    repos <- sprintf(
        "file://%s/%s",
        normalizePath(dir),
        c("CRAN", file.path("Bioconductor", BioC_version, BioC_paths))
    )
    names(repos) <- c("CRAN", BioC_names)
    repos
}

format_timings_from_ts0_and_ts1 <- function(dir) {
    ts0 <- Sys.glob(file.path(dir, "*.ts0"))
    ts1 <- Sys.glob(file.path(dir, "*.ts1"))
    ## These should really have the same length, but who knows.
    mt0 <- file.mtime(ts0)
    mt1 <- file.mtime(ts1)
    timings <-
        merge(
            data.frame(
                Package = sub("\\.ts0$", "", basename(ts0)),
                mt0 = mt0, stringsAsFactors = FALSE
            ),
            data.frame(
                Package = sub("\\.ts1$", "", basename(ts1)),
                mt1 = mt1, stringsAsFactors = FALSE
            )
        )
    sprintf("%s %f", timings$Package, timings$mt1 - timings$mt0)
}

format_timings_from_ts2 <- function(dir, pnames = NULL) {
    if (is.null(pnames)) {
        ts2 <- Sys.glob(file.path(dir, "*.ts2"))
    } else {
        ts2 <- file.path(dir, paste0(pnames, ".ts2"))
        ts2 <- ts2[file.exists(ts2)]
    }
    sprintf(
        "%s %f",
        sub("\\.ts2$", "", basename(ts2)),
        unlist(lapply(
            ts2,
            get_CPU_seconds_used_from_time_output_file
        ))
    )
}

get_CPU_seconds_used_from_time_output_file <- function(f) {
    x <- readLines(f, warn = FALSE)
    p <- "(.*)user (.*)system"
    x <- x[grepl(p, x)][1L]
    if (is.na(x)) {
        return(0)
    }
    m <- regexec(p, x)
    y <- regmatches(x, m)[[1L]][-1L]
    sum(vapply(parse(text = sub(":", "*60+", y)), eval, 0))
}

write_file <- function(file, content) {
    fd <- file(file, "wt")
    cat(content, file = fd)
    close(fd)
}

# We create the dependency tree by first resolving all dependencies (incl `Suggests`,
# needed for testing) of the input. We then resolve only the `Depends` and `Import`
# for each of the dependencies of the input as we're not testing them directly.
resolve_deps <- function(pnames, available) {
    # Get a copy of the system dependencies
    system_deps <- tools:::.get_standard_package_names()$base

    # # For each package, resolve all (incl. Suggests) dependencies: list($p = c($ds...))
    # # We also remove the system ones which we won't install/check and take the
    # # intersection with available packages so that we don't end up with NAs later.
    # pkg_and_deps <- lapply(
    #     tools::package_dependencies(pnames, available, which = "most"),
    #     function(deps) intersect(setdiff(deps, system_deps), rownames(available))
    # )

    # exclude <- union(system_deps, names(pkg_and_deps))
    # # Finally, for all dependencies (values), recursively resolve remaining dependencies.
    # # Drop system deps. and intersectionn with availables ones like the previous step.
    # deps_pkg_and_deps <- lapply(
    #     tools::package_dependencies(
    #         unique(unlist(unname(pkg_and_deps))),
    #         available,
    #         recursive = TRUE
    #     ),
    #     function(deps) intersect(setdiff(deps, system_deps), rownames(available))
    # )
    # # Also drop any packages which we have already determined the suggested dependencies of.
    # deps_pkg_and_deps[names(pkg_and_deps)] <- NULL

    # # message("Top level:")
    # # print(pkg_and_deps)
    # # message("Rest:")
    # # print(deps_pkg_and_deps)


    # message("***")
    # # We have everything now.
    # all_pkg_and_deps <- append(pkg_and_deps, deps_pkg_and_deps)

    # # Remove top-level packages on the RHS to avoid circular dependencies.
    # all_pkg_and_deps <- lapply(
    #     all_pkg_and_deps,
    #     function(deps) setdiff(deps, names(all_pkg_and_deps))
    # )

    # # Make sure all packages (dependency or not) appear in the list by adding
    # # packages that only appear in dep list.
    # no_dep_pkgs <- setdiff(unique(unlist(unname(all_pkg_and_deps))), names(all_pkg_and_deps))

    # # XXX why can't we just do `xs <- character(0)`?
    # all_pkg_and_deps[no_dep_pkgs] <- list(character(0))
    # all_pkg_and_deps


    ## Want to install the given packages and their available
    ## dependencies including Suggests.
    pdepends <- tools::package_dependencies(pnames, available,
        which = "most"
    )
    pnames <- unique(c(
        pnames,
        intersect(
            unlist(pdepends[pnames],
                use.names = FALSE
            ),
            rownames(available)
        )
    )) # pnames = pnames ++ pname,deps
    ## Need to install these and their recursive dependencies.
    pdepends <- tools::package_dependencies(rownames(available),
        available,
        recursive = TRUE
    )
    ## Could also use utils:::.make_dependency_list(), which is a bit
    ## faster (if recursive = TRUE, this drops base packages).
    pnames <- unique(c(
        pnames,
        intersect(
            unlist(pdepends[pnames],
                use.names = FALSE
            ),
            rownames(available)
        )
    ))
    ## Drop base packages from the dependencies.
    pdepends <- lapply(pdepends, setdiff, system_deps)
    #
    pdepends[pnames]
}

extract_local_deps <- function(pkg_and_deps, available) {
    message("Extracting ", length(pkg_and_deps), " packages to ", build_dir)
    all_pkgs <- union(names(pkg_and_deps), unlist(unname(pkg_and_deps)))

    # Extract the path of each package, skip entries without a path.
    pkg_files <- available[, "Path"][all_pkgs]
    pkg_files <- pkg_files[unlist(lapply(pkg_files, function(x) !is.na(x)))]

    results <- parallel::mclapply(pkg_files, function(p) {
        line <- sprintf("cd %s && tar xzf %s", shQuote(build_dir), p)
        message(line)
        system(line)
    }, mc.cores = Ncpus_i)
    message("Done untar")
}

download_remote_deps <- function(pkg_and_deps, available) {
    all_remote_packages <- rownames(available)[!startsWith(available[, "Repository"], "file://")]
    remote_packages <- intersect(
        union(names(pkg_and_deps), unlist(unname(pkg_and_deps))),
        all_remote_packages
    )
    message(sprintf(
        "Found %s (out of %s) remote packages: %s",
        length(remote_packages), length(pkg_and_deps), paste(remote_packages, collapse = ", ")
    ))
    if (length(remote_packages)) {
        dir.create(file.path(build_dir, "Depends"))
        rppaths <- available[remote_packages, "Path"]
        rpfiles <- file.path(build_dir, "Depends", basename(rppaths))
        for (i in seq_along(remote_packages)) {
            download.file(rppaths[i], rpfiles[i], quiet = TRUE)
        }
        available[remote_packages, "Path"] <- rpfiles
    }
}


generate_pkg_makefile <- function(pkg_and_deps, suffix, libdir, timeout, cmd_fn, deps_fn) {
    env_make_flags <- sprintf("/usr/bin/env MAKEFLAGS=-j%s R_LIBS_USER=%s", 1, shQuote(libdir))
    timeout_cmd <- sprintf("%s %s", Sys.which("timeout"), timeout)
    r_exe <- shQuote(file.path(R.home("bin"), "R"))
    # base_r_cmd <- sprintf("%s %s %s", env_make_flags, xvfb_run, timeout_cmd)

    all_pkgs <- union(names(pkg_and_deps), unlist(unname(pkg_and_deps)))
    all_pkgs_obj_with_fmt <- paste(
        strwrap(
            paste(paste0(all_pkgs, ".", suffix, ".ts1"), collapse = " "),
            width = 100, exdent = 2
        ),
        collapse = " \\\n"
    )
    total <- sprintf("total=%s", length(all_pkgs))
    all_rule <- sprintf("all: %s", all_pkgs_obj_with_fmt)
    clean_rule <- "clean:\n\trm *.ts1 && rm *.out"
    echo_pct_fn <- "define echo_pct
\t$(eval started=$(shell echo $$(( $(started)+1 ))))
\t@echo \"[$$((  ($(started)*100) / $(total)  ))%] $(1) ($(started)/$(total))\"
endef"

    # Sort in dependency count order, the ordering is not important for the rules but it's easier to debug.
    sorted_pkg_and_deps <- pkg_and_deps[order(unlist(lapply(pkg_and_deps, length)), decreasing = FALSE)]
    # Generate rules for each package
    pkg_rules <- lapply(names(sorted_pkg_and_deps), function(pkg) {
        deps <- sorted_pkg_and_deps[[pkg]]

        base_r_cmd <- sprintf("%s %s -e %s %s", env_make_flags, xvfb_run, paste0(pkg, ".", suffix, ".xerr"), timeout_cmd)

        cmd <- cmd_fn(base_r_cmd, r_exe, pkg, paste0(pkg, ".", suffix, ".out"))
        paste(sprintf("%s.%s.ts1: %s", pkg, suffix, if (length(deps)) deps_fn(paste0(deps, ".", suffix, ".ts1")) else ""),
            if (verbose) sprintf("\t$(call echo_pct, \"performing %s for %s\")", suffix, sQuote(pkg)),
            sprintf("\t@touch %s.%s.ts0", pkg, suffix),
            sprintf("\t@-/usr/bin/time -o %s.%s.ts2 %s", pkg, suffix, cmd),
            sprintf("\t@touch %s.%s.ts1", pkg, suffix),
            sep = "\n"
        )
    })

    paste(c(total, all_rule, clean_rule, echo_pct_fn, pkg_rules, ""), collapse = "\n")
}


## Compute available packages as used for CRAN checking:
## Use CRAN versions in preference to versions from other repositories
## (even if these have a higher version number)
## For now, also exclude packages according to OS requirement: to
## change, drop 'OS_type' from the list of filters below.
filters <- c("R_version", "OS_type", "CRAN", "duplicates")
repos <- check_repository_URLs(check_repository_root)
## Needed for CRAN filtering below.
options(repos = repos)
## Also pass this to the profile used for checking:
Sys.setenv(
    "_CHECK_CRAN_REGULAR_REPOSITORIES_" =
        paste(sprintf("%s=%s", names(repos), repos), collapse = ";")
)

curls <- contrib.url(repos)
available <- available.packages(contriburl = curls, filters = filters)
## Recommended packages require special treatment: the versions in the
## version specific CRAN subdirectories are not listed as available.  So
## create the corresponding information from what is installed in the
## system library, and merge this in by removing duplicates (so that for
## recommended packages we check the highest "available" version, which
## for release/patched may be in the main package area).
installed <- installed.packages(lib.loc = .Library)
ind <- (installed[, "Priority"] == "recommended")
pos <- match(colnames(available), colnames(installed), nomatch = 0L)
nightmare <- matrix(NA_character_, sum(ind), ncol(available),
    dimnames = list(
        installed[ind, "Package"],
        colnames(available)
    )
)
nightmare[, pos > 0] <- installed[ind, pos]
## Compute where the recommended packages came from.
## Could maybe get this as R_VERSION from the environment.
R_version <- sprintf("%s.%s", R.version$major, R.version$minor)
if (R.version$status == "Patched") {
    R_version <- sub("\\.[[:digit:]]*$", "-patched", R_version)
}
nightmare[, "Repository"] <-
    file.path(repos["CRAN"], "src", "contrib", R_version, "Recommended")

ind <- (!is.na(priority <- available[, "Priority"]) & (priority == "recommended"))
available <- rbind(tools:::.remove_stale_dups(rbind(nightmare, available[ind, ])), available[!ind, ])

## Make sure we have the most recent versions of the recommended
## packages in .Library.
update.packages(lib.loc = .Library, available = available, ask = FALSE)

## Paths to package tarballs.
pfiles <- sub(
    "^file://", "",
    sprintf("%s/%s_%s.tar.gz", available[, "Repository"], available[, "Package"], available[, "Version"])
)
available <- cbind(available, Path = pfiles)


# write.csv(available,"~/available.csv")

# stop()


## Unpack all CRAN packages to simplify checking via Make.
ind <- startsWith(available[, "Repository"], repos["CRAN"])
## <NOTE>
## In principle we could also check the e.g. BioC (software) packages by
## (optionally) doing
##    ind <- ind | startsWith(available[, "Repository"],
##                            repos["BioCsoft"])
## </NOTE>

# print(head(pfiles, 10))
# print(head(pnames, 10))
# print(length(which(ind == FALSE)))
# stop()



## <NOTE>
## * Earlier version also installed the CRAN packages from the unpacked
##   sources, to save the resources of the additional unpacking when
##   installing from the tarballs.  This complicates checking (and made
##   it necessary to use an .install_timestamp mechanism to identify
##   files in the unpacked sources created by installation): hence, we
##   no longer do so.
## * We could easily change check_packages_with_timings_via_fork() to
##   use the package tarballs for checking: simply replace 'pname' by
##   'available[pname, "Path"]' in the call to R CMD check.
##   For check_packages_with_timings_via_make(), we would need to change
##   '$*' in the Make rule by something like $(*-path), and add these
##   PNAME-path variables along the lines of adding the PNAME-cflags
##   variables.
## </NOTE>

## Add information on install and check flags.
## Keep things simple, assuming that the check args db entries are one
## of '--install=fake', '--install=no', or a combination of other
## arguments to be used for full installs.
check_args_db <- stoplist

pnames <- rownames(available)[ind]
pnames_using_install_no <- intersect(names(check_args_db)[check_args_db == "--install=no"], pnames)
pnames_using_install_fake <- intersect(names(check_args_db)[check_args_db == "--install=fake"], pnames)
pnames_using_install_full <- setdiff(pnames, c(pnames_using_install_no, pnames_using_install_fake))
## For simplicity, use character vectors of install and check flags.
iflags <- character(length(pfiles))
names(iflags) <- rownames(available)
cflags <- iflags
iflags[pnames_using_install_fake] <- "--fake"
## Packages using a full install are checked with '--install=check:OUT',
## where OUT is the full/fake install output file.
## <FIXME>
## Packages using a fake install are checked with '--install=fake'.
## Currently it is not possible to re-use the install output file, as we
## cannot give both --install=fake --install=check:OUT to R CMD check.
## However, in principle checking with --install=fake mostly only
## turns off the run time tests, so we check --install=fake packages
## with  --install=check:OUT --no-examples --no-vignettes --no-tests.
cflags[pnames_using_install_no] <- "--install=no"
##   cflags[pnames_using_install_fake] <- "--install=fake"
cflags[pnames_using_install_fake] <- sprintf(
    if ((getRversion() >= "4.2.0") && (as.integer(R.version[["svn rev"]]) >= 80722)) {
        "--install='check+fake:%s/%s.install.out' %s"
    } else {
        "--install='check:%s/%s.install.out' %s"
    },
    build_dir, pnames_using_install_fake,
    "--no-examples --no-vignettes --no-tests"
)
## </FIXME>
pnames <- intersect(pnames_using_install_full, names(check_args_db))
cflags[pnames] <- sprintf("--install='check:%s/%s.install.out' %s", build_dir, pnames, check_args_db[pnames])
pnames <- setdiff(pnames_using_install_full, names(check_args_db))
cflags[pnames] <- sprintf("--install='check:%s/%s.install.out'", build_dir, pnames)
## Now add install and check flags to available db.
available <- cbind(available, Iflags = iflags, Cflags = cflags)

if (!utils::file_test("-d", libdir)) stop("library dir: ", libdir, " is missing!")

## For testing purposes:
# pnames <-
#     c(
#         head(pnames_using_install_full, 10),
#         pnames_using_install_fake,
#         pnames_using_install_no
#     )
pnames <- c(pnames_using_install_full, pnames_using_install_fake, pnames_using_install_no)

## <FIXME>
## Some packages cannot be checked using the current timeouts (e.g., as
## of 2019-03 maGUI takes very long to perform the R code analysis,
## which cannot be disabled selectively).
## Hence, drop these ...
## There should perhaps be a way of doing this programmatically from the
## stoplists ...
pnames_to_be_dropped <- c("maGUI")
pnames <- setdiff(pnames, pnames_to_be_dropped)

## Some packages fail when using SNOW to create socket clusters
## simultaneously, with
##   In socketConnection(port = port, server = TRUE, blocking = TRUE,  :
##     port 10187 cannot be opened
## These must be checked serially (or without run time tests).
## Others (e.g., gpuR) need enough system resources to be available when
## checking.
pnames_to_be_checked_serially <- c(
    "MSToolkit", "MSwM", "gdsfmt", "geneSignatureFinder", "gpuR",
    "simFrame", "snowFT", "AFM", "AIG"
)

## </FIXME>
message("Start check par ... ", libdir)


resolved <- resolve_deps(pnames, available)

message("Packages to install/check: ", length(resolved))

extract_local_deps(resolved, available)
download_remote_deps(resolved, available)

write_file(file.path(build_dir, "Makefile.install"), generate_pkg_makefile(
    resolved, "install", libdir,
    Sys.getenv("_R_INSTALL_PACKAGES_ELAPSED_TIMEOUT_", "3600"),
    function(base_cmd, r_bin, pkg, out) {
        sprintf(
            "%s %s CMD INSTALL --pkglock %s %s > %s 2>&1",
            base_cmd,
            r_bin,
            available[pkg, "Iflags"],
            pkg,
            out
        )
    },
    function(deps) paste(deps, collapse = " ")
))

write_file(file.path(build_dir, "Makefile.check"), generate_pkg_makefile(
    resolved, "check", libdir,
    Sys.getenv("_R_CHECK_ELAPSED_TIMEOUT_", "1800"),
    function(base_cmd, r_bin, pkg, out) {
        sprintf(
            "%s sh -c \"%s CMD check --timings -l %s %s %s >> %s 2>&1\"",
            base_cmd,
            # out,
            r_bin,
            shQuote(libdir),
            available[pkg, "Cflags"],
            pkg,
            out
        )
    },
    function(deps) "" # No dependencies needed for checking, run everything in parallel.
))

buildstr <- sprintf("cd %s && make -f Makefile.install -k -j %s", shQuote(build_dir), Ncpus_i)
message("Starting build...")
message("CMD=", buildstr)
system(buildstr)
system(sprintf("cd %s && make -f Makefile.check -k -j %s ", shQuote(build_dir), Ncpus_i))

stop()




message("Starting install of ", length(pnames), " packages")
timings <- install_packages_with_timings(setdiff(pnames, pnames_using_install_no), available, libdir, Ncpus_i)
writeLines(timings, "timings_i.tab")

message("Done install, starting checks...")



## Do not allow packages to modify their system files when checking.
## Ideally, this is achieved via a read-only bind (re)mount of libdir,
## which can be achieved in user space via bindfs, or in kernel space
## via dedicated '/etc/fstab' non-superuser mount point entries.
## (E.g.,
## <https://unix.stackexchange.com/questions/198590/what-is-a-bind-mount>
## for more information on bind mounts.)
## The user space variant adds a noticeable overhead: in 2018-01, about
## 30 minutes for check runs taking about 6.5 hours.
## Hence, do the kernel space variant if possible (as inferred by an
## entry for libdir in '/etc/fstab').
## For the user space variant, '--no-allow-other' seems to suffice, and
## avoids the need for enabling 'user_allow_other' in '/etc/fuse.conf'.
## However, it apparently has problems when (simultaneously) checking
## Rcmdr* packages, giving "too many open files" errors when using the
## default maximum number for open file descriptors of 1024: this can be
## fixed via ulimit -n 2048 in check-R-ng.

bind_mount_in_user_space <- TRUE
#     ! any(startsWith(readLines("/etc/fstab", warn = FALSE), libdir))
# if (bind_mount_in_user_space) {
#     system2(
#         "bindfs",
#         c(
#             "-r", "--no-allow-other",
#             shQuote(libdir), shQuote(libdir)
#         )
#     )
# } else {
#     system2("mount", c("--bind", libdir, libdir, "-o", "ro"))
#     # system2("mount", shQuote(libdir))
# }

## <FIXME>
## (We should really look at the return values of these calls.)
## </FIXME>

## Older variants explicitly removed write mode bits for files in libdir
## while checking: also possible, but a bit too much, given that using a
## umask of 222 seems "strange", and *copying* from the libdir, e.g.,
## using file.copy(), will by default copy the modes.
## <COMMENT>
## system2("chmod", c("-R", "a-w", shQuote(libdir)))
## ## <FIXME>
## ## See above for '--install=fake' woes and how we currently work
## ## around these.
## ##   But allow some access to libdir for packages using --install=fake.
## ##   system2("chmod", c("u+w", shQuote(libdir)))
## ##   for(p in pnames_using_install_fake)
## ##       system2("chmod", c("-R", "u+w", shQuote(file.path(libdir, p))))
## ## </FIXME>
## </COMMENT>
message("\t Serial:", length(pnames_to_be_checked_serially), "\n\tParallel:", length(setdiff(pnames, pnames_to_be_checked_serially)))
timings <- check_packages_with_timings_via_make(
    setdiff(pnames, pnames_to_be_checked_serially),
    available, libdir, Ncpus_c
)
stop()
if (length(pnames_to_be_checked_serially)) {
    timings <- c(
        timings,
        check_packages_with_timings_via_make(
            intersect(pnames, pnames_to_be_checked_serially),
            available, libdir, 1
        )
    )
}
writeLines(timings, "timings_c.tab")

if (bind_mount_in_user_space) {
    system2("fusermount", c("-u", shQuote(libdir)))
} else {
    system2("umount", shQuote(libdir))
}

## <FIXME>
## (We should really look at the return values of these calls.)
## </FIXME>

## Older variants case:
## <COMMENT>
## ## Re-enable write permissions.
## system2("chmod", c("-R", "u+w", shQuote(libdir)))
## </COMMENT>

## Copy the package DESCRIPTION metadata over to the directories with
## the check results.
dpaths <- file.path(sprintf("%s.Rcheck", pnames), "00package.dcf")
invisible(file.copy(file.path(pnames, "DESCRIPTION"), dpaths))
Sys.chmod(dpaths, "644") # Avoid rsync permission woes.

## Summaries.

## Source to get check_flavor_summary() and check_details_db().
source(file.path(R_scripts_dir, "check.R"))



## Check summary.
summary <- as.matrix(check_flavor_summary(check_dirs_root = cwd))
## Change NA priority to empty.
summary[is.na(summary)] <- ""
## Older versions also reported all packages with NOTEs as OK.
## But why should we not want to see new NOTEs?
write.csv(summary,
    file = "summary.csv", quote = 4L, row.names = FALSE
)

## Check details.
dir <- dirname(cwd)
details <- check_details_db(dirname(dir), basename(dir), drop_ok = NA)
write.csv(details[c("Package", "Version", "Check", "Status")],
    file = "details.csv", quote = 3L, row.names = FALSE
)
## Also saveRDS details without flavor column and and ok results left in
## from drop_ok = NA (but keep ok stubs).
details <-
    details[(details$Check == "*") |
        is.na(match(
            details$Status,
            c("OK", "NONE", "SKIPPED")
        )), ]
details$Flavor <- NULL
saveRDS(details, "details.rds", version = 2)

## Check timings.
timings <- merge(read.table(file.path(cwd, "timings_i.tab")),
    read.table(file.path(cwd, "timings_c.tab")),
    by = 1L, all = TRUE
)
names(timings) <- c("Package", "T_install", "T_check")
timings$"T_total" <-
    rowSums(timings[, c("T_install", "T_check")], na.rm = TRUE)
write.csv(timings,
    file = "timings.csv", quote = FALSE, row.names = FALSE
)
