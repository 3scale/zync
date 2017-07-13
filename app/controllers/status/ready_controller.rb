# frozen_string_literal: true
class Status::ReadyController < ApplicationController
  skip_before_action :authenticate

  def show
    respond_with StatusService.ready
  end
end
