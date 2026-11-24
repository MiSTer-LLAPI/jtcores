"""Run the upstream game's ROM-header and CPU I/O logic with the synthesized configuration."""
import importlib.util
import subprocess
import sys
from pathlib import Path

root, generated, scratch = map(Path, sys.argv[1:])
support = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("verifier",support/"verificar-autofire.py")
checker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checker)
defines = checker.generated_definitions(generated/"effective.qsf")
assert defines["JTFRAME_BUTTONS"]=="2" and "JTFRAME_1942_INPUT_PROFILE" in defines
flags = [f"-D{k}={v}" if v else f"-D{k}" for k,v in defines.items()]
g = root/"cores/1942/hdl"
h = root/"modules/jtframe/target/mister/hdl"
i = root/"modules/jtframe/hdl/inc"
top = checker.preprocessed(h/"jtframe_mister.sv",flags)
for pin in (".clk_rom(clk_rom)",".clk_sys(clk_sys)",".first_byte(ioctl_addr == 0)",
            ".rom_write(ioctl_rom && ioctl_wr)",".header_data(ioctl_dout)",".one_action(snac_one_action)"):
    assert pin in top, pin
image=scratch/"cabinet"
subprocess.run(["iverilog","-g2012","-i","-s","capcom_controls_tb",*flags,
                "-I", str(i),"-I",str(generated),"-I",str(g),"-o",image,
                support/"cabinet_tb.sv", g/"jt1942_game.v",g/"jt1942_main.v",g/"jt1942_snac_profile.v",
                h/"jtframe_serial_arcade.sv",h/"jtframe_snac_turbo.sv",h/"jtframe_llapi_arcade.sv",
                h/"jtframe_llapi_protocol.sv",h/"joydb15.v"],check=True)
subprocess.run(["vvp","-N",image],check=True)
download_image = scratch/"download_profile"
subprocess.run(["iverilog","-g2012","-s","download_profile_tb",*flags,"-o",download_image,
                support/"download_profile_tb.sv",g/"jt1942_snac_profile.v",h/"jtframe_mister_dwnld.v",
                root/"modules/jtframe/hdl/ram/jtframe_rpwp_ram.v"],check=True)
subprocess.run(["vvp","-N",download_image],check=True)
