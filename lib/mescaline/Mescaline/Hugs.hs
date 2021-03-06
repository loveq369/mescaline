module Mescaline.Hugs (
    Option(..)
  , Import(..)
  , Module(..)
  , run
  , eval
) where

import           Data.List (intercalate)
import           Mescaline.Util (readMaybe, withTempFile)
import           System.Exit (ExitCode(..))
import           System.IO
import           System.Process (readProcessWithExitCode)

-- | Hugs commandline options.
data Option =
    Haskell98 Bool
  | SearchPath [String] -- ^ Search path (-P)
  | ShowLoadedFiles Bool
  deriving (Eq, Read, Show)

boolOption :: String -> Bool -> String
boolOption s b = (if b then "+" else "-") ++ s

optionToString :: Option -> String
optionToString (Haskell98 b) = boolOption "98" b
optionToString (SearchPath xs) = "-P" ++ intercalate ":" xs
optionToString (ShowLoadedFiles b) = boolOption "w" b

data Import = Unqual
            | As String
            | Qual String
            | Hiding [String]
            deriving (Eq, Read, Show)

data Module = Module String Import
              deriving (Eq, Read, Show)

modToString :: Module -> String
modToString (Module m Unqual)      = "import " ++ m
modToString (Module m (As q))      = "import " ++ m ++ " as " ++ q
modToString (Module m (Qual q))    = "import qualified " ++ m ++ " as " ++ q
modToString (Module m (Hiding xs)) = "import " ++ m ++ " hiding (" ++ intercalate "," xs ++ ")"

run :: FilePath -> [Option] -> [Module] -> String -> IO (Either String String)
run runhugs opts mods src = withTempFile "Mescaline.Hugs.run.XXXX.hs" $ \f h -> do
    hPutStr h src' >> hClose h
    (e, sout, serr) <- readProcessWithExitCode runhugs (map optionToString opts ++ [f]) ""
    case e of
        ExitSuccess   -> return $ Right sout
        ExitFailure _ -> return $ Left serr
    where
        src' = unlines $
                map modToString mods ++ [
                src
              , "main :: IO ()"
              , "main = putStr (show it)" ]

eval :: Read a => FilePath -> [Option] -> [Module] -> String -> IO (Either String a)
eval exe opts mods src = do
    res <- run exe opts mods src
    case res of
        Left e -> return $ Left e
        Right s -> do
            case readMaybe s of
                Nothing -> return $ Left ("Read error: " ++ s)
                Just a  -> return $ Right a
