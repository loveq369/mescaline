{-# LANGUAGE DeriveDataTypeable
           , ScopedTypeVariables #-}
module Mescaline.Pattern.Patch.Version_0_0_1 (
    LoadError(..)
  , load
  , store
) where

import           Control.Arrow
import           Control.Exception.Control (Exception, SomeException, catch, throw)
import           Control.Monad.IO.Control (MonadControlIO)
import           Control.Monad.Trans (MonadIO, liftIO)
import qualified Data.List as List
import           Data.Typeable (Typeable)
import qualified Data.Vector.Generic as V
import           Mescaline.Application (AppT)
import qualified Mescaline.Pattern.Patch as P
import qualified Mescaline.Pattern.Sequencer as S
import qualified Mescaline.FeatureSpace.Model as FS
import           Prelude hiding (catch)

data Sequencer = Sequencer Int Int [((Int, Int), Double)] [(Int, (Int, Int))]
     deriving (Read, Show)

data Region = Region Int [Double] Double
    deriving (Read, Show)

data File = File {
    sourceCode :: String
  , sequencer :: Sequencer
  , regions :: [Region]
  } deriving (Read, Show)

regionFromPatch :: FS.Region -> Region
regionFromPatch r = Region (FS.regionId r) (V.toList (FS.center r)) (FS.radius r)

regionToPatch :: Region -> FS.Region
regionToPatch (Region i c r) = FS.mkRegion i (c !! 0, c !! 1) r

sequencerFromPatch :: S.Sequencer -> Sequencer
sequencerFromPatch s = Sequencer (S.rows s) (S.cols s) (S.assocs s) (map (\(i, c) -> (i, (S.row c, S.column c))) (S.cursors s))

sequencerToPatch :: Sequencer -> S.Sequencer
sequencerToPatch (Sequencer r c vs cs) = List.foldl' (\s ((r, c), v) -> S.insert r c v s) s vs
    where s = S.cons r c (map (second (uncurry S.Cursor)) cs)

fileFromPatch :: P.Patch -> File
fileFromPatch p = File {
    sourceCode = P.sourceCode p
  , sequencer = sequencerFromPatch (P.sequencer p)
  , regions = map regionFromPatch (P.regions p) }

fileToPatch :: MonadIO m => File -> AppT m P.Patch
fileToPatch (File c s rs) = P.new c (sequencerToPatch s) (map regionToPatch rs)

data LoadError = LoadError String
                 deriving (Eq, Read, Typeable)

instance Show LoadError where
    show (LoadError s) = "Load error: " ++ s

instance Exception LoadError

load :: MonadControlIO m => FilePath -> AppT m P.Patch
load path = catch (liftIO (readFile path) >>= return . read >>= fileToPatch)
                (\(e :: SomeException) -> throw $ LoadError "Parse error")

store :: FilePath -> P.Patch -> IO ()
store path = writeFile path . show . fileFromPatch
