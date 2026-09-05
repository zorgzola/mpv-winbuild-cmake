# orender runtime — the spatial-audio renderer shared library from
# mgth/Omniphony (omniphony-renderer workspace, orender_ffi crate).
# mpv's ad_orender (mpv-omni patch series) LoadLibrary's "orender.dll" at
# runtime, so this is NOT a link-time dependency of mpv: the dll is simply
# shipped next to mpv.exe by mpv's copy-binary step. Built against the same
# master-tracking source the patch series targets.
ExternalProject_Add(orender
    GIT_REPOSITORY https://github.com/mgth/Omniphony.git
    SOURCE_DIR ${SOURCE_LOCATION}
    GIT_REMOTE_NAME origin
    GIT_TAG main
    GIT_CLONE_FLAGS "--filter=tree:0"
    UPDATE_COMMAND ""
    PATCH_COMMAND ""
    CONFIGURE_COMMAND ""
    BUILD_ALWAYS TRUE
    BUILD_COMMAND ${EXEC}
        LD_PRELOAD=
        cargo build --release -p orender_ffi
        --manifest-path <SOURCE_DIR>/omniphony-renderer/Cargo.toml
        --target ${TARGET_CPU}-pc-windows-${rust_target}
    INSTALL_COMMAND ""
    LOG_DOWNLOAD 1 LOG_UPDATE 1 LOG_CONFIGURE 1 LOG_BUILD 1 LOG_INSTALL 1
)

force_rebuild_git(orender)
cleanup(orender install)
