# frozen_string_literal: true
class StatusesController < ApplicationController
  def show
    respond_with StatusService.call
  end
end
