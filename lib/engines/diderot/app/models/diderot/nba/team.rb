# frozen_string_literal: true

module Diderot
  module NBA
    class Team < ApplicationRecord
      self.table_name = 'diderot_nba_teams'

      has_many :memberships, class_name: 'Diderot::NBA::TeamMembership'
      has_many :players, through: :memberships
    end
  end
end

# == Schema Information
#
# Table name: diderot_nba_teams
#
#  id          :bigint           not null, primary key
#  logo_url    :string
#  market      :string
#  name        :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  external_id :string
#
