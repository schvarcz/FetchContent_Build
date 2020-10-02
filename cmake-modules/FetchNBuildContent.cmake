option(FETCHCONTENT_QUIET "Enables QUIET option for all content population" OFF)

include(FetchContent)
set(__FetchNBuildContent_privateDir "${CMAKE_CURRENT_LIST_DIR}/FetchNBuildContent")

# set(FETCHCONTENT_QUIET OFF CACHE BOOL "Enables QUIET option for all content population")

#=======================================================================
# Recording and retrieving content details for later population
#=======================================================================

# Saves population details of the content, sets defaults for the
# SOURCE_DIR and BUILD_DIR.
function(FetchContent_Declare contentName)

  set(options "")
  set(oneValueArgs SVN_REPOSITORY)
  set(multiValueArgs "")

  cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  unset(srcDirSuffix)
  unset(svnRepoArgs)
  if(ARG_SVN_REPOSITORY)
    # Add a hash of the svn repository URL to the source dir. This works
    # around the problem where if the URL changes, the download would
    # fail because it tries to checkout/update rather than switch the
    # old URL to the new one. We limit the hash to the first 7 characters
    # so that the source path doesn't get overly long (which can be a
    # problem on windows due to path length limits).
    string(SHA1 urlSHA ${ARG_SVN_REPOSITORY})
    string(SUBSTRING ${urlSHA} 0 7 urlSHA)
    set(srcDirSuffix "-${urlSHA}")
    set(svnRepoArgs  SVN_REPOSITORY ${ARG_SVN_REPOSITORY})
  endif()

  string(TOLOWER ${contentName} contentNameLower)
  __FetchContent_declareDetails(
    ${contentNameLower}
    SOURCE_DIR "${FETCHCONTENT_BASE_DIR}/${contentNameLower}-src${srcDirSuffix}"
    BINARY_DIR "${FETCHCONTENT_BASE_DIR}/${contentNameLower}-build"
    INSTALL_DIR "${FETCHCONTENT_BASE_DIR}/${contentNameLower}-install"
    ${svnRepoArgs}
    # List these last so they can override things we set above
    ${ARG_UNPARSED_ARGUMENTS}
  )

endfunction()


#=======================================================================
# Set/get whether the specified content has been populated yet.
# The setter also records the source and binary dirs used.
#=======================================================================

# Internal use, projects must not call this directly. It is
# intended for use by the FetchContent_*() function to
# record when FetchContent_*() is called for a particular
# content name.
function(__FetchContent_setPopulated contentName sourceDir binaryDir)

    string(TOLOWER ${contentName} contentNameLower)
    set(prefix "_FetchContent_${contentNameLower}")

    set(propertyName "${prefix}_sourceDir")
    define_property(GLOBAL PROPERTY ${propertyName}
        BRIEF_DOCS "Internal implementation detail of FetchContent_Populate()"
        FULL_DOCS  "Details used by FetchContent_Populate() for ${contentName}"
    )
    set_property(GLOBAL PROPERTY ${propertyName} ${sourceDir})

    set(propertyName "${prefix}_binaryDir")
    define_property(GLOBAL PROPERTY ${propertyName}
        BRIEF_DOCS "Internal implementation detail of FetchContent_*()"
        FULL_DOCS  "Details used by FetchContent_*() for ${contentName}"
    )
    set_property(GLOBAL PROPERTY ${propertyName} ${binaryDir})

    if ( ARGN EQUAL 4 )
        set(installDir ${ARGV4})
        set(propertyName "${prefix}_installDir")
        define_property(GLOBAL PROPERTY ${propertyName}
            BRIEF_DOCS "Internal implementation detail of FetchContent_Install()"
            FULL_DOCS  "Details used by FetchContent_Install() for ${contentName}"
        )
        set_property(GLOBAL PROPERTY ${propertyName} ${installDir})
    endif()

    set(propertyName "${prefix}_populated")
    define_property(GLOBAL PROPERTY ${propertyName}
        BRIEF_DOCS "Internal implementation detail of FetchContent_Populate()"
        FULL_DOCS  "Details used by FetchContent_Populate() for ${contentName}"
    )
    set_property(GLOBAL PROPERTY ${propertyName} True)

endfunction()


# Set variables in the calling scope for any of the retrievable
# properties. If no specific properties are requested, variables
# will be set for all retrievable properties.
#
# This function is intended to also be used by projects as the canonical
# way to detect whether they should call FetchContent_Populate()
# and pull the populated source into the build with add_subdirectory(),
# if they are using the populated content in that way.
function(FetchContent_GetProperties contentName)

  string(TOLOWER ${contentName} contentNameLower)

  set(options "")
  set(oneValueArgs SOURCE_DIR BINARY_DIR INSTALL_DIR POPULATED)
  set(multiValueArgs "")

  cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  if(NOT ARG_SOURCE_DIR AND
     NOT ARG_BINARY_DIR AND
     NOT ARG_INSTALL_DIR AND
     NOT ARG_POPULATED)
    # No specific properties requested, provide them all
    set(ARG_SOURCE_DIR ${contentNameLower}_SOURCE_DIR)
    set(ARG_BINARY_DIR ${contentNameLower}_BINARY_DIR)
    set(ARG_INSTALL_DIR ${contentNameLower}_INSTALL_DIR)
    set(ARG_POPULATED  ${contentNameLower}_POPULATED)
  endif()

  set(prefix "_FetchContent_${contentNameLower}")

  if(ARG_SOURCE_DIR)
    set(propertyName "${prefix}_sourceDir")
    get_property(value GLOBAL PROPERTY ${propertyName})
    if(value)
      set(${ARG_SOURCE_DIR} ${value} PARENT_SCOPE)
    endif()
  endif()

  if(ARG_BINARY_DIR)
    set(propertyName "${prefix}_binaryDir")
    get_property(value GLOBAL PROPERTY ${propertyName})
    if(value)
      set(${ARG_BINARY_DIR} ${value} PARENT_SCOPE)
    endif()
  endif()

  if(ARG_INSTALL_DIR)
    set(propertyName "${prefix}_installDir")
    get_property(value GLOBAL PROPERTY ${propertyName})
    if(value)
      set(${ARG_INSTALL_DIR} ${value} PARENT_SCOPE)
    endif()
  endif()

  if(ARG_POPULATED)
    set(propertyName "${prefix}_populated")
    get_property(value GLOBAL PROPERTY ${propertyName} DEFINED)
    set(${ARG_POPULATED} ${value} PARENT_SCOPE)
  endif()

endfunction()


#=======================================================================
# Performing the population
#=======================================================================

# The value of contentName will always have been lowercased by the caller.
# All other arguments are assumed to be options that are understood by
# ExternalProject_Add(), except for QUIET and SUBBUILD_DIR.
function(__FetchContent_directBuild contentName)

  set(options
      QUIET
  )
  set(oneValueArgs
      SUBBUILD_DIR
      SOURCE_DIR
      BINARY_DIR
      INSTALL_DIR
      CMAKELISTS_TEMPLATE
  )
  set(multiValueArgs CMAKE_ARGS)

  cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  if(NOT ARG_SUBBUILD_DIR)
    message(FATAL_ERROR "Internal error: SUBBUILD_DIR not set")
  elseif(NOT IS_ABSOLUTE "${ARG_SUBBUILD_DIR}")
    set(ARG_SUBBUILD_DIR "${CMAKE_CURRENT_BINARY_DIR}/${ARG_SUBBUILD_DIR}")
  endif()

  if(NOT ARG_SOURCE_DIR)
    message(FATAL_ERROR "Internal error: SOURCE_DIR not set")
  elseif(NOT IS_ABSOLUTE "${ARG_SOURCE_DIR}")
    set(ARG_SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}/${ARG_SOURCE_DIR}")
  endif()

  if(NOT ARG_BINARY_DIR)
    message(FATAL_ERROR "Internal error: BINARY_DIR not set")
  elseif(NOT IS_ABSOLUTE "${ARG_BINARY_DIR}")
    set(ARG_BINARY_DIR "${CMAKE_CURRENT_BINARY_DIR}/${ARG_BINARY_DIR}")
  endif()

  if(NOT ARG_INSTALL_DIR)
    message(FATAL_ERROR "Internal error: INSTALL_DIR not set")
  elseif(NOT IS_ABSOLUTE "${ARG_INSTALL_DIR}")
    set(ARG_INSTALL_DIR "${CMAKE_CURRENT_BINARY_DIR}/${ARG_INSTALL_DIR}")
  endif()

  if(ARG_CMAKE_ARGS)
    message(STATUS " ${contentName} will be compiled with:")
    message(STATUS "   CMAKE_ARGS = ${ARG_CMAKE_ARGS} -DCMAKE_INSTALL_PREFIX=<INSTALL_DIR>")
  endif()
  set(ARG_CMAKE_ARGS "${ARG_CMAKE_ARGS} -DCMAKE_INSTALL_PREFIX=<INSTALL_DIR>")

  # Ensure the caller can know where to find the source and build directories
  # with some convenient variables. Doing this here ensures the caller sees
  # the correct result in the case where the default values are overridden by
  # the content details set by the project.
  set(${contentName}_SOURCE_DIR  "${ARG_SOURCE_DIR}"  PARENT_SCOPE)
  set(${contentName}_BINARY_DIR  "${ARG_BINARY_DIR}"  PARENT_SCOPE)
  set(${contentName}_INSTALL_DIR "${ARG_INSTALL_DIR}" PARENT_SCOPE)

  # The unparsed arguments may contain spaces, so build up ARG_EXTRA
  # in such a way that it correctly substitutes into the generated
  # CMakeLists.txt file with each argument quoted.
  unset(ARG_EXTRA)
  # foreach(arg IN LISTS ARG_UNPARSED_ARGUMENTS)
  #   set(ARG_EXTRA "${ARG_EXTRA} ${arg}")
  # endforeach()
  set(ARG_EXTRA ${ARG_UNPARSED_ARGUMENTS})
  if(ARG_CMAKE_ARGS)
    list(APPEND ARG_EXTRA "CMAKE_ARGS ${ARG_CMAKE_ARGS}")
  endif()
  string (REPLACE ";" "\n                    " ARG_EXTRA "${ARG_EXTRA}")

  # Hide output if requested, but save it to a variable in case there's an
  # error so we can show the output upon failure. When not quiet, don't
  # capture the output to a variable because the user may want to see the
  # output as it happens (e.g. progress during long downloads). Combine both
  # stdout and stderr in the one capture variable so the output stays in order.
  if (ARG_QUIET)
    set(outputOptions
        OUTPUT_VARIABLE capturedOutput
        ERROR_VARIABLE  capturedOutput
    )
  else()
    set(capturedOutput)
    set(outputOptions)
    message(STATUS "Populating ${contentName}")
  endif()

  if(CMAKE_GENERATOR)
    set(generatorOpts "-G${CMAKE_GENERATOR}")
    if(CMAKE_GENERATOR_PLATFORM)
      list(APPEND generatorOpts "-A${CMAKE_GENERATOR_PLATFORM}")
    endif()
    if(CMAKE_GENERATOR_TOOLSET)
      list(APPEND generatorOpts "-T${CMAKE_GENERATOR_TOOLSET}")
    endif()

    if(CMAKE_MAKE_PROGRAM)
      list(APPEND generatorOpts "-DCMAKE_MAKE_PROGRAM:FILEPATH=${CMAKE_MAKE_PROGRAM}")
    endif()

  else()
    # Likely we've been invoked via CMake's script mode where no
    # generator is set (and hence CMAKE_MAKE_PROGRAM could not be
    # trusted even if provided). We will have to rely on being
    # able to find the default generator and build tool.
    unset(generatorOpts)
  endif()

  # Create and build a separate CMake project to carry out the population.
  # If we've already previously done these steps, they will not cause
  # anything to be updated, so extra rebuilds of the project won't occur.
  # Make sure to pass through CMAKE_MAKE_PROGRAM in case the main project
  # has this set to something not findable on the PATH.
  configure_file(${ARG_CMAKELISTS_TEMPLATE}
                 "${ARG_SUBBUILD_DIR}/CMakeLists.txt")
  execute_process(
    COMMAND ${CMAKE_COMMAND} ${generatorOpts} .
    RESULT_VARIABLE result
    ${outputOptions}
    WORKING_DIRECTORY "${ARG_SUBBUILD_DIR}"
  )
  if(result)
    if(capturedOutput)
      message("${capturedOutput}")
    endif()
    message(FATAL_ERROR "CMake step for ${contentName} failed: ${result}")
  endif()
  execute_process(
    COMMAND ${CMAKE_COMMAND} --build .
    RESULT_VARIABLE result
    ${outputOptions}
    WORKING_DIRECTORY "${ARG_SUBBUILD_DIR}"
  )
  if(result)
    if(capturedOutput)
      message("${capturedOutput}")
    endif()
    message(FATAL_ERROR "Build step for ${contentName} failed: ${result}")
  endif()

endfunction()

# Build the specified content using details stored from
# an earlier call to FetchContent_Declare().
function(__FetchContent_Build contentName)

  if(NOT contentName)
    message(FATAL_ERROR "Empty contentName not allowed for FetchContent_Build()")
  endif()

  set(options "")
  set(oneValueArgs CMAKELISTS_TEMPLATE)
  set(multiValueArgs CMAKE_ARGS)

  cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  string(TOLOWER ${contentName} contentNameLower)

  if(ARG_UNPARSED_ARGUMENTS)
    # This is the direct population form with details fully specified
    # as part of the call, so we already have everything we need
    __FetchContent_directBuild(
      ${contentNameLower}
      SUBBUILD_DIR        "${CMAKE_CURRENT_BINARY_DIR}/${contentNameLower}-subbuild"
      SOURCE_DIR          "${CMAKE_CURRENT_BINARY_DIR}/${contentNameLower}-src"
      BINARY_DIR          "${CMAKE_CURRENT_BINARY_DIR}/${contentNameLower}-build"
      INSTALL_DIR         "${CMAKE_CURRENT_BINARY_DIR}/${contentNameLower}-install"
      CMAKELISTS_TEMPLATE "${ARG_CMAKELISTS_TEMPLATE}"
      CMAKE_ARGS          "${ARG_CMAKE_ARGS}"
      ${ARGN}  # Could override any of the above ..._DIR variables
    )

    # Pass source, binary and install dir variables back to the caller
    set(${contentNameLower}_SOURCE_DIR  "${${contentNameLower}_SOURCE_DIR}"  PARENT_SCOPE)
    set(${contentNameLower}_BINARY_DIR  "${${contentNameLower}_BINARY_DIR}"  PARENT_SCOPE)
    set(${contentNameLower}_INSTALL_DIR "${${contentNameLower}_INSTALL_DIR}" PARENT_SCOPE)

    # Don't set global properties, or record that we did this population, since
    # this was a direct call outside of the normal declared details form.
    # We only want to save values in the global properties for content that
    # honours the hierarchical details mechanism so that projects are not
    # robbed of the ability to override details set in nested projects.
    return()
  endif()

  # No details provided, so assume they were saved from an earlier call
  # to FetchContent_Declare().

  string(TOUPPER ${contentName} contentNameUpper)
  # set(FETCHCONTENT_SOURCE_DIR_${contentNameUpper}
  #     "${FETCHCONTENT_SOURCE_DIR_${contentNameUpper}}"
  #     CACHE PATH "When not empty, overrides where to find pre-populated content for ${contentName}")

  # if(FETCHCONTENT_SOURCE_DIR_${contentNameUpper})
  #   # The source directory has been explicitly provided in the cache,
  #   # so no population is required
  #   set(${contentNameLower}_SOURCE_DIR  "${FETCHCONTENT_SOURCE_DIR_${contentNameUpper}}")
  #   set(${contentNameLower}_BINARY_DIR  "${FETCHCONTENT_BASE_DIR}/${contentNameLower}-build")
  #   set(${contentNameLower}_INSTALL_DIR "${FETCHCONTENT_BASE_DIR}/${contentNameLower}-install")

  # else
  # if(FETCHCONTENT_FULLY_DISCONNECTED)
  #   # Bypass population and assume source is already there from a previous run
  #   set(${contentNameLower}_SOURCE_DIR  "${FETCHCONTENT_BASE_DIR}/${contentNameLower}-src")
  #   set(${contentNameLower}_BINARY_DIR  "${FETCHCONTENT_BASE_DIR}/${contentNameLower}-build")
  #   set(${contentNameLower}_INSTALL_DIR "${FETCHCONTENT_BASE_DIR}/${contentNameLower}-install")

  # else()
    # Support both a global "disconnect all updates" and a per-content
    # update test (either one being set disables updates for this content).
    option(FETCHCONTENT_UPDATES_DISCONNECTED_${contentNameUpper}
           "Enables UPDATE_DISCONNECTED behavior just for population of ${contentName}")
    if(FETCHCONTENT_UPDATES_DISCONNECTED OR
       FETCHCONTENT_UPDATES_DISCONNECTED_${contentNameUpper})
      set(disconnectUpdates True)
    else()
      set(disconnectUpdates False)
    endif()

    if(FETCHCONTENT_QUIET)
      set(quietFlag QUIET)
    else()
      unset(quietFlag)
    endif()

    __FetchContent_getSavedDetails(${contentName} contentDetails)
    if("${contentDetails}" STREQUAL "")
      message(FATAL_ERROR "No details have been set for content: ${contentName}")
    endif()

    __FetchContent_directBuild(
      ${contentNameLower}
      ${quietFlag}
      UPDATE_DISCONNECTED ${disconnectUpdates}
      SUBBUILD_DIR        "${FETCHCONTENT_BASE_DIR}/${contentNameLower}-subbuild"
      SOURCE_DIR          "${FETCHCONTENT_BASE_DIR}/${contentNameLower}-src"
      BINARY_DIR          "${FETCHCONTENT_BASE_DIR}/${contentNameLower}-build"
      INSTALL_DIR         "${FETCHCONTENT_BASE_DIR}/${contentNameLower}-install"
      CMAKELISTS_TEMPLATE "${ARG_CMAKELISTS_TEMPLATE}"
      CMAKE_ARGS          "${ARG_CMAKE_ARGS}"
      # Put the saved details last so they can override any of the
      # the options we set above (this can include SOURCE_DIR or
      # BUILD_DIR)
      ${contentDetails}
    )
  # endif()

  __FetchContent_setPopulated(
    ${contentName}
    ${${contentNameLower}_SOURCE_DIR}
    ${${contentNameLower}_BINARY_DIR}
    ${${contentNameLower}_INSTALL_DIR}
  )

  # Pass variables back to the caller. The variables passed back here
  # must match what FetchContent_GetProperties() sets when it is called
  # with just the content name.
  set(${contentNameLower}_SOURCE_DIR  "${${contentNameLower}_SOURCE_DIR}"  PARENT_SCOPE)
  set(${contentNameLower}_BINARY_DIR  "${${contentNameLower}_BINARY_DIR}"  PARENT_SCOPE)
  set(${contentNameLower}_INSTALL_DIR "${${contentNameLower}_INSTALL_DIR}" PARENT_SCOPE)
  set(${contentNameLower}_POPULATED  True PARENT_SCOPE)

endfunction()


function(FetchContent_Build)
    __FetchContent_Build(${ARGN} CMAKELISTS_TEMPLATE "${__FetchNBuildContent_privateDir}/CMakeLists.build.cmake.in")
endfunction()

function(FetchContent_Install)
    __FetchContent_Build(${ARGN} CMAKELISTS_TEMPLATE "${__FetchNBuildContent_privateDir}/CMakeLists.install.cmake.in")
endfunction()


# Arguments are assumed to be the names of dependencies that have been
# declared previously and should be populated. It is not an error if
# any of them have already been populated (they will just be skipped in
# that case). The command is implemented as a macro so that the variables
# defined by the FetchContent_GetProperties() and FetchContent_Populate()
# calls will be available to the caller.
macro(FetchContent_MakeAvailable)

  foreach(contentName IN ITEMS ${ARGV})
    string(TOLOWER ${contentName} contentNameLower)
    __FetchContent_getSavedDetails(${contentName} contentDetails)
    if("${contentDetails}" STREQUAL "")
      message(FATAL_ERROR "No details have been set for content: ${contentName}")
    endif()

    set(options "")
    set(oneValueArgs BUILD_COMMAND INSTALL_COMMAND SOURCE_SUBDIR)
    set(multiValueArgs "")
  
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${contentDetails})

    message(STATUS "${contentName}")
    message(STATUS "${contentDetails}")
    if (NOT "${ARG_BUILD_COMMAND}" STREQUAL "")
    message(STATUS ${ARG_BUILD_COMMAND})
    endif()
    if ((ARG_BUILD_COMMAND) AND (NOT "${ARG_BUILD_COMMAND}" STREQUAL ""))
      if ((ARG_INSTALL_COMMAND) AND (NOT "${ARG_INSTALL_COMMAND}" STREQUAL ""))
        FetchContent_Install(${contentName})
      else()
        FetchContent_Build(${contentName})
      endif()
    else()
      FetchContent_Populate(${contentName})

      # Only try to call add_subdirectory() if the populated content
      # can be treated that way. Protecting the call with the check
      # allows this function to be used for projects that just want
      # to ensure the content exists, such as to provide content at
      # a known location. We check the saved details for an optional
      # SOURCE_SUBDIR which can be used in the same way as its meaning
      # for ExternalProject. It won't matter if it was passed through
      # to the ExternalProject sub-build, since it would have been
      # ignored there.
      set(__fc_srcdir "${${contentNameLower}_SOURCE_DIR}")

      if(NOT "${ARG_SOURCE_SUBDIR}" STREQUAL "")
        string(APPEND __fc_srcdir "/${ARG_SOURCE_SUBDIR}")
      endif()

      if(EXISTS ${__fc_srcdir}/CMakeLists.txt)
        add_subdirectory(${__fc_srcdir} ${${contentNameLower}_BINARY_DIR})
      endif()

      unset(__fc_srcdir)
    endif()

    unset(ARG_BUILD_COMMAND)
    unset(ARG_INSTALL_COMMAND)
    unset(ARG_SOURCE_SUBDIR)
  endforeach()
endmacro()