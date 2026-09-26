# OBS-4B Audition Receive Window Contract

## Status

OBS-4B operational supplement to the fixed OBS-4 audition reference.

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

The receiver buffer holds at most 32 receipts per agent. Overflow marks that
window `PARTIAL` and `output_limited`; accepted receipts are still processed.
Closing a window removes only its receipts. Delivery does not recreate a sound
or reopen a closed window.

Direction and `observer_frame_ref` are captured when the World event is
emitted. Later movement or rotation cannot rewrite the historical direction.
An event exactly at the boundary belongs to the later window because windows
are half-open.

## Acceptance

1. Two brief first-window events mix into one detection.
2. Removing the source after emission does not erase accepted receipts.
3. Rotating both agents before close/delivery does not alter the first
   detection's `before-turn` pose reference or local direction.
4. An event at `250000 us` occurs once in the second window, never both.
5. A 33-event window processes its first 32 receipts while recording partial
   coverage for the overflow.
6. Frames are delivered after both windows close without being counted again.
7. No Experience, semantic interpretation, canonical input, or action change
   is introduced.

