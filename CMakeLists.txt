# Copyright 2022 MaBling <akck0918@gmail.com>. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

include(${PROJECT_SOURCE_DIR}/third_party/icu/config.cmake)
include(${PROJECT_SOURCE_DIR}/third_party/icu/sources.cmake)

if(MAC)
  include(${PROJECT_SOURCE_DIR}/build/config/sanitizers/sanitizers.cmake)
endif()

add_library(icu INTERFACE)
target_link_libraries(icu INTERFACE icui18n icuuc)

function(generate_icu_component)
  set(OPTIONS "")
  set(ONE_VALUE_ARGS "")
  set(MULTI_VALUE_ARGS SOURCES DEFINES DEPS PUBLIC_DEPS)
  cmake_parse_arguments(ARGS "${OPTIONS}" "${ONE_VALUE_ARGS}" "${MULTI_VALUE_ARGS}" ${ARGN})

  add_library(${TARGET_NAME} ${ARGS_SOURCES})
  target_compile_definitions(${TARGET_NAME} PRIVATE ${ARGS_DEFINES})
  target_link_libraries(${TARGET_NAME} PRIVATE ${ARGS_DEPS})
  target_link_libraries(${TARGET_NAME} PUBLIC ${ARGS_PUBLIC_DEPS})

  # icu_config
  # Shared config used by ICU and all dependents.
  target_compile_definitions(${TARGET_NAME} PUBLIC
    U_USING_ICU_NAMESPACE=0
    U_ENABLE_DYLOAD=0
    USE_CHROMIUM_ICU=1
    U_ENABLE_TRACING=1
    U_ENABLE_RESOURCE_TRACING=0)

  if(NOT BUILD_SHARED_LIBS)
    target_compile_definitions(${TARGET_NAME} PUBLIC U_STATIC_IMPLEMENTATION)
  endif()

  target_include_directories(${TARGET_NAME} PUBLIC source/common source/i18n)

  if(ICU_USE_DATA_FILE)
    target_compile_definitions(${TARGET_NAME} PUBLIC ICU_UTIL_DATA_IMPL=ICU_UTIL_DATA_FILE)
  else()
    target_compile_definitions(${TARGET_NAME} PUBLIC ICU_UTIL_DATA_IMPL=ICU_UTIL_DATA_STATIC)
  endif()

  # icu_code
  # Config used only by ICU code
  target_compile_definitions(${TARGET_NAME} PRIVATE
    HAVE_DLOPEN=0

    UCONFIG_ONLY_HTML_CONVERSION=1

    UCONFIG_USE_WINDOWS_LCID_MAPPING_API=0

    U_CHARSET_IS_UTF8=1)

  if(LINUX OR CHROMEOS OR ANDROID)
    target_compile_options(${TARGET_NAME} PRIVATE -Wno-unused-function)
  endif()
  if(CLANG)
    target_compile_options(${TARGET_NAME} PRIVATE
      -Wno-parentheses
      -Wno-unused-function
      -Wno-unused-variable)
  endif()
  if(CLANG OR LINUX OR CHROMEOS OR ANDROID)
    target_compile_options(${TARGET_NAME} PRIVATE -Wno-deprecated-declarations)
  endif()
endfunction()

function(generate_icui18n TARGET_NAME)
  set(OPTIONS "")
  set(ONE_VALUE_ARGS "")
  set(MULTI_VALUE_ARGS ICUUC_DEPS)
  cmake_parse_arguments(ARGS "${OPTIONS}" "${ONE_VALUE_ARGS}" "${MULTI_VALUE_ARGS}" ${ARGN})

  if(NOT ARGS_ICUUC_DEPS)
    message(FATAL_ERROR "Need the 'ICUUC_DEPS' parameter.")
  endif()

  generate_icu_component(${TARGET_NAME}
    SOURCES ${ICU18N_SOURCES}
    DEFINES U_I18N_IMPLEMENTATION
    DEPS ${ARGS_ICUUC_DEPS})
endfunction()

generate_icui18n(icui18n ICUUC_DEPS icuuc_private)

generate_icui18n(icui18n_hidden_visibility ICUUC_DEPS icuuc_private_hidden_visibility)

function(generate_icuuc TARGET_NAME)
  generate_icu_component(${TARGET_NAME}
    SOURCES ${ICUUC_SOURCES}
    DEFINES U_COMMON_IMPLEMENTATION U_ICUDATAENTRY_IN_COMMON)
  if(ICU_USE_DATA_FILE AND ICU_USE_STUB_DATA)
    target_sources(${TARGET_NAME} PRIVATE source/stubdata/stubdata.cpp)
  endif()
endfunction()

add_library(icuuc INTERFACE)
target_link_libraries(icuuc INTERFACE icuuc_private)

add_library(icuuc_hidden_visibility INTERFACE)
target_link_libraries(icuuc_hidden_visibility INTERFACE icuuc_private_hidden_visibility)

generate_icuuc(icuuc_private)
set_target_properties(icuuc_private PROPERTIES OUTPUT_NAME icuuc)

generate_icuuc(icuuc_private_hidden_visibility)
set_target_properties(icuuc_private_hidden_visibility PROPERTIES OUTPUT_NAME icuuc_hidden_visibility)

if(ANDROID)
  set(DATA_DIR android)
elseif(IOS)
  set(DATA_DIR ios)
elseif(CHROMEOS)
  set(DATA_DIR chromeos)
else()
  set(DATA_DIR common)
endif()

set(DATA_BUNDLE_PREFIX icudtl)
set(DATA_BUNDLE ${DATA_BUNDLE_PREFIX}.dat)

if(ICU_USE_DATA_FILE)
  if(IOS)
  else()
    file(COPY ${DATA_DIR}/${DATA_BUNDLE} DESTINATION ${CMAKE_CURRENT_BINARY_DIR})
  endif()

  if(CHROMEOS)
    file(COPY ${PROJECT_SOURCE_DIR}/third_party/icu/chromeos/icudtl.dat.hash
      DESTINATION ${CMAKE_CURRENT_BINARY_DIR})
  endif()
else()
  if(MAC OR IOS)
    set(ARGS --mac)
  elseif(WIN32)
    set(ARGS --win)
  endif()
  set(DATA_ASSEMBLY ${CMAKE_CURRENT_BINARY_DIR}/${DATA_BUNDLE_PREFIX}_dat.S)
  set(INLINE_DATA_ASSEMBLY ${CMAKE_CURRENT_BINARY_DIR}/${DATA_BUNDLE_PREFIX}_dat.cc)
  add_custom_command(
    OUTPUT ${DATA_ASSEMBLY}
    COMMAND scripts/make_data_cpp.py ${ARGS})
  add_custom_target(make_data_assembly DEPENDS ${DATA_ASSEMBLY})

  if(WIN32)
    add_custom_command(
      OUTPUT ${INLINE_DATA_ASSEMBLY}
      COMMAND scripts/asm_to_inline_asm.py
      DEPENDS ${DATA_ASSEMBLY})
    add_custom_target(make_inline_data_assembly DEPENDS ${INLINE_DATA_ASSEMBLY})
  endif()
endif()
