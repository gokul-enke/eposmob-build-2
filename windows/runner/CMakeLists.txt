cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "main.cpp"
  "startup_window.cpp"
  "app_restart.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the build version.
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION=\"${FLUTTER_VERSION}\"")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MAJOR=${FLUTTER_VERSION_MAJOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MINOR=${FLUTTER_VERSION_MINOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_PATCH=${FLUTTER_VERSION_PATCH}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_BUILD=${FLUTTER_VERSION_BUILD}")

# Branding. CLOUDPOS_BRAND picks brands/<id>/brand.json (scripts/build_brand.ps1
# sets it together with the matching --dart-define-from-file). Read on every
# configure, which `flutter build` runs each time, so switching brands works
# without a clean.
if(CMAKE_VERSION VERSION_LESS 3.19)
  message(FATAL_ERROR "Branding needs CMake 3.19+ for string(JSON).")
endif()
set(BRAND_ID "$ENV{CLOUDPOS_BRAND}")
if(BRAND_ID STREQUAL "")
  set(BRAND_ID "cloudpos")
endif()
get_filename_component(BRAND_DIR "${CMAKE_SOURCE_DIR}/../brands/${BRAND_ID}" ABSOLUTE)
if(NOT EXISTS "${BRAND_DIR}/brand.json")
  message(FATAL_ERROR "Unknown brand '${BRAND_ID}': ${BRAND_DIR}/brand.json not found.")
endif()
file(READ "${BRAND_DIR}/brand.json" BRAND_JSON)
foreach(key BRAND_NAME BRAND_TITLE BRAND_COMPANY BRAND_PRODUCT_NAME BRAND_EXE_NAME)
  string(JSON ${key} GET "${BRAND_JSON}" ${key})
endforeach()
# Prefix for the single-instance mutex, window props and classes. CloudPOS
# keeps its historical "CLOUDPOS" so installed copies still see each other.
if(BRAND_ID STREQUAL "cloudpos")
  set(BRAND_INSTANCE_KEY "CLOUDPOS")
else()
  string(TOUPPER "CLOUDPOS_${BRAND_ID}" BRAND_INSTANCE_KEY)
endif()
if(EXISTS "${BRAND_DIR}/app_icon.ico")
  set(BRAND_ICON_FILE "${BRAND_DIR}/app_icon.ico")
else()
  set(BRAND_ICON_FILE "${CMAKE_CURRENT_SOURCE_DIR}/resources/app_icon.ico")
endif()
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${BRAND_DIR}/brand.json")
configure_file("brand_config.h.in" "${CMAKE_CURRENT_BINARY_DIR}/brand_config.h" @ONLY)
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_CURRENT_BINARY_DIR}")
# rc.exe does not track the icon through a macro; rebuild when it changes.
set_source_files_properties("Runner.rc" PROPERTIES
  OBJECT_DEPENDS "${BRAND_ICON_FILE};${CMAKE_CURRENT_BINARY_DIR}/brand_config.h")
message(STATUS "Brand: ${BRAND_ID} (${BRAND_TITLE})")

# Disable Windows macros that collide with C++ standard library functions.
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")

# Add dependency libraries and include directories. Add any application-specific
# dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib")
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# Run the Flutter tool portions of the build. This must not be removed.
add_dependencies(${BINARY_NAME} flutter_assemble)
