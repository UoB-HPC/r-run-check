#!/usr/bin/env bash

set -eu -x
export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

variant="gcc"
r_flavour="r-release"
cran_dir="/srv/R/Repositories/CRAN"
check_dir="$HOME/tmp/R.check"
check_flavor="$r_flavour-$variant"
n_jobs=$(($(nproc) + 8))
build_r=true

script_dir=$(realpath "$(dirname "${BASH_SOURCE[0]}")")

# No process is allowed more than 20 minutes
ulimit -t 1200
# Apparently needed when using bindfs to obtain a read-only mounted user library for checking:
ulimit -n 2048
# Use a bit more max stack size than used by default.
ulimit -s 16384

# Customize R
export R_BROWSER=false
export R_PDFVIEWER=false
export LANG="C.UTF-8" # Try using a UTF-8 locale.
export LC_COLLATE=C   # But not for sorting ...
export LANGUAGE="en@quot"
export R_PARALLEL_PORT=random
export R_PAPERSIZE=a4                             # Avoid hyperref problems with paper size 'letter'.
export _R_SHLIB_BUILD_OBJECTS_SYMBOL_TABLES_=true # Documented to be true in R-ints, but apparently not always.

# Use r-devel-clang to record S3 method search path lookups.
if test "${check_flavor}" = "r-devel-clang"; then
  export _R_S3_METHOD_LOOKUP_REPORT_SEARCH_PATH_USES_=true
fi

if test "${check_flavor}" = "r-devel-clang"; then # FIXME
  export LANG=en_US.iso885915
fi

# Structure inside ${check_dir}: subdirectories for each flavor.
# Within a flavor subdirectory, most of the work happens in 'Work'.
# Inside this, R sources are in 'src', R is built in 'build', and
# packages are in 'PKGS'.  When done, 'PKGS' is moved up for mirroring,
# and results are saved in 'Results/${check_date}'.
# $check_dir/
#  └─ $check_flavour/
#      ├─ user/
#      │  ├─ config/ # R user config dir
#      │  ├─ cache/  # R user cache dir
#      │  └─ data/   # R user data dir
#      ├─ work/
#      │  ├─ pkg_build_dir/   # this is the wd where we write Makefile and untar to
#      │  ├─ libdir/          # library dir for R packages, this is where we install packages to
#      │  ├─ src/             # extracted R sources
#      │  └─ build/           # R install prefix
#      ├─ xvfb.pid
#      └─ check.pid

mkdir -p "$check_dir/$check_flavor/user" "$check_dir/$check_flavor/work"

check_pid_file="$check_dir/$check_flavor/check.pid"
xvfb_pid_file="$check_dir/$check_flavor/xvfb.pid"
work_dir="$check_dir/$check_flavor/work"

if [[ "$build_r" == true ]]; then
  "$script_dir/build_r.sh" "$variant" "$r_flavour" "$cran_dir" "$work_dir" "$work_dir/build"
fi

R_HOME="$("$check_dir/$check_flavor/work/build/bin/R" RHOME)"
export R_HOME
R_PROFILE_USER="$script_dir/check_CRAN_regular.Rprofile"
export R_PROFILE_USER
R_CHECK_ENVIRON="$script_dir/check_CRAN_regular.Renviron"
export R_CHECK_ENVIRON
R_MAKEVARS_USER="$script_dir/Makevars-$variant"
export R_MAKEVARS_USER

if [[ ! -f "$R_PROFILE_USER" ]]; then echo "R_PROFILE_USER ($R_PROFILE_USER) does not exist!" && exit 1; fi
if [[ ! -f "$R_CHECK_ENVIRON" ]]; then echo "R_CHECK_ENVIRON ($R_CHECK_ENVIRON) does not exist!" && exit 1; fi
if [[ ! -f "$R_MAKEVARS_USER" ]]; then echo "R_MAKEVARS_USER ($R_MAKEVARS_USER) does not exist!" && exit 1; fi

export R_USER_DATA_DIR="$check_dir/$check_flavor/user/data"
export R_USER_CACHE_DIR="$check_dir/$check_flavor/user/cache"
export R_USER_CONFIG_DIR="$check_dir/$check_flavor/user/config"
export _CHECK_CRAN_REGULAR_LIBRARY_DIR_="$work_dir/libdir"
export _CHECK_CRAN_REGULAR_BUILD_DIR_="$work_dir/build_dir"

mkdir -p \
  "$R_USER_DATA_DIR" "$R_USER_CACHE_DIR" "$R_USER_CONFIG_DIR" \
  "$_CHECK_CRAN_REGULAR_LIBRARY_DIR_" \
  "$_CHECK_CRAN_REGULAR_BUILD_DIR_"

if [[ -f "$check_pid_file" ]]; then echo "Old check process still running ($check_pid_file), aborting..." && exit 1; fi

echo ${$} >"$check_pid_file" # Record check pid.
# # Start a virtual framebuffer X server and use this for DISPLAY so that we can run package tcltk and friends.
# # We use the PID of the check process as the server number so that the checks for different flavors get different servers.
Xvfb :${$} -screen 0 1280x1024x24 >/dev/null 2>&1 &
echo ${!} >"$xvfb_pid_file"
export DISPLAY=:${$}

# <FIXME>
# Shouldn't this shut down Xvfb as well and remove its pid file?
do_cleanup_and_exit() {
  kill -9 "$(cat "$xvfb_pid_file")" 2>/dev/null && rm -f "$xvfb_pid_file"
  rm -f "$check_pid_file"
  # These get populated by the check runs ...
  rm -rf "$HOME/.cache/fontconfig"
  rm -rf "$HOME/.cache/pocl"
  exit ${1-0}
}

export _SCRIPT_DIR_="$script_dir"
export _N_JOBS_="$n_jobs"

# Pass over to R for installation and checking and summaries ...
"$R_HOME/bin/Rscript" "$script_dir/check_CRAN_regular.R" || echo "R exited with $?"

echo "Done"

do_cleanup_and_exit 0

# # Wrap up.
# cd ${check_dir}/${check_flavor}

# # Rotate old check results files.
# for f in ${check_results_files} details.rds; do
#   test -f "${f}.prev" && rm -f "${f}.prev"
#   test -f "${f}" && mv "${f}" "${f}.prev"
# done
# # Rotate old check results.
# # <FIXME>
# # Remove the chmod -R eventually ...
# test -d PKGS.prev && chmod -R u+w PKGS.prev && rm -rf PKGS.prev
# test -d PKGS && chmod -R u+w PKGS && mv PKGS PKGS.prev
# # </FIXME>
# # Move new check results up from Work.
# mv Work/PKGS PKGS
# chmod -R u+w PKGS
# # Move new check results files up from PKGS.
# for f in ${check_results_files} details.rds; do
#   mv PKGS/"${f}" .
# done
# # Save new check results files.
# for d in Results Results/${check_date}; do
#   test -d ${d} || mkdir ${d} || do_cleanup_and_exit 1
# done
# for f in ${check_results_files}; do
#   cp "${f}" "Results/${check_date}"
# done

# echo "Stop here>>>"
# exit 0

# # And notify of differences ...
# if test -f "summary.csv.prev"; then
#   diff "summary.csv.prev" "summary.csv" >"summary.csv.diff"
#   test -s "summary.csv.diff" || rm -f "summary.csv.diff"
# fi
# if test -f "summary.csv.diff"; then
#   echo "source(\"${R_scripts_dir}/check.R\"); \
#         write_check_summary_diffs_to_con(\".\", \"summary.csv.diff\")" |
#     ${R_exe} --vanilla --slave
#   env from=Kurt.Hornik@wu.ac.at replyto=Kurt.Hornik@R-project.org \
#     REPLYTO=Kurt.Hornik@R-project.org \
#     mail -s "[CRAN-check-ng] ${check_flavor}/$(hostname) summary.csv changes on $(date '+%FT%T%z')" \
#     -r Kurt.Hornik@wu.ac.at \
#     ${check_results_mail_recipients} <"summary.csv.diff"
#   rm -f "summary.csv.diff"
# fi

# if test -f "details.csv.prev"; then
#   diff "details.csv.prev" "details.csv" >"details.csv.diff"
#   test -s "details.csv.diff" || rm -f "details.csv.diff"
# fi
# if test -f "details.csv.diff"; then
#   echo "source(\"${R_scripts_dir}/check.R\"); \
#         flavor <- check_flavors_map[\"${check_flavor}\"]; \
#         write_check_details_diffs_to_con(\".\", \"details.csv.diff\", flavor)" |
#     ${R_exe} --vanilla --slave
#   env from=Kurt.Hornik@wu.ac.at replyto=Kurt.Hornik@R-project.org \
#     REPLYTO=Kurt.Hornik@R-project.org \
#     mail -s "[CRAN-check-ng] ${check_flavor}/$(hostname) details.csv changes on $(date '+%FT%T%z')" \
#     -r Kurt.Hornik@wu.ac.at \
#     ${check_results_mail_recipients} <"details.csv.diff"
#   rm -f "details.csv.diff"
#   echo "source(\"${R_scripts_dir}/check.R\"); \
#         write_check_details_for_new_problems_to_con(\".\", \"details.txt\")" |
#     ${R_exe} --vanilla --slave
#   test -s "details.txt" &&
#     env from=Kurt.Hornik@wu.ac.at replyto=Kurt.Hornik@R-project.org \
#       REPLYTO=Kurt.Hornik@R-project.org \
#       mail -s "[CRAN-check-ng] ${check_flavor}/$(hostname) new problems on $(date '+%FT%T%z')" \
#       -r Kurt.Hornik@wu.ac.at \
#       ${check_results_mail_recipients} <"details.txt"
#   rm -f "details.txt"
# fi

# # Manuals

# if test -n "${build_R}"; then
#   test -d Manuals.prev && rm -rf Manuals.prev
#   test -d Manuals && mv Manuals Manuals.prev
#   mkdir Manuals
#   # <FIXME 3.4.0>
#   # Change back to copying when 3.2.0 is out.
#   #   cp Work/build/doc/manual/*.html Manuals
#   for f in Work/build/doc/manual/*.html; do
#     grep -v '="dir.html#Top"' ${f} >Manuals/$(basename ${f})
#   done
#   # </FIXME>
#   cp Work/build/doc/manual/*.pdf Manuals
#   # It would be better to have a single R.css and logo.jpg/Rlogo.svg, and
#   # fix NEWS.html accordingly.
#   cat Work/build/doc/html/NEWS.html |
#     sed 's/img src="[^"]*logo.jpg"/img src="logo.jpg"/' |
#     sed 's/img src="[^"]*Rlogo.svg"/img src="Rlogo.svg"/' \
#       >Manuals/NEWS.html
#   cp Work/build/doc/html/R.css Manuals
#   cp Work/build/doc/html/logo.jpg Manuals
#   cp Work/build/doc/html/Rlogo.svg Manuals
#   cp Work/build/doc/NEWS*.pdf Manuals
#   cat Work/build/doc/html/NEWS.2.html |
#     sed 's/img src="[^"]*Rlogo.svg"/img src="Rlogo.svg"/' \
#       >Manuals/NEWS.2.html
#   cat Work/build/doc/html/NEWS.3.html |
#     sed 's/img src="[^"]*Rlogo.svg"/img src="Rlogo.svg"/' \
#       >Manuals/NEWS.3.html
#   cp Work/build/doc/manual/*.epub Manuals
#   mkdir Manuals/images
#   cp Work/build/doc/manual/images/*.png Manuals/images
# fi

# # Refmans in HTML (if available)
# if test -f Work/build/library/base/html/mean.html; then
#   test -d Refmans.prev && rm -rf Refmans.prev
#   test -d Refmans && mv Refmans Refmans.prev
#   mkdir -p Refmans/base
#   for f in Work/build/library/*/DESCRIPTION; do
#     grep -q "^Priority: base" ${f} || continue
#     d=$(dirname ${f})
#     p=$(basename ${d})
#     mkdir -p Refmans/base/${p}
#     cp ${d}/DESCRIPTION Refmans/base/${p}
#     cp -r ${d}/help Refmans/base/${p}
#     cp -r ${d}/html Refmans/base/${p}
#   done
#   mkdir -p Refmans/CRAN
#   for f in Work/build/Packages/*/DESCRIPTION; do
#     grep -q "^Repository: CRAN" ${f} || continue
#     d=$(dirname ${f})
#     p=$(basename ${d})
#     mkdir -p Refmans/CRAN/${p}
#     mv ${d}/help Refmans/CRAN/${p}
#     mv ${d}/html Refmans/CRAN/${p}
#   done
# fi

# do_cleanup_and_exit

# ## Local Variables: ***
# ## mode: sh ***
# ## sh-basic-offset: 2 ***
# ## End: ***
