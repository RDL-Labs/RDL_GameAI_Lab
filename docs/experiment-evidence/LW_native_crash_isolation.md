# LW native crash isolation — 2026-10-09

Status: minimal GameAI-independent failure reproduced; root cause NOT identified.

The repeated three-day 1-second observation run failed after 196.0757 wall seconds with 0xc0000005. Last hourly progress was 0.3333 day; raw log 616,776,451 bytes. No three-day acceptance is claimed.

Windows Application event 1000 identifies python312.dll at three different offsets for today's LW failures: 0x23636, 0x9a095 and 0x29e24. Python stacks point to segment_hit, a visibility generator and ray_hit respectively. A hot Python frame is not proof of the faulty native operation.

## Bounded probes

- Pure ray_hit/segment_hit loop, 256 seeded numeric cases: 41,798,400 pairs in 30 seconds, Python 3.12.14, completed. This does not exonerate every possible input.
- Integrated 7200-World-second attempt, 1-second observations, PYTHONMALLOC=debug: native access violation after 3.398 seconds. Output: outputs/crash_debug_7200s_20261009. No allocator diagnostic preceded the access violation.
- Same intended integrated duration on existing Python 3.11.9: failed in standard-library copy.py with UnboundLocalError for its memo argument. Output: outputs/crash_py311_7200s_20261009.
- Isolated standard-library-only deepcopy loop via stdin on 3.11: abnormal exception reporting (Exception expected, bool found).
- File-based `integrations/lightweight/stdlib_crash_probe.py`, Python 3.11.9, `-I -X faulthandler`: access violation in copy.py within about 2.5 seconds. Exit -1073741819 (0xc0000005). Log: outputs/stdlib_probe_311_20261009.log.
- Identical file-based probe, bundled Python 3.12.14, `-I -X faulthandler`: 340,232 copies in 30 seconds, exit 0. Log: outputs/stdlib_probe_312_20261009.log.

The probe imports only copy, sys and time, holds a small fixed dictionary/list structure and does not retain copies. It imports no GameAI module, third-party package or custom ctypes code. Thus the application is not necessary to trigger at least one native failure on this host. The passing 3.12 probe does not establish long-run stability.

CPU reported by Win32_Processor: Intel Core i9-13900KF. Hardware failure is NOT established. Runtime installation integrity, OS/injected software and CPU/RAM stability remain alternatives. No BIOS, clock, voltage, security software or system configuration was modified.

Next useful comparison: run this exact minimal file on another known-stable host, and examine this host's runtime/system stability before another long acceptance run. A process restart is not a demonstrated fix. No gameplay workaround or ray geometry change was made.
