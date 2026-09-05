# libdovi (dolby_vision crate from quietvoid/dovi_tool) — Dolby Vision RPU
# parsing, required by libplacebo's FEL reconstruction path (-Dlibdovi).
# Built with cargo-c so it installs a static lib + dovi.pc for pkg-config.
set(LIBDOVI_BUILD ${CMAKE_CURRENT_BINARY_DIR}/libdovi-build.sh)
file(WRITE ${LIBDOVI_BUILD}
"#!/bin/bash
set -e
command -v cargo-cinstall >/dev/null 2>&1 || OPENSSL_DIR=/usr OPENSSL_LIB_DIR=/usr/lib OPENSSL_INCLUDE_DIR=/usr/include cargo install cargo-c --locked
LD_PRELOAD= CARGO_PROFILE_RELEASE_CODEGEN_UNITS=1 cargo cinstall --release \
    --manifest-path $1/dolby_vision/Cargo.toml \
    --target $2 \
    --features capi \
    --prefix $3 \
    --libdir $3/lib \
    --pkgconfigdir $3/lib/pkgconfig \
    --includedir $3/include")

ExternalProject_Add(libdovi
    GIT_REPOSITORY https://github.com/quietvoid/dovi_tool.git
    SOURCE_DIR ${SOURCE_LOCATION}
    GIT_REMOTE_NAME origin
    GIT_TAG main
    GIT_CLONE_FLAGS "--filter=tree:0"
    UPDATE_COMMAND ""
    PATCH_COMMAND ""
    # cargo-c install + cargo cinstall are done in configure because the
    # build step's stamp keeps getting restored from cache and skipped
    # even with BUILD_ALWAYS; configure is reliably re-run.
    CONFIGURE_COMMAND ${EXEC} bash ${LIBDOVI_BUILD}
        <SOURCE_DIR>
        ${TARGET_CPU}-pc-windows-${rust_target}
        ${MINGW_INSTALL_PREFIX}
    BUILD_COMMAND ${EXEC} true
    INSTALL_COMMAND ""
    LOG_DOWNLOAD 1 LOG_UPDATE 1 LOG_CONFIGURE 1 LOG_BUILD 1 LOG_INSTALL 1
)

force_rebuild_git(libdovi)
cleanup(libdovi install)

# Stamp files are restored from the toolchain cache; drop the configure stamp
# at cmake-configure time (workflow reconfigures every run) so the combined
# cargo-c install + cargo cinstall always runs and reinstalls dovi.pc/dovi.h.
get_property(_libdovi_stamp_dir TARGET libdovi PROPERTY _EP_STAMP_DIR)
execute_process(COMMAND ${CMAKE_COMMAND} -E remove -f
    ${_libdovi_stamp_dir}/libdovi-configure)
