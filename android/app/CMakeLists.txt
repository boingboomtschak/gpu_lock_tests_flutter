cmake_minimum_required(VERSION 3.4.1)
project(gpu_lock_tests)

add_library(easyvk OBJECT vk_backend/easyvk.cpp)
add_library(gpulock SHARED vk_backend/vk_lock_test.cpp)

target_link_libraries(gpulock easyvk vulkan log)