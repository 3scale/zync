# frozen_string_literal: true
class Status::LiveController < ApplicationController
  skip_before_action :authenticate

  def show
    respond_with StatusService.live
  end
end
