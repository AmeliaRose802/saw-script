; ModuleID = 'test.c'
source_filename = "test.c"
target datalayout = "e-m:w-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-windows-msvc19.44.35225"

%struct.config = type { i32, ptr }

@lookup_table = dso_local global [4 x i32] [i32 100, i32 200, i32 300, i32 400], align 16, !dbg !0
@table_ptr = dso_local global ptr getelementptr (i8, ptr @lookup_table, i64 8), align 8, !dbg !5
@secondary_data = dso_local global i32 42, align 4, !dbg !11
@global_config = dso_local global { i32, [4 x i8], ptr } { i32 1, [4 x i8] zeroinitializer, ptr @secondary_data }, align 8, !dbg !13

; Function Attrs: noinline nounwind optnone uwtable
define dso_local i32 @read_via_global_ptr() #0 !dbg !29 {
  %1 = load ptr, ptr @table_ptr, align 8, !dbg !32
  %2 = load i32, ptr %1, align 4, !dbg !32
  ret i32 %2, !dbg !32
}

; Function Attrs: noinline nounwind optnone uwtable
define dso_local i32 @read_config_data() #0 !dbg !33 {
  %1 = load ptr, ptr getelementptr inbounds nuw (%struct.config, ptr @global_config, i32 0, i32 1), align 8, !dbg !34
  %2 = load i32, ptr %1, align 4, !dbg !34
  ret i32 %2, !dbg !34
}

; Function Attrs: noinline nounwind optnone uwtable
define dso_local i32 @read_both() #0 !dbg !35 {
  %1 = load ptr, ptr @table_ptr, align 8, !dbg !36
  %2 = load i32, ptr %1, align 4, !dbg !36
  %3 = load ptr, ptr getelementptr inbounds nuw (%struct.config, ptr @global_config, i32 0, i32 1), align 8, !dbg !36
  %4 = load i32, ptr %3, align 4, !dbg !36
  %5 = add nsw i32 %2, %4, !dbg !36
  ret i32 %5, !dbg !36
}

attributes #0 = { noinline nounwind optnone uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }

!llvm.dbg.cu = !{!2}
!llvm.module.flags = !{!22, !23, !24, !25, !26, !27}
!llvm.ident = !{!28}

!0 = !DIGlobalVariableExpression(var: !1, expr: !DIExpression())
!1 = distinct !DIGlobalVariable(name: "lookup_table", scope: !2, file: !3, line: 4, type: !19, isLocal: false, isDefinition: true)
!2 = distinct !DICompileUnit(language: DW_LANG_C11, file: !3, producer: "clang version 22.1.3 (https://github.com/llvm/llvm-project e9846648fd6183ee6d8cbdb4502213fcf902a211)", isOptimized: false, runtimeVersion: 0, emissionKind: FullDebug, globals: !4, splitDebugInlining: false, nameTableKind: None)
!3 = !DIFile(filename: "test.c", directory: "C:\\Users\\ameliapayne\\saw-script\\intTests\\test_llvm_cross_global_refs", checksumkind: CSK_MD5, checksum: "e1a903c263f46382f6859cc7afb3c9a7")
!4 = !{!0, !5, !11, !13}
!5 = !DIGlobalVariableExpression(var: !6, expr: !DIExpression())
!6 = distinct !DIGlobalVariable(name: "table_ptr", scope: !2, file: !3, line: 7, type: !7, isLocal: false, isDefinition: true)
!7 = !DIDerivedType(tag: DW_TAG_pointer_type, baseType: !8, size: 64)
!8 = !DIDerivedType(tag: DW_TAG_typedef, name: "int32_t", file: !9, line: 20, baseType: !10)
!9 = !DIFile(filename: "C:\\Program Files (x86)\\Microsoft Visual Studio\\2022\\BuildTools\\VC\\Tools\\MSVC\\14.44.35207\\include\\stdint.h", directory: "", checksumkind: CSK_MD5, checksum: "56e2956fe219a08d408dc2fb7a857cfc")
!10 = !DIBasicType(name: "int", size: 32, encoding: DW_ATE_signed)
!11 = !DIGlobalVariableExpression(var: !12, expr: !DIExpression())
!12 = distinct !DIGlobalVariable(name: "secondary_data", scope: !2, file: !3, line: 15, type: !8, isLocal: false, isDefinition: true)
!13 = !DIGlobalVariableExpression(var: !14, expr: !DIExpression())
!14 = distinct !DIGlobalVariable(name: "global_config", scope: !2, file: !3, line: 16, type: !15, isLocal: false, isDefinition: true)
!15 = distinct !DICompositeType(tag: DW_TAG_structure_type, name: "config", file: !3, line: 10, size: 128, elements: !16)
!16 = !{!17, !18}
!17 = !DIDerivedType(tag: DW_TAG_member, name: "version", scope: !15, file: !3, line: 11, baseType: !8, size: 32)
!18 = !DIDerivedType(tag: DW_TAG_member, name: "data", scope: !15, file: !3, line: 12, baseType: !7, size: 64, offset: 64)
!19 = !DICompositeType(tag: DW_TAG_array_type, baseType: !8, size: 128, elements: !20)
!20 = !{!21}
!21 = !DISubrange(count: 4)
!22 = !{i32 2, !"CodeView", i32 1}
!23 = !{i32 2, !"Debug Info Version", i32 3}
!24 = !{i32 1, !"wchar_size", i32 2}
!25 = !{i32 8, !"PIC Level", i32 2}
!26 = !{i32 7, !"uwtable", i32 2}
!27 = !{i32 1, !"MaxTLSAlign", i32 65536}
!28 = !{!"clang version 22.1.3 (https://github.com/llvm/llvm-project e9846648fd6183ee6d8cbdb4502213fcf902a211)"}
!29 = distinct !DISubprogram(name: "read_via_global_ptr", scope: !3, file: !3, line: 20, type: !30, scopeLine: 20, flags: DIFlagPrototyped, spFlags: DISPFlagDefinition, unit: !2)
!30 = !DISubroutineType(types: !31)
!31 = !{!8}
!32 = !DILocation(line: 21, scope: !29)
!33 = distinct !DISubprogram(name: "read_config_data", scope: !3, file: !3, line: 26, type: !30, scopeLine: 26, flags: DIFlagPrototyped, spFlags: DISPFlagDefinition, unit: !2)
!34 = !DILocation(line: 27, scope: !33)
!35 = distinct !DISubprogram(name: "read_both", scope: !3, file: !3, line: 32, type: !30, scopeLine: 32, flags: DIFlagPrototyped, spFlags: DISPFlagDefinition, unit: !2)
!36 = !DILocation(line: 33, scope: !35)
