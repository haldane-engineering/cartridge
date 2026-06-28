# frozen_string_literal: true

# == Schema Information
#
# Table name: diderot_nba_players
#
#  id          :bigint           not null, primary key
#  first_name  :string
#  last_name   :string
#  photo_url   :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  external_id :integer
#  league_id   :integer
#
module Diderot
  module Nba
    class Player < ApplicationRecord
      self.table_name = 'diderot_nba_players'
    end
  end
end
