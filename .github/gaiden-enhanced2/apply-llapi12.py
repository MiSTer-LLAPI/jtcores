"""Upgrade the shared Enhanced transport from LLAPI 1.0.0 to LLAPI 1.2."""
from pathlib import Path


def replace_once(data: bytes, before: bytes, after: bytes) -> bytes:
    if data.count(before) != 1:
        raise ValueError(f"Unexpected LLAPI source, expected one match: {before!r}")
    return data.replace(before, after)


driver = Path("modules/jtframe/target/mister/hdl/jtframe_llapi_protocol.sv")
source = driver.read_bytes()
changes = (
    (b"* Copyright 2019 Jamie Dickson aka Kitrinx\n",
     b"* Copyright 2019 Jamie Dickson aka Kitrinx\n"
     b"* Copyright 2026 Ricardo Saraiva aka RickDangerous (UltimateMiSTer.com)\n"),
    (b"// Feb, 1 2019 - Initial Release\n",
     b"// Feb, 1 2019 - Initial Release\n\n"
     b"// LLAPI Enhanced v1.0.0: extended Poll ACK and immediate repoll support.\n"
     b"// v1.1: require consecutive high DATA samples at receive start.\n"
     b"// v1.2: cover all payload commands for premature replies and preserve\n"
     b"// the command slot when an invalid command is rejected.\n"),
    (b"CMD_ERROR, // 0=completed, E0=timeout, E1=rejected, E2=premature raw reply",
     b"CMD_ERROR, // 0=completed, E0=timeout, E1=rejected, E2=premature reply during payload transmission"),
    (b"wire premature_reply = raw_active &&",
     b"wire premature_reply = command_busy &&"),
    (b"command_slot <= 0; CMD_ERROR <= 0; CMD_REPLY <= 0; CMD_REPLY_LENGTH <= 0;",
     b"CMD_REPLY <= 0; CMD_REPLY_LENGTH <= 0;"),
    (b"command_busy <= 1; active_opcode <= CMD_OPCODE; raw_selected <= request_raw;",
     b"command_slot <= 0; CMD_ERROR <= 0;\n"
     b"                    command_busy <= 1; active_opcode <= CMD_OPCODE; raw_selected <= request_raw;"),
    (b"end else if (cycle >= TIME_LEADIN && data_in) begin // If we get data high it means we're reading\n"
     b"\t\t\t\tcount <= count + 1'b1;\n"
     b"\t\t\tend\n",
     b"end else if (cycle >= TIME_LEADIN && data_in) begin\n"
     b"\t\t\t\tcount <= count + 1'b1;\n"
     b"\t\t\tend else begin\n"
     b"\t\t\t\t// A low sample breaks the high run, including during a long Poll ACK.\n"
     b"\t\t\t\tcount <= 0;\n"
     b"\t\t\tend\n"),
)
for before, after in changes:
    source = replace_once(source, before, after)
driver.write_bytes(source)

cfg = Path("modules/jtframe/target/mister/cfgstr")
cfg.write_text(cfg.read_text().replace("LLAPI Driver: 1.0.0", "LLAPI Driver: 1.2")
               .replace("LLAPI DRIVER: V1.0.0", "LLAPI DRIVER: V1.2"))
