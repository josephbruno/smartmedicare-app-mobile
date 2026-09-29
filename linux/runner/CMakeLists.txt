cmake_minimum_required(VERSION 3.13)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME}
  "main.cc"
  "my_application.cc"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the application ID.
add_definitions(-DAPPLICATION_ID="${APPLICATION_ID}")

# Add dependency libraries. Add any application-specific dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter)
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::GTK)

target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# sqflite_common_ffi needs libsqlite3.so (unversioned).
# Ubuntu ships only libsqlite3.so.0 with no unversioned symlink.
# We copy it into the bundle lib/ dir at build time so every `flutter run`
# works without requiring `sudo apt-get install libsqlite3-dev`.
set(_SQLITE3_SRC "/lib/x86_64-linux-gnu/libsqlite3.so.0")
if(NOT EXISTS "${_SQLITE3_SRC}")
  set(_SQLITE3_SRC "/usr/lib/x86_64-linux-gnu/libsqlite3.so.0")
endif()
if(EXISTS "${_SQLITE3_SRC}")
  # BUILD_BUNDLE_DIR is set by the parent CMakeLists.txt
  add_custom_command(
    TARGET ${BINARY_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory
      "${CMAKE_BINARY_DIR}/bundle/lib"
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
      "${_SQLITE3_SRC}"
      "${CMAKE_BINARY_DIR}/bundle/lib/libsqlite3.so"
    COMMENT "sqflite: bundling libsqlite3.so from ${_SQLITE3_SRC}"
  )
endif()
