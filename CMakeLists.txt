# Top-level CMake file for the ESP32-C3 assembly template.
# ESP-IDF builds the bootloader and partition table itself; we only supply
# the "main" component.
cmake_minimum_required(VERSION 3.16)
include($ENV{IDF_PATH}/tools/cmake/project.cmake)
project(esp32c3_asm_template)
