# frozen_string_literal: true
class Status::LiveController < ApplicationController
  def show
    respond_with StatusService.live
  end
end
