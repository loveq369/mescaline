module Mescaline.Synth.SequencerView (
    SequencerView
  , sequencerView
) where

import           Control.Concurrent (forkIO)
import           Control.Concurrent.Chan
import           Control.Concurrent.MVar
import           Control.Monad
import           Control.Monad.Fix (fix)
import           Data.Accessor
import qualified Data.Map as Map
import qualified Data.Foldable as Fold
import           Mescaline (Time)
import qualified Mescaline.Application as App
import           Mescaline.Synth.Sequencer as Seq
import qualified Mescaline.UI as UI
import qualified Sound.OpenSoundControl.Time as Time

import qualified Qtc.Classes.Gui                as Qt
import qualified Qtc.Classes.Qccs_h             as Qt
import qualified Qtc.ClassTypes.Gui             as Qt
import qualified Qtc.Core.Base                  as Qt
import qualified Qtc.Enums.Core.Qt              as Qt
import qualified Qtc.Gui.QBrush                 as Qt
import qualified Qtc.Gui.QGraphicsRectItem      as Qt
import qualified Qtc.Gui.QGraphicsRectItem_h    as Qt
import qualified Qtc.Gui.QGraphicsScene         as Qt
import qualified Qth.Core.Rect                  as Qt

type SequencerView = Qt.QGraphicsSceneSc (CSequencerView)
data CSequencerView = CSequencerView

sequencerView_ :: IO (SequencerView)
sequencerView_ = Qt.qSubClass (Qt.qGraphicsScene ())

data Params = Params {
    boxSize   :: Double
  , padding   :: Double
  } deriving (Show)

type Fields = Map.Map (Int,Int) ((Int, Int), Qt.QGraphicsRectItem ())

data State a = State {
    params    :: Params
  , sequencer :: Sequencer a
  , fields    :: Fields
  , colors    :: [Qt.QColor ()]
  }

mouseHandler :: (Int, Int) -> ((Int, Int) -> IO ()) -> Qt.QGraphicsRectItem () -> Qt.QGraphicsSceneMouseEvent () -> IO ()
mouseHandler coord action this evt = action coord >> Qt.mousePressEvent_h this evt

initScene :: SequencerView -> Params -> Int -> Int -> ((Int, Int) -> IO ()) -> IO Fields
initScene view p rows cols action = do
    xs <- forM [0..rows - 1] $ \r -> do
            forM [0..cols - 1] $ \c -> do
                let y = padding p + fromIntegral r * (boxSize p + padding p)
                    x = padding p + fromIntegral c * (boxSize p + padding p)
                    box = Qt.rectF x y (boxSize p) (boxSize p)
                    coord = (r, c)
                item <- Qt.qGraphicsRectItem_nf box
                Qt.setHandler item "mousePressEvent(QGraphicsSceneMouseEvent*)" $ mouseHandler coord action
                Qt.addItem view item
                return (coord, (coord, item))
    return $ Map.fromList (concat xs)

updateScene :: MVar (State a) -> SequencerView -> SequencerView -> IO ()
updateScene stateVar this _ = do
    state <- readMVar stateVar
    Fold.mapM_ (update state) (fields state)
    where
        update state (coord, field) = do
            -- print (coord, cursor_ (sequencer state))
            b <- if sequencer state `isCursorAtIndex` coord
                    then Qt.qBrush Qt.edarkRed
                    else if sequencer state `isElemAtIndex` coord
                        then Qt.qBrush Qt.edarkGray
                        else Qt.qBrush (colors state !! (fst coord `mod` length (colors state)))
            Qt.setBrush field b

sequencerProcess :: Sequencer a -> Chan (Sequencer a -> Sequencer a) -> IO (Chan (Time, Sequencer a))
sequencerProcess s0 ichan = do
    ochan <- newChan
    t0 <- Time.utcr
    forkIO $ loop ichan ochan s0 t0
    return ochan
    where
        loop ichan ochan s t = do
            s' <- applyUpdates ichan s
            let t' = t + getVal Seq.tick s'
            writeChan ochan (t, s')
            Time.pauseThreadUntil t'
            let s'' = Seq.step (undefined::Seq.Score) s'
            loop ichan ochan s'' t'
        applyUpdates c s = do
            b <- isEmptyChan c
            if b
                then return s
                else do
                    f <- readChan c
                    let s' = f s
                    s' `seq` applyUpdates c s'

sequencerView :: Double -> Double -> Sequencer a -> Chan (Sequencer a -> Sequencer a) -> IO (SequencerView, Chan (Time, Sequencer a))
sequencerView boxSize padding seq0 ichan = do
    let params = Params boxSize padding
    this <- sequencerView_
    ochan <- newChan
    seq_ichan <- newChan
    seq_ochan <- sequencerProcess seq0 seq_ichan
    fields <- initScene this params (rows seq0) (cols seq0) $ \(r, c) -> do
        writeChan seq_ichan (Seq.toggle r c undefined)
    colors <- UI.defaultColorsFromFile
    state <- newMVar (State params seq0 fields colors)
    
    Qt.connectSlot this "updateScene()" this "updateScene()" $ updateScene state
    Qt.emitSignal this "updateScene()" ()

    forkIO $ fix $ \loop -> do
        readChan ichan >>= writeChan seq_ichan
        loop
    
    forkIO $ fix $ \loop -> do
        e@(t, s') <- readChan seq_ochan
        writeChan ochan e
        modifyMVar_ state (\s -> return $ s { sequencer = s' })
        forkIO $ Qt.emitSignal this "updateScene()" ()
        loop

    return (this, ochan)
