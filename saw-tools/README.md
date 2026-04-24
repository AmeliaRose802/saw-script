This directory contains the sources for the SAW programs besides SAW
itself (`saw` and `saw-remote-api`):

- `css`, the Cryptol Symbolic Simulator, trainslates a single Cryptol
  function to an and-inverter graph (AIG), and is not built by default.

- `extcore-info` is a tool for viewing/dumping the saw-core external
  dump format.

- `strip-nuw` strips `nuw`/`nsw` wrap flags from LLVM bitcode to
  prevent poison-value proof obligations during SAW verification of
  optimized C++ code.

- `verif-viewer` is a tool for viewing the verification summaries
  produced by SAW.
