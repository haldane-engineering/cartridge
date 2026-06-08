# frozen_string_literal: true

module Diderot
  module Leagues
    class Nba < Diderot::League
    end
  end
end

# == Schema Information
#
# Table name: diderot_leagues
#
#  id          :bigint           not null, primary key
#  logo_base64 :text
#  metadata    :jsonb
#  name        :string
#  ticker      :string
#  type        :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_diderot_leagues_on_type  (type)
#
