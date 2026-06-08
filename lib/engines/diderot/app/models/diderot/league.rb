# frozen_string_literal: true

module Diderot
  class League < ApplicationRecord
    self.table_name = 'diderot_leagues'
  end
end

# == Schema Information
#
# Table name: diderot_leagues
#
#  id          :bigint           not null, primary key
#  logo_base64 :text
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
