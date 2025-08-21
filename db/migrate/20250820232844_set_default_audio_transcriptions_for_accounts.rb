class SetDefaultAudioTranscriptionsForAccounts < ActiveRecord::Migration[7.1]
  def change
    change_column_default :accounts, :settings, { audio_transcriptions: true }
  end
end
