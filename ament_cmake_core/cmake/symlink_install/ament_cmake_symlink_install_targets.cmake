# Copyright 2014-2015 Open Source Robotics Foundation, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set(__AMENT_CMAKE_SYMLINK_INSTALL_TARGETS_INDEX "0"
  CACHE INTERNAL "Index for unique symlink install targets")

#
# Reimplement CMake install(TARGETS) command to use symlinks instead of copying
# resources.
#
# :param ARGN: the same arguments as the CMake install command.
# :type ARGN: various
#
function(ament_cmake_symlink_install_targets)
  if(NOT "${ARGV0}" STREQUAL "TARGETS")
    message(FATAL_ERROR "ament_cmake_symlink_install_targets() first argument "
      "must be 'TARGETS', not '${ARGV0}'")
  endif()

  set(unsupported_keywords
    "EXPORT"
    "FRAMEWORK"
    "BUNDLE"
    "PRIVATE_HEADER"
    "PUBLIC_HEADER"
    "RESOURCE"
    "INCLUDES"
    "PERMISSIONS"
    "CONFIGURATIONS"
    "COMPONENT"
    "NAMELINK_ONLY"
    "NAMELINK_SKIP"
  )
  foreach(unsupported_keyword ${unsupported_keywords})
    list(FIND ARGN "${unsupported_keyword}" index)
    if(NOT index EQUAL -1)
      # fall back to CMake install() command
      # if the arguments can't be handled
      _install(${ARGN})
      break()
    endif()
  endforeach()

  if(index EQUAL -1)
    cmake_parse_arguments(ARG "ARCHIVE;LIBRARY;RUNTIME;OPTIONAL" "DESTINATION"
      "TARGETS" ${ARGN})
    if(ARG_UNPARSED_ARGUMENTS)
      message(FATAL_ERROR "ament_cmake_symlink_install_targets() called with "
        "unused/unsupported arguments: ${ARG_UNPARSED_ARGUMENTS}")
    endif()

    # convert target names into absolute files
    set(target_files "")
    foreach(target ${ARG_TARGETS})
      if(NOT TARGET ${target})
        message(FATAL_ERROR
          "ament_cmake_symlink_install_targets() '${target}' is not a target")
      endif()
      get_target_property(is_imported "${target}" IMPORTED)
      if(is_imported)
        message(FATAL_ERROR "ament_cmake_symlink_install_targets() "
          "'${target}' is an imported target")
      endif()
      list(APPEND target_files "$<TARGET_FILE:${target}>")
      get_target_property(target_type "${target}" TYPE)
      if("${target_type}" STREQUAL "SHARED_LIBRARY")
        if(NOT WIN32)
          list(APPEND target_files "$<TARGET_SONAME_FILE:${target}>")
        endif()
        list(APPEND target_files "$<TARGET_LINKER_FILE:${target}>")
      endif()
      if("${target_type}" STREQUAL "INTERFACE_LIBRARY")
        message(FATAL_ERROR
          "ament_cmake_symlink_install_targets() '${target}' is an interface "
          "library - there's nothing to symlink install. Perhaps you forgot "
          "to add EXPORT or INCLUDES DESTINATION?")
      endif()
    endforeach()

    string(REPLACE ";" "\" \"" target_files_quoted
      "\"TARGET_FILES;${target_files}\"")
    string(REPLACE ";" "\" \"" argn_quoted "\"${ARGN}\"")

    # join destination keyword with kind of target (e.g. ARCHIVE)
    # to simplify parsing in the next CMake function
    string(REPLACE "\"ARCHIVE\" \"DESTINATION\"" "\"ARCHIVE_DESTINATION\"" argn_quoted "${argn_quoted}")
    string(REPLACE "\"LIBRARY\" \"DESTINATION\"" "\"LIBRARY_DESTINATION\"" argn_quoted "${argn_quoted}")
    string(REPLACE "\"RUNTIME\" \"DESTINATION\"" "\"RUNTIME_DESTINATION\"" argn_quoted "${argn_quoted}")

    # generate unique files
    set(generated_file_base
      "${CMAKE_CURRENT_BINARY_DIR}/ament_cmake_symlink_install_targets_${__AMENT_CMAKE_SYMLINK_INSTALL_TARGETS_INDEX}")
    set(generated_file_generator_suffix "${generated_file_base}_$<CONFIG>.cmake")
    set(generated_file_variable_suffix "${generated_file_base}_\${CMAKE_INSTALL_CONFIG_NAME}.cmake")
    math(EXPR __AMENT_CMAKE_SYMLINK_INSTALL_TARGETS_INDEX
      "${__AMENT_CMAKE_SYMLINK_INSTALL_TARGETS_INDEX} + 1")
    set(__AMENT_CMAKE_SYMLINK_INSTALL_TARGETS_INDEX "${__AMENT_CMAKE_SYMLINK_INSTALL_TARGETS_INDEX}"
      CACHE INTERNAL "Index for unique symlink install targets")

    file(GENERATE OUTPUT "${generated_file_generator_suffix}"
      CONTENT
      "ament_cmake_symlink_install_targets(${target_files_quoted} ${argn_quoted})\n")
    ament_cmake_symlink_install_append_install_code(
      "include(\"${generated_file_variable_suffix}\")"
      COMMENTS "install(${argn_quoted})"
    )
  endif()
endfunction()
