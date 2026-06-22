# frozen_string_literal: true

module Diderot
  class PlatformDistribution < ApplicationRecord
    self.table_name = 'diderot_platform_distributions'

    belongs_to :resource, polymorphic: true
  end
end

# == Schema Information
#
# Table name: diderot_platform_distributions
#
#  id            :bigint           not null, primary key
#  metadata      :jsonb
#  platform_type :string
#  resource_type :string
#  status        :string
#  url           :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  league_id     :bigint
#  resource_id   :string
#
# Indexes
#
#  index_diderot_platform_distributions_on_league_id  (league_id)
#
# Foreign Keys
#
#  fk_rails_...  (league_id => diderot_leagues.id)
#
