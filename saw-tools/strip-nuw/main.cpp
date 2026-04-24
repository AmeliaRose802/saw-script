#include "StripNuwPass.h"

#include "llvm/Bitcode/BitcodeReader.h"
#include "llvm/Bitcode/BitcodeWriter.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/Module.h"
#include "llvm/IRReader/IRReader.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/Error.h"
#include "llvm/Support/FileSystem.h"
#include "llvm/Support/InitLLVM.h"
#include "llvm/Support/MemoryBuffer.h"
#include "llvm/Support/SourceMgr.h"
#include "llvm/Support/ToolOutputFile.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;

static cl::opt<std::string> InputFilename(cl::Positional,
                                          cl::desc("<input bitcode file>"),
                                          cl::Required);

static cl::opt<std::string> OutputFilename("o",
                                           cl::desc("Output bitcode file"),
                                           cl::value_desc("filename"),
                                           cl::Required);

int main(int argc, char **argv) {
  InitLLVM X(argc, argv);

  cl::ParseCommandLineOptions(argc, argv,
                              "Strip nuw/nsw flags from LLVM bitcode\n\n"
                              "Removes nuw/nsw flags from arithmetic and GEP\n"
                              "instructions to prevent poison-value proof\n"
                              "obligations during SAW verification.\n");

  LLVMContext Ctx;
  SMDiagnostic Diag;
  std::unique_ptr<Module> M = parseIRFile(InputFilename, Diag, Ctx);
  if (!M) {
    Diag.print(argv[0], errs());
    return 1;
  }

  // Build and run the pass pipeline.
  LoopAnalysisManager LAM;
  FunctionAnalysisManager FAM;
  CGSCCAnalysisManager CGAM;
  ModuleAnalysisManager MAM;

  PassBuilder PB;
  PB.registerModuleAnalyses(MAM);
  PB.registerCGSCCAnalyses(CGAM);
  PB.registerFunctionAnalyses(FAM);
  PB.registerLoopAnalyses(LAM);
  PB.crossRegisterProxies(LAM, FAM, CGAM, MAM);

  ModulePassManager MPM;
  MPM.addPass(stripnuw::StripNuwPass());
  MPM.run(*M, MAM);

  // Write output bitcode.
  std::error_code EC;
  ToolOutputFile Out(OutputFilename, EC, sys::fs::OF_None);
  if (EC) {
    errs() << "strip-nuw: error opening output file: " << EC.message() << "\n";
    return 1;
  }

  WriteBitcodeToFile(*M, Out.os());
  Out.keep();

  return 0;
}
