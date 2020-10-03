cmake_minimum_required(VERSION 3.14.0)
project(FetchContent_Build)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake-modules")
include(FetchNBuildContent)

FetchContent_Declare(
  opencv
  GIT_REPOSITORY https://github.com/opencv/opencv.git
  GIT_TAG        4.4.0
)

FetchContent_Install(opencv)