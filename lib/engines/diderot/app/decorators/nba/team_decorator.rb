# frozen_string_literal: true

# module Diderot
module Nba
  class TeamDecorator < SimpleDecorator
    delegate_all

    def full_name
      @full_name ||= "#{market} #{name}"
    end
  end
end
