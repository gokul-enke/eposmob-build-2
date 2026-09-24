# Project-level configuration.
cmake_minimum_required(VERSION 3.14)
project(cloudpos LANGUAGES CXX)

# The name of the executable created for the application. Change this to change
# the on-disk name of your application.
set(BINARY_NAME "cloudpos")

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(SET CMP0063 NEW)

# Define build configuration option.
get_property(IS_MULTICONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(IS_MULTICONFIG)
  set(CMAKE_CONFIGURATION_TYPES "Debug;Profile;Release"
    CACHE STRING "" FORCE)
else()
  if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Debug" CACHE
      STRING "Flutter build mode" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
      "Debug" "Profile" "Release")
  endif()
endif()
# Define settings for the Profile build mode.
set(CMAKE_EXE_LINKER_FLAGS_PROFILE "${CMAKE_EXE_LINKER_FLAGS_RELEASE}")
set(CMAKE_SHARED_LINKER_FLAGS_PROFILE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE}")
set(CMAKE_C_FLAGS_PROFILE "${CMAKE_C_FLAGS_RELEASE}")
set(CMAKE_CXX_FLAGS_PROFILE "${CMAKE_CXX_FLAGS_RELEASE}")

# Use Unicode for all projects.
add_definitions(-DUNICODE -D_UNICODE)

# Newer MSVC toolchains (VS 2022 17.14+/VS 18, MSVC 14.4x+) turn the deprecated
# <experimental/coroutine> header into a hard error (STL1011). Some plugins
# (e.g. permission_handler_windows) still use the old /await + experimental
# coroutine headers, so silence it project-wide to keep them building.
add_compile_definitions(_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS)

# Compilation settings that should be applied to most targets.
#
# Be cautious about adding new options here, as plugins use this function by
# default. In most cases, you should add new options to specific targets instead
# of modifying this function.
function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_17)
  target_compile_options(${TARGET} PRIVATE /W4 /WX /wd"4100")
  target_compile_options(${TARGET} PRIVATE /EHsc)
  target_compile_definitions(${TARGET} PRIVATE "_HAS_EXCEPTIONS=0")
  target_compile_definitions(${TARGET} PRIVATE "$<$<CONFIG:Debug>:_DEBUG>")
endfunction()

# Flutter library and tool build rules.
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# Application build; see runner/CMakeLists.txt.
add_subdirectory("runner")

# sentry_flutter 9.x pulls package:jni as a Windows FFI plugin. FindJNI needs a
# JDK with headers (jni.h). Flutter/Android Studio often set JAVA_HOME to the
# bundled JBR, which has no include/ directory, so configure fails with
# "Could NOT find JNI (missing: JAVA_INCLUDE_PATH JAVA_INCLUDE_PATH2)".
function(cloudpos_ensure_jni_jdk)
  if(DEFINED JAVA_HOME AND EXISTS "${JAVA_HOME}/include/jni.h")
    return()
  endif()
  if(DEFINED ENV{JAVA_HOME} AND EXISTS "$ENV{JAVA_HOME}/include/jni.h")
    return()
  endif()

  set(_jdk "")
  find_program(_javac NAMES javac javac.exe)
  if(_javac)
    get_filename_component(_java_bin "${_javac}" DIRECTORY)
    get_filename_component(_java_home "${_java_bin}" DIRECTORY)
    if(EXISTS "${_java_home}/include/jni.h")
      set(_jdk "${_java_home}")
    endif()
  endif()

  if(NOT _jdk)
    file(GLOB _jdk_candidates
      "C:/Program Files/Microsoft/jdk*"
      "C:/Program Files/Eclipse Adoptium/jdk*"
      "C:/Program Files/Java/jdk*"
      "C:/Program Files/BellSoft/jdk*"
      "C:/Program Files/Zulu/zulu*"
      "C:/Program Files/Amazon Corretto/jdk*"
    )
    list(REVERSE _jdk_candidates)
    foreach(_candidate IN LISTS _jdk_candidates)
      if(EXISTS "${_candidate}/include/jni.h")
        set(_jdk "${_candidate}")
        break()
      endif()
    endforeach()
  endif()

  if(NOT _jdk)
    message(WARNING
      "No JDK with JNI headers was found. The Windows build will fail while "
      "compiling the jni plugin from sentry_flutter. Install JDK 17+ or point "
      "JAVA_HOME at a JDK that contains include/jni.h (Android Studio's JBR does not).")
    return()
  endif()

  file(TO_CMAKE_PATH "${_jdk}" _jdk)
  set(JAVA_HOME "${_jdk}" CACHE PATH "JDK used to locate JNI headers" FORCE)
  set(ENV{JAVA_HOME} "${_jdk}")
  foreach(_jni_cache_var
      JAVA_INCLUDE_PATH
      JAVA_INCLUDE_PATH2
      JAVA_JVM_LIBRARY
      JAVA_AWT_LIBRARY
      JAVA_AWT_INCLUDE_PATH)
    unset(${_jni_cache_var} CACHE)
  endforeach()
  message(STATUS "Using JDK for JNI: ${_jdk}")
endfunction()
cloudpos_ensure_jni_jdk()

# package:jni 0.14.2 Windows CMake uses unset ${TARGET_NAME} for /DELAYLOAD.
set(TARGET_NAME jni)

# printing's PDFiumConfig uses find_file() without NO_DEFAULT_PATH. A leftover
# CMAKE_INSTALL_PREFIX of "C:/Program Files/cloudpos" can cache PDFium_LIBRARY
# as the installed copy, and INSTALL then tries to copy from Program Files.
if(PDFium_LIBRARY MATCHES "[Pp]rogram [Ff]iles")
  unset(PDFium_LIBRARY CACHE)
  unset(PDFium_IMPLIB CACHE)
endif()

# Generated plugin build rules, which manage building the plugins and adding
# them to the application.
include(flutter/generated_plugins.cmake)


# === Installation ===
# Support files are copied into place next to the executable, so that it can
# run in place. This is done instead of making a separate bundle (as on Linux)
# so that building and running from within Visual Studio will work.
set(BUILD_BUNDLE_DIR "$<TARGET_FILE_DIR:${BINARY_NAME}>")
# Make the "install" step default, as it's required to run.
set(CMAKE_VS_INCLUDE_INSTALL_TO_DEFAULT_BUILD 1)
# Always install next to the executable. A leftover CMake cache (or a
# configure run outside `flutter build`) can leave CMAKE_INSTALL_PREFIX at
# "C:/Program Files/cloudpos", which makes INSTALL.vcxproj fail without admin.
set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)

set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}")

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)

if(PLUGIN_BUNDLED_LIBRARIES)
  install(FILES "${PLUGIN_BUNDLED_LIBRARIES}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endif()

# Fully re-copy the assets directory on each build to avoid having stale files
# from a previous install.
set(FLUTTER_ASSET_DIR_NAME "flutter_assets")
install(CODE "
  file(REMOVE_RECURSE \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")
  " COMPONENT Runtime)
install(DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)

# Install the AOT library on non-Debug builds only.
install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  CONFIGURATIONS Profile;Release
  COMPONENT Runtime)
