module Mescaline.Meap.Import (
    importDirectory
) where

import           Database.HDBC (IConnection)

-- import           Mescaline.Data.Unique (Unique)
-- import qualified Mescaline.Data.Unique as Unique
import           Mescaline.Database.Feature (Feature)
import qualified Mescaline.Database.Feature as Feature
import           Mescaline.Database.Model ()
import           Mescaline.Database.Unit (Unit)
import qualified Mescaline.Database.Unit as Unit
import           Mescaline.Database.SourceFile (SourceFile)
import qualified Mescaline.Database.SourceFile as SourceFile
import qualified Mescaline.Database.Table as Table
import           Mescaline.Data.Array.Vector
import           Mescaline.Meap.Extractor as Extractor
import           Mescaline.Meap.Segmenter as Segmenter
import           Mescaline.Meap.Chain as Chain
import qualified Sound.Analysis.Meapsoft as Meap

meapFeatures :: [String]
meapFeatures = [
    "AvgChroma"
  , "AvgChromaScalar"
  , "AvgChunkPower"
  , "AvgFreqSimple"
  , "AvgMelSpec"
  , "AvgMFCC"
  , "AvgPitch"
  , "AvgSpecCentroid"
  , "AvgSpecFlatness"
  , "AvgTonalCentroid"
  , "ChunkLength"
  , "ChunkStartTime"
  , "Entropy"
  , "RMSAmplitude"
  , "SpectralStability"
  ]

options :: Unit.Segmentation -> Chain.Options
options seg = Chain.defaultOptions {
            segmenter = Segmenter.defaultOptions {
            segmentation = case seg of
                            Unit.Beat -> Segmenter.Beat
                            Unit.Onset -> Segmenter.Onset
            }
          , extractor = Extractor.defaultOptions {
            features  = meapFeatures } }

meapFeaturePrefix :: String
meapFeaturePrefix = "com_meapsoft_"

convUnit :: SourceFile -> Unit.Segmentation -> (Double, Double) -> Unit
convUnit sf s (o, d) = Unit.cons sf s o d

convFeatureDesc :: Meap.Feature -> Feature.Descriptor
convFeatureDesc f = Feature.consDescriptor
                       (meapFeaturePrefix ++ (Meap.feature_name f))
                       (Meap.feature_degree f)

convFeature :: Feature.Descriptor -> Meap.Feature -> Unit -> [Double] -> Feature
convFeature d f u l = Feature.cons u d v
    -- TODO: Make this more efficient
    where v = toU . take (Meap.feature_degree f) . drop (Meap.feature_column f) $ l

insert :: (Table.Model a, IConnection c) => c -> a -> IO a
insert c a = Table.insert c a >> return a

meapFrames :: Meap.MEAP -> [[Double]]
meapFrames meap = map (Meap.frame_l meap) [0..Meap.n_frames meap - 1]

insertFile :: IConnection c => Unit.Segmentation -> c -> FilePath -> Meap.MEAP -> IO ()
insertFile seg c path meap = do
    -- mapM_ print (Meap.features meap)
    -- mapM_ print (meapFrames meap)
    sf <- SourceFile.newLocal path
    Table.insert c sf
    ds <- mapM (insert c . convFeatureDesc) $ Meap.features meap
    us <- mapM (insert c . convUnit sf seg) $ Meap.segments_l meap
    flip mapM_ (zip ds (Meap.features meap)) $ \(d, f) ->
        flip mapM_ (zip us (meapFrames meap)) $
            insert c . uncurry (convFeature d f)

importDirectory :: IConnection c => Int -> FilePath -> c -> IO ()
importDirectory np dir c = do
    Chain.mapDirectory np (insertFile Unit.Onset c) (options Unit.Onset) dir
    Chain.mapDirectory np (insertFile Unit.Beat c) (options Unit.Beat) dir
