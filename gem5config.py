import m5
from m5.objects import *
import argparse
import sys

parser = argparse.ArgumentParser(description='Run gem5 SE simulation for a specified ARM binary with optional arguments and vector length.')

parser.add_argument('--binary', type=str, required=True,
                    help='Path to the ARM binary to execute (relative to gem5 root)')

parser.add_argument('--options', type=str, default="",
                    help='Command line options for the binary (enclose multiple args in quotes, e.g., "arg1 arg2")')

parser.add_argument('--vector-length', type=int, default=128, 
                    help='SVE/SME vector length in bits (e.g., 128, 256, 512). Must be multiple of 128.')

args = parser.parse_args()


MIN_VL = 128
MAX_VL = 2048
if args.vector_length % 128 != 0 or args.vector_length < MIN_VL or args.vector_length > MAX_VL:
    print(f"\nError: Invalid vector length '{args.vector_length}'. Must be a multiple of 128 between {MIN_VL} and {MAX_VL}.", file=sys.stderr)
    sys.exit(1)
vl_multiplier = args.vector_length // 128


system = System()

system.clk_domain = SrcClockDomain()
system.clk_domain.clock = "1GHz"
system.clk_domain.voltage_domain = VoltageDomain()

system.mem_mode = "timing"
system.mem_ranges = [AddrRange("8192MB")]

system.cpu = ArmO3CPU()
system.cpu.release = Armv92() 

system.membus = SystemXBar()

system.cpu.icache_port = system.membus.cpu_side_ports
system.cpu.dcache_port = system.membus.cpu_side_ports
system.cpu.createInterruptController()
system.system_port = system.membus.cpu_side_ports

system.mem_ctrl = MemCtrl()
system.mem_ctrl.dram = DDR3_1600_8x8() 
system.mem_ctrl.dram.range = system.mem_ranges[0]
system.mem_ctrl.port = system.membus.mem_side_ports

binary_path = args.binary
binary_options_string = args.options

system.workload = SEWorkload.init_compatible(binary_path)

process = Process()

process_args = binary_options_string.split()
process.cmd = [binary_path] + process_args

system.cpu.workload = process
system.cpu.createThreads()

print(f"\nConfiguring gem5 CPU ISA with SVE/SME Vector Length: {args.vector_length} bits (Multiplier: {vl_multiplier})")
try:
    if hasattr(system.cpu.isa[0], 'sve_vl_se'):
        system.cpu.isa[0].sve_vl_se = vl_multiplier
    else:
        print("Warning: CPU ISA object does not have 'sve_vl_se' attribute.", file=sys.stderr)

    if hasattr(system.cpu.isa[0], 'sme_vl_se'):
        system.cpu.isa[0].sme_vl_se = vl_multiplier
    else:
        print("Warning: CPU ISA object does not have 'sme_vl_se' attribute.", file=sys.stderr)
except IndexError:
     print("Error: system.cpu.isa list is empty. Cannot set vector lengths.", file=sys.stderr)
     sys.exit(1)
except Exception as e:
     print(f"Error setting vector length attributes: {e}", file=sys.stderr)
     sys.exit(1)


root = Root(full_system=False, system=system)
m5.instantiate()

print("\n--starting sim--\n")
print(f"Beginning simulation for: {' '.join(process.cmd)}")
print(f"Using Vector Length: {args.vector_length} bits")
exit_event = m5.simulate()
print(
    f"\nExiting @ tick {m5.curTick()} because {exit_event.getCause()}"
)