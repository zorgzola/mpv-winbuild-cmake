# orender runtime — the spatial-audio renderer shared library from
# mgth/Omniphony (omniphony-renderer workspace, orender_ffi crate).
# mpv's ad_orender (mpv-omni patch series) LoadLibrary's "orender.dll" at
# runtime, so this is NOT a link-time dependency of mpv: the dll is simply
# shipped next to mpv.exe by mpv's copy-binary step. Built against the same
# master-tracking source the patch series targets.
set(ORENDER_BUILD ${CMAKE_CURRENT_BINARY_DIR}/orender-build.sh)
file(WRITE ${ORENDER_BUILD}
"#!/bin/bash
set -e
export RUSTFLAGS=\"-C panic=abort -C link-arg=-static-libgcc -C link-arg=-static-libstdc++\"
LD_PRELOAD= cargo build --release -p orender_ffi \
    --manifest-path $1/omniphony-renderer/Cargo.toml \
    --target $2")

ExternalProject_Add(orender
    GIT_REPOSITORY https://github.com/mgth/Omniphony.git
    SOURCE_DIR ${SOURCE_LOCATION}
    GIT_REMOTE_NAME origin
    GIT_TAG main
    GIT_CLONE_FLAGS "--filter=tree:0"
    UPDATE_COMMAND ""
    PATCH_COMMAND ""
    # cargo build runs in configure because the build step's stamp keeps
    # getting restored from cache and skipped even with BUILD_ALWAYS;
    # configure is reliably re-run.
    CONFIGURE_COMMAND ${EXEC} bash ${ORENDER_BUILD}
        <SOURCE_DIR>
        ${TARGET_CPU}-pc-windows-${rust_target}
    BUILD_COMMAND ${EXEC} true
    INSTALL_COMMAND ""
    LOG_DOWNLOAD 1 LOG_UPDATE 1 LOG_CONFIGURE 1 LOG_BUILD 1 LOG_INSTALL 1
)

force_rebuild_git(orender)
cleanup(orender install)

# Drop the configure stamp at cmake-configure time so cargo build always runs
# and orender.dll is regenerated for the mpv copy-binary step.
get_property(_orender_stamp_dir TARGET orender PROPERTY _EP_STAMP_DIR)
execute_process(COMMAND ${CMAKE_COMMAND} -E remove -f
    ${_orender_stamp_dir}/orender-configure)
