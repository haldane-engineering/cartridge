# frozen_string_literal: true

Rails.application.routes.draw do
  mount Diderot::Engine => '/diderot'
end
