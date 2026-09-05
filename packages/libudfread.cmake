ExternalProject_Add(libudfread
    GIT_REPOSITORY https://code.videolan.org/videolan/libudfread.git
    GIT_TAG 139a2194525f2745b98a98e4d8fa627d07440176
    SOURCE_DIR ${SOURCE_LOCATION}
    GIT_CLONE_FLAGS "--filter=tree:0"
    # libudfread master (>= 2026-08-26) reworked UDF directory parsing and
    # breaks listing directory-based AppCache entries (e.g. BDMV/JAR/00001/
    # on some BD-J discs), killing the Xlet. Pin to the commit libbluray's
    # submodule uses. The update step runs on every build, so this also
    # repairs a repository cache that restored a newer checkout: git skips
    # rewriting unchanged files, making the reset idempotent and cheap.
    UPDATE_COMMAND ${EXEC} git -C <SOURCE_DIR> reset --hard 139a2194525f2745b98a98e4d8fa627d07440176
    CONFIGURE_COMMAND ${EXEC} CONF=1 meson setup <BINARY_DIR> <SOURCE_DIR>
        --prefix=${MINGW_INSTALL_PREFIX}
        --libdir=${MINGW_INSTALL_PREFIX}/lib
        --cross-file=${MESON_CROSS}
        --buildtype=release
        --default-library=static
    BUILD_COMMAND ${EXEC} ninja -C <BINARY_DIR>
    INSTALL_COMMAND ${EXEC} ninja -C <BINARY_DIR> install
    LOG_DOWNLOAD 1 LOG_UPDATE 1 LOG_CONFIGURE 1 LOG_BUILD 1 LOG_INSTALL 1
)

force_rebuild_git(libudfread)
force_meson_configure(libudfread)
cleanup(libudfread install)
