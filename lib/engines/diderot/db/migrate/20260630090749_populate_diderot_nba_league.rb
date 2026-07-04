# frozen_string_literal: true

class PopulateDiderotNbaLeague < ActiveRecord::Migration[6.1]
  def change
    logo_base64 = File.open(File.expand_path('../fixtures/nba.jpg', __dir__), 'rb', &->(img) {
      Base64.strict_encode64(img.read)
    })
    ::Diderot::Leagues::Nba.create!(name: 'National Basketball Association', ticker: 'NBA', logo_base64:, metadata: {})
  end
end
