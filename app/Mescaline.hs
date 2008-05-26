-- sample code, doesn't necessarily compile
module Main where

import Control.Monad.Trans
import Database.Sqlite.Enumerator
import Database.Enumerator
import System.Environment

import Mescaline.Database.Feature (FeatureDescriptor(..), Feature(..))

import Mescaline.Database.SourceFile (SourceFile(..))
import qualified Mescaline.Database.SourceFile as SourceFile

querySourceFileIteratee :: (Monad m) => Int -> FilePath -> String -> IterAct m [SourceFile]
querySourceFileIteratee a b c accum = result' (SourceFile a b c:accum)

queryFeatureDescIteratee :: (Monad m) => Int -> String -> IterAct m [FeatureDescriptor]
queryFeatureDescIteratee a b accum = result' (FeatureDescriptor a b:accum)


bindShortcutExample sfid = do
  let
    iter :: (Monad m) => Int -> String -> Int -> IterAct m [(Int, String, Int)]
    iter a b c acc = result $ (a, b, c):acc
    bindVals = [bindP (sfid::Int)]
    query = prefetch 1000 "select sf.id, sf.path, u.id from source_file sf, unit u, feature_unit fu left join unit on u.sfid=sf.id where sf.id = ?" bindVals
  actual <- doQuery query iter []
  liftIO (print actual)



main :: IO ()
main = do
    [dbPath] <- getArgs
    withSession (connect dbPath) ( do
    -- simple query, returning reversed list of rows.
    -- select sf.id, sf.path, u.id from source_file sf, unit u left join unit on u.sfid=sf.id;
    sourceFiles <- doQuery (sql "select * from source_file") querySourceFileIteratee []
    featureDescs <- doQuery (sql "select * from feature") queryFeatureDescIteratee []
    mapM_ (bindShortcutExample . SourceFile.id) sourceFiles
    --liftIO $ putStrLn $ show featureDescs
    --otherActions session
	-- bindShortcutExample 
    )
