#ifndef STRIP_NUW_PASS_H
#define STRIP_NUW_PASS_H

#include "llvm/IR/PassManager.h"

namespace stripnuw {

/// StripNuwPass - Removes nuw/nsw/nusw flags from arithmetic and GEP
/// instructions so that SAW's symbolic execution does not generate
/// unprovable poison-value proof obligations.
class StripNuwPass : public llvm::PassInfoMixin<StripNuwPass> {
public:
  llvm::PreservedAnalyses run(llvm::Module &M,
                              llvm::ModuleAnalysisManager &MAM);

  static bool isRequired() { return true; }
};

} // namespace stripnuw

#endif // STRIP_NUW_PASS_H
