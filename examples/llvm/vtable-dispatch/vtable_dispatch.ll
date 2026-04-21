; ModuleID = 'vtable_dispatch'
source_filename = "vtable_dispatch.cpp"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

; Declaration for the virtual method (no body — it's a pure virtual method).
; SAW needs this declaration so llvm_unsafe_assume_spec can reference it.
declare i32 @get_config(ptr, i32, ptr)

; is_machine_enabled - Verify a virtual dispatch call using llvm_bind_method.
;
; This function takes an IKeyStore* (object with vtable) and a container ID.
; It calls GetMachineConfiguration through the vtable (slot 1; slot 0 is the
; destructor) and returns 1 if the call succeeded (result == 0) AND the config
; flag is set (hostDataEnabled != 0).
;
; The vtable dispatch pattern:
;   object[0]       -> vtable pointer
;   vtable[slot*8]  -> function pointer
;   call through function pointer
define i32 @is_machine_enabled(ptr %keystore_obj, i32 %container_id) {
entry:
  ; Allocate config_out on stack, initialize to 0
  %config_out = alloca i32, align 4
  store i32 0, ptr %config_out, align 4

  ; Step 1: Load vtable pointer from object at offset 0
  ;   In C++, the first field of a polymorphic object is the vtable pointer.
  %vtable = load ptr, ptr %keystore_obj, align 8

  ; Step 2: GEP to vtable slot 1 (slot 0 = destructor)
  ;   Each slot is a pointer (8 bytes on x86_64).
  %slot_ptr = getelementptr inbounds ptr, ptr %vtable, i64 1

  ; Step 3: Load function pointer from the vtable slot
  %fn_ptr = load ptr, ptr %slot_ptr, align 8

  ; Step 4: Indirect call - get_config(self, container_id, &config_out) -> i32
  %ks_result = call i32 %fn_ptr(ptr %keystore_obj, i32 %container_id, ptr %config_out)

  ; Load the config value written by get_config
  %host_enabled = load i32, ptr %config_out, align 4

  ; Compute: (ks_result == 0) && (host_enabled != 0)
  %is_success = icmp eq i32 %ks_result, 0
  %is_enabled = icmp ne i32 %host_enabled, 0
  %both = and i1 %is_success, %is_enabled

  ; Zero-extend i1 to i32 for return
  %ret_val = zext i1 %both to i32
  ret i32 %ret_val
}
