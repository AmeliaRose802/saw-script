{- |
Module      : SAWCentral.LLVMBuiltins
Description : Implementations of LLVM-related SAW-Script primitives.
License     : BSD3
Maintainer  : atomb
Stability   : provisional
-}
{-# LANGUAGE ImplicitParams #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}

module SAWCentral.LLVMBuiltins (
      llvm_load_module,
      llvm_combine_modules,
      llvm_type,
      llvm_int,
      llvm_float,
      llvm_double,
      llvm_array,
      llvm_alias,
      llvm_packed_struct_type,
      llvm_pointer,
      llvm_struct_type,
      llvm_vtable_slots
  ) where

import Data.String
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Parameterized.Some
import Control.Monad (unless, forM_)
import Control.Monad.State (gets)
import Data.List (isPrefixOf, isSuffixOf)
import Data.Maybe (mapMaybe, catMaybes)

import qualified Text.LLVM.AST as LLVM
import qualified Data.LLVM.BitCode as LLVM
import qualified Text.LLVM.Parser as LLVM (parseType)

import qualified SAWCentral.Crucible.LLVM.CrucibleLLVM as CL
import qualified SAWCentral.Crucible.LLVM.MethodSpecIR as CMS (LLVMModule, loadLLVMModule
                                                              , combineLLVMModules
                                                              , modAST)
import SAWCentral.Options
import SAWCentral.Value as SV

llvm_load_module :: FilePath -> TopLevel (Some CMS.LLVMModule)
llvm_load_module file =
  do laxArith <- gets rwLaxArith
     debugIntrinsics <- gets rwDebugIntrinsics
     let ?transOpts = CL.defaultTranslationOptions
                        { CL.laxArith = laxArith
                        , CL.debugIntrinsics = debugIntrinsics
                        }
     halloc <- getHandleAlloc
     io (CMS.loadLLVMModule file halloc) >>= \case
       Left err -> fail (LLVM.formatError err)
       Right (llvm_mod, warnings) -> do
         unless (null warnings) $
           printOutLnTop Warn $ show $ LLVM.ppParseWarnings warnings
         return llvm_mod

llvm_combine_modules :: Some CMS.LLVMModule -> [Some CMS.LLVMModule]
                     -> TopLevel (Some CMS.LLVMModule)
llvm_combine_modules main others =
  do laxArith <- gets rwLaxArith
     debugIntrinsics <- gets rwDebugIntrinsics
     let ?transOpts = CL.defaultTranslationOptions
                        { CL.laxArith = laxArith
                        , CL.debugIntrinsics = debugIntrinsics
                        }
     halloc <- getHandleAlloc
     io $ CMS.combineLLVMModules halloc main others

llvm_type :: Text -> TopLevel LLVM.Type
llvm_type str =
  case LLVM.parseType (Text.unpack str) of
    Left e -> fail (show e)
    Right t -> return t

llvm_int :: Int -> LLVM.Type
llvm_int n = LLVM.PrimType (LLVM.Integer (fromIntegral n))

llvm_float :: LLVM.Type
llvm_float = LLVM.PrimType (LLVM.FloatType LLVM.Float)

llvm_double :: LLVM.Type
llvm_double = LLVM.PrimType (LLVM.FloatType LLVM.Double)

llvm_array :: Int -> LLVM.Type -> LLVM.Type
llvm_array n t = LLVM.Array (fromIntegral n) t

llvm_alias :: Text -> LLVM.Type
llvm_alias n = LLVM.Alias (fromString $ Text.unpack n)

llvm_packed_struct_type :: [LLVM.Type] -> LLVM.Type
llvm_packed_struct_type = LLVM.PackedStruct

llvm_pointer :: LLVM.Type -> LLVM.Type
llvm_pointer = LLVM.PtrTo

llvm_struct_type :: [LLVM.Type] -> LLVM.Type
llvm_struct_type = LLVM.Struct

-- | Display the vtable layout for classes matching the given pattern.
--
-- This command searches the LLVM module for vtables (global variables with
-- mangled names starting with _ZTV) that match the given class name pattern,
-- and displays which method occupies each vtable slot.
--
-- Example usage:
--   llvm_vtable_slots m "MyClass"
--
-- Example output:
--   Vtable for _ZTV7MyClass:
--     slot 0: offset-to-top
--     slot 1: RTTI
--     slot 2: ~MyClass (destructor)
--     slot 3: MyClass::method1
--     slot 4: MyClass::method2
llvm_vtable_slots :: Some CMS.LLVMModule -> String -> TopLevel ()
llvm_vtable_slots (Some llvmMod) classPattern = do
  let ast = CMS.modAST llvmMod
      globals = LLVM.modGlobals ast
      -- Find vtables: globals with names starting with "_ZTV" containing the pattern
      vtables = filter (isVtableForClass classPattern) globals

  if null vtables
    then printOutLnTop Info $ "No vtables found matching pattern: " ++ classPattern
    else forM_ vtables $ \vtable -> do
      let vtableName = show (LLVM.globalSym vtable)
      printOutLnTop Info $ "\nVtable for " ++ vtableName ++ ":"
      case LLVM.globalValue vtable of
        Nothing -> printOutLnTop Info "  (no initializer)"
        Just initializer -> printVtableSlots initializer

-- | Check if a global variable is a vtable for a class matching the pattern.
isVtableForClass :: String -> LLVM.Global -> Bool
isVtableForClass pattern global =
  let name = show (LLVM.globalSym global)
      -- Vtables have mangled names starting with _ZTV
      isVtable = "_ZTV" `isPrefixOf` name
      -- Check if the pattern appears in the vtable name
      matchesPattern = pattern `isSubsequenceOf` name
  in isVtable && matchesPattern

-- | Helper to check if one string is a subsequence of another (case-insensitive).
isSubsequenceOf :: String -> String -> Bool
isSubsequenceOf pattern str =
  let lowerPattern = map toLower pattern
      lowerStr = map toLower str
  in lowerPattern `isInfixOf` lowerStr
  where
    toLower c | c >= 'A' && c <= 'Z' = toEnum (fromEnum c + 32)
              | otherwise = c
    isInfixOf needle haystack = any (needle `isPrefixOf`) (tails haystack)
    tails [] = [[]]
    tails xs@(_:xs') = xs : tails xs'

-- | Print the slots of a vtable initializer.
printVtableSlots :: LLVM.Value -> TopLevel ()
printVtableSlots value = do
  let slots = extractVtableSlots value
  if null slots
    then printOutLnTop Info "  (could not parse vtable structure)"
    else forM_ (zip [0..] slots) $ \(idx, slotDesc) ->
      printOutLnTop Info $ "  slot " ++ show (idx :: Int) ++ ": " ++ slotDesc

-- | Extract slot descriptions from a vtable initializer value.
-- Vtables are typically structs or arrays containing function pointers.
extractVtableSlots :: LLVM.Value -> [String]
extractVtableSlots val = case val of
  -- Vtables are often struct initializers
  LLVM.ValStruct _ fields -> concatMap extractFromField fields
  
  -- Or arrays of structs
  LLVM.ValArray _ elements -> concatMap extractVtableSlots elements
  
  -- Packed structs
  LLVM.ValPackedStruct _ fields -> concatMap extractFromField fields
  
  -- Sometimes they're just directly initialized with values
  _ -> [describeValue val]

-- | Extract slot info from a struct field, which might be nested.
extractFromField :: LLVM.Value -> [String]
extractFromField val = case val of
  LLVM.ValStruct _ fields -> concatMap extractFromField fields
  LLVM.ValArray _ elements -> map describeValue elements
  LLVM.ValPackedStruct _ fields -> concatMap extractFromField fields
  _ -> [describeValue val]

-- | Describe a single vtable slot value.
describeValue :: LLVM.Value -> String
describeValue val = case val of
  -- Function pointer
  LLVM.ValSymbol sym -> show sym
  
  -- Null pointer (unused slot or end marker)
  LLVM.ValZeroInit _ -> "null"
  
  -- Constant integer (offset-to-top, etc.)
  LLVM.ValInteger i -> "constant " ++ show i
  
  -- Bitcast of a function pointer
  LLVM.ValConstExpr (LLVM.ConstConv LLVM.BitCast _ (LLVM.Typed _ inner)) ->
    describeValue inner
  
  -- Pointer arithmetic (GEP)
  LLVM.ValConstExpr (LLVM.ConstGEP{}) -> "offset/GEP"
  
  -- Other constant expressions
  LLVM.ValConstExpr _ -> "const-expr"
  
  -- Metadata or other
  _ -> "?"
