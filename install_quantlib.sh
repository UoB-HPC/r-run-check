#!/usr/bin/env bash

set -eu
cd

if ! command -v cmake3 &>/dev/null; then cmake3() { cmake "$@"; }; fi

version="1.28"

wget "https://github.com/lballabio/QuantLib/releases/download/QuantLib-v$version/QuantLib-$version.tar.gz"
tar xf "QuantLib-$version.tar.gz"

cd "QuantLib-$version" || exit 1

# QuantLib, when using autotools, has a `install-data-hook` that rewrites a few names in ql/config.hpp
# so we need to recreate that ourselves if we're using CMake.
sed '/^\#define quantlib_config_h$/r'<(
  echo ""
  echo '#define QL_PACKAGE_NAME "@PACKAGE_NAME@"'
  echo '#define QL_PACKAGE_STRING "@PACKAGE_STRING@"'
  echo '#define QL_PACKAGE_TARNAME "@PACKAGE_TARNAME@"'
  echo '#define QL_PACKAGE_VERSION "@PACKAGE_VERSION@"'
  echo '#define QL_PACKAGE_BUGREPORT "@PACKAGE_BUGREPORT@"'
) -i "ql/config.hpp.cfg"

# When installed with CMake, doesn't generate pkg-config files so we implement it ourselves.
# The template quantlib.pc is already there for configure.ac, so we're just adding the config step to CMake.
# Most of the first half is taken from https://github.com/OSGeo/PROJ/blob/master/cmake/ProjUtilities.cmake.
cat <<'EOF' >>CMakeLists.txt

include(GNUInstallDirs)

function(set_variable_from_rel_or_absolute_path var root rel_or_abs_path)
  if(IS_ABSOLUTE "${rel_or_abs_path}")
    set(${var} "${rel_or_abs_path}" PARENT_SCOPE)
  else()
    set(${var} "${root}/${rel_or_abs_path}" PARENT_SCOPE)
  endif()
endfunction()

set(prefix "${CMAKE_INSTALL_PREFIX}")
set_variable_from_rel_or_absolute_path("libdir" "${prefix}" "${CMAKE_INSTALL_LIBDIR}")
set_variable_from_rel_or_absolute_path("includedir" "${prefix}" "${CMAKE_INSTALL_INCLUDEDIR}")
set_variable_from_rel_or_absolute_path("datarootdir" "${prefix}" "${CMAKE_INSTALL_DATAROOTDIR}")

set(BOOST_INCLUDE "${Boost_INCLUDE_DIRS}")
set(OPENMP_CXXFLAGS "${OpenMP_CXX_FLAGS} -I ${OpenMP_CXX_INCLUDE_DIRS}")
set(PTHREAD_CXXFLAGS "")
set(CPP14_CXXFLAGS "-std=c++14")
set(PTHREAD_LIB "${CMAKE_THREAD_LIBS_INIT}")

configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/quantlib.pc.in"
    "${CMAKE_CURRENT_BINARY_DIR}/quantlib.pc"
    @ONLY)

configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/quantlib-config.in"
    "${CMAKE_CURRENT_BINARY_DIR}/quantlib-config"
    @ONLY)    
    
install(FILES
  "${CMAKE_CURRENT_BINARY_DIR}/quantlib.pc"
  DESTINATION "${CMAKE_INSTALL_LIBDIR}/pkgconfig")

install(FILES
  "${CMAKE_CURRENT_BINARY_DIR}/quantlib-config"
  PERMISSIONS WORLD_EXECUTE OWNER_READ OWNER_WRITE
  DESTINATION "${CMAKE_INSTALL_BINDIR}")

EOF

cmake3 -Bbuild -H. -DCMAKE_BUILD_TYPE=Release -GNinja
cmake3 --build build --target install
cd .. && rm -rf "QuantLib-$version.tar.gz" "QuantLib-$version"
echo "Done"
