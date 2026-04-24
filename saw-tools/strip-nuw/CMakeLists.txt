cmake_minimum_required(VERSION 3.16)
project(strip-nuw LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(LLVM 14 REQUIRED CONFIG)

message(STATUS "Found LLVM ${LLVM_PACKAGE_VERSION}")
message(STATUS "Using LLVMConfig.cmake in: ${LLVM_DIR}")

include_directories(${LLVM_INCLUDE_DIRS})
separate_arguments(LLVM_DEFINITIONS_LIST NATIVE_COMMAND ${LLVM_DEFINITIONS})
add_definitions(${LLVM_DEFINITIONS_LIST})

add_executable(strip-nuw
  main.cpp
  StripNuwPass.cpp
)

llvm_map_components_to_libnames(LLVM_LIBS
  Core
  BitReader
  BitWriter
  Passes
  Support
  Analysis
)

target_link_libraries(strip-nuw PRIVATE ${LLVM_LIBS})
