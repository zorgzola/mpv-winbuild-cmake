# Steinberg ASIO SDK 2.3.4 — headers only, used by mpv's ao_asio (-Dasio-sdk).
# audiosdk/asio is a single-commit mirror of the SDK; pin it so the build is
# reproducible. Nothing is compiled from the SDK, only common/asio.h and
# friends are included by mpv's audio output driver.
ExternalProject_Add(asio-sdk
    GIT_REPOSITORY https://github.com/audiosdk/asio.git
    SOURCE_DIR ${SOURCE_LOCATION}
    GIT_REMOTE_NAME origin
    GIT_TAG main
    GIT_RESET 496a0765b8bb9c26f764f22f9a9712a937177db2
    GIT_CLONE_FLAGS "--filter=tree:0"
    UPDATE_COMMAND ""
    CONFIGURE_COMMAND ""
    BUILD_COMMAND ""
    INSTALL_COMMAND ""
    LOG_DOWNLOAD 1 LOG_UPDATE 1
)

force_rebuild_git(asio-sdk)
cleanup(asio-sdk install)
