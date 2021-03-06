module Resolver.Services.PoolsResolver 
    ( PoolResolver(..)
    , mkPoolResolver
    ) where

import RIO
import Resolver.Repositories.PoolRepository
import Prelude (print)
import ErgoDex.Amm.Pool
import ErgoDex.State
import Cardano.Types
import Cardano.Models
import Plutus.V1.Ledger.Tx

data PoolResolver = PoolResolver
    { resolve :: PoolId -> IO (Maybe Pool) 
    }

mkPoolResolver :: PoolRepository -> PoolResolver
mkPoolResolver p = PoolResolver $ resolve' p

resolve' :: PoolRepository -> PoolId -> IO (Maybe Pool)
resolve' p@PoolRepository{..} poolId = do
    lastConfirmed <- getLastConfirmed poolId
    _             <- print lastConfirmed
    lastPredicted <- getLastPredicted poolId
    _             <- print lastPredicted
    process p lastConfirmed lastPredicted

process :: PoolRepository -> Maybe (Confirmed Pool) -> Maybe (Predicted Pool) -> IO (Maybe Pool)
process p@PoolRepository{..} confirmedMaybe predictedMaybe = do
    case (confirmedMaybe, predictedMaybe) of 
        (Just (Confirmed out confirmed), Just (Predicted candidate predicted)) -> do
            _ <- print "Got confirmed and predicted pools in process function."
            let upToDate = (gIdx $ outGId (fullTxOut confirmed)) == (gIdx $ outGId (fullTxOut predicted))           
            consistentChain <- existsPredicted (poolId $ poolData confirmed) (refId $ fullTxOut confirmed) (refIdx $ fullTxOut confirmed)
            fmap Just (if upToDate then pure predicted else pessimistic p consistentChain (Predicted out predicted) (Confirmed out confirmed))
        (Just (Confirmed confirmed), _) -> do
            _ <- print "Just only confirmed. Predicted is empty."
            pure $ Just confirmed
        _ -> do
            _ <- print "Both are nothing."
            pure Nothing

pessimistic :: PoolRepository -> Bool -> Predicted Pool -> Confirmed Pool -> IO Pool 
pessimistic p consistentChain predictedPool confirmedPool = do
    if consistentChain then needToUpdate p predictedPool (outGId $ fullTxOut $ confirmed confirmedPool) else pure $ confirmed confirmedPool

needToUpdate :: PoolRepository -> Predicted Pool -> Gix -> IO Pool
needToUpdate PoolRepository{..} (Predicted out (Pool b (FullTxOut _ q w e r t) s)) newGix = do
    let updatedPool = Predicted out (Pool b (FullTxOut newGix q w e r t) s)
    _ <- putPredicted updatedPool
    pure $ predicted updatedPool
