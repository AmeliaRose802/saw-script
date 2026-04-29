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
      llvm_vtable_slots,
      llvm_subclasses,
      llvm_symbol_exists
  ) where

import Data.String
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Parameterized.Some
import Control.Monad (unless, forM_)
import Control.Monad.State (gets)
import Data.List (isPrefixOf)
import qualified Data.Map.Strict as Map


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

-- | Check whether a symbol (function, global, or extern) exists in the LLVM module.
llvm_symbol_exists :: Some CMS.LLVMModule -> Text -> Bool
llvm_symbol_exists (Some llvmMod) symNameText =
  let symName = Text.unpack symNameText
      ast = CMS.modAST llvmMod
      defNames  = map (show . LLVM.defName)   (LLVM.modDefines ast)
      declNames = map (show . LLVM.decName)    (LLVM.modDeclares ast)
      globNames = map (show . LLVM.globalSym)  (LLVM.modGlobals ast)
  in symName `elem` defNames || symName `elem` declNames || symName `elem` globNames

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
llvm_vtable_slots :: Some CMS.LLVMModule -> Text -> TopLevel ()
llvm_vtable_slots (Some llvmMod) classPatternText = do
  let classPattern = Text.unpack classPatternText
      ast = CMS.modAST llvmMod
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
  LLVM.ValStruct fields -> concatMap extractFromField fields
  
  -- Or arrays of structs
  LLVM.ValArray _ elements -> concatMap extractVtableSlots elements
  
  -- Packed structs
  LLVM.ValPackedStruct fields -> concatMap extractFromField fields
  
  -- Sometimes they're just directly initialized with values
  _ -> [describeValue val]

-- | Extract slot info from a struct field, which might be nested.
extractFromField :: LLVM.Typed LLVM.Value -> [String]
extractFromField (LLVM.Typed _ val) = case val of
  LLVM.ValStruct fields -> concatMap extractFromField fields
  LLVM.ValArray _ elements -> map describeValue elements
  LLVM.ValPackedStruct fields -> concatMap extractFromField fields
  _ -> [describeValue val]

-- | Describe a single vtable slot value.
describeValue :: LLVM.Value -> String
describeValue val = case val of
  -- Function pointer
  LLVM.ValSymbol sym -> show sym
  
  -- Null pointer (unused slot or end marker)
  LLVM.ValZeroInit -> "null"
  
  -- Constant integer (offset-to-top, etc.)
  LLVM.ValInteger i -> "constant " ++ show i
  
  -- Bitcast of a function pointer
  LLVM.ValConstExpr (LLVM.ConstConv LLVM.BitCast (LLVM.Typed _ inner) _) ->
    describeValue inner
  
  -- Pointer arithmetic (GEP)
  LLVM.ValConstExpr (LLVM.ConstGEP{}) -> "offset/GEP"
  
  -- Other constant expressions
  LLVM.ValConstExpr _ -> "const-expr"
  
  -- Metadata or other
  _ -> "?"

-- ---------------------------------------------------------------------------
-- Subclass enumeration via RTTI typeinfo structures
-- ---------------------------------------------------------------------------

-- | Enumerate all concrete subclasses of a base class by inspecting RTTI
-- typeinfo structures in the LLVM module.
--
-- The Itanium C++ ABI emits typeinfo globals with @_ZTI@ prefixes.
-- Single-inheritance typeinfo (@__si_class_type_info@) has a pointer to the
-- parent typeinfo at field index 2, allowing us to reconstruct the
-- inheritance graph.
--
-- Example:
--
-- > subs <- llvm_subclasses m "Shape"
-- > -- subs = ["Circle", "Rectangle"]
llvm_subclasses :: Some CMS.LLVMModule -> Text -> TopLevel [Text]
llvm_subclasses (Some llvmMod) baseClassText = do
  let baseClass = Text.unpack baseClassText
      ast       = CMS.modAST llvmMod
      globals   = LLVM.modGlobals ast

      -- Step 1: Collect all _ZTI globals and extract class name + parent name
      typeinfoEntries = concatMap extractTypeinfoEntry globals

      -- Step 2: Build parent -> [child] map
      childMap = buildChildMap typeinfoEntries

      -- Step 3: Transitively collect all descendants of baseClass
      descendants = collectDescendants childMap baseClass

  if null descendants
    then do
      printOutLnTop Info $ "No subclasses found for: " ++ baseClass
      return []
    else do
      forM_ descendants $ \cls ->
        printOutLnTop Info $ "  subclass: " ++ cls
      return (map Text.pack descendants)

-- | A typeinfo entry: (className, Maybe parentClassName).
type TypeinfoEntry = (String, Maybe String)

-- | Extract a typeinfo entry from an LLVM global if it has a @_ZTI@ prefix.
--
-- For single-inheritance (@__si_class_type_info@), the initializer is a
-- struct with three pointer-sized fields:
--   { vtable-ptr-for-type-info-kind, name-string-ptr, parent-typeinfo-ptr }
--
-- We extract the class name from the symbol (demangling the length-prefixed
-- name embedded in the @_ZTI@ symbol) and the parent from field 2.
extractTypeinfoEntry :: LLVM.Global -> [TypeinfoEntry]
extractTypeinfoEntry global =
  let name = show (LLVM.globalSym global)
  in case stripPrefix "_ZTI" name of
       Nothing -> []
       Just mangled ->
         let className   = demangleClassName mangled
             parentName  = case LLVM.globalValue global of
                             Just val -> extractParentFromTypeinfo val
                             Nothing  -> Nothing
         in [(className, parentName)]
  where
    stripPrefix pfx str
      | pfx `isPrefixOf` str = Just (drop (length pfx) str)
      | otherwise             = Nothing

-- | Demangle an Itanium-style length-prefixed class name.
-- E.g. "6Circle" -> "Circle", "9Rectangle" -> "Rectangle".
-- For nested names (N prefix), we take a simplified approach.
demangleClassName :: String -> String
demangleClassName ('N':rest) = demangleNested rest
demangleClassName s =
  let (digits, remainder) = span isDigit s
  in case digits of
       [] -> s  -- fallback: return as-is
       _  -> let n = read digits :: Int
             in take n remainder
  where
    isDigit c = c >= '0' && c <= '9'

-- | Handle nested names (N...E): extract the last component.
demangleNested :: String -> String
demangleNested = go ""
  where
    go acc [] = acc
    go _   ('E':_) = ""  -- shouldn't happen with valid names
    go _   s =
      let (digits, rest) = span isDigit s
      in case digits of
           [] -> s  -- malformed, return remainder
           _  -> let n = read digits :: Int
                     component = take n rest
                     rest' = drop n rest
                 in case rest' of
                      ('E':_) -> component  -- last component before 'E'
                      _       -> go component rest'
    isDigit c = c >= '0' && c <= '9'

-- | Extract the parent class name from a typeinfo initializer value.
-- In single-inheritance typeinfo, the parent typeinfo pointer is the
-- third field (index 2) of the struct initializer.
extractParentFromTypeinfo :: LLVM.Value -> Maybe String
extractParentFromTypeinfo val = case val of
  LLVM.ValStruct fields
    | length fields >= 3 ->
      let LLVM.Typed _ parentVal = fields !! 2
      in resolveTypeinfoRef parentVal
  LLVM.ValPackedStruct fields
    | length fields >= 3 ->
      let LLVM.Typed _ parentVal = fields !! 2
      in resolveTypeinfoRef parentVal
  _ -> Nothing

-- | Resolve a reference to a typeinfo global back to a class name.
-- The parent pointer is typically @_ZTI<name>@ or a bitcast thereof.
resolveTypeinfoRef :: LLVM.Value -> Maybe String
resolveTypeinfoRef val = case val of
  LLVM.ValSymbol sym ->
    let s = show sym
    in case stripZTI s of
         Just mangled -> Just (demangleClassName mangled)
         Nothing      -> Nothing
  LLVM.ValConstExpr (LLVM.ConstConv LLVM.BitCast (LLVM.Typed _ inner) _) ->
    resolveTypeinfoRef inner
  _ -> Nothing
  where
    stripZTI s
      | "_ZTI" `isPrefixOf` s = Just (drop 4 s)
      | otherwise              = Nothing

-- | Build a map from parent class name to list of direct children.
buildChildMap :: [TypeinfoEntry] -> Map.Map String [String]
buildChildMap entries =
  foldl addEntry Map.empty entries
  where
    addEntry m (child, Just parent) =
      Map.insertWith (++) parent [child] m
    addEntry m (_, Nothing) = m

-- | Transitively collect all descendants of a class.
collectDescendants :: Map.Map String [String] -> String -> [String]
collectDescendants childMap root =
  case Map.lookup root childMap of
    Nothing -> []
    Just directChildren ->
      directChildren ++ concatMap (collectDescendants childMap) directChildren
