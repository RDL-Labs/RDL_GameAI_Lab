# OBS-4B/4C Audition Receive Window Contract

## Status

OBS-4B receive-window contract with the OBS-4C boundary-hardening supplement.

## Processing Order

```text
World sound emit
-> evaluate observer position, yaw, and voxel path at emit time
-> append finite agent-owned receipt
-> close half-open [start, end) window once
-> mix cells and apply profile threshold
-> freeze frame
-> deliver later without recomputation
```

An event spanning multiple windows is split at each boundary. Each fragment's
energy is proportional to its overlap duration, preserving total event energy.

The receiver buffer holds at most 32 receipts per agent and window. Overflow marks that
window `PARTIAL` and `output_limited`; accepted receipts are still processed.
Closing a window removes only its receipts. Delivery does not recreate a sound
or reopen a closed window. Re-closing one returns the same frozen frame. Events
delivered to a closed window are rejected and cannot mutate that frame.

At most eight qualifying detections are published per frame. If more qualify,
the first eight in deterministic cell order are retained and the frame records
`PARTIAL / output_limited`. Below-threshold cells do not count as omitted output.

Direction and `observer_frame_ref` are captured when the World event is
emitted. Later movement or rotation cannot rewrite the historical direction.
An event exactly at the boundary belongs to the later window because windows
are half-open.

## Acceptance

1. Two brief first-window events mix into one detection.
2. Removing the source after emission does not erase accepted receipts.
3. Rotating both agents before close/delivery does not alter the first
   detection's `before-turn` pose reference or local direction.
4. An event over `[245000, 255000)` is split into two 5000-us fragments inside
   their respective half-open windows.
5. Duplicate close is idempotent, and a later event for that window is rejected.
6. A 33-event window processes its first 32 receipts while recording partial
   coverage for the overflow.
7. Nine qualifying cells publish eight detections plus explicit missingness;
   nine below-threshold cells remain complete with zero detections.
8. Frames are delivered after three windows close without being counted again.
9. No Experience, semantic interpretation, canonical input, or action change
   is introduced.

