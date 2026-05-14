# frozen_string_literal: true

# == Schema Information
#
# Table name: diderot_players
#
#  id         :bigint           not null, primary key
#  first_name :string
#  last_name  :string
#  photo_url  :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
module Diderot
  class Player < ApplicationRecord
    self.table_name = 'diderot_players'
  end
end
