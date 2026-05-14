# frozen_string_literal: true

# == Schema Information
#
# Table name: diderot_teams
#
#  id          :bigint           not null, primary key
#  logo_url    :string
#  market      :string
#  name        :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  external_id :string
#
module Diderot
  class Team < ApplicationRecord
    self.table_name = 'diderot_teams'

    has_many :memberships, class_name: 'Diderot::Teams::Membership'
    has_many :players, through: :memberships
  end
end
