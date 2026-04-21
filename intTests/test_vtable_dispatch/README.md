This regression test exercises `llvm_bind_method` on a minimal
`IsMachineEnabled`-style vtable dispatch.

It checks the full boolean decision rule:

`result == (ks_result == SUCCESS && hostDataEnabled != 0)`

using the committed `test.bc` artifact.
