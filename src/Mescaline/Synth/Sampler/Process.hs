module Mescaline.Synth.Sampler.Process (
    Handle
    -- * Input
  , Input(..)
    -- * Output
  , Output(..)
  , new
) where

import           Control.Concurrent
import           Control.Concurrent.Process hiding (Handle)
import qualified Control.Concurrent.Process as Process
import           Control.Exception
import           Mescaline (Time)
import qualified Mescaline.Application as App
import qualified Mescaline.Database.Unit as Unit
import           Mescaline.Synth.Pattern.Event (SynthParams)
import qualified Mescaline.Synth.Sampler.Model as Model
import qualified Sound.SC3.Server.Process as Server
import qualified Sound.SC3.Server.Process.Monad as Server
import           Sound.SC3.Server.Monad as S
import qualified Sound.SC3.Server.Process.CommandLine as Server

data Input =
    Reset
  | Quit
  | PlayUnit Time Unit.Unit SynthParams
  | EngineException_ SomeException
  deriving (Show)

data Output =
    UnitStarted Time Unit.Unit
  | UnitStopped Time Unit.Unit
  | EngineException SomeException

type Handle = Process.Handle Input Output

getEnginePaths :: IO (FilePath, Maybe [FilePath])
getEnginePaths = do
    exe <- App.getResourceExecutable "supercollider/scsynth"
    case exe of
        Nothing -> do
            exe' <- App.findExecutable "scsynth"
            case exe' of
                -- TODO: Display this in the UI
                Nothing -> do
                    d <- App.getResourceDirectory
                    fail $ unwords [
                            "I couldn't find the SuperCollider audio engine `scsynth'."
                          , "You need to put it either in `" ++ d ++ "/supercollider" ++ "' or into your PATH."
                          , "WARNING: Sound output will not work!" ]
                Just exe'' -> return (exe'', Nothing)
        Just exe' -> do
            plg <- App.getResourcePath "supercollider/plugins"
            return (exe', Just [plg])

new :: IO (Handle, IO ())
new = do
    (scsynth, plugins) <- getEnginePaths
    let
        serverOptions = Server.defaultServerOptions {
            Server.loadSynthDefs  = False
          , Server.serverProgram  = scsynth
          , Server.ugenPluginPath = plugins
          }
        rtOptions = Server.defaultRTOptions { Server.udpPortNumber = 2278 }
    
    putStrLn $ unwords $ Server.rtCommandLine serverOptions rtOptions
    
    chan <- newChan
    quit <- newEmptyMVar
    h <- spawn $ process chan
    _ <- forkIO $ runSynth serverOptions rtOptions h chan quit

    return (h, sendTo h Quit >> readMVar quit)
    where
        runSynth serverOptions rtOptions h chan quit = do
            e <- try $
                Server.withSynthUDP
                    serverOptions
                    rtOptions
                    Server.defaultOutputHandler
                    -- (Server.withTransport
                    --     serverOptions
                    --     rtOptions
                    (Model.new >>= loop h chan)
            case e of
                Left exc -> writeChan chan $ EngineException_ exc
                _ -> return ()
            putMVar quit ()
        process :: Chan Input -> ReceiverT Input Output IO ()
        process chan = do
            x <- recv
            case x of
                EngineException_ exc -> notify $ EngineException exc
                msg -> io $ writeChan chan msg
            process chan
        loop :: Handle -> Chan Input -> Model.Sampler -> Server ()
        loop h chan sampler = do
            x <- io $ readChan chan
            case x of
                Quit ->
                    return ()
                Reset -> do
                    Model.free sampler
                    loop h chan sampler
                PlayUnit t u p -> do
                    _ <- fork $ do
                        io $ notifyListeners h $ UnitStarted t u
                        -- io $ putStrLn $ "playUnit: " ++ show (t, u, p)
                        Model.playUnit sampler t u p
                        -- io $ putStrLn $ "stoppedUnit: " ++ show (t, u, p)
                        io $ notifyListeners h $ UnitStopped t u
                    loop h chan sampler
                _ -> loop h chan sampler
