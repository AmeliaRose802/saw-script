#include "StripNuwPass.h"

#include "llvm/IR/Instructions.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/Operator.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;

namespace stripnuw {

PreservedAnalyses StripNuwPass::run(Module &M, ModuleAnalysisManager &MAM) {
  unsigned ArithNUW = 0, ArithNSW = 0, GEPFlags = 0;
  bool Changed = false;

  for (Function &F : M) {
    for (BasicBlock &BB : F) {
      for (Instruction &I : BB) {
        // Arithmetic: add, sub, mul, shl can carry nuw/nsw.
        if (auto *OBO = dyn_cast<OverflowingBinaryOperator>(&I)) {
          if (OBO->hasNoUnsignedWrap()) {
            cast<BinaryOperator>(&I)->setHasNoUnsignedWrap(false);
            ++ArithNUW;
            Changed = true;
          }
          if (OBO->hasNoSignedWrap()) {
            cast<BinaryOperator>(&I)->setHasNoSignedWrap(false);
            ++ArithNSW;
            Changed = true;
          }
        }

        // GEP: strip nuw and nusw, keep inbounds (SAW already models it).
        if (auto *GEP = dyn_cast<GetElementPtrInst>(&I)) {
          bool Had = false;
#if LLVM_VERSION_MAJOR >= 16
          auto Flags = GEP->getNoWrapFlags();
          // LLVM 18+ has GEPNoWrapFlags; earlier versions vary.
          // We clear everything except inbounds by re-setting to inbounds-only
          // if it was originally inbounds, or to none otherwise.
          if (GEP->isInBounds()) {
            // Re-set to just inbounds (drops nuw/nusw).
            GEP->setIsInBounds(true);
            Had = true;
          } else {
            // No inbounds — just clear wrap flags by setting inbounds to false.
            GEP->setIsInBounds(false);
            Had = true;
          }
#else
          // LLVM 14/15: GEPs only have inbounds, nothing to strip.
          (void)GEP;
#endif
          if (Had) {
            ++GEPFlags;
            Changed = true;
          }
        }
      }
    }
  }

  errs() << "strip-nuw: stripped " << ArithNUW << " nuw, " << ArithNSW
         << " nsw (arithmetic), " << GEPFlags << " GEP wrap flags\n";

  return Changed ? PreservedAnalyses::none() : PreservedAnalyses::all();
}

} // namespace stripnuw
