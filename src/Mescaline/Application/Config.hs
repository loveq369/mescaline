{-# LANGUAGE DeriveDataTypeable, ScopedTypeVariables #-}
module Mescaline.Application.Config (
    module Data.ConfigFile
  , getIO
  , getColor
  , getConfig
) where

import           Control.Concurrent.MVar
import           Control.Exception
import           Control.Monad
import           Control.Monad.Error (MonadError)
import           Data.ConfigFile
import           Data.Typeable
import           Mescaline.Application
import           Mescaline.Util (readMaybe)
import qualified Qtc.Classes.Qccs as Qt
import qualified Qtc.ClassTypes.Gui as Qt
import qualified Qtc.Gui.QColor as Qt
import           System.Directory
import           System.FilePath
import           Text.Regex

newtype Color = Color (Qt.QColor ())

data ConfigParserError = ConfigParserError { cpError :: CPError } deriving (Show, Typeable)

instance Exception ConfigParserError

hexAlphaRegex :: Regex
hexAlphaRegex = mkRegex "^(#[A-Ba-b0-9][A-Ba-b0-9][A-Ba-b0-9][A-Ba-b0-9][A-Ba-b0-9][A-Ba-b0-9][A-Ba-b0-9][A-Ba-b0-9])([A-Ba-b0-9][A-Ba-b0-9])$"

alphaRegex :: Regex
alphaRegex = mkRegex "^([^*]+)\\*([0-9]+(\\.[0-9]+)?)$"

getIO :: Get_C a => ConfigParser -> SectionSpec -> OptionSpec -> IO a
getIO config section option = do
    case get config section option of
        Left e  -> throw (ConfigParserError e)
        Right a -> return a

getColor :: ConfigParser -> SectionSpec -> OptionSpec -> IO (Qt.QColor ())
getColor config section option = do
    colorSpec <- getIO config section option
    case matchRegex hexAlphaRegex colorSpec of
        Just (rgb:alpha:_) -> do
            color <- Qt.qColor rgb
            case readMaybe ("0x" ++ alpha) of
                Nothing         -> return ()
                Just (a :: Int) -> Qt.setAlpha color a
            return color
        Nothing ->
            case matchRegex alphaRegex colorSpec of
                Just (name:alpha:_) -> do
                    color <- Qt.qColor name
                    case readMaybe alpha of
                        Nothing -> return ()
                        Just a  -> Qt.setAlphaF color a
                    return color
                Nothing -> Qt.qColor colorSpec

defaultConfig :: ConfigParser
defaultConfig = emptyCP { optionxform = id
                        , accessfunc = interpolatingAccess 16 }

readConfigFile :: ConfigParser -> FilePath -> IO ConfigParser
readConfigFile cp path = do
    exists <- doesFileExist path
    if exists
        then do
            result <- readfile cp path
            case result of
                Right cp' -> return cp'
                Left e    -> throw (ConfigParserError e)
        else return cp

getConfig :: IO ConfigParser
getConfig = do
    defaultFile <- getResourcePath "config"
    userFile    <- getUserDataPath "config"
    foldM readConfigFile defaultConfig [defaultFile, userFile]
