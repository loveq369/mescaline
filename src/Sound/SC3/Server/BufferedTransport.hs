module Sound.SC3.Server.BufferedTransport (
    BufferedTransport
  , new
  , dup
  , fork
  , waitFor
  , wait
) where

import Control.Concurrent
import Control.Concurrent.STM
import Control.Monad (join)
import Control.Monad.Loops (iterateUntil)
import Data.Unique
import Sound.OpenSoundControl (OSC(..), Transport(..))

data BufferedTransport t = BufferedTransport t (Chan OSC)

instance Transport t => Transport (BufferedTransport t) where
   -- send  (BufferedTransport _ _ c) = atomically . writeTChan c
   send  (BufferedTransport t _) = send t
   recv  (BufferedTransport _ c) = readChan c
   close (BufferedTransport t _) = close t

new :: Transport t => t -> IO (BufferedTransport t)
new t = do
    c <- newChan
    forkIO $ recvLoop c
    return $ BufferedTransport t c
    where
        -- TODO: exception handling: terminate loop when handle is closed
        recvLoop c = recv t >>= writeChan c >> recvLoop c

-- | Duplicate the transport so that subsequent reads don't affect the original transport.
dup :: BufferedTransport t -> IO (BufferedTransport t)
dup (BufferedTransport t c) = BufferedTransport t `fmap` dupChan c

-- | Fork a thread with a duplicate transport.
fork :: BufferedTransport t -> (BufferedTransport t -> IO ()) -> IO ThreadId
fork t f = dup t >>= forkIO . f

-- | Wait for an OSC message where the supplied function does not give
--   Nothing, discarding intervening messages.
waitFor :: Transport t => BufferedTransport t -> (OSC -> Bool) -> IO OSC
waitFor t@(BufferedTransport _ c) = flip iterateUntil (readChan c)

-- | Wait for an OSC message matching a specific address.
wait :: Transport t => BufferedTransport t -> String -> IO OSC
wait t s = waitFor t (has_address s)
    where
        has_address x (Message y _) = x == y
        has_address x (Bundle _ xs) = any (has_address x) xs