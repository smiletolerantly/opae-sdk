## Copyright(c) 2017, 2018, Intel Corporation
##
## Redistribution  and  use  in source  and  binary  forms,  with  or  without
## modification, are permitted provided that the following conditions are met:
##
## * Redistributions of  source code  must retain the  above copyright notice,
##   this list of conditions and the following disclaimer.
## * Redistributions in binary form must reproduce the above copyright notice,
##   this list of conditions and the following disclaimer in the documentation
##   and/or other materials provided with the distribution.
## * Neither the name  of Intel Corporation  nor the names of its contributors
##   may be used to  endorse or promote  products derived  from this  software
##   without specific prior written permission.
##
## THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
## AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING,  BUT NOT LIMITED TO,  THE
## IMPLIED WARRANTIES OF  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
## ARE DISCLAIMED.  IN NO EVENT  SHALL THE COPYRIGHT OWNER  OR CONTRIBUTORS BE
## LIABLE  FOR  ANY  DIRECT,  INDIRECT,  INCIDENTAL,  SPECIAL,  EXEMPLARY,  OR
## CONSEQUENTIAL  DAMAGES  (INCLUDING,  BUT  NOT LIMITED  TO,  PROCUREMENT  OF
## SUBSTITUTE GOODS OR SERVICES;  LOSS OF USE,  DATA, OR PROFITS;  OR BUSINESS
## INTERRUPTION)  HOWEVER CAUSED  AND ON ANY THEORY  OF LIABILITY,  WHETHER IN
## CONTRACT,  STRICT LIABILITY,  OR TORT  (INCLUDING NEGLIGENCE  OR OTHERWISE)
## ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,  EVEN IF ADVISED OF THE
## POSSIBILITY OF SUCH DAMAGE.

set(ASE_WORKDIR             "${PROJECT_BINARY_DIR}")
set(ASE_CONFIG              "${PROJECT_BINARY_DIR}/ase.cfg")
set(ASE_REGRESS_SCRIPT      "${PROJECT_BINARY_DIR}/ase_regress.sh")
set(ASE_SERVER_SCRIPT       "${PROJECT_BINARY_DIR}/ase_server.sh")
set(ASE_SIMULATION_SCRIPT   "${PROJECT_BINARY_DIR}/vsim_run.tcl")

# Create ASE scripts
configure_file(${ASE_SCRIPTS_IN}/ase.cfg.in
        ${ASE_CONFIG})
configure_file(${ASE_SCRIPTS_IN}/ase_regress.sh.in
        ${ASE_REGRESS_SCRIPT})
configure_file(${ASE_SCRIPTS_IN}/vsim_run.tcl.in
        ${ASE_SIMULATION_SCRIPT})
configure_file(${ASE_SCRIPTS_IN}/ase_server.in
        ${PROJECT_BINARY_DIR}/tmp/ase_server.sh)

  set(questa_flags "")
  list(APPEND questa_flags +define+VENDOR_ALTERA)
  list(APPEND questa_flags +define+TOOL_QUARTUS)
  list(APPEND questa_flags +define+${ASE_SIMULATOR})
  list(APPEND questa_flags +define+${ASE_PLATFORM})
  set(QUESTA_VLOG_DEFINES "${questa_flags}"
          CACHE STRING "Modelsim/Questa compiler define flags")

  set(questa_flags "")
  list(APPEND questa_flags +incdir+.+work+${ASE_SERVER_RTL}+${PLATFORM_IF_RTL})
  set(QUESTA_VLOG_INCLUDES "${questa_flags}"
          CACHE STRING "Modelsim/Questa compiler include flags")

  set(questa_flags "")
  list(APPEND questa_flags -nologo -sv +librescan)
  list(APPEND questa_flags -timescale ${ASE_TIMESCALE})
  list(APPEND questa_flags -work work)
  list(APPEND questa_flags -novopt)
  list(APPEND questa_flags ${QUESTA_VLOG_DEFINES})
  list(APPEND questa_flags ${QUESTA_VLOG_INCLUDES})
  set(QUESTA_VLOG_FLAGS "${questa_flags}"
          CACHE STRING "Modelsim/Questa compiler flags")

  # SW library name
  set(ASE_SHOBJ_NAME "libopae-c-ase-server")
  set(ASE_SHOBJ_SO  ${ASE_SHOBJ_NAME}.so)

  set(questa_flags "")
  list(APPEND questa_flags -novopt)
  list(APPEND questa_flags -c)
  list(APPEND questa_flags -dpioutoftheblue 1)
  # list(APPEND questa_flags -wlf ${questa_waveform})
  list(APPEND questa_flags -sv_lib ${CMAKE_BINARY_DIR}/sw/${ASE_SHOBJ_NAME})
  list(APPEND questa_flags -do vsim_run.tcl)
  list(APPEND questa_flags -sv_seed 1234)
  list(APPEND questa_flags -L ${ALTERA_MEGAFUNCTIONS})
  list(APPEND questa_flags -l vlog_run.log)
  string(REPLACE ";" " " questa_flags "${questa_flags}")
  set(QUESTA_VSIM_FLAGS "${questa_flags}"
          CACHE STRING "Modelsim/Questa simulator flags")

  # Define rule to generate platform_afu_top_config.vh
  set(questa_flags "")

  # afu_platform_config --sim --tgt=rtl --src ccip_std_afu.json  intg_xeon
  file(MAKE_DIRECTORY ${PROJECT_BINARY_DIR}/platform_includes)
  add_custom_command(OUTPUT "platform_includes/platform_afu_top_config.vh"
          WORKING_DIRECTORY ${PROJECT_BINARY_DIR}
          COMMAND ${AFU_PLATFORM_CONFIG} --sim --tgt=platform_includes --src ${PROJECT_BINARY_DIR}/ccip_std_afu.json ${ASE_PLATFORM_ABBREV})

  # Build DPI header file for ASE
  set(questa_flags ${QUESTA_VLOG_FLAGS})
  list(APPEND questa_flags -f ${CMAKE_BINARY_DIR}/${ASE_PROJECT_SOURCES})
  list(APPEND questa_flags -l vlog_if.log)
  file(MAKE_DIRECTORY ${PROJECT_BINARY_DIR}/include)
  add_custom_command(OUTPUT "include/platform_dpi.h"
          WORKING_DIRECTORY ${PROJECT_BINARY_DIR}
          COMMAND ${QUESTA_VLIB_EXECUTABLE} work
          COMMAND ${QUESTA_VLOG_EXECUTABLE} -dpiheader ${PROJECT_BINARY_DIR}/include/platform_dpi.h ${questa_flags}
          DEPENDS "platform_includes/platform_afu_top_config.vh")

  # Compile SystemVerilog code for AFU, keep reuse questa_flags
  list(APPEND questa_flags -f ${CMAKE_BINARY_DIR}/${ASE_PROJECT_SOURCES})
  list(APPEND questa_flags -l vlog_afu.log)
  add_custom_command (OUTPUT vlog
          WORKING_DIRECTORY ${PROJECT_BINARY_DIR}
          COMMAND ${QUESTA_VLOG_EXECUTABLE} ${questa_flags}
          DEPENDS "include/platform_dpi.h")

  # Define SystemVerilog compilation target
  add_custom_target (vlog_compile ALL
          DEPENDS vlog)

  # Create simulation application
  file(COPY ${PROJECT_BINARY_DIR}/tmp/ase_server.sh
          DESTINATION ${PROJECT_BINARY_DIR}
          FILE_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ
          GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
