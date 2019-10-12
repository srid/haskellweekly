module HW.Handler.Episode
  ( episodeHandler
  )
where

import qualified Data.Map
import qualified Data.Text
import qualified Data.Text.Encoding
import qualified HW.Handler.Base
import qualified HW.Template.Episode
import qualified HW.Type.App
import qualified HW.Type.Caption
import qualified HW.Type.Config
import qualified HW.Type.Number
import qualified HW.Type.State
import qualified Network.HTTP.Types
import qualified Network.Wai
import qualified System.FilePath

episodeHandler :: HW.Type.Number.Number -> HW.Type.App.App Network.Wai.Response
episodeHandler number = do
  state <- HW.Type.App.getState
  let episodes = HW.Type.State.stateEpisodes state
  case Data.Map.lookup number episodes of
    Nothing -> pure HW.Handler.Base.notFoundResponse
    Just episode -> do
      maybeCaptions <- readCaptionFile number
      pure
        . HW.Handler.Base.htmlResponse Network.HTTP.Types.ok200 []
        $ HW.Template.Episode.episodeTemplate
            (HW.Type.Config.configBaseUrl $ HW.Type.State.stateConfig state)
            episode
            maybeCaptions

-- | Reads a caption file and parses it as SRT. This will return nothing if the
-- file doesn't exist. If parsing fails, this will raise an exception.
readCaptionFile
  :: HW.Type.Number.Number -> HW.Type.App.App (Maybe [HW.Type.Caption.Caption])
readCaptionFile number = do
  let
    name = "episode-" <> HW.Type.Number.numberToText number
    file = System.FilePath.addExtension (Data.Text.unpack name) "srt"
    path = System.FilePath.combine "podcast" file
  result <- HW.Type.App.readDataFile path
  case result of
    Nothing -> pure Nothing
    Just byteString -> do
      text <- case Data.Text.Encoding.decodeUtf8' byteString of
        Left exception -> fail $ show exception
        Right text -> pure text
      case HW.Type.Caption.parseSrt text of
        Nothing -> fail $ "failed to parse caption file: " <> show path
        Just captions -> pure $ Just captions
