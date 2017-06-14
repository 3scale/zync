# frozen_string_literal: true
class Status::ReadyController < ApplicationController
  def show
    respond_with StatusService.ready
  end
end
