module Mescaline.Synth.SequencerView (
    SequencerView
  , sequencerNew
) where

import Control.Concurrent.Chan
import Control.Concurrent.MVar
import Control.Monad
import Data.Colour.SRGB.Linear (rgb)
import Data.IORef
import Graphics.Rendering.Cairo (Render)
import Graphics.UI.Gtk hiding (Image, Point, get)
import Graphics.UI.Gtk.Diagram
import Mescaline.Synth.Sequencer
import qualified System.Glib.MainLoop as MainLoop

import qualified Graphics.Rendering.Cairo as C
import Graphics.Rendering.Cairo (Render)
import Control.Monad.State (liftIO)
import Data.List (find)
import Data.Maybe
import Graphics.UI.Gtk hiding (Point)
import Graphics.UI.Gtk.Gdk.EventM

import Debug.Trace

type SequencerView = DrawingArea

type Rect = (Double, Double, Double, Double)

data Params a = Params {
    boxSize   :: Double
  , padding   :: Double
  , sequencer :: Sequencer a
  , bboxes    :: [[((Int,Int), Rect)]] }

sequencerSizeRequest :: Params a -> IO Requisition
sequencerSizeRequest p = do
    let w = fromIntegral (cols (sequencer p)) * (boxSize p + padding p) + padding p
        h = fromIntegral (rows (sequencer p)) * (boxSize p + padding p) + padding p
    return $ Requisition (truncate w) (truncate h)

withState :: Render a -> Render a
withState action = do
    C.save
    a <- action
    C.restore
    return a
    
sequencerRender :: Params a -> Render ()
sequencerRender p = do
    withState $ do
        C.translate (padding p) (padding p)
        forM_ [0..cols (sequencer p) - 1] $ \r -> do
            withState $ do
                C.translate 0 (fromIntegral r * (boxSize p + padding p))
                forM_ [0..rows (sequencer p) - 1] $ \c -> do
                    withState $ do
                        C.translate (fromIntegral c * (boxSize p + padding p)) 0
                        C.rectangle 0 0 (boxSize p) (boxSize p)
                        if sequencer p `isCursorAtIndex` (r, c)
                            then C.fill
                            else C.stroke

sequencerExpose :: Params a -> EventM EExpose Bool
sequencerExpose p = do
    win <- eventWindow
    liftIO $ do
        (width, height) <- drawableGetSize win
        renderWithDrawable win (sequencerRender p)
    return True

translateRect :: (Double, Double) -> Rect -> Rect
translateRect (dx, dy) (x, y, w, h) = (x+dx, y+dy, w, h)

isWithin :: (Double, Double) -> Rect -> Bool
(px, py) `isWithin` (x, y, w, h) = px >= x && px <= x+w && py >= y && py <= y+h 

mkBboxes :: Double -> Double -> Sequencer a -> [[((Int,Int), Rect)]]
mkBboxes boxSize padding s = map fr [0..rows s - 1]
    where
        fr r = map (fc r) [0..cols s - 1]
        fc r c = ((r, c), (padding + (boxSize+padding) * fromIntegral c, padding + (boxSize+padding) * fromIntegral r, boxSize, boxSize))

pointToIndex :: Params a -> (Double, Double) -> Maybe (Int, Int)
pointToIndex params p = fmap fst $ find (isWithin p . snd) $ concat $ bboxes params

sequencerMouseEvent :: Params a -> EventM EButton Bool
sequencerMouseEvent p = do
    (x, y) <- eventCoordinates
    win <- eventWindow
    (_, h) <- liftIO $ drawableGetSize win
    let index = pointToIndex p (x, fromIntegral h - y)
    -- liftIO $ print (bboxes p)
    liftIO $ print index
    return True

-- redraw :: Double -> Double -> Sequencer a -> Diagram
-- redraw boxSize padding s = grid $ [ [ pad padding padding $ box r c $ s `isCursorAtIndex` (r, c) | c <- [0..cols s - 1] ] |  r <- [0..rows s - 1] ]
--     where
--         box r c b = D.Region (r * cols s + c) $ fillColor (fc b) $ rect boxSize boxSize
--         fc True  = rgb 0.2 0.2 0.2
--         fc False = rgb 1.0 1.0 1.0

sequencerNew :: Double -> Double -> Sequencer a -> Chan (Sequencer a) -> IO SequencerView
sequencerNew boxSize padding s c = do
    ref <- newIORef (Params boxSize padding s (mkBboxes boxSize padding s))
    w <- drawingAreaNew
    w `on` sizeRequest $ readIORef ref >>= sequencerSizeRequest
    w `on` exposeEvent $ liftIO (readIORef ref) >>= sequencerExpose
    w `on` buttonPressEvent $ liftIO (readIORef ref) >>= sequencerMouseEvent
    -- w <- diagramNew $ \p -> readIORef ref >>= \s -> return (Auto, redraw boxSize padding s)
    flip MainLoop.timeoutAdd 5 $ do
        e <- isEmptyChan c
        when (not e) $ do
            readChan c >>= \s -> modifyIORef ref (\p -> p { sequencer = s })
            widgetQueueDraw w
        return True
    return w