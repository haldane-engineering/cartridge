# frozen_string_literal: true

module Diderot
  module NBA
    class Game < ApplicationRecord
      self.table_name = 'diderot_nba_games'

      belongs_to :home_team, class_name: 'Diderot::NBA::Team'
      belongs_to :away_team, class_name: 'Diderot::NBA::Team'
      belongs_to :league, class_name: 'Diderot::Leagues::Nba'

      has_one :game_log, class_name: 'Diderot::Nba::GameLog', dependent: :nullify

      def full_identifier
        raise NotImplementedError
      end

      def participants = [away_team, home_team]

      # ################## MOVE ALL OF THESE TO A DECORATOR
      # @param [String] salt required for multiple iteration, idea here is that
      # videos should be saved in different folders -> I guess a more sensible option
      # will be the hash_commit as the folder name
      def assets_directory(salt = nil)
        game_digest = Digest::SHA256.hexdigest(log.game_id)
        salt ? game_digest + "_#{salt}" : game_digest
      end

      def full_identifier
        raise NotImplementedError
      end

      # @param [String] context - search context for the video (local returns the local
      # path, :aws returns the s3 path)
      #
      def output_video_path(context: :local, salt: nil)
        case context
        when :local
          assets_directory(salt) + "/#{full_identifier}"
        else
          raise NotImplementedEerror
        end
      end
    end
  end
end

# == Schema Information
#
# Table name: diderot_nba_games
#
#  id                    :bigint           not null, primary key
#  away_timezone         :string
#  broadcast_network     :string
#  home_timezeone        :string
#  scheduled_at          :datetime
#  season_type           :string
#  season_year           :bigint
#  status                :string
#  venue_name            :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  away_team_id          :bigint
#  external_id           :string
#  external_reference_id :string
#  game_log_id           :integer
#  home_team_id          :bigint
#  league_id             :integer
#
# Indexes
#
#  index_diderot_nba_games_on_away_team_id  (away_team_id)
#  index_diderot_nba_games_on_game_log_id   (game_log_id)
#  index_diderot_nba_games_on_home_team_id  (home_team_id)
#
# Foreign Keys
#
#  fk_rails_...  (away_team_id => diderot_nba_teams.id)
#  fk_rails_...  (game_log_id => diderot_nba_game_logs.id) ON DELETE => nullify
#  fk_rails_...  (home_team_id => diderot_nba_teams.id)
#
