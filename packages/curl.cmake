# HTTP/3 (ngtcp2 + nghttp3), libssh and the curl command-line tool are
# deliberately disabled: those upstream deps are unpinned moving targets and
# are currently broken in this toolchain (ngtcp2's OpenSSL QUIC check fails to
# link with GNU ld because static OpenSSL 4.x pulls in zlib/zstd/brotli;
# curl master no longer compiles against libssh master's removed ssh_scp API).
# None of them affect mpv: ffmpeg provides http(s)/sftp for playback and
# nothing in the mpv target consumes curl.exe.
ExternalProject_Add(curl
    DEPENDS
        brotli
        c-ares
        libpsl
        nghttp2
        openssl
        zlib
        zstd
    GIT_REPOSITORY https://github.com/curl/curl.git
    SOURCE_DIR ${SOURCE_LOCATION}
    GIT_CLONE_FLAGS "--filter=tree:0"
    GIT_CLONE_POST_COMMAND "sparse-checkout set --no-cone /* !tests !docs"
    PATCH_COMMAND ""
    UPDATE_COMMAND ""
    CONFIGURE_COMMAND ${EXEC} ${CMAKE_COMMAND} -H<SOURCE_DIR> -B<BINARY_DIR>
        -G Ninja
        -DCMAKE_BUILD_TYPE=Release
        -DCMAKE_TOOLCHAIN_FILE=${TOOLCHAIN_FILE}
        -DCMAKE_INSTALL_PREFIX=${MINGW_INSTALL_PREFIX}
        -DCMAKE_FIND_ROOT_PATH=${MINGW_INSTALL_PREFIX}
        -DBUILD_SHARED_LIBS=OFF
        -DBUILD_STATIC_LIBS=ON
        -DBUILD_CURL_EXE=OFF
        -DBUILD_LIBCURL_DOCS=OFF
        -DBUILD_EXAMPLES=OFF
        -DBUILD_MISC_DOCS=OFF
        -DCURL_CA_NATIVE=ON
        -DCURL_BROTLI=ON
        -DCURL_USE_LIBPSL=ON
        -DCURL_USE_LIBSSH2=OFF
        -DCURL_USE_OPENSSL=ON
        -DCURL_ZSTD=ON
        -DENABLE_ARES=ON
        -DENABLE_CURL_MANUAL=OFF
        -DENABLE_UNICODE=ON
        -DENABLE_THREADED_RESOLVER=ON
        -DUSE_NGHTTP2=ON
        -DUSE_WIN32_IDN=ON
        -DUSE_WINDOWS_SSPI=ON
        -DCURL_USE_PKGCONFIG=ON
        -DCMAKE_DISABLE_FIND_PACKAGE_Perl=ON
        "-DCMAKE_C_FLAGS='-DNGHTTP2_STATICLIB -lz -lbrotlienc -lbrotlidec -lbrotlicommon -lzstd -lcrypt32 -lsecur32'"
    BUILD_COMMAND ${EXEC} ninja -C <BINARY_DIR>
    INSTALL_COMMAND ${EXEC} ninja -C <BINARY_DIR> install
    LOG_DOWNLOAD 1 LOG_UPDATE 1 LOG_CONFIGURE 1 LOG_BUILD 1 LOG_INSTALL 1
)

force_rebuild_git(curl)
cleanup(curl install)
