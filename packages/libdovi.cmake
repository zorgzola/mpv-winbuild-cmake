# libdovi (dolby_vision crate from quietvoid/dovi_tool) — Dolby Vision RPU
# parsing, required by libplacebo's FEL reconstruction path (-Dlibdovi).
# Built with cargo-c so it installs a static lib + dovi.pc for pkg-config.
set(LIBDOVI_CARGOC ${CMAKE_CURRENT_BINARY_DIR}/libdovi-ensure-cargo-c.sh)
file(WRITE ${LIBDOVI_CARGOC}
"#!/bin/bash
set -e
command -v cargo-cinstall >/dev/null 2>&1 || OPENSSL_DIR=/usr OPENSSL_LIB_DIR=/usr/lib OPENSSL_INCLUDE_DIR=/usr/include cargo install cargo-c --locked")

ExternalProject_Add(libdovi
    GIT_REPOSITORY https://github.com/quietvoid/dovi_tool.git
    SOURCE_DIR ${SOURCE_LOCATION}
    GIT_REMOTE_NAME origin
    GIT_TAG main
    GIT_CLONE_FLAGS "--filter=tree:0"
    UPDATE_COMMAND ""
    PATCH_COMMAND ""
    CONFIGURE_COMMAND ${EXEC} bash ${LIBDOVI_CARGOC}
    BUILD_ALWAYS TRUE
    BUILD_COMMAND ${EXEC}
        LD_PRELOAD=
        CARGO_PROFILE_RELEASE_CODEGEN_UNITS=1
        cargo cinstall --release
        --manifest-path <SOURCE_DIR>/dolby_vision/Cargo.toml
        --target ${TARGET_CPU}-pc-windows-${rust_target}
        --features capi
        --prefix ${MINGW_INSTALL_PREFIX}
        --libdir ${MINGW_INSTALL_PREFIX}/lib
        --pkgconfigdir ${MINGW_INSTALL_PREFIX}/lib/pkgconfig
        --includedir ${MINGW_INSTALL_PREFIX}/include
    INSTALL_COMMAND ""
    LOG_DOWNLOAD 1 LOG_UPDATE 1 LOG_CONFIGURE 1 LOG_BUILD 1 LOG_INSTALL 1
)

force_rebuild_git(libdovi)
cleanup(libdovi install)

# Stamp files are restored from the toolchain cache, so a changed
# BUILD_COMMAND does not trigger a rebuild. Drop the build stamps at
# cmake-configure time (the workflow reconfigures every run with
# --fresh) so cargo cinstall always runs and reinstalls dovi.pc/dovi.h.
get_property(_libdovi_stamp_dir TARGET libdovi PROPERTY _EP_STAMP_DIR)
execute_process(COMMAND ${CMAKE_COMMAND} -E remove -f
    ${_libdovi_stamp_dir}/libdovi-configure
    ${_libdovi_stamp_dir}/libdovi-build
    ${_libdovi_stamp_dir}/libdovi-install)
